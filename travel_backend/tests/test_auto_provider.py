"""Offline regressions: replace SDK adapters and context before app imports.
Run from travel_backend: python -m unittest discover -s tests -v
"""
import asyncio
import time
import json
import sys
import threading
import types
import unittest
from datetime import datetime, timedelta, timezone
from email.utils import format_datetime
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


def complete_plan(count=2):
    return json.dumps({"days": [{"day": i + 1, "date": f"2026-11-{i+1:02}",
        "activities": [{"time": "09:00", "activity": "Walk"}]} for i in range(count)]})


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


def window_reply(prompt):
    """Valid JSON for exactly the days a window prompt asks for."""
    import re
    pairs = re.findall(r'(\d+): (\d{4}-\d{2}-\d{2})', prompt.split('Generate ONLY')[1])
    return json.dumps({'days': [{'day': int(number), 'date': day,
        'activities': [{'time': '09:00', 'activity': 'Explore'}]} for number, day in pairs]})


def streamer(name, pieces, gap=0, stall_after=None, first_delay=0, error=None, on_close=None):
    """Fake streaming provider: yields `pieces` `gap` seconds apart, optionally stalling."""
    class Streamer:
        generate_calls = 0
        async def stream_text(self, system, user):
            try:
                if first_delay:
                    await asyncio.sleep(first_delay)
                if error is not None:
                    raise error
                for i, piece in enumerate(pieces):
                    if gap and i:
                        await asyncio.sleep(gap)
                    yield piece
                    if stall_after is not None and i + 1 >= stall_after:
                        await asyncio.sleep(10)  # Goes silent.
            finally:
                if on_close is not None:
                    on_close()
        async def generate_json(self, system, user):
            Streamer.generate_calls += 1
            return ''.join(pieces)
    Streamer.name = name
    return Streamer


class FakeOpenAIClient:
    """Stands in for AsyncOpenAI: create(stream=True) returns chunked deltas."""
    def __init__(self, pieces, include_empty_chunk=False):
        self.pieces, self.include_empty_chunk = pieces, include_empty_chunk
        self.kwargs, self.closed = None, False
        self.chat = types.SimpleNamespace(completions=types.SimpleNamespace(create=self._create))

    async def _create(self, **kwargs):
        self.kwargs = kwargs
        client = self
        class Stream:
            response = types.SimpleNamespace(aclose=client._close_response)
            async def __aiter__(self):
                if client.include_empty_chunk:
                    yield types.SimpleNamespace(choices=[])  # e.g. a usage-only chunk
                for piece in client.pieces:
                    delta = types.SimpleNamespace(content=piece)
                    yield types.SimpleNamespace(choices=[types.SimpleNamespace(delta=delta)])
        return Stream()

    async def _close_response(self):
        self.closed = True

    async def close(self):
        pass


def load_real_adapter(module_name):
    """Load a real provider adapter against fake SDK/config modules (never the real config)."""
    import importlib.util
    import pathlib
    created = []
    class AsyncOpenAI:
        def __init__(self, **kwargs):
            created.append(kwargs)
        async def close(self):
            pass
    fake_openai = types.ModuleType('openai')
    fake_openai.AsyncOpenAI = AsyncOpenAI
    fake_config = types.ModuleType('config')
    fake_config.settings = types.SimpleNamespace(**{key: 'test' for key in [
        'GROQ_API_KEY', 'GROQ_BASE_URL', 'GROQ_MODEL', 'OPENROUTER_API_KEY', 'OPENROUTER_BASE_URL',
        'OPENROUTER_MODEL', 'GEMINI_API_KEY', 'GEMINI_MODEL']})
    fake_types = types.ModuleType('google.genai.types')
    fake_types.GenerateContentConfig = lambda **kwargs: kwargs
    fake_genai = types.ModuleType('google.genai')
    fake_genai.Client = lambda **kwargs: None
    fake_genai.types = fake_types
    fake_google = types.ModuleType('google')
    fake_google.genai = fake_genai
    path = pathlib.Path(__file__).resolve().parents[1] / 'services' / 'llm_providers' / f'{module_name}.py'
    with patch.dict(sys.modules, {'openai': fake_openai, 'config': fake_config, 'google': fake_google,
                                  'google.genai': fake_genai, 'google.genai.types': fake_types}):
        spec = importlib.util.spec_from_file_location(f'services.llm_providers._real_{module_name}', path)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
    return module, created


