"""Offline regressions: replace SDK adapters and context before app imports.
Run from travel_backend: python -m unittest discover -s tests -v
"""
import asyncio
import time
import json
import sys
import types
import unittest
from unittest.mock import patch

# Never import config or SDKs: no credentials or external calls in this suite.
for module_name, class_name, name in [
    ('groq_provider', 'GroqProvider', 'groq'),
    ('gemini_provider', 'GeminiProvider', 'gemini'),
    ('openrouter_provider', 'OpenRouterProvider', 'openrouter'),
]:
    module = types.ModuleType('services.llm_providers.' + module_name)
    async def unavailable(self, *args):
        raise RuntimeError('offline')
    setattr(module, class_name, type(class_name, (), {'name': name, 'generate_json': unavailable}))
    sys.modules[module.__name__] = module

for module_name, function_name in [('weather', 'get_forecast'), ('places', 'get_attractions')]:
    module = types.ModuleType('routers.' + module_name)
    async def context(**kwargs):
        return {}
    setattr(module, function_name, context)
    sys.modules[module.__name__] = module

from services.llm_providers import auto_provider as auto
from services.llm_providers.factory import get_provider
from services.chat_parser import parse_chat
from services.itinerary_builder import build_itinerary
from models.chat import LemonChatRequest
from models.itinerary import TripRequest


def provider(name, output=None, constructor_error=False):
    class Fake:
        calls = 0
        def __init__(self):
            if constructor_error:
                raise RuntimeError('constructor failed')
        async def generate_json(self, *args):
            Fake.calls += 1
            if isinstance(output, Exception):
                raise output
            return output
    Fake.name = name
    return Fake


