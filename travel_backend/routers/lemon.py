import logging
from fastapi import APIRouter, HTTPException
from pydantic import ValidationError
from models.itinerary import TripRequest, ItineraryResponse
from models.chat import LemonChatRequest, LemonChatResponse
from services.itinerary_builder import build_itinerary
from services.chat_parser import parse_chat

logger = logging.getLogger("lemon_ai")

router = APIRouter(prefix="/lemon", tags=["lemon-ai"])


@router.post("/plan", response_model=ItineraryResponse)
async def plan_trip(trip: TripRequest):
    """
    Generate a full itinerary in a single AI call, using real weather/attraction
    data as context. `provider` in the request body picks which LLM answers:
    'claude', 'gpt', 'gemini', or 'mock' (no API key needed, for testing).
    """
    try:
        return await build_itinerary(trip)
    except ValueError as e:
        raise HTTPException(status_code=502, detail=str(e))
    except ValidationError as e:
        raise HTTPException(status_code=502, detail=f"Itinerary shape was invalid: {e}")
    except Exception as e:
        logger.exception(f"Unhandled error from provider '{trip.provider}' in /lemon/plan")
        raise HTTPException(status_code=502, detail=f"The '{trip.provider}' provider failed: {e}")


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
    except ValueError as e:
        raise HTTPException(status_code=502, detail=str(e))
    except ValidationError as e:
        raise HTTPException(status_code=502, detail=f"Chat response shape was invalid: {e}")
    except Exception as e:
        logger.exception(f"Unhandled error from provider '{payload.provider}' in /lemon/chat")
        raise HTTPException(status_code=502, detail=f"The '{payload.provider}' provider failed: {e}")