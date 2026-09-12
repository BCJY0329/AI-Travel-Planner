from openai import AsyncOpenAI
from config import settings
from .base import LLMProvider


class OpenAIProvider(LLMProvider):
    name = "gpt"

    def __init__(self):
        self._client = AsyncOpenAI(api_key=settings.OPENAI_API_KEY)

    async def generate_json(self, system_prompt: str, user_prompt: str) -> str:
        if not settings.OPENAI_API_KEY:
            raise ValueError("GPT provider selected but OPENAI_API_KEY is not set in .env")
        response = await self._client.chat.completions.create(
            model=settings.OPENAI_MODEL,
            messages=[
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": user_prompt},
            ],
            response_format={"type": "json_object"},
        )
        return response.choices[0].message.content
