"""
Destination banner photos via Pixabay.

A place ("Kyoto", "Bavaria") is geocoded with the shared, cached OpenWeatherMap
lookup to find its country, and photos are searched per country, so every city
in a country shares one cached search. Pixabay's terms require caching searches
for 24 hours and forbid permanent hotlinking, so image bytes are downloaded and
served from this backend (/photos/image/{id}) with a credit to Pixabay.
"""
from urllib.parse import urlparse

import httpx
from fastapi import APIRouter, HTTPException, Query, Response
from config import settings
from models.photos import FeaturedPhotosResponse, PlacePhotosResponse
from routers.weather import _geocode_city
from services.countries import country_name
from services.ttl_cache import TTLCache, normalize

router = APIRouter(prefix="/photos", tags=["photos"])

_search_cache = TTLCache(ttl_seconds=24 * 3600, max_entries=300)
# Banner images are ~150-400 KB each, so this stays around 30 MB at most.
_image_cache = TTLCache(ttl_seconds=24 * 3600, max_entries=80)
# Photo id -> Pixabay CDN URL, learned from searches. Bounded; oldest dropped first.
_image_sources: dict[int, str] = {}
_MAX_SOURCES = 2000
_MAX_IMAGE_BYTES = 5 * 1024 * 1024
# Each search tries these extra filters in order until one has hits.
_PLACE_FILTERS = ({"category": "travel"}, {})
_FEATURED_FILTERS = ({"category": "travel", "editors_choice": "true"}, {"category": "travel"})
_FEATURED_QUERY = "travel landscape"


@router.get("/place", response_model=PlacePhotosResponse)
async def get_place_photos(place: str = Query(..., min_length=1, max_length=120,
                                              description="Destination, e.g. 'Kyoto'")):
    """Up to 3 photos of the country a place is in (of the place itself if the country is unknown)."""
    if not settings.PIXABAY_API_KEY:
        raise HTTPException(status_code=503, detail="PIXABAY_API_KEY is not configured")

    location = await _geocode_city(place)
    country = country_name(location.get("country"))
    subject = country or location["name"]
    photos = await _search_cache.get_or_fetch(
        normalize(subject), lambda: _search(subject, 3, _PLACE_FILTERS))
    return {"place": location["name"], "country_code": location.get("country"),
            "country": country, "photos": _publish(photos)}


@router.get("/featured", response_model=FeaturedPhotosResponse)
async def get_featured_photos():
    """Up to 10 Pixabay editors' choice travel photos for the Discover hero slideshow."""
    if not settings.PIXABAY_API_KEY:
        raise HTTPException(status_code=503, detail="PIXABAY_API_KEY is not configured")
    photos = await _search_cache.get_or_fetch(
        ("featured",), lambda: _search(_FEATURED_QUERY, 10, _FEATURED_FILTERS))
    return {"photos": _publish(photos)}


@router.get("/image/{photo_id}")
async def get_photo_image(photo_id: int):
    """Serves a photo found by /photos/place. Unknown ids (e.g. after a restart) are 404."""
    source = _image_sources.get(photo_id)
    if source is None:
        raise HTTPException(status_code=404, detail="Unknown photo")
    content, media_type = await _image_cache.get_or_fetch(photo_id, lambda: _download(source))
    return Response(content=content, media_type=media_type,
                    headers={"Cache-Control": "public, max-age=86400"})


def _publish(photos: list[dict]) -> list[dict]:
    """Registers each photo's CDN URL for /photos/image and drops it from the response."""
    for photo in photos:
        _remember_source(photo["id"], photo.pop("source"))
    return photos


async def _search(subject: str, count: int, filters: tuple[dict, ...]) -> list[dict]:
    params = {
        "key": settings.PIXABAY_API_KEY,
        "q": subject[:100],
        "image_type": "photo",
        "orientation": "horizontal",
        "safesearch": "true",
        "min_width": 1280,
        "per_page": max(count, 3),  # Pixabay's minimum is 3
    }
    try:
        async with httpx.AsyncClient(timeout=10) as client:
            for extra in filters:
                resp = await client.get(f"{settings.PIXABAY_BASE_URL}/api/",
                                        params={**params, **extra})
                resp.raise_for_status()
                hits = resp.json().get("hits") or []
                if hits:
                    break
    except httpx.HTTPStatusError as e:
        # Never echo the request or response: the URL carries the API key.
        status = 429 if e.response.status_code == 429 else 502
        raise HTTPException(status_code=status, detail="Photo search failed")
    except (httpx.RequestError, ValueError, AttributeError):
        raise HTTPException(status_code=502, detail="Photo search is unavailable right now.")

    photos = []
    for hit in hits[:count]:
        try:
            source = hit["largeImageURL"]
            if not (urlparse(source).hostname or "").endswith("pixabay.com"):
                continue
            photos.append({
                "id": int(hit["id"]),
                "image_url": f"/photos/image/{int(hit['id'])}",
                "page_url": hit.get("pageURL") or "https://pixabay.com/",
                "photographer": hit.get("user") or "Pixabay",
                "photographer_url": f"https://pixabay.com/users/{hit.get('user', '')}-{hit.get('user_id', '')}/",
                "tags": hit.get("tags") or "",
                "source": source,
            })
        except (KeyError, TypeError, ValueError):
            continue  # Skip an incomplete hit rather than failing the search.
    return photos


def _remember_source(photo_id: int, source: str) -> None:
    _image_sources.pop(photo_id, None)
    _image_sources[photo_id] = source
    while len(_image_sources) > _MAX_SOURCES:
        del _image_sources[next(iter(_image_sources))]


async def _download(source: str) -> tuple[bytes, str]:
    try:
        async with httpx.AsyncClient(timeout=15, follow_redirects=True) as client:
            resp = await client.get(source)
            resp.raise_for_status()
    except (httpx.HTTPStatusError, httpx.RequestError):
        raise HTTPException(status_code=502, detail="Photo download failed")
    media_type = resp.headers.get("content-type", "").split(";")[0].strip()
    if not media_type.startswith("image/") or len(resp.content) > _MAX_IMAGE_BYTES:
        raise HTTPException(status_code=502, detail="Photo download failed")
    return resp.content, media_type
