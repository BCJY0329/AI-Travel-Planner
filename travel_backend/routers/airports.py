"""
Airports for a place, so the Flights tab can follow a planned trip.

Duffel's place suggestions are searched by name first ("Tokyo" -> HND, NRT).
Places without an airport of their own ("Kyoto") are geocoded with the shared,
cached geocoder (routers/weather.py) and matched to airports nearby, nearest first.
"""
import math
import re

import httpx
from fastapi import APIRouter, HTTPException, Query
from config import settings
from models.airports import AirportsResponse
from routers.weather import _geocode_city
from services.ttl_cache import TTLCache, normalize

router = APIRouter(prefix="/airports", tags=["airports"])

# Airports don't move; a day keeps repeat lookups off the quota.
_airports_cache = TTLCache(ttl_seconds=24 * 3600, max_entries=500)
_MAX_AIRPORTS = 3
_NEARBY_METERS = 100_000


@router.get("/search", response_model=AirportsResponse)
async def search_airports(place: str = Query(..., min_length=1, max_length=120,
                                             description="City or place, e.g. 'Kyoto'")):
    """Up to 3 airports serving a place. Empty when none are known."""
    if not settings.DUFFEL_API_KEY:
        raise HTTPException(status_code=503, detail="DUFFEL_API_KEY is not configured")
    airports = await _airports_cache.get_or_fetch(normalize(place), lambda: _find(place.strip()))
    return {"place": place.strip(), "airports": airports}


async def _find(place: str) -> list[dict]:
    by_name = _airports_in(await _suggestions({"query": place}))
    wanted = place.split(",")[0].strip().lower()
    # Name search also matches places that only contain the word ("Kyotango"),
    # so only airports of the city itself count; otherwise look nearby.
    matching = [a for a in by_name if (a["city_name"] or "").lower() == wanted]
    # Then airports named after the place, e.g. "Bali" in an airport's name.
    word = re.compile(rf"\b{re.escape(wanted)}\b", re.IGNORECASE)
    matching = matching or [a for a in by_name if word.search(a["name"])]
    if matching:
        return matching[:_MAX_AIRPORTS]

    try:
        location = await _geocode_city(place)
    except HTTPException as e:
        if e.status_code == 404:
            return []
        raise
    nearby = _airports_in(await _suggestions(
        {"lat": location["lat"], "lng": location["lon"], "rad": _NEARBY_METERS}))
    nearby.sort(key=lambda a: _distance(location, a))
    return nearby[:_MAX_AIRPORTS]


async def _suggestions(params: dict) -> list:
    headers = {"Duffel-Version": "v2", "Authorization": f"Bearer {settings.DUFFEL_API_KEY}"}
    try:
        async with httpx.AsyncClient(timeout=10) as client:
            resp = await client.get(f"{settings.DUFFEL_BASE_URL}/places/suggestions",
                                    params=params, headers=headers)
            resp.raise_for_status()
            data = resp.json()["data"]
    except httpx.HTTPStatusError as e:
        raise HTTPException(status_code=e.response.status_code, detail="Airport lookup failed")
    except httpx.TimeoutException:
        raise HTTPException(status_code=504, detail="Airport lookup timed out. Please try again.")
    except (httpx.RequestError, ValueError, KeyError, TypeError):
        raise HTTPException(status_code=502, detail="Airport lookup is unavailable right now.")
    return data if isinstance(data, list) else []


def _airports_in(places: list) -> list[dict]:
    """Airports from suggestions, in order: an airport itself or a city's airports."""
    found: dict[str, dict] = {}
    for place in places:
        try:
            candidates = (place.get("airports") or []) if place.get("type") == "city" else [place]
            for airport in candidates:
                code = airport["iata_code"]
                if isinstance(code, str) and len(code) == 3 and code not in found:
                    found[code] = {
                        "iata_code": code.upper(),
                        "name": airport.get("name") or code,
                        "city_name": airport.get("city_name") or place.get("name"),
                        "lat": airport.get("latitude"),
                        "lon": airport.get("longitude"),
                    }
        except (AttributeError, KeyError, TypeError):
            continue  # Skip an incomplete suggestion rather than failing the lookup.
    return list(found.values())


def _distance(origin: dict, airport: dict) -> float:
    """Rough distance for ordering; airports without coordinates sort last."""
    if not isinstance(airport["lat"], (int, float)) or not isinstance(airport["lon"], (int, float)):
        return math.inf
    dlat = airport["lat"] - origin["lat"]
    dlon = (airport["lon"] - origin["lon"]) * math.cos(math.radians(origin["lat"]))
    return math.hypot(dlat, dlon)
