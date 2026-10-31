from openai import AsyncOpenAI
from config import settings
from .base import LLMProvider
from .openai_stream import collect, stream_chat_json


class GroqProvider(LLMProvider):
    """
    Groq's API is OpenAI-compatible, so this reuses the `openai` SDK pointed at
    Groq's base URL instead of writing a separate HTTP client. As of late 2026,
    Groq's free tier (no credit card) covers the gpt-oss models — check
    https://console.groq.com/docs/rate-limits for current RPM/RPD numbers if
    you start seeing 429s.
    """
    name = "groq"

    def __init__(self):
        self._client = AsyncOpenAI(
            api_key=settings.GROQ_API_KEY or "placeholder",  # SDK needs a non-empty string at construction
            base_url=settings.GROQ_BASE_URL,
            # No hidden SDK retries: AutoProvider handles 429/Retry-After and
            # fallback itself, and silent retry sleeps would look like a stall.
            max_retries=0,
        )

    async def aclose(self):
        await self._client.close()

    async def stream_text(self, system_prompt: str, user_prompt: str):
        if not settings.GROQ_API_KEY:
            raise ValueError("Groq provider selected but GROQ_API_KEY is not set in .env")
        async for part in stream_chat_json(self._client, settings.GROQ_MODEL, system_prompt, user_prompt):
            yield part

    async def generate_json(self, system_prompt: str, user_prompt: str) -> str:
        return await collect(self.stream_text(system_prompt, user_prompt))
