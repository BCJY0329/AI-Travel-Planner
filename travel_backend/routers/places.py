"""
Attractions / points of interest via Geoapify Places API — the same account
and key already used for hotels, just a different category filter. Replaces
OpenTripMap, whose real free tier is quite limited (paid plans start ~$19/mo).
"""
import httpx
from fastapi import APIRouter, HTTPException, Query
from config import settings
from routers.weather import _area_filter, _geocode_city, _items
from services.ttl_cache import TTLCache, normalize

router = APIRouter(prefix="/places", tags=["places"])

# Points of interest rarely change; a day keeps repeat searches off the quota.
_attractions_cache = TTLCache(ttl_seconds=24 * 3600)


@router.get("/attractions")
async def get_attractions(
    city: str = Query(..., min_length=1, max_length=120, description="City name, e.g. 'Paris'"),
    radius_km: int = Query(5, ge=1, le=20),
):
    """Points of interest (sights, culture, entertainment) near a city center."""
    return await _attractions_cache.get_or_fetch(
        (normalize(city), radius_km), lambda: _fetch_attractions(city, radius_km))


async def _fetch_attractions(city: str, radius_km: int) -> dict:
    location = await _geocode_city(city)

    try:
        url = f"{settings.GEOAPIFY_BASE_URL}/v2/places"
        params = {
            "categories": "tourism.sights,entertainment,tourism.attraction",
            "filter": _area_filter(location, radius_km),
            "limit": 20,
            "apiKey": settings.GEOAPIFY_API_KEY,
        }
        async with httpx.AsyncClient(timeout=10) as client:
            resp = await client.get(url, params=params)
            resp.raise_for_status()
            data = resp.json()
    except httpx.HTTPStatusError as e:
        raise HTTPException(status_code=e.response.status_code, detail="Places lookup failed")
    except httpx.TimeoutException:
        raise HTTPException(status_code=504, detail="Attractions timed out. Please try again.")
    except (httpx.RequestError, ValueError):
        raise HTTPException(status_code=502, detail="Attractions are unavailable right now.")

    simplified = []
    for feature in _items(data, "features"):
        try:
            if not feature["properties"].get("name"):
                continue
            simplified.append({
                "name": feature["properties"]["name"],
                "category": (feature["properties"].get("categories") or [None])[0],
                "lat": feature["geometry"]["coordinates"][1],
                "lon": feature["geometry"]["coordinates"][0],
            })
        except (KeyError, IndexError, TypeError, AttributeError):
            continue  # Skip an incomplete place rather than failing the search.
    return {"city": location["name"], "attractions": simplified}
