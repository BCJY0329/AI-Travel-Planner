"""Ordered fallback with guarded construction and caller-specific validation.

Failed providers are skipped for a cooldown within this process. Hard failures
(auth/missing key, 404, construction, other call errors) cool down for five
minutes; 429 honours Retry-After (capped at one hour). Slowness, bad output and
503 "unavailable" are treated as transient: a per-attempt timeout, an
invalid/incomplete reply or a 503 cools down for 30 seconds, and a timeout caused only by the caller's shared
budget running out adds no cooldown. The last resort is demo itinerary JSON, or
a caller-supplied local chat fallback.

`attempt_provider` is one bounded, validated call to one provider. AutoProvider
uses it for single replies (chat); itinerary_builder uses it to give one
provider every window of a plan and restart with the next on any failure.
"""
import asyncio
import json
import logging
import math
import time
from datetime import datetime, timezone
from email.utils import parsedate_to_datetime
from typing import Callable, Dict, Optional

from .base import LLMProvider
from .groq_provider import GroqProvider
from .gemini_provider import GeminiProvider
from .openrouter_provider import OpenRouterProvider
from .mock_provider import MockProvider
from .diagnostics import error_details, http_status

logger = logging.getLogger("lemon_ai")
_FALLBACK_ORDER = [GroqProvider, GeminiProvider, OpenRouterProvider]
_COOLDOWN_SECONDS = 5 * 60          # hard failures
_TRANSIENT_COOLDOWN_SECONDS = 30    # per-attempt timeouts and invalid output
# Mid-stream error codes (no HTTP status) that mean the model's own output was
# rejected, e.g. Groq's JSON mode refusing a malformed reply: bad output, not a
# broken setup (DECISIONS 064).
_BAD_OUTPUT_CODES = frozenset({"json_validate_failed"})
_RETRY_AFTER_MIN_SECONDS = 1
_RETRY_AFTER_MAX_SECONDS = 60 * 60
_cooldown_until: Dict[str, float] = {}
_pending_tasks = set()


def _is_timeout(exc):
    # asyncio/builtin timeouts plus SDK ones (openai APITimeoutError, httpx
    # TimeoutException subclasses), matched by name so no SDK is imported here.
    return isinstance(exc, (asyncio.TimeoutError, TimeoutError)) or any(
        "Timeout" in cls.__name__ for cls in type(exc).__mro__)


def _retry_after_seconds(exc):
    """Seconds from a 429 response's Retry-After header, clamped; None if absent/invalid."""
    headers = getattr(getattr(exc, "response", None), "headers", None)
    if headers is None:
        return None
    try:
        millis = headers.get("retry-after-ms")
        value = headers.get("retry-after")
    except Exception:
        return None
    seconds = None
    try:
        if millis is not None:
            seconds = float(str(millis).strip()) / 1000
    except ValueError:
        seconds = None
    if seconds is None and value is not None:
        text = str(value).strip()
        try:
            seconds = float(text)
        except ValueError:
            try:
                when = parsedate_to_datetime(text)
            except (TypeError, ValueError, IndexError):
                return None
            if when.tzinfo is None:
                when = when.replace(tzinfo=timezone.utc)
            seconds = (when - datetime.now(timezone.utc)).total_seconds()
    if seconds is None or not math.isfinite(seconds):
        return None
    return min(max(seconds, _RETRY_AFTER_MIN_SECONDS), _RETRY_AFTER_MAX_SECONDS)


def _classify_failure(exc, stage, budget_exhausted):
    """Return (kind, cooldown_seconds) for a failed attempt."""
    status = http_status(exc)
    if status == 429:
        retry_after = _retry_after_seconds(exc)
        return "rate_limit", retry_after if retry_after is not None else _COOLDOWN_SECONDS
    if status == 503:
        # "Overloaded / try again" is a passing state, not a broken setup (DECISIONS 061).
        return "unavailable", _TRANSIENT_COOLDOWN_SECONDS
    if _is_timeout(exc):
        if budget_exhausted:
            return "budget", 0
        return ("stalled" if isinstance(exc, StreamStalled) else "timeout"), _TRANSIENT_COOLDOWN_SECONDS
    if stage == "response_validation" or getattr(exc, "code", None) in _BAD_OUTPUT_CODES:
        return "invalid_output", _TRANSIENT_COOLDOWN_SECONDS
    return "hard", _COOLDOWN_SECONDS


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


class StreamStalled(asyncio.TimeoutError):
    """A streaming provider went silent for longer than the inactivity limit."""


async def _collect_stream(stream, first_chunk_timeout, idle_timeout):
    """Join a provider's streamed text, failing only if it goes silent.

    Every chunk, including empty ones (reasoning, role headers), resets the
    timer. There is no total limit here; the caller bounds the whole attempt by
    its remaining budget.
    """
    parts = []
    iterator = stream.__aiter__()
    limit = first_chunk_timeout if first_chunk_timeout is not None else idle_timeout
    try:
        while True:
            try:
                part = await asyncio.wait_for(iterator.__anext__(), limit)
            except StopAsyncIteration:
                return "".join(parts)
            except asyncio.TimeoutError:
                raise StreamStalled() from None
            parts.append(part)
            limit = idle_timeout
    finally:
        close = getattr(iterator, "aclose", None)
        if close is not None:
            try:
                await _bounded(close(), 0.25)
            except Exception:
                pass


