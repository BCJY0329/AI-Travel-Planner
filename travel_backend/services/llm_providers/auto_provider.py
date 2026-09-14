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
"""
import logging
from .base import LLMProvider
from .groq_provider import GroqProvider
from .gemini_provider import GeminiProvider
from .anthropic_provider import AnthropicProvider
from .openai_provider import OpenAIProvider
from .mock_provider import MockProvider

logger = logging.getLogger("lemon_ai")

_FALLBACK_ORDER = [GroqProvider, GeminiProvider, AnthropicProvider, OpenAIProvider, MockProvider]


class AutoProvider(LLMProvider):
    name = "auto"

    async def generate_json(self, system_prompt: str, user_prompt: str) -> str:
        last_error: Exception | None = None
        for i, provider_cls in enumerate(_FALLBACK_ORDER):
            provider = provider_cls()
            try:
                result = await provider.generate_json(system_prompt, user_prompt)
                if i > 0:
                    logger.warning(
                        f"Auto-fallback: '{provider.name}' succeeded after "
                        f"{i} earlier provider(s) failed."
                    )
                if provider.name == "mock":
                    logger.warning(
                        "Auto-fallback exhausted every real provider and fell back to "
                        "mock data — check API keys/quota if this wasn't intentional."
                    )
                # Report which provider actually answered, not the literal string "auto",
                # so callers (itinerary_builder, chat_parser) surface the real engine used.
                self.name = provider.name
                return result
            except Exception as e:
                logger.warning(f"Auto-fallback: '{provider.name}' failed ({e}); trying next provider.")
                last_error = e
        raise ValueError(f"All providers failed. Last error: {last_error}")