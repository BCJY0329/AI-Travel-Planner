from openai import AsyncOpenAI
from config import settings
from .base import LLMProvider


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
        )

    async def aclose(self):
        await self._client.close()

    async def generate_json(self, system_prompt: str, user_prompt: str) -> str:
        if not settings.GROQ_API_KEY:
            raise ValueError("Groq provider selected but GROQ_API_KEY is not set in .env")
        response = await self._client.chat.completions.create(
            model=settings.GROQ_MODEL,
            messages=[
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": user_prompt},
            ],
            response_format={"type": "json_object"},
        )
        return response.choices[0].message.content
