"""Ordered fallback with guarded construction and caller-specific validation.

Failures cool real providers down for five minutes within this process. The
last resort is demo itinerary JSON, or a caller-supplied local chat fallback.
"""
import asyncio
import json
import logging
import time
from typing import Callable, Dict, Optional

from .base import LLMProvider
from .groq_provider import GroqProvider
from .gemini_provider import GeminiProvider
from .openrouter_provider import OpenRouterProvider
from .mock_provider import MockProvider
from .diagnostics import error_details

logger = logging.getLogger("lemon_ai")
_FALLBACK_ORDER = [GroqProvider, GeminiProvider, OpenRouterProvider]
_COOLDOWN_SECONDS = 5 * 60
_cooldown_until: Dict[str, float] = {}
_pending_tasks = set()


def _finish_task(task):
    _pending_tasks.discard(task)
    if not task.cancelled():
        task.exception()  # Retrieve late failures without logging response contents.


async def _bounded(awaitable, seconds):
    """Bound caller waiting even if an SDK is slow to acknowledge cancellation."""
    task = asyncio.create_task(awaitable)
    _pending_tasks.add(task)
    task.add_done_callback(_finish_task)
    try:
        done, _ = await asyncio.wait({task}, timeout=seconds)
        if not done:
            raise asyncio.TimeoutError()
        return task.result()
    finally:
        if not task.done():
            task.cancel()


class AutoProvider(LLMProvider):
    name = "auto"

    async def generate_json(
        self, system_prompt: str, user_prompt: str, *,
        validate: Optional[Callable[[str], object]] = None,
        mock_fallback: Optional[Callable[[], str]] = None,
        attempt_timeout: Optional[float] = None,
        total_timeout: Optional[float] = None,
    ) -> str:
        self.name = "auto"
        validate = validate or json.loads
        deadline = time.monotonic() + total_timeout if total_timeout is not None else None
        for provider_cls in _FALLBACK_ORDER:
            remaining = deadline - time.monotonic() if deadline is not None else None
            if remaining is not None and remaining <= 0:
                logger.warning("Auto real-provider budget exhausted; using local fallback")
                break
            if _cooldown_until.get(provider_cls.name, 0) > time.monotonic():
                logger.info("Auto provider %s skipped: cooldown", provider_cls.name)
                continue
            started = time.monotonic()
            state = {"stage": "construction"}
            logger.info("Auto provider %s starting", provider_cls.name)
            async def attempt(cls=provider_cls, state=state):
                provider = cls()
                try:
                    state["stage"] = "generation"
                    result = await provider.generate_json(system_prompt, user_prompt)
                    state["stage"] = "response_validation"
                    validate(result)
                    return result
                finally:
                    close = getattr(provider, "aclose", None)
                    if close is not None:
                        try:
                            await _bounded(close(), 0.25)
                        except Exception as exc:
                            logger.warning("Auto client cleanup failed (%s)", type(exc).__name__)
            try:
                limits = [value for value in (attempt_timeout, remaining) if value is not None]
                result = await _bounded(attempt(), min(limits)) if limits else await attempt()
            except Exception as exc:
                # SDK exception text can contain request details; log only its type.
                logger.warning("Auto provider %s failed stage=%s elapsed=%.2fs details=%s; cooldown=%ss",
                               provider_cls.name, state["stage"], time.monotonic() - started,
                               error_details(exc), _COOLDOWN_SECONDS)
                _cooldown_until[provider_cls.name] = time.monotonic() + _COOLDOWN_SECONDS
                if (isinstance(exc, asyncio.TimeoutError) and remaining is not None
                        and (attempt_timeout is None or remaining <= attempt_timeout)):
                    # Timer resolution may wake just before the monotonic deadline.
                    # This attempt already consumed its allocated remaining budget.
                    deadline = 0.0
                continue
            _cooldown_until.pop(provider_cls.name, None)
            self.name = provider_cls.name
            logger.info("Auto provider %s succeeded elapsed=%.2fs", provider_cls.name, time.monotonic() - started)
            return result

        logger.warning("Auto providers unavailable; using local mock/demo fallback")
        result = (mock_fallback() if mock_fallback is not None else
                  await MockProvider().generate_json(system_prompt, user_prompt))
        validate(result)
        self.name = "mock"
        return result
