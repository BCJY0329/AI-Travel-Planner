"""
Flight search (view-only) via Duffel's test mode (free sandbox, no billing account
needed for a 'duffel_test_' key). Replaces Amadeus Flight Offers Search, which went
away with the Amadeus self-service portal shutdown on July 17, 2026.

Duffel is a two-step flow: create an "offer request" (POST), then read back the
offers it generated (GET). No booking step is implemented here.
"""
import httpx
from fastapi import APIRouter, HTTPException, Query
from config import settings

router = APIRouter(prefix="/flights", tags=["flights"])

_HEADERS = {
    "Duffel-Version": "v2",
    "Content-Type": "application/json",
}


@router.get("/search")
async def search_flights(
    origin: str = Query(..., description="Origin IATA code, e.g. 'KUL'"),
    destination: str = Query(..., description="Destination IATA code, e.g. 'NRT'"),
    departure_date: str = Query(..., description="YYYY-MM-DD"),
    adults: int = Query(1, ge=1, le=9),
):
    """Returns a simplified list of flight offers — for viewing only, not booking."""
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
        async with httpx.AsyncClient(timeout=15) as client:
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

    simplified = []
    for offer in data.get("offers", [])[:10]:
        slice0 = offer["slices"][0]
        segments = slice0["segments"]
        simplified.append(
            {
                "price": offer["total_amount"],
                "currency": offer["total_currency"],
                "duration": slice0.get("duration"),
                "stops": len(segments) - 1,
                "departure": segments[0]["origin"]["iata_code"],
                "departure_time": segments[0]["departing_at"],
                "arrival": segments[-1]["destination"]["iata_code"],
                "arrival_time": segments[-1]["arriving_at"],
                "carrier": segments[0]["operating_carrier"]["iata_code"],
            }
        )
    return {"offers": simplified}
