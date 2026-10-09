from openai import AsyncOpenAI
from config import settings
from .base import LLMProvider


class OpenRouterProvider(LLMProvider):
    """
    OpenRouter's API is OpenAI-compatible, so this reuses the `openai` SDK the
    same way GroqProvider does — just pointed at OpenRouter's base URL, with a
    ':free' model suffix to stay on the no-cost tier.

    Free-tier notes (check https://openrouter.ai/docs for current numbers if
    you start seeing 429s):
    - ~20 requests/min, 50 requests/day per account on ':free' models
      (rises to ~1,000/day once the account has ever purchased $10 of credit)
    - Data policy is inherited from whichever upstream model you pick — some
      free models train on prompts, some don't. Check the model's page on
      openrouter.ai/models if that matters for what you send it.
    """
    name = "openrouter"

    def __init__(self):
        self._client = AsyncOpenAI(
            api_key=settings.OPENROUTER_API_KEY or "placeholder",  # SDK needs a non-empty string at construction
            base_url=settings.OPENROUTER_BASE_URL,
            default_headers={
                # OpenRouter asks for these on every request — they're used for
                # its public leaderboard/rankings, not for auth. Not required for
                # calls to succeed, but good practice per their docs.
                "HTTP-Referer": "https://github.com/",
                "X-Title": "AI Travel Planner (Lemon.ai)",
            },
        )

    async def aclose(self):
        await self._client.close()

    async def generate_json(self, system_prompt: str, user_prompt: str) -> str:
        if not settings.OPENROUTER_API_KEY:
            raise ValueError("OpenRouter provider selected but OPENROUTER_API_KEY is not set in .env")
        response = await self._client.chat.completions.create(
            model=settings.OPENROUTER_MODEL,
            messages=[
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": user_prompt},
            ],
            response_format={"type": "json_object"},
        )
        return response.choices[0].message.content
