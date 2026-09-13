"""
Turns a freeform conversation into structured trip-planning fields, using the
same interchangeable LLM providers as itinerary_builder.py. This is what lets
Lemon.ai's chat feel like a normal conversation instead of a rigid form.

'mock' uses a cheap local heuristic instead of calling a real model, so the
whole flow stays testable with zero API keys — same philosophy as
MockProvider for itinerary generation.
"""
import json
import re
import logging
from datetime import date, timedelta
from typing import List

from models.chat import ChatTurn, LemonChatRequest, LemonChatResponse
from services.llm_providers.factory import get_provider
from services.text_sanitize import strip_markdown

logger = logging.getLogger("lemon_ai")

SYSTEM_PROMPT_TEMPLATE = """You are Lemon.ai's trip-intake assistant. Have a friendly, natural conversation \
with a traveler to learn these fields about the trip they want to plan:

- destination (a city or place name)
- start_date and end_date (each YYYY-MM-DD)
- travelers (integer, default to 1 if the user is clearly travelling solo or never says)
- budget_level: one of "low", "medium", "high"
- interests: a short list of trip interests/themes (e.g. food, museums, hiking)

Today's date is {today}. Resolve relative dates like "next month" or "in December" into \
real YYYY-MM-DD dates. If the user gives a start date and a trip length (e.g. "5 days"), \
compute the end date yourself.

Rules:
- Ask only about whatever fields are still missing, one or two at a time, in a warm tone.
- Once destination, start_date, and end_date are known, summarize everything gathered so far \
in plain conversational sentences and ask the user to confirm before you proceed.
- Only set "ready" to true once the user has clearly confirmed (e.g. said yes, sounds good, \
let's go) AND destination, start_date, and end_date are all filled in.
- If the user corrects or changes a detail already filled in, update it.
- Never use markdown formatting: no #, no *, no _, no backticks, no bullet dashes. Plain \
sentences only.
- Respond with ONLY a valid JSON object, no commentary, no markdown fences, matching exactly:

{{
  "destination": "string or null",
  "start_date": "YYYY-MM-DD or null",
  "end_date": "YYYY-MM-DD or null",
  "travelers": integer or null,
  "budget_level": "low, medium, high, or null",
  "interests": ["..."],
  "ready": true or false,
  "reply": "your natural-language reply to show the user right now"
}}"""


def _build_transcript(messages: List[ChatTurn]) -> str:
    lines = []
    for turn in messages:
        speaker = "Traveler" if turn.role == "user" else "Lemon"
        lines.append(f"{speaker}: {turn.content}")
    return "\n".join(lines)


async def parse_chat(request: LemonChatRequest) -> LemonChatResponse:
    if request.provider.lower() == "mock":
        return _mock_parse(request.messages)
    return await _ai_parse(request)


async def _ai_parse(request: LemonChatRequest) -> LemonChatResponse:
    system_prompt = SYSTEM_PROMPT_TEMPLATE.format(today=date.today().isoformat())
    user_prompt = (
        "Conversation so far (oldest first):\n"
        f"{_build_transcript(request.messages)}\n\n"
        "Respond with ONLY the JSON object described in the system prompt, reflecting "
        "the latest state of the conversation."
    )

    provider = get_provider(request.provider)
    raw = await provider.generate_json(system_prompt, user_prompt)

    try:
        parsed = json.loads(raw)
    except json.JSONDecodeError as e:
        logger.error(f"{provider.name} returned non-JSON chat output: {raw[:300]}")
        raise ValueError(f"{provider.name} did not return valid JSON while parsing the chat ({e}).")

    parsed["reply"] = strip_markdown(parsed.get("reply") or "")
    if not parsed["reply"]:
        parsed["reply"] = "Got it! Anything else you'd like to add, or shall I plan the trip?"

    return LemonChatResponse(**parsed)


# --- Mock heuristic path (no API key / network needed) ---------------------

_BUDGET_WORDS = {
    "low": "low", "cheap": "low", "budget": "low",
    "medium": "medium", "moderate": "medium",
    "high": "high", "luxury": "high", "splurge": "high",
}
_DATE_RE = re.compile(r"\b(\d{4}-\d{2}-\d{2})\b")
_NUM_DAYS_RE = re.compile(r"\b(\d{1,2})\s*-?\s*day", re.IGNORECASE)
_TRAVELERS_RE = re.compile(r"\b(\d{1,2})\s*(?:people|travelers|travellers|pax|of us)\b", re.IGNORECASE)
_TO_CITY_RE = re.compile(r"\b(?:to|in|visiting|around)\s+([A-Z][a-zA-Z\s]{2,25})")
_CONFIRM_WORDS = ("yes", "yep", "yeah", "sounds good", "let's go", "go ahead", "plan it", "confirm", "sure")


def _mock_parse(messages: List[ChatTurn]) -> LemonChatResponse:
    full_text = " ".join(m.content for m in messages if m.role == "user")

    destination = None
    city_match = _TO_CITY_RE.search(full_text)
    if city_match:
        destination = city_match.group(1).strip().rstrip(".,!?")

    dates = _DATE_RE.findall(full_text)
    start_date = dates[0] if len(dates) >= 1 else None
    end_date = dates[1] if len(dates) >= 2 else None
    if start_date and not end_date:
        days_match = _NUM_DAYS_RE.search(full_text)
        if days_match:
            n_days = max(int(days_match.group(1)) - 1, 0)
            try:
                start = date.fromisoformat(start_date)
                end_date = (start + timedelta(days=n_days)).isoformat()
            except ValueError:
                pass

    travelers_match = _TRAVELERS_RE.search(full_text)
    travelers = int(travelers_match.group(1)) if travelers_match else None

    budget_level = None
    for word, level in _BUDGET_WORDS.items():
        if word in full_text.lower():
            budget_level = level
            break

    interests_match = re.search(r"(?:interested in|into|love|enjoy)\s+([a-zA-Z, ]+)", full_text, re.IGNORECASE)
    interests = []
    if interests_match:
        interests = [w.strip() for w in interests_match.group(1).split(",") if w.strip()][:5]

    confirmed = any(word in full_text.lower() for word in _CONFIRM_WORDS)
    have_minimum = bool(destination and start_date and end_date)
    ready = have_minimum and confirmed

    if ready:
        reply = f"Perfect, locking it in: {destination}, {start_date} to {end_date}. Give me a moment to put your itinerary together!"
    elif have_minimum:
        extra = f", {travelers} traveler(s)" if travelers else ""
        extra += f", {budget_level} budget" if budget_level else ""
        reply = f"Got it — {destination} from {start_date} to {end_date}{extra}. Shall I go ahead and plan it?"
    elif destination and not start_date:
        reply = f"{destination} sounds great! When would you like to travel — what dates?"
    elif not destination:
        reply = "I'd love to help! Where are you thinking of travelling to?"
    else:
        reply = "Thanks! Could you tell me the trip dates too (e.g. 2026-11-01 to 2026-11-05)?"

    return LemonChatResponse(
        reply=reply,
        destination=destination,
        start_date=start_date,
        end_date=end_date,
        travelers=travelers,
        budget_level=budget_level,
        interests=interests,
        ready=ready,
    )