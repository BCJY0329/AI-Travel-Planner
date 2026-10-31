import logging
from fastapi import APIRouter, HTTPException
from models.itinerary import TripRequest, ItineraryResponse
from models.chat import LemonChatRequest, LemonChatResponse
from services.itinerary_builder import build_itinerary
from services.chat_parser import parse_chat

logger = logging.getLogger("lemon_ai")

router = APIRouter(prefix="/lemon", tags=["lemon-ai"])

# Clients only ever see these. Exception details stay in the server log, since
# provider errors can echo prompts, trip details or upstream responses.
_PLAN_FAILED = "Lemon couldn't build this itinerary right now. Please try again."
_CHAT_FAILED = "Lemon had trouble understanding that. Please try again."


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


@router.post("/chat", response_model=LemonChatResponse)
async def chat_intake(payload: LemonChatRequest):
    """
    One turn of the freeform trip-planning conversation. Send the full message
    history each time; get back Lemon's next reply plus whatever trip fields
    have been extracted so far. When `ready` is true and destination/start/end
    date are all present, the client follows up with POST /lemon/plan.
    """
    try:
        return await parse_chat(payload)
    except Exception:
        logger.exception(f"Chat parsing failed for provider '{payload.provider}' in /lemon/chat")
        raise HTTPException(status_code=502, detail=_CHAT_FAILED)
