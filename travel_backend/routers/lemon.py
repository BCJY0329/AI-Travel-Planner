from fastapi import APIRouter, HTTPException
from pydantic import ValidationError
from models.itinerary import TripRequest, ItineraryResponse
from services.itinerary_builder import build_itinerary

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
        # Bad provider name, or the model returned invalid JSON — client-fixable or retryable.
        raise HTTPException(status_code=502, detail=str(e))
    except ValidationError as e:
        # The model returned JSON, but not in the shape we asked for.
        raise HTTPException(status_code=502, detail=f"Itinerary shape was invalid: {e}")
    except Exception as e:
        # Catch-all for provider SDK errors (bad API key, no credits, model
        # retired, rate limited, network issue, etc.) so the client always
        # gets a clean, readable error instead of a raw 500 traceback.
        raise HTTPException(
            status_code=502,
            detail=f"The '{trip.provider}' provider failed: {e}",
        )