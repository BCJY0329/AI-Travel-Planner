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

logger = logging.getLogger("lemon_ai")

SYSTEM_PROMPT = """You are Lemon.ai, a friendly, practical travel-planning assistant.
You will receive a traveler's trip details plus real weather and attraction data for
their destination. Build a realistic day-by-day itinerary using that data.

Personality: write the "summary" and any activity "notes" with warmth and genuine
enthusiasm for the destination — like a well-traveled friend sharing recommendations,
not a dry schedule generator. A little personality is welcome (an occasional exclamation
mark, a light aside), but keep it tasteful: no more than one emoji total across the whole
response, and never let the enthusiasm get in the way of the itinerary actually being
useful and specific.

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