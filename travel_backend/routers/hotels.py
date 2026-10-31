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
from routers.weather import _area_filter, _geocode_city, _items
from services.ttl_cache import TTLCache, normalize

router = APIRouter(prefix="/hotels", tags=["hotels"])

# Hotel names and locations rarely change; a day keeps repeat searches off the quota.
_hotels_cache = TTLCache(ttl_seconds=24 * 3600)


@router.get("/search")
async def search_hotels(
    city: str = Query(..., min_length=1, max_length=120, description="City name, e.g. 'Paris'"),
    radius_km: int = Query(5, ge=1, le=20),
):
    """Returns hotel listings (name + location) near a city center. No live pricing."""
    return await _hotels_cache.get_or_fetch(
        (normalize(city), radius_km), lambda: _fetch_hotels(city, radius_km))


async def _fetch_hotels(city: str, radius_km: int) -> dict:
    location = await _geocode_city(city)

    try:
        url = f"{settings.GEOAPIFY_BASE_URL}/v2/places"
        params = {
            "categories": "accommodation.hotel",
            "filter": _area_filter(location, radius_km),
            "limit": 20,
            "apiKey": settings.GEOAPIFY_API_KEY,
        }
        async with httpx.AsyncClient(timeout=10) as client:
            resp = await client.get(url, params=params)
            resp.raise_for_status()
            data = resp.json()
    except httpx.HTTPStatusError as e:
        raise HTTPException(status_code=e.response.status_code, detail="Hotel search failed")
    except httpx.TimeoutException:
        raise HTTPException(status_code=504, detail="Hotel search timed out. Please try again.")
    except (httpx.RequestError, ValueError):
        raise HTTPException(status_code=502, detail="Hotel search is unavailable right now.")

    simplified = []
    for feature in _items(data, "features"):
        try:
            if not feature["properties"].get("name"):
                continue
            simplified.append({
                "name": feature["properties"]["name"],
                "address": feature["properties"].get("formatted"),
                "lat": feature["geometry"]["coordinates"][1],
                "lon": feature["geometry"]["coordinates"][0],
            })
        except (KeyError, IndexError, TypeError, AttributeError):
            continue  # Skip an incomplete hotel rather than failing the search.
    return {"city": location["name"], "hotels": simplified}