class AutoTests(unittest.IsolatedAsyncioTestCase):
    def setUp(self):
        auto._cooldown_until.clear()

    def tearDown(self):
        auto._cooldown_until.clear()

    async def test_timeout_cancels_closes_and_tries_next(self):
        cancelled, closed = asyncio.Event(), asyncio.Event()
        class Slow:
            name = 'slow'
            async def generate_json(self, *args):
                try:
                    await asyncio.sleep(10)
                finally:
                    cancelled.set()
            async def aclose(self):
                closed.set()
        with patch.object(auto, '_FALLBACK_ORDER', [Slow, provider('fast', '{}')]):
            engine = auto.AutoProvider()
            result = await engine.generate_json('', '', attempt_timeout=.03, total_timeout=.2)
            await asyncio.wait_for(closed.wait(), .5)
        self.assertEqual(result, '{}')
        self.assertTrue(cancelled.is_set())
        self.assertEqual(engine.name, 'fast')
        self.assertIn('slow', auto._cooldown_until)

    async def test_total_budget_shortens_last_attempt_and_skips_rest(self):
        calls = []
        def slow(name):
            class Slow:
                async def generate_json(self, *args):
                    calls.append(name)
                    await asyncio.sleep(10)
            Slow.name = name
            return Slow
        started = time.monotonic()
        with patch.object(auto, '_FALLBACK_ORDER', [slow('one'), slow('two'), slow('three')]):
            engine = auto.AutoProvider()
            await engine.generate_json('', '', attempt_timeout=.08, total_timeout=.12)
        elapsed = time.monotonic() - started
        self.assertEqual(calls, ['one', 'two'])
        self.assertEqual(engine.name, 'mock')
        self.assertLess(elapsed, .4)
        self.assertNotIn('three', auto._cooldown_until)

    async def test_all_slow_chat_returns_local_reply(self):
        class Slow:
            name = 'slow'
            async def generate_json(self, *args):
                await asyncio.sleep(10)
        original = auto.AutoProvider.generate_json
        async def short_budget(engine, *args, **kwargs):
            self.assertEqual(kwargs['attempt_timeout'], 9.0)
            self.assertEqual(kwargs['total_timeout'], 30.0)
            kwargs.update(attempt_timeout=.02, total_timeout=.06)
            return await original(engine, *args, **kwargs)
        with patch.object(auto, '_FALLBACK_ORDER', [Slow]), patch.object(auto.AutoProvider, 'generate_json', short_budget):
            result = await asyncio.wait_for(parse_chat(LemonChatRequest(provider='auto', messages=[{'role': 'user', 'content': 'Osaka'}])), .5)
        self.assertEqual(result.destination, 'Osaka')
        self.assertEqual(result.next_field, 'start_date')

    async def test_caller_cancellation_does_not_fallback_or_cooldown(self):
        entered, stopped = asyncio.Event(), asyncio.Event()
        class Slow:
            name = 'slow'
            async def generate_json(self, *args):
                entered.set()
                try:
                    await asyncio.sleep(10)
                finally:
                    stopped.set()
        next_provider = provider('next', '{}')
        with patch.object(auto, '_FALLBACK_ORDER', [Slow, next_provider]):
            task = asyncio.create_task(auto.AutoProvider().generate_json('', '', attempt_timeout=9, total_timeout=30))
            await entered.wait()
            task.cancel()
            with self.assertRaises(asyncio.CancelledError):
                await task
            await asyncio.wait_for(stopped.wait(), .5)
        self.assertEqual(next_provider.calls, 0)
        self.assertNotIn('slow', auto._cooldown_until)

    async def test_slow_cancellation_does_not_hold_up_fallback(self):
        finished = asyncio.Event()
        class Reluctant:
            name = 'reluctant'
            async def generate_json(self, *args):
                try:
                    await asyncio.sleep(10)
                except asyncio.CancelledError:
                    await asyncio.sleep(.2)
                    finished.set()
                    return '{}'
        with patch.object(auto, '_FALLBACK_ORDER', [Reluctant]):
            engine = auto.AutoProvider()
            await asyncio.wait_for(engine.generate_json('', '', attempt_timeout=.02, total_timeout=.05), .15)
            self.assertEqual(engine.name, 'mock')
            self.assertFalse(finished.is_set())
            await asyncio.wait_for(finished.wait(), .5)
            self.assertEqual(engine.name, 'mock')

    async def test_cleanup_failure_does_not_discard_success(self):
        class Good:
            name = 'good'
            async def generate_json(self, *args):
                return '{}'
            async def aclose(self):
                raise RuntimeError('cleanup')
        with patch.object(auto, '_FALLBACK_ORDER', [Good]):
            engine = auto.AutoProvider()
            self.assertEqual(await engine.generate_json('', '', attempt_timeout=.1, total_timeout=.2), '{}')
            self.assertEqual(engine.name, 'good')

    async def test_stalled_cleanup_is_bounded(self):
        stopped = asyncio.Event()
        class Good:
            name = 'good'
            async def generate_json(self, *args):
                return '{}'
            async def aclose(self):
                try:
                    await asyncio.sleep(10)
                finally:
                    stopped.set()
        with patch.object(auto, '_FALLBACK_ORDER', [Good]):
            engine = auto.AutoProvider()
            result = await asyncio.wait_for(engine.generate_json('', '', attempt_timeout=1, total_timeout=2), .8)
            await asyncio.wait_for(stopped.wait(), .5)
        self.assertEqual(result, '{}')
        self.assertEqual(engine.name, 'good')

    async def test_itinerary_context_radius_and_prompt(self):
        from services import itinerary_builder as builder
        async def attractions(*, city, radius_km):
            self.assertEqual(city, "Kyoto")
            self.assertEqual(radius_km, 5)
            self.assertIsInstance(radius_km, int)
            return {"attractions": [{"name": "Actual landmark"}]}
        class Capture:
            name = "capture"
            async def generate_json(inner, system, prompt):
                self.assertIn("Actual landmark", prompt)
                return '{"days": []}'
        with patch.object(builder, 'get_attractions', attractions), patch.object(builder, 'get_provider', return_value=Capture()):
            result = await build_itinerary(TripRequest(destination="Kyoto", start_date="2026-11-01", end_date="2026-11-02"))
        self.assertEqual(result.provider_used, "capture")

    async def test_itinerary_slow_context_and_provider_fall_back_within_budget(self):
        from services import itinerary_builder as builder
        started_context = []
        async def slow_context(**kwargs):
            started_context.append(kwargs)
            await asyncio.sleep(10)
        class Slow:
            name = 'slow_plan'
            async def generate_json(self, *args):
                await asyncio.sleep(10)
        original_bound = auto._bounded
        budgets = []
        async def short_bound(request, seconds):
            budgets.append(seconds)
            return await original_bound(request, min(seconds, .02))
        with patch.object(builder, 'get_forecast', slow_context), patch.object(builder, 'get_attractions', slow_context), patch.object(builder, '_bounded', short_bound), patch.object(auto, '_bounded', short_bound), patch.object(auto, '_FALLBACK_ORDER', [Slow]):
            started = time.monotonic()
            result = await build_itinerary(TripRequest(destination='Kyoto', start_date='2026-11-01', end_date='2026-11-02', provider='auto'))
        self.assertEqual(result.provider_used, 'mock')
        self.assertEqual(len(started_context), 2)
        self.assertEqual(budgets[:2], [10.0, 10.0])
        self.assertIn(12.0, budgets)
        self.assertLess(time.monotonic() - started, .5)

    async def test_itinerary_auto_uses_total_budget(self):
        from services import itinerary_builder as builder
        from unittest.mock import AsyncMock
        engine = auto.AutoProvider()
        engine.generate_json = AsyncMock(return_value='{"days": []}')
        with patch.object(builder, 'get_provider', return_value=engine):
            await build_itinerary(TripRequest(destination='Kyoto', start_date='2026-11-01', end_date='2026-11-02', provider='auto'))
        self.assertEqual(engine.generate_json.call_args.kwargs['total_timeout'], 36.0)
        self.assertEqual(engine.generate_json.call_args.kwargs['attempt_timeout'], 12.0)

    async def test_factory(self):
        self.assertIsInstance(get_provider('AUTO'), auto.AutoProvider)
        self.assertEqual(get_provider('mock').name, 'mock')
        with self.assertRaises(ValueError):
            get_provider('unknown')

    async def test_diagnostics_redact_validation_input(self):
        from services.llm_providers.diagnostics import error_details
        from models.chat import LemonChatResponse
        from pydantic import ValidationError
        try:
            LemonChatResponse(reply='private conversation', interests=None)
        except ValidationError as exc:
            details = error_details(exc)
        self.assertEqual(details['validation'], [{'field': 'interests', 'type': 'list_type'}])
        self.assertNotIn('private conversation', str(details))
        failure = RuntimeError('secret request and key')
        failure.code = 404
        self.assertEqual(error_details(failure), {'error_type': 'RuntimeError', 'status': 404, 'reason': 'not_found'})

    async def test_diagnostics_identify_stage(self):
        with patch.object(auto, '_FALLBACK_ORDER', [provider('bad', '{"interests": null, "reply": "private"}')]):
            with self.assertLogs('lemon_ai', level='INFO') as logs:
                await parse_chat(LemonChatRequest(provider='auto', messages=[]))
        output = ' '.join(logs.output)
        self.assertIn('stage=response_validation', output)
        self.assertIn('interests', output)
        self.assertNotIn('private', output)

    async def test_constructor_call_and_json_failures(self):
        candidates = [provider('constructor', constructor_error=True),
                      provider('call', RuntimeError('failed')),
                      provider('json', 'not json'), provider('ok', '{}'),
                      provider('unused', '{}')]
        with patch.object(auto, '_FALLBACK_ORDER', candidates):
            engine = get_provider('auto')
            self.assertEqual(await engine.generate_json('', ''), '{}')
        self.assertEqual(engine.name, 'ok')
        self.assertEqual(candidates[-1].calls, 0)
        self.assertEqual(set(auto._cooldown_until), {'constructor', 'call', 'json'})

    async def test_cooldown_skips_then_expires(self):
        candidate = provider('retry', RuntimeError('failed'))
        with patch.object(auto, '_FALLBACK_ORDER', [candidate]), patch.object(auto.time, 'monotonic', return_value=100):
            await get_provider('auto').generate_json('', '')
            await get_provider('auto').generate_json('', '')
            self.assertEqual(candidate.calls, 1)
        with patch.object(auto, '_FALLBACK_ORDER', [candidate]), patch.object(auto.time, 'monotonic', return_value=401):
            await get_provider('auto').generate_json('', '')
            self.assertEqual(candidate.calls, 2)

    async def test_chat_rejects_wrong_schema_then_succeeds(self):
        with patch.object(auto, '_FALLBACK_ORDER', [provider('bad', '{"days": []}'), provider('good', '{"reply": "Hello", "next_field": "destination"}')]):
            result = await parse_chat(LemonChatRequest(provider='auto', messages=[]))
        self.assertEqual(result.reply, 'Hello')
        self.assertIn('bad', auto._cooldown_until)

    async def test_chat_exhaustion_matches_explicit_mock(self):
        messages = [{'role': 'user', 'content': value} for value in
                    ['Kyoto', '2026-11-01', '2026-11-03', '2', 'medium', 'food']]
        with patch.object(auto, '_FALLBACK_ORDER', [provider('bad', RuntimeError())]):
            result = await parse_chat(LemonChatRequest(provider='auto', messages=messages))
        expected = await parse_chat(LemonChatRequest(provider='mock', messages=messages))
        self.assertEqual(result, expected)
        self.assertEqual(result.next_field, 'confirm')
        self.assertEqual(result.destination, 'Kyoto')

    async def test_plan_validation_and_actual_provider(self):
        trip = TripRequest(destination='Kyoto', start_date='2026-11-01', end_date='2026-11-03', provider='auto')
        with patch.object(auto, '_FALLBACK_ORDER', [provider('bad', '[]'), provider('schema', '{"days": "wrong"}'), provider('good', '{"days": []}')]):
            result = await build_itinerary(trip)
        self.assertEqual(result.provider_used, 'good')
        self.assertEqual(result.destination, 'Kyoto')
        with patch.object(auto, '_FALLBACK_ORDER', []):
            result = await build_itinerary(trip)
        self.assertEqual(result.provider_used, 'mock')
        self.assertIn('mock', result.summary)

    async def test_mock_validation_failure_is_not_hidden(self):
        with patch.object(auto, '_FALLBACK_ORDER', []):
            with self.assertRaises(json.JSONDecodeError):
                await get_provider('auto').generate_json('', '', mock_fallback=lambda: 'invalid')

    async def test_http_routes(self):
        from fastapi import FastAPI
        from fastapi.testclient import TestClient
        from routers.lemon import router
        app = FastAPI()
        app.include_router(router)
        with patch.object(auto, '_FALLBACK_ORDER', []), TestClient(app) as client:
            chat = client.post('/lemon/chat', json={'provider': 'auto', 'messages': []})
            self.assertEqual(chat.status_code, 200)
            self.assertEqual(chat.json()['next_field'], 'destination')
            plan = client.post('/lemon/plan', json={'provider': 'auto', 'destination': 'Kyoto', 'start_date': '2026-11-01', 'end_date': '2026-11-03'})
            self.assertEqual(plan.status_code, 200)
            self.assertEqual(plan.json()['provider_used'], 'mock')
            self.assertEqual(client.post('/lemon/chat', json={'provider': 'unknown', 'messages': []}).status_code, 502)


if __name__ == '__main__':
    unittest.main()
