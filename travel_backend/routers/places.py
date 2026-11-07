"""
Attractions / points of interest via Geoapify Places API — the same account
and key already used for hotels, just a different category filter. Replaces
OpenTripMap, whose real free tier is quite limited (paid plans start ~$19/mo).
"""
import asyncio
import logging

import httpx
from fastapi import APIRouter, HTTPException, Query
from config import settings
from routers.weather import _area_filter, _geocode_city, _items
from services.ttl_cache import TTLCache, normalize

router = APIRouter(prefix="/places", tags=["places"])
logger = logging.getLogger(__name__)

# Points of interest rarely change; a day keeps repeat searches off the quota.
_attractions_cache = TTLCache(ttl_seconds=24 * 3600)

# One Geoapify search per app chip (DECISIONS 053). A single search returned
# 20 places in no useful order, mostly memorial plaques, so whole chips stayed
# empty. The app still picks each place's chip from its full category list.
ATTRACTION_GROUPS = (
    "tourism.attraction",                                   # Sightseeing
    "tourism.sights",                                       # Landmark & Sights
    "heritage,entertainment.museum,entertainment.culture",  # Culture & Heritage
    "entertainment",                                        # Entertainment
)
GROUP_FETCH = 20  # places asked for per group
GROUP_KEEP = 10   # places kept per group, after duplicates and plaques


class _PartialResult(Exception):
    """Some groups failed: return what arrived, but keep it out of the cache."""

    def __init__(self, result: dict):
        super().__init__("partial attractions result")
        self.result = result


def _category_list(raw) -> list[str]:
    """Every category string Geoapify gave a place; [] when absent or malformed."""
    if not isinstance(raw, list):
        return []
    return [item for item in raw if isinstance(item, str)]


def _is_plain_memorial(categories: list[str]) -> bool:
    """A memorial with no more specific tag: usually a street plaque. These are
    kept, but only after every other place in the group."""
    return "tourism.sights.memorial" in categories and not any(
        c.startswith(("tourism.sights.memorial.", "heritage", "entertainment"))
        for c in categories)


def _simplify(feature) -> dict | None:
    try:
        if not feature["properties"].get("name"):
            return None
        categories = _category_list(feature["properties"].get("categories"))
        lon, lat = feature["geometry"]["coordinates"][:2]
        if not all(isinstance(v, (int, float)) for v in (lat, lon)):
            return None
        return {
            "name": feature["properties"]["name"],
            # First entry only, kept for older clients; the app classifies
            # from "categories", so Geoapify's order does not matter.
            "category": categories[0] if categories else None,
            "categories": categories,
            "lat": lat,
            "lon": lon,
            # Lets a plan activity at this place carry its id (DECISIONS 069).
            "place_id": feature["properties"].get("place_id"),
        }
    except (KeyError, IndexError, TypeError, AttributeError, ValueError):
        return None  # Skip an incomplete place rather than failing the search.


def _as_http_error(error: Exception) -> HTTPException:
    if isinstance(error, httpx.HTTPStatusError):
        return HTTPException(status_code=error.response.status_code, detail="Places lookup failed")
    if isinstance(error, httpx.TimeoutException):
        return HTTPException(status_code=504, detail="Attractions timed out. Please try again.")
    return HTTPException(status_code=502, detail="Attractions are unavailable right now.")


@router.get("/attractions")
async def get_attractions(
    city: str = Query(..., min_length=1, max_length=120, description="City name, e.g. 'Paris'"),
    radius_km: int = Query(5, ge=1, le=20),
):
    """Points of interest (sights, culture, entertainment) near a city center."""
    try:
        return await _attractions_cache.get_or_fetch(
            (normalize(city), radius_km), lambda: _fetch_attractions(city, radius_km))
    except _PartialResult as partial:
        return partial.result


async def _fetch_group(client: httpx.AsyncClient, url: str, params: dict) -> list[dict]:
    resp = await client.get(url, params=params)
    resp.raise_for_status()
    places = [_simplify(feature) for feature in _items(resp.json(), "features")]
    return [place for place in places if place is not None]


async def _fetch_attractions(city: str, radius_km: int) -> dict:
    location = await _geocode_city(city)

    url = f"{settings.GEOAPIFY_BASE_URL}/v2/places"
    params = {
        "filter": _area_filter(location, radius_km),
        "limit": GROUP_FETCH,
        "apiKey": settings.GEOAPIFY_API_KEY,
    }
    lat, lon = location.get("lat"), location.get("lon")
    if isinstance(lat, (int, float)) and isinstance(lon, (int, float)):
        params["bias"] = f"proximity:{lon},{lat}"  # nearest to the centre first

    async with httpx.AsyncClient(timeout=10) as client:
        results = await asyncio.gather(
            *(_fetch_group(client, url, {**params, "categories": group})
              for group in ATTRACTION_GROUPS),
            return_exceptions=True)

    failures = []
    for group, result in zip(ATTRACTION_GROUPS, results):
        if isinstance(result, BaseException):
            if not isinstance(result, (httpx.HTTPError, ValueError)):
                raise result  # a bug, not an upstream failure
            # Type and status only: httpx messages carry the URL and its apiKey.
            status = getattr(getattr(result, "response", None), "status_code", None)
            logger.warning("Geoapify attractions group %r failed (%s, status %s)",
                           group, type(result).__name__, status)
            failures.append(result)
    if len(failures) == len(results):
        raise _as_http_error(failures[0])

    attractions, seen = [], set()
    for result in results:
        if isinstance(result, BaseException):
            continue
        kept = 0
        # sorted() is stable: Geoapify's nearest-first order holds otherwise.
        for place in sorted(result, key=lambda p: _is_plain_memorial(p["categories"])):
            key = (str(place["name"]).casefold(), place["lat"], place["lon"])
            if key in seen:
                continue  # also returned by an earlier group
            seen.add(key)
            attractions.append(place)
            kept += 1
            if kept == GROUP_KEEP:
                break

    response = {"city": location["name"], "attractions": attractions}
    if failures:
        raise _PartialResult(response)
    return response
