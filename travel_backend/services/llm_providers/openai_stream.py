"""Shared streaming for the OpenAI-compatible providers (Groq, OpenRouter).

Yields one string per streamed chunk. Chunks that carry no answer text (role
headers, reasoning deltas, usage) yield "" so callers can still count them as
signs of life; joining every yielded string gives the complete reply, exactly
what the non-streaming `message.content` used to return.
"""


async def stream_chat_json(client, model: str, system_prompt: str, user_prompt: str, extra_body=None):
    # extra_body carries provider-specific fields the pinned openai SDK (1.54)
    # doesn't know, such as Groq's reasoning_effort.
    stream = await client.chat.completions.create(
        model=model,
        messages=[
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_prompt},
        ],
        response_format={"type": "json_object"},
        stream=True,
        **({"extra_body": extra_body} if extra_body else {}),
    )
    try:
        async for chunk in stream:
            delta = chunk.choices[0].delta if chunk.choices else None
            yield (delta.content or "") if delta is not None else ""
    finally:
        # Release the HTTP connection whether we finished, failed or were cut off.
        await stream.response.aclose()


async def collect(stream) -> str:
    return "".join([part async for part in stream])
