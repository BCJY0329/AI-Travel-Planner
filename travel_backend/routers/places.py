"""
Attractions / points of interest via Geoapify Places API — the same account
and key already used for hotels, just a different category filter. Replaces
OpenTripMap, whose real free tier is quite limited (paid plans start ~$19/mo).
"""
import httpx
from fastapi import APIRouter, HTTPException, Query
from config import settings
from routers.weather import _geocode_city

router = APIRouter(prefix="/places", tags=["places"])


@router.get("/attractions")
async def get_attractions(
    city: str = Query(..., description="City name, e.g. 'Paris'"),
    radius_km: int = Query(5, ge=1, le=20),
):
    """Points of interest (sights, culture, entertainment) near a city center."""
    location = await _geocode_city(city)

    try:
        url = f"{settings.GEOAPIFY_BASE_URL}/v2/places"
        params = {
            "categories": "tourism.sights,entertainment,tourism.attraction",
            "filter": f"circle:{location['lon']},{location['lat']},{radius_km * 1000}",
            "limit": 20,
            "apiKey": settings.GEOAPIFY_API_KEY,
        }
        async with httpx.AsyncClient(timeout=10) as client:
            resp = await client.get(url, params=params)
            resp.raise_for_status()
            data = resp.json()
    except httpx.HTTPStatusError as e:
        raise HTTPException(status_code=e.response.status_code, detail="Places lookup failed")

    simplified = [
        {
            "name": feature["properties"].get("name") or "Unnamed",
            "category": (feature["properties"].get("categories") or [None])[0],
            "lat": feature["geometry"]["coordinates"][1],
            "lon": feature["geometry"]["coordinates"][0],
        }
        for feature in data.get("features", [])
        if feature["properties"].get("name")
    ]
    return {"city": location["name"], "attractions": simplified}
