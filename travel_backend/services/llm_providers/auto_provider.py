"""
Automatically tries providers in priority order and falls back to the next one
whenever a provider fails for ANY reason — out of quota, rate-limited, missing/invalid
API key, empty credit balance, transient network error, etc. This removes the need for
the user to manually pick an engine and swap it by hand when one runs dry.

Deliberately uses a broad `except Exception` per attempt rather than trying to special-case
every SDK's specific rate-limit/quota exception type: those types differ across the
Anthropic/OpenAI/Google SDKs, change between SDK versions, and — as already learned from
the empty-credit-balance case — quota exhaustion doesn't always surface as a clean
"rate limit" error anyway. Any failure from one provider just means "try the next one";
the caller only ever sees an error if every provider in the chain failed.

Order is chosen for cost/reliability, not raw quality: Groq first (fast, generous
always-free tier), then Gemini (also has a solid free tier), then Claude and GPT (paid,
kept as high-quality fallbacks if configured), with 'mock' as an absolute last resort so
the app never hard-fails even if every real provider is unavailable — note this WILL
return fake demo data, so it's a safety net for dev, not something you want to silently
hit in production without noticing.

Cooldown: once a provider fails, it's skipped (not retried) for _COOLDOWN_SECONDS rather
than being hit again on the very next chat message. Without this, a provider that just ran
out of tokens would eat one guaranteed-failed network round trip on every single request
until its quota happened to reset — pure wasted latency for the user. This is in-memory
only (module-level, like amadeus_client's token cache) and resets on server restart, which
is fine: the goal is just to avoid hammering an already-known-bad provider within one run
of the server, not to persist quota state forever.
"""
import time
import logging
from typing import Dict, Optional
from .base import LLMProvider
from .groq_provider import GroqProvider
from .gemini_provider import GeminiProvider
from .anthropic_provider import AnthropicProvider
from .openai_provider import OpenAIProvider
from .mock_provider import MockProvider

logger = logging.getLogger("lemon_ai")

_FALLBACK_ORDER = [GroqProvider, GeminiProvider, AnthropicProvider, OpenAIProvider, MockProvider]

_COOLDOWN_SECONDS = 5 * 60
_cooldown_until: Dict[str, float] = {}


class AutoProvider(LLMProvider):
    name = "auto"

    async def generate_json(self, system_prompt: str, user_prompt: str) -> str:
        now = time.time()
        candidates = [cls for cls in _FALLBACK_ORDER if _cooldown_until.get(cls.name, 0) <= now]
        # If literally everything is on cooldown (e.g. every free-tier quota
        # got hit within the last few minutes), ignore the cooldown rather
        # than refusing outright — a stale "probably still bad" guess beats
        # hard-failing the whole request.
        if not candidates:
            candidates = _FALLBACK_ORDER

        last_error: Optional[Exception] = None
        for i, provider_cls in enumerate(candidates):
            provider = provider_cls()
            try:
                result = await provider.generate_json(system_prompt, user_prompt)
                if i > 0:
                    logger.warning(
                        f"Auto-fallback: '{provider.name}' succeeded after "
                        f"{i} earlier provider(s) failed or were on cooldown."
                    )
                if provider.name == "mock":
                    logger.warning(
                        "Auto-fallback exhausted every real provider and fell back to "
                        "mock data — check API keys/quota if this wasn't intentional."
                    )
                # A successful call means whatever cooldown this provider may
                # have had has clearly expired (or never applied) — clear it.
                _cooldown_until.pop(provider.name, None)
                # Report which provider actually answered, not the literal string "auto",
                # so callers (itinerary_builder, chat_parser) surface the real engine used.
                self.name = provider.name
                return result
            except Exception as e:
                logger.warning(
                    f"Auto-fallback: '{provider.name}' failed ({e}); skipping it for "
                    f"{_COOLDOWN_SECONDS // 60} minutes and trying the next provider."
                )
                _cooldown_until[provider.name] = now + _COOLDOWN_SECONDS
                last_error = e
        raise ValueError(f"All providers failed. Last error: {last_error}")