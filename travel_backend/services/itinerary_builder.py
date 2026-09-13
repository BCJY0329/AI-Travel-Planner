"""
This is the heart of Lemon.ai's single-call itinerary generation:
1. Gather real weather + attraction data for the destination (best-effort — if either
   external call fails, we degrade gracefully and tell the model that data is missing,
   rather than failing the whole request).
2. Build one system prompt + one user prompt containing that context.
3. Call the user's chosen provider ONCE.
4. Parse and validate the JSON response before returning it.
"""
import json
import logging
from models.itinerary import TripRequest, ItineraryResponse
from services.llm_providers.factory import get_provider
from routers.weather import get_forecast
from routers.places import get_attractions
from services.text_sanitize import strip_markdown

logger = logging.getLogger("lemon_ai")

SYSTEM_PROMPT = """You are Lemon.ai, a friendly, practical travel-planning assistant.
You will receive a traveler's trip details plus real weather and attraction data for
their destination. Build a realistic day-by-day itinerary using that data.

Respond with ONLY a valid JSON object — no markdown fences, no commentary, no extra text.
It must match exactly this shape:

{
  "summary": "2-3 sentence overview of the plan",
  "days": [
    {
      "day": 1,
      "date": "YYYY-MM-DD or null if unknown",
      "activities": [
        {"time": "09:00", "activity": "short description", "location": "place name or null", "notes": "optional tip or null"}
      ]
    }
  ]
}

CRITICAL FORMATTING RULES:
- Do NOT use any markdown symbols such as ##, #, **, *, _, or bullets in any strings.
- Keep all summaries, activity names, locations, and notes in plain, clean text without any headers or symbols.

If the weather or attraction data provided is missing or has an "error" field, do not
mention the error to the user — just fall back to sensible general suggestions for that
destination instead."""


async def build_itinerary(trip: TripRequest) -> ItineraryResponse:
    # Step 1: gather context, best-effort. Each call is independently wrapped so one
    # failing API doesn't take down the whole itinerary request.
    try:
        weather_context = await get_forecast(city=trip.destination)
    except Exception as e:
        logger.warning(f"Weather lookup failed for '{trip.destination}': {e}")
        weather_context = {"error": "weather data unavailable"}

    try:
        attractions_context = await get_attractions(city=trip.destination)
    except Exception as e:
        logger.warning(f"Attractions lookup failed for '{trip.destination}': {e}")
        attractions_context = {"error": "attraction data unavailable"}

    # Step 2: build the single prompt
    user_prompt = f"""Trip request:
- Destination: {trip.destination}
- Dates: {trip.start_date} to {trip.end_date}
- Travelers: {trip.travelers}
- Budget level: {trip.budget_level}
- Interests: {', '.join(trip.interests) if trip.interests else 'no specific preference given'}

Weather data:
{json.dumps(weather_context)}

Attractions data:
{json.dumps(attractions_context)}"""

    # Step 3: single call to the chosen provider
    provider = get_provider(trip.provider)
    raw = await provider.generate_json(SYSTEM_PROMPT, user_prompt)

    # Step 4: parse and validate before it ever reaches the user
    try:
        parsed = json.loads(raw)
    except json.JSONDecodeError as e:
        logger.error(f"{provider.name} returned non-JSON output: {raw[:300]}")
        raise ValueError(
            f"{provider.name} did not return valid JSON ({e}). "
            f"This usually means the prompt needs tightening for that provider."
        )

    parsed["destination"] = trip.destination
    parsed["provider_used"] = provider.name

    # Pydantic validation — if the shape is wrong, this raises a clear error rather
    # than silently returning malformed data to the Flutter app.
    return ItineraryResponse(**parsed)

    # Step 4: parse and validate before it ever reaches the user
    try:
        parsed = json.loads(raw)
    except json.JSONDecodeError as e:
        logger.error(f"{provider.name} returned non-JSON output: {raw[:300]}")
        raise ValueError(
            f"{provider.name} did not return valid JSON ({e}). "
            f"This usually means the prompt needs tightening for that provider."
        )

    parsed["destination"] = trip.destination
    parsed["provider_used"] = provider.name

    # Server-side backstop against stray markdown (##, **, etc.) — the
    # Flutter app also sanitizes, but cleaning it here too means every
    # client that ever calls this API gets plain text.
    if parsed.get("summary"):
        parsed["summary"] = strip_markdown(parsed["summary"])
    for day in parsed.get("days", []):
        for activity in day.get("activities", []):
            for field in ("activity", "location", "notes"):
                if activity.get(field):
                    activity[field] = strip_markdown(activity[field])

    return ItineraryResponse(**parsed)
