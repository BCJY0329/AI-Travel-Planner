"""
Turns a freeform conversation into structured trip-planning fields, using the
same interchangeable LLM providers as itinerary_builder.py. This is what lets
Lemon.ai's chat feel like a normal conversation instead of a rigid form.

'mock' uses a cheap local heuristic instead of calling a real model, so the
whole flow stays testable with zero API keys — same philosophy as
MockProvider for itinerary generation.

Mock-path design note: extraction is split into two passes on purpose.
  1. `_extract_fields` — broad regex scan over the WHOLE conversation, only
     matching fields that appear in an unambiguous shape (explicit "to <City>",
     an actual YYYY-MM-DD date, "3 people", etc). This pass is intentionally
     conservative so it doesn't misfire on message #1 being a greeting.
  2. `_interpret_as_field_answer` — looks at ONLY the latest user message and,
     if the broad pass didn't already fill in whatever field Lemon just asked
     about, treats that bare reply (e.g. just "Tokyo", or just "2") as the
     direct answer to that specific field.
This fixes the old bug where a bare destination reply was only ever checked
against messages[0], and where the city regex could swallow trailing words
("Tokyo for 5 days" -> "Tokyo for").
"""
import json
import re
import logging
from datetime import date, timedelta
from typing import List, Optional

from models.chat import ChatTurn, LemonChatRequest, LemonChatResponse
from services.llm_providers.factory import get_provider
from services.text_sanitize import strip_markdown

logger = logging.getLogger("lemon_ai")

SYSTEM_PROMPT_TEMPLATE = """You are Lemon.ai, a travel planner assistant. Have a friendly, natural conversation \
with a traveler to learn these fields about the trip they want to plan:

- destination (a city or place name)
- start_date and end_date (each YYYY-MM-DD)
- travelers (integer, default to 1 if the user is clearly travelling solo or never says)
- budget_level: one of "low", "medium", "high"
- interests: a short list of trip interests/themes (e.g. food, museums, hiking)

Today's date is {today}. Resolve relative dates like "next month" or "in December" into \
real YYYY-MM-DD dates. If the user gives a start date and a trip length (e.g. "5 days"), \
compute the end date yourself.

Personality: you're warm, upbeat, and genuinely excited about travel — like a well-traveled \
friend helping someone plan something fun, not a form to fill out. Show real enthusiasm about \
their destination and choices ("Ooh, Kyoto in autumn is gorgeous!"). Keep it natural though: \
one light touch (an exclamation mark, a small aside, at most one emoji like 🍋 ✨ 🌍 🧳) per \
reply is plenty — don't stack multiple emoji or gush in every single sentence, or it starts \
to feel forced instead of friendly.

Rules:
- For the initial opening message, greet the user warmly and introduce yourself, then ask \
where they want to go, as TWO separate sentences separated by a blank line (a "\\n\\n" double \
newline) — the frontend renders each blank-line-separated chunk as its own chat bubble, so \
this is what makes it feel like two messages instead of one wall of text.
- Ask ONLY ONE question at a time in a friendly, conversational tone.
- Start by asking for the destination if missing.
- Once destination is provided, ask for the start date. If only the start date is provided, ask for the end date (or trip duration) before proceeding.
- Next, ask about the number of travelers or budget/interests.
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
  "next_field": "one of 'destination', 'start_date', 'end_date', 'travelers', 'budget_level', 'confirm', or null once ready is true",
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
# Only captures consecutive CAPITALIZED words after the lead-in, so it stops
# at lowercase connector words instead of swallowing the rest of the sentence
# (e.g. "to Tokyo for 5 days" -> "Tokyo", not "Tokyo for").
_TO_CITY_RE = re.compile(r"\b(?:to|in|visiting|around)\s+([A-Z][a-zA-Z]*(?:\s+[A-Z][a-zA-Z]*)*)")
_CONFIRM_WORDS = ("yes", "yep", "yeah", "sounds good", "let's go", "go ahead", "plan it", "confirm", "sure")
_NON_DESTINATION_WORDS = {
    "hi", "hello", "hey", "yes", "no", "ok", "okay", "sure", "thanks", "thank you",
}


def _extract_fields(full_text: str) -> dict:
    """Broad, conservative regex scan across the whole conversation so far.
    Only fills a field when the text is unambiguous — bare/short replies are
    intentionally left for `_interpret_as_field_answer` to handle instead."""
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

    travelers = None
    travelers_match = _TRAVELERS_RE.search(full_text)
    if travelers_match:
        travelers = int(travelers_match.group(1))

    budget_level = None
    for word, level in _BUDGET_WORDS.items():
        if word in full_text.lower():
            budget_level = level
            break

    interests: List[str] = []
    interests_match = re.search(r"(?:interested in|into|love|enjoy)\s+([a-zA-Z, ]+)", full_text, re.IGNORECASE)
    if interests_match:
        raw_interests = interests_match.group(1)
        # split on commas and " and " so "food and museums" yields two interests
        parts = re.split(r",|\band\b", raw_interests, flags=re.IGNORECASE)
        interests = [w.strip() for w in parts if w.strip()][:5]

    return {
        "destination": destination,
        "start_date": start_date,
        "end_date": end_date,
        "travelers": travelers,
        "budget_level": budget_level,
        "interests": interests,
    }


def _determine_next_field(fields: dict) -> Optional[str]:
    """Which field Lemon should ask about next, given what's known so far."""
    if not fields["destination"]:
        return "destination"
    if not fields["start_date"]:
        return "start_date"
    if not fields["end_date"]:
        return "end_date"
    if fields["travelers"] is None:
        return "travelers"
    return "confirm"


