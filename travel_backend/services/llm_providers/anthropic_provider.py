from anthropic import AsyncAnthropic
from config import settings
from .base import LLMProvider


class AnthropicProvider(LLMProvider):
    name = "claude"

    def __init__(self):
        self._client = AsyncAnthropic(api_key=settings.ANTHROPIC_API_KEY)

    async def generate_json(self, system_prompt: str, user_prompt: str) -> str:
        if not settings.ANTHROPIC_API_KEY:
            raise ValueError("Claude provider selected but ANTHROPIC_API_KEY is not set in .env")
        response = await self._client.messages.create(
            model=settings.ANTHROPIC_MODEL,
            max_tokens=2000,
            system=system_prompt,
            messages=[{"role": "user", "content": user_prompt}],
        )
        return "".join(block.text for block in response.content if block.type == "text")
