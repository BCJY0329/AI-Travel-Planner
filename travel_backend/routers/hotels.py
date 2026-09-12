"""
Hotel listings via Geoapify Places API (free tier, no billing account needed).
Replaces Amadeus Hotel List + Hotel Offers, which went away with the
Amadeus self-service portal shutdown on July 17, 2026.

Note: Geoapify gives location/name only, no live pricing — no commercial hotel
pricing API is realistically free. Since this project already isn't doing real
booking/payments yet, that's an acceptable gap for now rather than a regression.
"""
import httpx
from fastapi import APIRouter, HTTPException, Query
from config import settings
from routers.weather import _geocode_city

router = APIRouter(prefix="/hotels", tags=["hotels"])


@router.get("/search")
async def search_hotels(
    city: str = Query(..., description="City name, e.g. 'Paris'"),
    radius_km: int = Query(5, ge=1, le=20),
):
    """Returns hotel listings (name + location) near a city center. No live pricing."""
    location = await _geocode_city(city)

    try:
        url = f"{settings.GEOAPIFY_BASE_URL}/v2/places"
        params = {
            "categories": "accommodation.hotel",
            "filter": f"circle:{location['lon']},{location['lat']},{radius_km * 1000}",
            "limit": 20,
            "apiKey": settings.GEOAPIFY_API_KEY,
        }
        async with httpx.AsyncClient(timeout=10) as client:
            resp = await client.get(url, params=params)
            resp.raise_for_status()
            data = resp.json()
    except httpx.HTTPStatusError as e:
        raise HTTPException(status_code=e.response.status_code, detail="Hotel search failed")

    simplified = [
        {
            "name": feature["properties"].get("name") or "Unnamed hotel",
            "address": feature["properties"].get("formatted"),
            "lat": feature["geometry"]["coordinates"][1],
            "lon": feature["geometry"]["coordinates"][0],
        }
        for feature in data.get("features", [])
        if feature["properties"].get("name")
    ]
    return {"city": location["name"], "hotels": simplified}
