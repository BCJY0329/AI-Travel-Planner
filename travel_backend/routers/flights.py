"""
Flight search (view-only) via Duffel's test mode (free sandbox, no billing account
needed for a 'duffel_test_' key). Replaces Amadeus Flight Offers Search, which went
away with the Amadeus self-service portal shutdown on July 17, 2026.

Duffel is a two-step flow: create an "offer request" (POST), then read back the
offers it generated (GET). No booking step is implemented here.
"""
from datetime import date

import httpx
from fastapi import APIRouter, HTTPException, Query
from config import settings
from services.ttl_cache import TTLCache

router = APIRouter(prefix="/flights", tags=["flights"])

# Prices move, so offers are only reused briefly (Duffel offers stay valid
# longer than this). Enough to absorb repeat clicks on the same search.
_offers_cache = TTLCache(ttl_seconds=5 * 60)

_HEADERS = {
    "Duffel-Version": "v2",
    "Content-Type": "application/json",
}

# With return_offers=true Duffel answers only after polling every airline, which
# in test mode regularly exceeds 15 s. Fail fast on connect, wait longer on read.
# The frontend waits slightly longer than this (TravelApiService).
_TIMEOUT = httpx.Timeout(45.0, connect=10.0)

# Rejected with 422 before any Duffel call.
_IATA = r"^\s*[A-Za-z]{3}\s*$"
_ISO_DATE = r"^\d{4}-\d{2}-\d{2}$"



def _simplify(offer: dict) -> dict:
    slice0 = offer["slices"][0]
    segments = slice0["segments"]
    return {
        "price": offer["total_amount"],
        "currency": offer["total_currency"],
        "duration": slice0.get("duration"),
        "stops": len(segments) - 1,
        "departure": segments[0]["origin"]["iata_code"],
        "departure_time": segments[0]["departing_at"],
        "arrival": segments[-1]["destination"]["iata_code"],
        "arrival_time": segments[-1]["arriving_at"],
        # The arrival airport's city, e.g. "Tokyo" for NRT; used for banner photos.
        "arrival_city": segments[-1]["destination"].get("city_name"),
        "carrier": segments[0]["operating_carrier"]["iata_code"],
    }


@router.get("/search")
async def search_flights(
    origin: str = Query(..., pattern=_IATA, description="Origin IATA code, e.g. 'KUL'"),
    destination: str = Query(..., pattern=_IATA, description="Destination IATA code, e.g. 'NRT'"),
    departure_date: str = Query(..., pattern=_ISO_DATE, description="YYYY-MM-DD"),
    adults: int = Query(1, ge=1, le=9),
):
    """Returns a simplified list of flight offers — for viewing only, not booking."""
    try:
        date.fromisoformat(departure_date)  # The pattern alone accepts 2026-02-31.
    except ValueError:
        raise HTTPException(status_code=422, detail="departure_date must be a real YYYY-MM-DD date")
    key = (origin.strip().upper(), destination.strip().upper(), departure_date, adults)
    return await _offers_cache.get_or_fetch(
        key, lambda: _fetch_offers(key[0], key[1], departure_date, adults))


async def _fetch_offers(origin: str, destination: str, departure_date: str, adults: int) -> dict:
    if not settings.DUFFEL_API_KEY:
        raise HTTPException(status_code=500, detail="DUFFEL_API_KEY is not configured")

    headers = {**_HEADERS, "Authorization": f"Bearer {settings.DUFFEL_API_KEY}"}
    body = {
        "data": {
            "slices": [
                {
                    "origin": origin.upper(),
                    "destination": destination.upper(),
                    "departure_date": departure_date,
                }
            ],
            "passengers": [{"type": "adult"} for _ in range(adults)],
            "cabin_class": "economy",
        }
    }

    try:
        async with httpx.AsyncClient(timeout=_TIMEOUT) as client:
            # Step 1: create the offer request. return_offers=true gets us
            # results in the same call, avoiding a slower second round trip.
            create_resp = await client.post(
                f"{settings.DUFFEL_BASE_URL}/air/offer_requests?return_offers=true",
                headers=headers,
                json=body,
            )
            create_resp.raise_for_status()
            data = create_resp.json()["data"]
    except httpx.HTTPStatusError as e:
        raise HTTPException(status_code=e.response.status_code, detail="Flight search failed")
    except httpx.TimeoutException:
        raise HTTPException(status_code=504, detail="Flight search timed out. Please try again.")
    except (httpx.RequestError, ValueError, KeyError, TypeError):
        # Network failure or a response body without the expected "data" object.
        raise HTTPException(status_code=502, detail="Flight search is unavailable right now.")

    simplified = []
    for offer in data.get("offers", []):
        try:
            simplified.append(_simplify(offer))
        except (KeyError, IndexError, TypeError):
            continue  # Skip an incomplete offer rather than failing the search.
        if len(simplified) == 10:
            break
    return {"offers": simplified}
