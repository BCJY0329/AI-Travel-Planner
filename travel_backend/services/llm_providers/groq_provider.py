"""
Groq — free-tier LLM provider (no credit card required).

Groq's API is OpenAI-compatible, so rather than writing a separate client from
scratch this just points the existing OpenAI SDK at Groq's base URL. Free tier
is rate-limited (requests/tokens per minute and per day), not credit-metered,
so there's no bill to worry about — see https://console.groq.com/docs/rate-limits.

Model names on Groq change more often than the other providers' (they deprecate/replace
open-source models on a few months' notice). GROQ_MODEL defaults to a currently-active
model that supports JSON response mode as of writing, but check
https://console.groq.com/docs/models before relying on it long-term.
"""
from openai import AsyncOpenAI
from config import settings
from .base import LLMProvider


class GroqProvider(LLMProvider):
    name = "groq"

    def __init__(self):
        self._client = AsyncOpenAI(api_key=settings.GROQ_API_KEY, base_url=settings.GROQ_BASE_URL)

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