from google import genai
from google.genai import types
from config import settings
from .base import LLMProvider


class GeminiProvider(LLMProvider):
    name = "gemini"

    def __init__(self):
        # Unlike the Anthropic/OpenAI SDKs, google-genai's Client raises immediately
        # if the key is empty rather than waiting until the first real call — so we
        # defer construction until generate_json actually needs it, and surface a
        # clear message if the key is missing rather than that constructor error.
        self._client = None

    async def generate_json(self, system_prompt: str, user_prompt: str) -> str:
        if not settings.GEMINI_API_KEY:
            raise ValueError("Gemini provider selected but GEMINI_API_KEY is not set in .env")
        if self._client is None:
            self._client = genai.Client(api_key=settings.GEMINI_API_KEY)

        response = await self._client.aio.models.generate_content(
            model=settings.GEMINI_MODEL,
            contents=user_prompt,
            config=types.GenerateContentConfig(
                system_instruction=system_prompt,
                response_mime_type="application/json",
            ),
        )
        return response.text