def status_error(status, headers=None, attr='status_code'):
    """Fake SDK error: OpenAI-style (status_code) or genai-style (code), with response headers."""
    exc = RuntimeError('provider error')
    setattr(exc, attr, status)
    exc.response = types.SimpleNamespace(headers=dict(headers or {}))
    return exc


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
        # A per-attempt timeout is transient: short cooldown, not five minutes.
        self.assertAlmostEqual(auto._cooldown_until['slow'] - time.monotonic(), 30, delta=1)

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
        # 'one' hit its own attempt limit; 'two' was cut only by the shared budget.
        self.assertAlmostEqual(auto._cooldown_until['one'] - time.monotonic(), 30, delta=1)
        self.assertNotIn('two', auto._cooldown_until)

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
                return complete_plan()
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
        # No fixed per-attempt cap any more: the attempt is bounded by the window budget.
        self.assertNotIn(25.0, budgets)
        self.assertTrue(any(74.0 < value <= 75.0 for value in budgets[2:]), budgets)
        self.assertLess(time.monotonic() - started, .5)

    async def test_itinerary_auto_uses_total_budget(self):
        from services import itinerary_builder as builder
        from unittest.mock import AsyncMock
        engine = auto.AutoProvider()
        engine.generate_json = AsyncMock(return_value=complete_plan())
        with patch.object(builder, 'get_provider', return_value=engine):
            await build_itinerary(TripRequest(destination='Kyoto', start_date='2026-11-01', end_date='2026-11-02', provider='auto'))
        self.assertLessEqual(engine.generate_json.call_args.kwargs['total_timeout'], 75.0)
        self.assertGreater(engine.generate_json.call_args.kwargs['total_timeout'], 74.0)
        kwargs = engine.generate_json.call_args.kwargs
        self.assertIsNone(kwargs.get('attempt_timeout'))
        self.assertEqual(kwargs['idle_timeout'], 10.0)
        self.assertEqual(kwargs['first_chunk_timeout'], 25.0)

    async def test_generation_budget_scales_with_waves(self):
        from services.itinerary_builder import generation_budget_seconds
        # 3-day windows, 3 at a time: 1-9 days = 1 wave, 10-18 = 2, 19-27 = 3, 28-30 = 4.
        for days, budget in [(1, 75), (3, 75), (9, 75), (10, 150), (18, 150), (19, 225), (27, 225), (28, 300), (30, 300)]:
            with self.subTest(days=days):
                self.assertEqual(generation_budget_seconds(days), budget)

    async def test_every_window_of_long_trip_gets_full_wave_budget(self):
        from services import itinerary_builder as builder
        from unittest.mock import AsyncMock
        engine = auto.AutoProvider()
        engine.generate_json = AsyncMock(side_effect=lambda system, prompt, **kw: window_reply(prompt))
        with patch.object(builder, 'get_provider', return_value=engine):
            result = await build_itinerary(TripRequest(destination='Kyoto', start_date='2026-11-01', end_date='2026-11-30', provider='auto'))
        budgets = [call.kwargs['total_timeout'] for call in engine.generate_json.call_args_list]
        self.assertEqual(len(budgets), 10)
        self.assertTrue(all(74.0 < value <= 75.0 for value in budgets), budgets)
        self.assertEqual(len(result.days), 30)

    async def test_later_waves_are_not_starved_by_earlier_ones(self):
        from services import itinerary_builder as builder
        class SteadyWindow:
            name = 'steady'
            async def generate_json(self, system, prompt):
                await asyncio.sleep(.12)  # Slower than half a wave, faster than a full one.
                return window_reply(prompt)
        # 12 days = 4 windows = 2 waves. With the old flat budget the second wave
        # would start with only ~.08 s left and fall back to mock.
        with patch.object(builder, 'WAVE_BUDGET_SECONDS', .2), patch.object(auto, '_FALLBACK_ORDER', [SteadyWindow]):
            result = await build_itinerary(TripRequest(destination='Kyoto', start_date='2026-11-01', end_date='2026-11-12', provider='auto'))
        self.assertEqual(result.provider_used, 'steady')
        self.assertEqual([d.day for d in result.days], list(range(1, 13)))

    async def test_overall_plan_cap_still_bounds_each_window(self):
        from services import itinerary_builder as builder
        from unittest.mock import AsyncMock
        engine = auto.AutoProvider()
        engine.generate_json = AsyncMock(side_effect=lambda system, prompt, **kw: window_reply(prompt))
        with patch.object(builder, 'get_provider', return_value=engine), patch.object(builder, 'generation_budget_seconds', return_value=5.0):
            await build_itinerary(TripRequest(destination='Kyoto', start_date='2026-11-01', end_date='2026-11-12', provider='auto'))
        self.assertTrue(all(call.kwargs['total_timeout'] <= 5.0 for call in engine.generate_json.call_args_list))

    async def test_long_real_plan_combines_out_of_order_windows(self):
        from services import itinerary_builder as builder
        import re
        active = 0
        peak = 0
        class WindowProvider:
            name = 'fixture'
            async def generate_json(self, system, prompt):
                nonlocal active, peak
                pairs = re.findall(r'(\d+): (2026-11-\d+)', prompt.split('Generate ONLY')[1])
                active += 1
                peak = max(peak, active)
                await asyncio.sleep(.005 if pairs[0][0] == '1' else .001)
                active -= 1
                return json.dumps({'days': [{'day':int(number),'date':day,
                    'activities':[{'time':'09:00','activity':'Explore'}]} for number, day in pairs]})
        with patch.object(builder,'get_provider',side_effect=lambda _: WindowProvider()):
            result = await build_itinerary(TripRequest(destination='Kyoto',start_date='2026-11-01',end_date='2026-11-11',provider='groq'))
        self.assertEqual([d.day for d in result.days],list(range(1,12)))
        self.assertEqual(result.provider_used,'fixture')
        self.assertLessEqual(peak,3)

    async def test_long_trip_has_all_thirty_days(self):
        result = await build_itinerary(TripRequest(destination='Kyoto', start_date='2026-11-01', end_date='2026-11-30', provider='mock'))
        self.assertEqual([d.day for d in result.days], list(range(1,31)))
        self.assertEqual([d.date for d in result.days], [f'2026-11-{i:02}' for i in range(1,31)])
        self.assertTrue(all(d.activities for d in result.days))
        self.assertEqual(result.provider_used, 'mock')

    async def test_partial_plan_retries_then_fails(self):
        from services import itinerary_builder as builder
        fake = provider('partial', complete_plan(1))()
        with patch.object(builder, 'get_provider', return_value=fake):
            with self.assertRaisesRegex(ValueError, 'Incomplete itinerary'):
                await build_itinerary(TripRequest(destination='Kyoto', start_date='2026-11-01', end_date='2026-11-03', provider='groq'))
        self.assertEqual(fake.calls, 2)

    async def test_missing_date_and_empty_activities_are_rejected(self):
        from services import itinerary_builder as builder
        for days in [
            [{'day': 1, 'date': None, 'activities': [{'time':'09:00','activity':'Walk'}]}],
            [{'day': 1, 'date': '2026-11-01', 'activities': []}],
        ]:
            with patch.object(builder, 'get_provider', return_value=provider('invalid', json.dumps({'days': days}))()):
                with self.assertRaises(ValueError):
                    await build_itinerary(TripRequest(destination='Kyoto', start_date='2026-11-01', end_date='2026-11-01', provider='groq'))

    async def test_mock_rejects_noise_then_accepts_unicode_destination(self):
        from services.chat_parser import _mock_parse
        from models.chat import ChatTurn
        for text in ['asdfghjkl', '!!!!!!', 'aaaaaaa', 'write me code']:
            result = _mock_parse([ChatTurn(role='user',content=text)])
            self.assertIsNone(result.destination)
            self.assertFalse(result.ready)
            result = _mock_parse([ChatTurn(role='user',content=text), ChatTurn(role='user',content='京都')])
            self.assertEqual(result.destination,'京都')

    # ---- Step 3: streaming with an inactivity timeout -------------------------

    async def test_slow_but_steady_stream_succeeds(self):
        # 20 chunks, .03 s apart: 0.6 s in total, far beyond the .08 s idle limit.
        reply = json.dumps({'reply': 'x' * 40})
        pieces = [reply[i:i + 3] for i in range(0, len(reply), 3)]
        with patch.object(auto, '_FALLBACK_ORDER', [streamer('steady', pieces, gap=.03), provider('next', '{}')]):
            engine = auto.AutoProvider()
            result = await engine.generate_json('', '', total_timeout=5, idle_timeout=.08)
        self.assertEqual(result, reply)  # Same complete raw JSON string as non-streaming.
        self.assertEqual(engine.name, 'steady')
        self.assertNotIn('steady', auto._cooldown_until)

    async def test_stalled_stream_is_cut_off_and_next_provider_runs(self):
        closed = asyncio.Event()
        stalled = streamer('stalled', ['{"re', 'ply"'], gap=.01, stall_after=2, on_close=closed.set)
        started = time.monotonic()
        with patch.object(auto, '_FALLBACK_ORDER', [stalled, provider('next', '{}')]):
            with self.assertLogs('lemon_ai', level='WARNING') as logs:
                engine = auto.AutoProvider()
                result = await engine.generate_json('', '', total_timeout=5, idle_timeout=.08)
        self.assertLess(time.monotonic() - started, 1)
        self.assertEqual((result, engine.name), ('{}', 'next'))
        await asyncio.wait_for(closed.wait(), .5)  # Stream released.
        self.assertIn('failure=stalled cooldown=30', ' '.join(logs.output))
        self.assertAlmostEqual(auto._cooldown_until['stalled'] - time.monotonic(), 30, delta=1)

    async def test_empty_chunks_count_as_activity(self):
        # Reasoning/role chunks carry no answer text but prove the provider is alive.
        pieces = [''] * 15 + ['{}']
        with patch.object(auto, '_FALLBACK_ORDER', [streamer('thinking', pieces, gap=.03)]):
            engine = auto.AutoProvider()
            self.assertEqual(await engine.generate_json('', '', total_timeout=5, idle_timeout=.08), '{}')
        self.assertEqual(engine.name, 'thinking')

    async def test_first_chunk_gets_its_own_allowance(self):
        late = streamer('late', ['{}'], first_delay=.15)
        with patch.object(auto, '_FALLBACK_ORDER', [late]):
            engine = auto.AutoProvider()
            await engine.generate_json('', '', total_timeout=5, idle_timeout=.05, first_chunk_timeout=.3)
        self.assertEqual(engine.name, 'late')
        silent = streamer('silent', ['{}'], first_delay=10)
        with patch.object(auto, '_FALLBACK_ORDER', [silent]):
            engine = auto.AutoProvider()
            await asyncio.wait_for(engine.generate_json('', '', total_timeout=5, idle_timeout=.05, first_chunk_timeout=.1), 1)
        self.assertEqual(engine.name, 'mock')
        self.assertIn('silent', auto._cooldown_until)

    async def test_steady_stream_still_bounded_by_total_budget(self):
        endless = streamer('endless', ['x'] * 1000, gap=.01)
        with patch.object(auto, '_FALLBACK_ORDER', [endless, provider('next', '{}')]):
            engine = auto.AutoProvider()
            started = time.monotonic()
            await engine.generate_json('', '', total_timeout=.15, idle_timeout=.08)
        self.assertLess(time.monotonic() - started, .5)
        self.assertEqual(engine.name, 'mock')  # Budget used up: no further provider tried.
        self.assertNotIn('endless', auto._cooldown_until)

    async def test_stream_errors_keep_their_classification(self):
        failing = streamer('limited', [], error=status_error(429, {'retry-after': '9'}))
        with patch.object(auto, '_FALLBACK_ORDER', [failing]), patch.object(auto.time, 'monotonic', return_value=1000):
            await auto.AutoProvider().generate_json('', '', idle_timeout=5)
        self.assertEqual(auto._cooldown_until['limited'], 1009)

    async def test_without_idle_timeout_streamers_use_generate_json(self):
        quiet = streamer('chat', ['{}'])
        with patch.object(auto, '_FALLBACK_ORDER', [quiet]):
            engine = auto.AutoProvider()
            await engine.generate_json('', '', attempt_timeout=1, total_timeout=2)
        self.assertEqual((engine.name, quiet.generate_calls), ('chat', 1))

    async def test_itinerary_window_streams_past_old_attempt_limit(self):
        from services import itinerary_builder as builder
        class SlowWindow:
            name = 'slow_stream'
            async def stream_text(self, system, prompt):
                reply = window_reply(prompt)
                for i in range(0, len(reply), 20):
                    await asyncio.sleep(.02)
                    yield reply[i:i + 20]
        # Old rules (scaled down): a .1 s attempt cap would cut this ~.2-.3 s stream.
        with patch.object(builder, 'STREAM_IDLE_SECONDS', .1), patch.object(builder, 'STREAM_FIRST_CHUNK_SECONDS', .1), \
                patch.object(builder, 'WAVE_BUDGET_SECONDS', 2), patch.object(auto, '_FALLBACK_ORDER', [SlowWindow]):
            result = await build_itinerary(TripRequest(destination='Kyoto', start_date='2026-11-01', end_date='2026-11-03', provider='auto'))
        self.assertEqual(result.provider_used, 'slow_stream')
        self.assertEqual([d.day for d in result.days], [1, 2, 3])

    async def test_openai_compatible_stream_joins_text_and_closes(self):
        from services.llm_providers.openai_stream import collect, stream_chat_json
        client = FakeOpenAIClient(['{"a"', None, ': 1}'], include_empty_chunk=True)
        result = await collect(stream_chat_json(client, 'model-x', 'sys', 'user'))
        self.assertEqual(result, '{"a": 1}')
        self.assertTrue(client.kwargs['stream'])
        self.assertEqual(client.kwargs['response_format'], {'type': 'json_object'})
        self.assertEqual(client.kwargs['model'], 'model-x')
        self.assertTrue(client.closed)

    async def test_openai_compatible_adapters_stream_without_sdk_retries(self):
        for module_name, class_name in [('groq_provider', 'GroqProvider'), ('openrouter_provider', 'OpenRouterProvider')]:
            with self.subTest(module_name):
                module, created = load_real_adapter(module_name)
                instance = getattr(module, class_name)()
                self.assertEqual(created[-1]['max_retries'], 0)
                instance._client = FakeOpenAIClient(['{"ok"', ': true}'])
                self.assertEqual(await instance.generate_json('s', 'u'), '{"ok": true}')
                self.assertTrue(instance._client.kwargs['stream'])

    async def test_gemini_stream_runs_off_the_event_loop(self):
        module, _ = load_real_adapter('gemini_provider')
        def blocking_chunks(**kwargs):
            for piece in ['{"days"', ': ', '[]}']:
                time.sleep(.05)  # Blocking I/O, as in google-genai 0.3.0.
                yield types.SimpleNamespace(text=piece)
            yield types.SimpleNamespace(text=None)
        ticks = 0
        async def ticker():
            nonlocal ticks
            while True:
                await asyncio.sleep(.01)
                ticks += 1
        gemini = module.GeminiProvider()
        gemini._client = types.SimpleNamespace(models=types.SimpleNamespace(generate_content_stream=blocking_chunks))
        tick_task = asyncio.create_task(ticker())
        try:
            self.assertEqual(await gemini.generate_json('s', 'u'), '{"days": []}')
        finally:
            tick_task.cancel()
        self.assertGreater(ticks, 5)  # The loop kept running while the SDK blocked.

    async def test_gemini_stall_is_cut_off_without_freezing(self):
        module, _ = load_real_adapter('gemini_provider')
        release = threading.Event()
        def stalls(**kwargs):
            yield types.SimpleNamespace(text='{"da')
            release.wait(5)  # A dead connection that never sends more.
            yield types.SimpleNamespace(text='ys": []}')
        class StalledGemini(module.GeminiProvider):
            def __init__(self):
                super().__init__()
                self._client = types.SimpleNamespace(models=types.SimpleNamespace(generate_content_stream=stalls))
        try:
            with patch.object(auto, '_FALLBACK_ORDER', [StalledGemini, provider('next', '{}')]):
                engine = auto.AutoProvider()
                started = time.monotonic()
                result = await engine.generate_json('', '', total_timeout=5, idle_timeout=.1)
            self.assertLess(time.monotonic() - started, 1)
            self.assertEqual((result, engine.name), ('{}', 'next'))
            self.assertIn('gemini', auto._cooldown_until)
        finally:
            release.set()

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

    async def _cooldown_after(self, error=None, output=None):
        """Run one failing candidate at a fixed clock; return its cooldown length."""
        candidate = provider('p', error if error is not None else output)
        with patch.object(auto, '_FALLBACK_ORDER', [candidate]), patch.object(auto.time, 'monotonic', return_value=1000):
            engine = auto.AutoProvider()
            await engine.generate_json('', '')
        self.assertEqual(engine.name, 'mock')
        return auto._cooldown_until.pop('p', 1000) - 1000

    async def test_hard_failures_keep_five_minute_cooldown(self):
        for status in (401, 403, 404, 503):
            with self.subTest(status=status):
                self.assertEqual(await self._cooldown_after(status_error(status)), 300)
        with self.subTest('missing key'):
            self.assertEqual(await self._cooldown_after(ValueError('GROQ_API_KEY is not set')), 300)
        with self.subTest('genai-style code'):
            self.assertEqual(await self._cooldown_after(status_error(503, attr='code')), 300)

    async def test_invalid_output_gets_short_cooldown(self):
        self.assertEqual(await self._cooldown_after(output='not json'), 30)
        with patch.object(auto, '_FALLBACK_ORDER', [provider('bad', '{"days": []}')]):
            await parse_chat(LemonChatRequest(provider='auto', messages=[]))
        self.assertAlmostEqual(auto._cooldown_until['bad'] - time.monotonic(), 30, delta=1)

    async def test_sdk_timeout_error_gets_short_cooldown(self):
        class APITimeoutError(Exception):
            pass
        self.assertEqual(await self._cooldown_after(APITimeoutError()), 30)

    async def test_rate_limit_honours_retry_after(self):
        self.assertEqual(await self._cooldown_after(status_error(429, {'retry-after': '12'})), 12)
        self.assertEqual(await self._cooldown_after(status_error(429, {'retry-after-ms': '2500'})), 2.5)
        self.assertEqual(await self._cooldown_after(status_error(429, {'retry-after': '12'}, attr='code')), 12)
        when = format_datetime(datetime.now(timezone.utc) + timedelta(seconds=120), usegmt=True)
        self.assertAlmostEqual(await self._cooldown_after(status_error(429, {'retry-after': when})), 120, delta=2)

    async def test_rate_limit_without_usable_retry_after(self):
        self.assertEqual(await self._cooldown_after(status_error(429)), 300)
        self.assertEqual(await self._cooldown_after(status_error(429, {'retry-after': 'soon'})), 300)
        self.assertEqual(await self._cooldown_after(status_error(429, {'retry-after': '86400'})), 3600)
        self.assertEqual(await self._cooldown_after(status_error(429, {'retry-after': '0'})), 1)

    async def test_short_cooldown_expires_and_retries(self):
        candidate = provider('flaky', 'not json')
        with patch.object(auto, '_FALLBACK_ORDER', [candidate]), patch.object(auto.time, 'monotonic', return_value=100):
            await get_provider('auto').generate_json('', '')
            await get_provider('auto').generate_json('', '')
            self.assertEqual(candidate.calls, 1)
        with patch.object(auto, '_FALLBACK_ORDER', [candidate]), patch.object(auto.time, 'monotonic', return_value=131):
            await get_provider('auto').generate_json('', '')
            self.assertEqual(candidate.calls, 2)

    async def test_failure_log_names_kind_and_cooldown(self):
        with patch.object(auto, '_FALLBACK_ORDER', [provider('limited', status_error(429, {'retry-after': '7'}))]):
            with self.assertLogs('lemon_ai', level='WARNING') as logs:
                await auto.AutoProvider().generate_json('', '')
        output = ' '.join(logs.output)
        self.assertIn('failure=rate_limit cooldown=7', output)
        self.assertNotIn('retry-after', output)

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
        with patch.object(auto, '_FALLBACK_ORDER', [provider('bad', '[]'), provider('schema', '{"days": "wrong"}'), provider('good', complete_plan(3))]):
            result = await build_itinerary(trip)
        self.assertEqual(result.provider_used, 'good')
        self.assertEqual(result.destination, 'Kyoto')
        with patch.object(auto, '_FALLBACK_ORDER', []):
            result = await build_itinerary(trip)
        self.assertEqual(result.provider_used, 'mock')
        self.assertIn('demo', result.summary)

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
            failed = client.post('/lemon/chat', json={'provider': 'unknown', 'messages': []})
            self.assertEqual(failed.status_code, 502)
            self.assertNotIn('unknown', failed.json()['detail'])  # no exception text leaks
            with patch('routers.lemon.build_itinerary', side_effect=RuntimeError('secret prompt text')):
                broken = client.post('/lemon/plan', json={'provider': 'auto', 'destination': 'Kyoto', 'start_date': '2026-11-01', 'end_date': '2026-11-03'})
            self.assertEqual(broken.status_code, 502)
            self.assertNotIn('secret', broken.json()['detail'])
            for messages in ([{'role': 'system', 'content': 'hi'}],
                             [{'role': 'user', 'content': 'x' * 2001}],
                             [{'role': 'user', 'content': 'hi'}] * 101):
                self.assertEqual(client.post('/lemon/chat', json={'provider': 'mock', 'messages': messages}).status_code, 422)


if __name__ == '__main__':
    unittest.main()
