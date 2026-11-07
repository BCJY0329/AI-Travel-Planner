import asyncio
import logging
from typing import List
from fastapi import APIRouter, HTTPException, Query
from models.itinerary import TripRequest, ItineraryResponse, PlanEditRequest, PlanEditResponse
from models.chat import LemonChatRequest, LemonChatResponse
from services.itinerary_builder import EditFailed, build_itinerary, edit_day
from services.chat_parser import parse_chat
from services import popular_spots as spots_service

logger = logging.getLogger("lemon_ai")

router = APIRouter(prefix="/lemon", tags=["lemon-ai"])

# Clients only ever see these. Exception details stay in the server log, since
# provider errors can echo prompts, trip details or upstream responses.
_PLAN_FAILED = "Lemon couldn't build this itinerary right now. Please try again."
_CHAT_FAILED = "Lemon had trouble understanding that. Please try again."
_EDIT_FAILED = "Lemon couldn't change that day right now. Your plan is unchanged."
# The spots lookup can take ~35 s for a big city (Wikidata); it keeps running
# and caching after this, so a later request gets it at once.
SPOTS_WAIT_SECONDS = 60.0


@router.post("/plan", response_model=ItineraryResponse)
async def plan_trip(trip: TripRequest):
    """
    Generate a full itinerary in a single AI call, using real weather/attraction
    data as context. `provider` in the request body picks which LLM answers:
    'auto', 'groq', 'gemini', 'openrouter', or 'mock' (local demo output).
    Auto may attempt multiple providers before falling back to mock.
    """
    try:
        return await build_itinerary(trip)
    except Exception:
        logger.exception(f"Itinerary generation failed for provider '{trip.provider}' in /lemon/plan")
        raise HTTPException(status_code=502, detail=_PLAN_FAILED)


@router.post("/edit", response_model=PlanEditResponse)
async def edit_plan(payload: PlanEditRequest):
    """
    Change one day of an existing plan (DECISIONS 069): 'regenerate_day',
    'swap_activity' (one stop) or 'adjust_day' (from the traveller's words).
    Returns only the new day, for the app to preview before it replaces the old
    one. A real plan never gets a demo day: if every provider fails, this is a
    502 and the plan stays as it was.
    """
    try:
        return await edit_day(payload)
    except EditFailed:
        logger.warning("Day %d edit failed on every provider", payload.day)
        raise HTTPException(status_code=502, detail=_EDIT_FAILED)
    except Exception:
        logger.exception(f"Day edit failed for provider '{payload.trip.provider}' in /lemon/edit")
        raise HTTPException(status_code=502, detail=_EDIT_FAILED)


@router.get("/spots")
async def popular_spots(destination: str = Query(..., min_length=1, max_length=120),
                        interests: List[str] = Query(default_factory=list, max_length=12)):
    """
    Popular spots for Lemon's must-visit buttons (DECISIONS 069), most popular
    first: {status, destination, spots: [{name, place_id, lat, lon, popularity, kind}],
    picks: [names]}. `picks` are Lemon's choice for "surprise me", suited to
    `interests`. status: 'ready', 'none' (nothing found), 'too_broad' (a whole
    country: Lemon asks for a city or area) or 'unavailable' (a service failed
    or was slow).
    """
    try:
        result = await asyncio.wait_for(asyncio.shield(spots_service.popular_spots(destination)),
                                        SPOTS_WAIT_SECONDS)
        picks = spots_service.lemon_picks(result.get("spots", []), [i[:120] for i in interests])
        return {**result, "picks": [p["name"] for p in picks]}
    except asyncio.TimeoutError:
        logger.warning("Popular spots still loading after %.0fs", SPOTS_WAIT_SECONDS)
    except Exception as e:
        logger.warning("Popular spots unavailable (%s)", type(e).__name__)
    return {"status": "unavailable", "destination": destination, "spots": [], "picks": []}


@router.post("/chat", response_model=LemonChatResponse)
async def chat_intake(payload: LemonChatRequest):
    """
    One turn of the freeform trip-planning conversation. Send the full message
    history each time; get back Lemon's next reply plus whatever trip fields
    have been extracted so far. When `ready` is true and destination/start/end
    date are all present, the client follows up with POST /lemon/plan.
    """
    try:
        result = await parse_chat(payload)
    except Exception:
        logger.exception(f"Chat parsing failed for provider '{payload.provider}' in /lemon/chat")
        raise HTTPException(status_code=502, detail=_CHAT_FAILED)
    if result.destination_status == "verified":
        # Warm the cache so Lemon's popular spots are ready when the app asks.
        spots_service.prefetch(result.destination_label or result.destination)
    return result
