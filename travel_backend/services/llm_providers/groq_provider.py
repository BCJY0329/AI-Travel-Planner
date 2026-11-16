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
        # gpt-oss is a reasoning model: at its default effort it can spend the whole
        # output allowance thinking and return no answer at all (finish_reason
        # "length", reported by JSON mode as json_validate_failed). Low effort cuts
        # only the hidden thinking, not the itinerary (DECISIONS 066).
        effort = settings.GROQ_REASONING_EFFORT.strip()
        extra = {"reasoning_effort": effort} if effort else None
        async for part in stream_chat_json(self._client, settings.GROQ_MODEL, system_prompt, user_prompt,
                                           extra_body=extra):
            yield part

    async def generate_json(self, system_prompt: str, user_prompt: str) -> str:
        return await collect(self.stream_text(system_prompt, user_prompt))

    async def vision_json(self, system_prompt: str, user_text: str, images: list) -> str:
        """One JSON answer about up to 3 images (DECISIONS 073), from
        GROQ_VISION_MODEL. `images`: [(mime, base64 text)]. Not streamed: the
        answer is short. Errors (including 429) propagate to the caller."""
        if not settings.GROQ_API_KEY:
            raise ValueError("Groq vision selected but GROQ_API_KEY is not set in .env")
        content = [{"type": "text", "text": user_text}] + [
            {"type": "image_url", "image_url": {"url": f"data:{mime};base64,{data}"}} for mime, data in images]
        effort = settings.GROQ_VISION_REASONING_EFFORT.strip()
        response = await self._client.chat.completions.create(
            model=settings.GROQ_VISION_MODEL,
            messages=[{"role": "system", "content": system_prompt}, {"role": "user", "content": content}],
            response_format={"type": "json_object"},
            temperature=0.2,
            **({"extra_body": {"reasoning_effort": effort}} if effort else {}),
        )
        return response.choices[0].message.content or ""
