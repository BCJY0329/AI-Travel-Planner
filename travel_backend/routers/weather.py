"""
Weather data via OpenWeatherMap, plus the geocoder every place-based route shares.
Two-step lookup: geocode the city name to lat/lon, then fetch the forecast.
Both steps are cached in memory (services/ttl_cache.py) to save API quota.
"""
import logging

import httpx
from fastapi import APIRouter, HTTPException, Query
from config import settings
from services.ttl_cache import TTLCache, normalize

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/weather", tags=["weather"])

# Place coordinates don't move; forecasts refresh every 3 hours upstream.
_geocode_cache = TTLCache(ttl_seconds=24 * 3600, max_entries=1000)
_forecast_cache = TTLCache(ttl_seconds=30 * 60)

# Geoapify results that are a spot, not a destination ("Bali Street").
_NOT_A_DESTINATION = {"street", "building", "amenity", "postcode"}
_REGIONS = {"county", "state", "country"}


def _area_filter(location: dict, radius_km: int) -> str:
    """Geoapify Places filter: a region's whole boundary, else a circle around the point."""
    if location.get("region_id"):
        return f"place:{location['region_id']}"
    return f"circle:{location['lon']},{location['lat']},{radius_km * 1000}"


async def _geocode_city(city: str) -> dict:
    """Shared by weather, places, hotels, photos and airports. Cached per normalized city name."""
    return await _geocode_cache.get_or_fetch(normalize(city), lambda: _lookup_city(city))


async def _lookup_city(city: str) -> dict:
    """Geoapify first: it ranks well-known places first and knows islands and
    regions, so "Bali" is Indonesia's Bali, where OpenWeatherMap only knows the
    town in Bhutan (KI-25). OpenWeatherMap is the fallback if Geoapify fails."""
    try:
        return await _lookup_geoapify(city)
    except HTTPException as e:
        if e.status_code == 404:
            raise
        logger.warning("Geoapify geocoding failed (%s); using OpenWeatherMap", e.status_code)
        return await _lookup_openweather(city)


async def _lookup_geoapify(city: str) -> dict:
    results = await _geoapify_search(city)
    if not results:
        raise HTTPException(status_code=404, detail=f"City '{city}' not found")
    # Geoapify orders by relevance. When that is a region ("Osaka Prefecture"),
    # prefer the same-named city in the same country: hotels and sights are
    # searched around the point, and a region's centre can be far from town.
    # A city elsewhere (Bali in Bhutan) never wins over the top result.
    best = results[0]
    if best.get("result_type") in _REGIONS:
        wanted = city.split(",")[0].strip().lower()

        def same_city(r: dict) -> bool:
            # Exact names only: "Balikpapan" must not count as "Bali".
            name = (r.get("name") or "").lower()
            return (r.get("result_type") == "city"
                    and r.get("country_code") == best.get("country_code")
                    and wanted in {(r.get("city") or "").lower(), name, name.removesuffix(" city")})

        town = next((r for r in results if same_city(r)), None)
        if town is None:
            try:
                town = next((r for r in await _geoapify_search(city, type="city") if same_city(r)), None)
            except HTTPException:
                town = None  # The region is still a good answer.
        best = town or best
    name = best.get("name") or best.get("city") or best.get("state") or best.get("country") or city
    country = best.get("country_code")
    return {"lat": best["lat"], "lon": best["lon"], "name": name,
            "country": country.upper() if isinstance(country, str) else None,
            # A true region (an island, a state) is searched by its boundary.
            "region_id": best.get("place_id") if best.get("result_type") in _REGIONS else None}


async def _geoapify_search(text: str, **extra) -> list[dict]:
    """Geoapify geocoding candidates with coordinates, minus streets and buildings."""
    params = {"text": text, "format": "json", "limit": 5, "lang": "en",
              "apiKey": settings.GEOAPIFY_API_KEY, **extra}
    try:
        async with httpx.AsyncClient(timeout=10) as client:
            resp = await client.get(f"{settings.GEOAPIFY_BASE_URL}/v1/geocode/search", params=params)
            resp.raise_for_status()
            data = resp.json()
    except httpx.HTTPStatusError as e:
        raise HTTPException(status_code=e.response.status_code, detail="Geocoding lookup failed")
    except httpx.TimeoutException:
        raise HTTPException(status_code=504, detail="Place lookup timed out. Please try again.")
    except (httpx.RequestError, ValueError):
        raise HTTPException(status_code=502, detail="Place lookup is unavailable right now.")

    return [r for r in _items(data, "results") if isinstance(r, dict)
            and isinstance(r.get("lat"), (int, float)) and isinstance(r.get("lon"), (int, float))
            and r.get("result_type") not in _NOT_A_DESTINATION]