class AttemptFailed(Exception):
    """One provider attempt failed. Carries how it failed, never the SDK's message."""

    def __init__(self, provider: str, stage: str, kind: str, cooldown: float, budget_exhausted: bool):
        super().__init__(f"{provider} failed at {stage} ({kind})")
        self.provider = provider
        self.stage = stage
        self.kind = kind
        self.cooldown = cooldown
        self.budget_exhausted = budget_exhausted


def is_cooling_down(provider_cls) -> bool:
    if _cooldown_until.get(provider_cls.name, 0) > time.monotonic():
        logger.info("Auto provider %s skipped: cooldown", provider_cls.name)
        return True
    return False


def record_failure(error: AttemptFailed) -> None:
    if error.cooldown > 0:
        _cooldown_until[error.provider] = time.monotonic() + error.cooldown


def record_success(provider_cls) -> None:
    _cooldown_until.pop(provider_cls.name, None)


async def attempt_provider(
    provider_cls, system_prompt: str, user_prompt: str, *,
    validate: Callable[[str], object],
    attempt_timeout: Optional[float] = None,
    remaining: Optional[float] = None,
    idle_timeout: Optional[float] = None,
    first_chunk_timeout: Optional[float] = None,
) -> str:
    """One validated call to one provider, bounded by the tighter of the limits.

    Returns the raw text that passed `validate`. Any failure is logged and
    re-raised as AttemptFailed with its kind and cooldown; applying the
    cooldown is left to the caller (record_failure). Cancellation passes
    through untouched.
    """
    started = time.monotonic()
    state = {"stage": "construction"}
    logger.info("Auto provider %s starting", provider_cls.name)

    async def attempt():
        provider = provider_cls()
        try:
            state["stage"] = "generation"
            stream_text = getattr(provider, "stream_text", None)
            if idle_timeout is not None and stream_text is not None:
                result = await _collect_stream(stream_text(system_prompt, user_prompt),
                                               first_chunk_timeout, idle_timeout)
            else:
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
        # A stall is the provider's own silence, never the shared budget.
        budget_exhausted = (isinstance(exc, asyncio.TimeoutError)
                            and not isinstance(exc, StreamStalled) and remaining is not None
                            and (attempt_timeout is None or remaining <= attempt_timeout))
        kind, cooldown = _classify_failure(exc, state["stage"], budget_exhausted)
        # SDK exception text can contain request details; log only its type.
        logger.warning("Auto provider %s failed stage=%s elapsed=%.2fs details=%s; failure=%s cooldown=%ss",
                       provider_cls.name, state["stage"], time.monotonic() - started,
                       error_details(exc), kind, round(cooldown, 1))
        raise AttemptFailed(provider_cls.name, state["stage"], kind, cooldown, budget_exhausted) from exc
    logger.info("Auto provider %s succeeded elapsed=%.2fs", provider_cls.name, time.monotonic() - started)
    return result


class AutoProvider(LLMProvider):
    name = "auto"

    async def generate_json(
        self, system_prompt: str, user_prompt: str, *,
        validate: Optional[Callable[[str], object]] = None,
        mock_fallback: Optional[Callable[[], str]] = None,
        attempt_timeout: Optional[float] = None,
        total_timeout: Optional[float] = None,
        idle_timeout: Optional[float] = None,
        first_chunk_timeout: Optional[float] = None,
    ) -> str:
        """Try each provider in order; return the first output that validates.

        With idle_timeout set, providers that support streaming (`stream_text`)
        are cut off only after that many seconds without a new chunk
        (first_chunk_timeout, if given, applies while waiting for the first
        one); otherwise they may run until attempt_timeout/total_timeout.
        Providers without streaming use generate_json as before.
        """
        self.name = "auto"
        validate = validate or json.loads
        deadline = time.monotonic() + total_timeout if total_timeout is not None else None
        for provider_cls in _FALLBACK_ORDER:
            remaining = deadline - time.monotonic() if deadline is not None else None
            if remaining is not None and remaining <= 0:
                logger.warning("Auto real-provider budget exhausted; using local fallback")
                break
            if is_cooling_down(provider_cls):
                continue
            try:
                result = await attempt_provider(
                    provider_cls, system_prompt, user_prompt, validate=validate,
                    attempt_timeout=attempt_timeout, remaining=remaining,
                    idle_timeout=idle_timeout, first_chunk_timeout=first_chunk_timeout)
            except AttemptFailed as failure:
                record_failure(failure)
                if failure.budget_exhausted:
                    # Timer resolution may wake just before the monotonic deadline.
                    # This attempt already consumed its allocated remaining budget.
                    deadline = 0.0
                continue
            record_success(provider_cls)
            self.name = provider_cls.name
            return result

        logger.warning("Auto providers unavailable; using local mock/demo fallback")
        result = (mock_fallback() if mock_fallback is not None else
                  await MockProvider().generate_json(system_prompt, user_prompt))
        validate(result)
        self.name = "mock"
        return result
