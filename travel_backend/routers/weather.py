"""
Weather data via OpenWeatherMap.
Two-step lookup: geocode the city name to lat/lon, then fetch the forecast.
"""
import httpx
from fastapi import APIRouter, HTTPException, Query
from config import settings

router = APIRouter(prefix="/weather", tags=["weather"])


async def _geocode_city(city: str) -> dict:
    url = f"{settings.OPENWEATHER_BASE_URL}/geo/1.0/direct"
    params = {"q": city, "limit": 1, "appid": settings.OPENWEATHER_API_KEY}
    try:
        async with httpx.AsyncClient(timeout=10) as client:
            resp = await client.get(url, params=params)
            resp.raise_for_status()
            results = resp.json()
    except httpx.HTTPStatusError as e:
        raise HTTPException(status_code=e.response.status_code, detail="Geocoding lookup failed")
    except httpx.RequestError as e:
        raise HTTPException(status_code=502, detail=f"Geocoding service unreachable: {e}")

    if not results:
        raise HTTPException(status_code=404, detail=f"City '{city}' not found")
    return {"lat": results[0]["lat"], "lon": results[0]["lon"], "name": results[0]["name"]}


@router.get("/forecast")
async def get_forecast(city: str = Query(..., description="City name, e.g. 'Tokyo'")):
    """5-day / 3-hour forecast for a city — good enough for trip planning ranges."""
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

    # Trim the response to just what the itinerary UI needs
    simplified = [
        {
            "datetime": item["dt_txt"],
            "temp_c": item["main"]["temp"],
            "condition": item["weather"][0]["main"],
            "description": item["weather"][0]["description"],
        }
        for item in data.get("list", [])
    ]
    return {"city": location["name"], "forecast": simplified}
