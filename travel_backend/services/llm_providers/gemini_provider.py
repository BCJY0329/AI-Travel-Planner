import asyncio
import threading

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

    async def aclose(self):
        if self._client is not None:
            close = getattr(self._client.aio, "aclose", None)
            if close is not None:
                await close()

    async def stream_text(self, system_prompt: str, user_prompt: str):
        """Yield the reply text chunk by chunk (empty strings for text-less chunks).

        The pinned google-genai (0.3.0) reads its "async" stream with blocking
        `requests` calls on the event loop thread, so a stalled stream would
        freeze the whole server. The SDK's synchronous stream therefore runs on
        its own daemon thread and hands chunks over through an asyncio queue,
        which keeps the loop free and lets callers time out on silence.
        """
        if not settings.GEMINI_API_KEY:
            raise ValueError("Gemini provider selected but GEMINI_API_KEY is not set in .env")
        if self._client is None:
            self._client = genai.Client(api_key=settings.GEMINI_API_KEY)

        loop = asyncio.get_running_loop()
        queue: asyncio.Queue = asyncio.Queue()
        stop = threading.Event()
        client = self._client

        def post(kind, value=None):
            try:
                loop.call_soon_threadsafe(queue.put_nowait, (kind, value))
            except RuntimeError:
                pass  # Event loop already closed; nobody is listening.

        def produce():
            try:
                chunks = client.models.generate_content_stream(
                    model=settings.GEMINI_MODEL,
                    contents=user_prompt,
                    config=types.GenerateContentConfig(
                        system_instruction=system_prompt,
                        response_mime_type="application/json",
                    ),
                )
                for chunk in chunks:
                    if stop.is_set():
                        break
                    post("chunk", chunk.text or "")
            except BaseException as exc:  # Delivered to the awaiting coroutine.
                post("error", exc)
            else:
                post("done")

        threading.Thread(target=produce, name="gemini-stream", daemon=True).start()
        try:
            while True:
                kind, value = await queue.get()
                if kind == "chunk":
                    yield value
                elif kind == "error":
                    raise value
                else:
                    return
        finally:
            # On cut-off or cancellation the thread stops at its next chunk.
            stop.set()

    async def generate_json(self, system_prompt: str, user_prompt: str) -> str:
        return "".join([part async for part in self.stream_text(system_prompt, user_prompt)])
