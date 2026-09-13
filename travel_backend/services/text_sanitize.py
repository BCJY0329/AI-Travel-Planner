"""
Shared markdown-stripping helper. The itinerary and chat prompts both already
instruct the model to avoid markdown, but models don't always listen — this
is a server-side backstop so a stray '##' or '**' never reaches the client,
on top of the same cleanup already done in the Flutter app.
"""
import re

_PATTERNS = [
    (re.compile(r'```[a-zA-Z]*\n?'), ''),
    (re.compile(r'```'), ''),
    (re.compile(r'(^|\n)\s*#+\s*'), r'\1'),
    (re.compile(r'\*\*([^*]+)\*\*'), r'\1'),
    (re.compile(r'\*([^*]+)\*'), r'\1'),
    (re.compile(r'__([^_]+)__'), r'\1'),
    (re.compile(r'_([^_]+)_'), r'\1'),
    (re.compile(r'`([^`]+)`'), r'\1'),
    (re.compile(r'(^|\n)\s*[-*•]\s+'), r'\1'),
]


def strip_markdown(text: str) -> str:
    if not text:
        return text
    cleaned = text
    for pattern, repl in _PATTERNS:
        cleaned = pattern.sub(repl, cleaned)
    return re.sub(r'[ \t]+', ' ', cleaned).strip()