def _interpret_as_field_answer(latest_msg: str, asked_field: Optional[str], fields: dict) -> None:
    """If the broad scan didn't fill `asked_field`, treat the latest bare
    reply as a direct answer to it. Mutates `fields` in place."""
    cleaned = latest_msg.strip().rstrip(".,!?")
    if not cleaned:
        return

    if asked_field == "destination" and not fields["destination"]:
        lowered = cleaned.lower()
        word_count = len(cleaned.split())
        looks_like_place = (
            word_count <= 4
            and lowered not in _NON_DESTINATION_WORDS
            and not _DATE_RE.search(cleaned)
            and not cleaned.isdigit()
        )
        if looks_like_place:
            fields["destination"] = cleaned

    elif asked_field == "start_date" and not fields["start_date"]:
        date_match = _DATE_RE.search(cleaned)
        if date_match:
            fields["start_date"] = date_match.group(1)

    elif asked_field == "end_date" and not fields["end_date"]:
        date_match = _DATE_RE.search(cleaned)
        if date_match:
            fields["end_date"] = date_match.group(1)
        else:
            days_match = _NUM_DAYS_RE.search(cleaned)
            if days_match and fields["start_date"]:
                n_days = max(int(days_match.group(1)) - 1, 0)
                try:
                    start = date.fromisoformat(fields["start_date"])
                    fields["end_date"] = (start + timedelta(days=n_days)).isoformat()
                except ValueError:
                    pass

    elif asked_field == "travelers" and fields["travelers"] is None:
        if cleaned.isdigit():
            fields["travelers"] = int(cleaned)
        else:
            travelers_match = _TRAVELERS_RE.search(cleaned)
            if travelers_match:
                fields["travelers"] = int(travelers_match.group(1))

    elif asked_field == "budget_level" and not fields["budget_level"]:
        lowered = cleaned.lower()
        for word, level in _BUDGET_WORDS.items():
            if word in lowered:
                fields["budget_level"] = level
                break


def _mock_parse(messages: List[ChatTurn]) -> LemonChatResponse:
    user_messages = [m.content.strip() for m in messages if m.role == "user"]
    full_text = " ".join(user_messages)

    # Replay the conversation turn by turn rather than scanning the whole
    # transcript as one blob. This matters because a bare reply (e.g. just
    # "2" answering "how many travelers?") is only interpretable in light of
    # what was being asked *at that point* — once later turns are appended,
    # a single-pass full-text scan has no way to tell "2" was the traveler
    # count rather than noise, so a plain re-scan silently drops it.
    fields = {
        "destination": None,
        "start_date": None,
        "end_date": None,
        "travelers": None,
        "budget_level": None,
        "interests": [],
    }
    for msg in user_messages:
        asked_field = _determine_next_field(fields)

        single = _extract_fields(msg)
        for key in ("destination", "start_date", "end_date", "travelers", "budget_level"):
            if single[key] is not None and fields[key] is None:
                fields[key] = single[key]
        if single["interests"]:
            fields["interests"] = list(dict.fromkeys(fields["interests"] + single["interests"]))[:5]

        # If the broad scan of this message didn't already answer whatever
        # was being asked, see if the message is a bare direct answer to it.
        if asked_field and asked_field != "confirm" and fields.get(asked_field) is None:
            _interpret_as_field_answer(msg, asked_field, fields)

    confirmed = any(word in full_text.lower() for word in _CONFIRM_WORDS)
    have_minimum = bool(fields["destination"] and fields["start_date"] and fields["end_date"])
    ready = have_minimum and confirmed

    next_field = None if ready else _determine_next_field(fields)

    destination = fields["destination"]
    start_date = fields["start_date"]
    end_date = fields["end_date"]
    travelers = fields["travelers"]
    budget_level = fields["budget_level"]

    if ready:
        reply = (
            f"Yay, {destination} it is! 🎉 Locking in {start_date} to {end_date} — "
            "give me a moment to whip up your itinerary!"
        )
    elif next_field == "confirm":
        extra = f", {travelers} traveler(s)" if travelers else ""
        extra += f", {budget_level} budget" if budget_level else ""
        reply = f"Love it — {destination} from {start_date} to {end_date}{extra}. Ready for me to plan it out?"
    elif next_field == "travelers":
        reply = "Awesome! How many of you are jetsetting on this trip?"
    elif next_field == "destination":
        # "\n\n" is the bubble-break delimiter the frontend splits on to render
        # this as two separate chat bubbles instead of one long message.
        reply = (
            "Hi, I'm Lemon! 🍋 I'm your travel planner assistant, and I'm genuinely excited to help you plan something great!\n\n"
            "So — where are you dreaming of going?"
        )
    elif next_field == "start_date":
        reply = f"{destination} — great pick! 🌍 When would you like to kick off the trip?"
    elif next_field == "end_date":
        reply = f"Got your start date as {start_date}! What's your end date, or how many days will you be away?"
    else:
        reply = "Thanks! Could you tell me the trip dates too (e.g. 2026-11-01 to 2026-11-05)?"

    return LemonChatResponse(
        reply=reply,
        destination=destination,
        start_date=start_date,
        end_date=end_date,
        travelers=travelers,
        budget_level=budget_level,
        interests=fields["interests"],
        ready=ready,
        next_field=next_field,
    )