async def _lookup_openweather(city: str) -> dict:
    url = f"{settings.OPENWEATHER_BASE_URL}/geo/1.0/direct"
    # Ask for a few candidates instead of just 1 — lets us prefer an exact
    # name match over an odd fuzzy hit like "Osaka" -> "Orsk".
    params = {"q": city, "limit": 5, "appid": settings.OPENWEATHER_API_KEY}
    try:
        async with httpx.AsyncClient(timeout=10) as client:
            resp = await client.get(url, params=params)
            resp.raise_for_status()
            results = resp.json()
    except httpx.HTTPStatusError as e:
        raise HTTPException(status_code=e.response.status_code, detail="Geocoding lookup failed")
    except httpx.TimeoutException:
        raise HTTPException(status_code=504, detail="Place lookup timed out. Please try again.")
    except (httpx.RequestError, ValueError):
        # Never echo the error: the request URL carries the API key.
        raise HTTPException(status_code=502, detail="Place lookup is unavailable right now.")

    # Skip malformed candidates rather than failing the whole lookup.
    results = [r for r in results if isinstance(r, dict) and isinstance(r.get("name"), str)
               and "lat" in r and "lon" in r] if isinstance(results, list) else []
    if not results:
        raise HTTPException(status_code=404, detail=f"City '{city}' not found")

    # Prefer a result whose name matches what was typed (case-insensitive),
    # since the API's ranking sometimes surfaces an unrelated fuzzy match first.
    query_name = city.split(",")[0].strip().lower()
    best = next(
        (r for r in results if r["name"].strip().lower() == query_name),
        results[0],  # fall back to the API's top result if nothing matches exactly
    )
    return {"lat": best["lat"], "lon": best["lon"], "name": best["name"],
            "country": best.get("country")}  # ISO 3166 alpha-2, e.g. "JP"


def _items(data, key: str) -> list:
    """The list under data[key], or [] when the payload has an unexpected shape."""
    items = data.get(key) if isinstance(data, dict) else None
    return items if isinstance(items, list) else []


@router.get("/forecast")
async def get_forecast(city: str = Query(..., min_length=1, max_length=120, description="City name, e.g. 'Tokyo'")):
    """5-day / 3-hour forecast for a city — good enough for trip planning ranges."""
    return await _forecast_cache.get_or_fetch(normalize(city), lambda: _fetch_forecast(city))


async def _fetch_forecast(city: str) -> dict:
    try:
        location = await _geocode_city(city)
        url = f"{settings.OPENWEATHER_BASE_URL}/data/2.5/forecast"
        params = {
            "lat": location["lat"],
            "lon": location["lon"],
            "appid": settings.OPENWEATHER_API_KEY,
            "units": "metric",
        }
        async with httpx.AsyncClient(timeout=10) as client:
            resp = await client.get(url, params=params)
            resp.raise_for_status()
            data = resp.json()
    except httpx.HTTPStatusError as e:
        raise HTTPException(status_code=e.response.status_code, detail="Weather lookup failed")
    except httpx.TimeoutException:
        raise HTTPException(status_code=504, detail="Weather lookup timed out. Please try again.")
    except (httpx.RequestError, ValueError):
        raise HTTPException(status_code=502, detail="Weather is unavailable right now.")

    # Trim the response to just what the itinerary UI needs
    simplified = []
    for item in _items(data, "list"):
        try:
            simplified.append({
                "datetime": item["dt_txt"],
                "temp_c": item["main"]["temp"],
                "condition": item["weather"][0]["main"],
                "description": item["weather"][0]["description"],
            })
        except (KeyError, IndexError, TypeError):
            continue  # Skip an incomplete entry rather than failing the forecast.
    return {"city": location["name"], "forecast": simplified}
