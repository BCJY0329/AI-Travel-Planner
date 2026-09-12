"""
Thin async client for Amadeus Self-Service APIs.
Handles OAuth2 client-credentials auth and caches the token until it expires.
"""
import time
import httpx
from config import settings

_token_cache = {"access_token": None, "expires_at": 0}


async def _get_access_token() -> str:
    """Return a cached Amadeus access token, refreshing it if expired."""
    now = time.time()
    if _token_cache["access_token"] and now < _token_cache["expires_at"] - 30:
        return _token_cache["access_token"]

    url = f"{settings.AMADEUS_BASE_URL}/v1/security/oauth2/token"
    data = {
        "grant_type": "client_credentials",
        "client_id": settings.AMADEUS_API_KEY,
        "client_secret": settings.AMADEUS_API_SECRET,
    }

    async with httpx.AsyncClient(timeout=10) as client:
        resp = await client.post(url, data=data)
        resp.raise_for_status()
        payload = resp.json()

    _token_cache["access_token"] = payload["access_token"]
    _token_cache["expires_at"] = now + payload["expires_in"]
    return _token_cache["access_token"]


async def amadeus_get(endpoint: str, params: dict) -> dict:
    """
    Call any Amadeus GET endpoint with auth already handled.
    `endpoint` should start with a slash, e.g. '/v2/shopping/flight-offers'.
    Raises httpx.HTTPStatusError on non-2xx responses — callers should catch it.
    """
    token = await _get_access_token()
    url = f"{settings.AMADEUS_BASE_URL}{endpoint}"
    headers = {"Authorization": f"Bearer {token}"}

    async with httpx.AsyncClient(timeout=15) as client:
        resp = await client.get(url, params=params, headers=headers)
        resp.raise_for_status()
        return resp.json()
