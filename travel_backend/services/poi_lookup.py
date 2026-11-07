"""
Geoapify lookups for one place, such as a landmark, museum or neighbourhood,
rather than a destination (DECISIONS 069). Used to confirm Lemon's popular
spots, the must-visit places a traveller types, and the places a plan names.

- Each lookup is one Geoapify geocoding request (1 credit). Calls go through one
  limiter that keeps them under the free plan's 5 requests per second.
- Answers, including "no match", are cached for a day, so repeat plans and chat
  turns don't spend quota again. Errors are not cached.
- A result counts only when its name matches what was asked, or, when exact
  coordinates are known (a Wikidata spot), when it sits within EXACT_METRES of them.
  City, region and country results never count: they mean the geocoder fell
  back to the area itself.

Settings and the HTTP client are imported lazily, so offline tests never load
`config` (and so never load keys). Tests replace `find_place`.
"""
import asyncio
import logging
import math
import re
import time
from collections import deque
from typing import Optional

from services.geo_results import norm
from services.ttl_cache import TTLCache

logger = logging.getLogger("lemon_ai")

RATE_PER_SECOND = 5          # Geoapify free plan limit (pricing page, 2026-11-05)
REQUEST_TIMEOUT_SECONDS = 8.0
EXACT_METRES = 250
_cache = TTLCache(ttl_seconds=24 * 3600, max_entries=5000)
# Result kinds that are an area, not a spot.
_AREAS = {"city", "state", "country", "county", "postcode"}
# Words that say what kind of place it is, not which one ("museum", "temple").
_KIND_WORDS = {
    "the", "of", "de", "du", "des", "la", "le", "les", "el", "al", "and", "st", "saint", "san", "santa",
    "museum", "musee", "museo", "temple", "church", "park", "tower", "palace", "garden", "gardens",
    "market", "square", "station", "national", "cathedral", "shrine", "castle", "bridge", "street",
    "road", "avenue", "plaza", "praca", "place", "monument", "memorial", "gallery", "centre", "center",
    "basilica", "mosque", "abbey", "fort", "old", "new", "city", "great", "royal", "art", "arts",
    # Shops and food places (DECISIONS 071): "Bob's Cafe" is not "Cafe Nero".
    "cafe", "coffee", "tea", "house", "teahouse", "shop", "store", "restaurant", "bar", "pub",
    "bakery", "bistro", "diner", "food", "noodle", "noodles", "hotel",
    # The same in Japanese: kissa / kissaten (cafe), menya (noodle shop), jinja /
    # taisha / jingu (shrine), dera / tera (temple).
    "kissa", "kissaten", "menya", "ramen", "sushi", "izakaya", "udon", "soba", "jinja", "taisha",
    "jingu", "dera", "tera",
}


class _Limiter:
    """At most `rate` calls in any one-second window, shared by every caller."""

    def __init__(self, rate: int):
        self.rate = rate
        self._stamps: deque = deque()
        self._lock = asyncio.Lock()

    async def wait(self) -> None:
        async with self._lock:
            now = time.monotonic()
            while self._stamps and now - self._stamps[0] >= 1.0:
                self._stamps.popleft()
            if len(self._stamps) >= self.rate:
                await asyncio.sleep(1.0 - (now - self._stamps[0]) + 0.01)
                self._stamps.popleft()
            self._stamps.append(time.monotonic())


_limiters: dict = {}


def _limiter() -> _Limiter:
    # One per event loop: asyncio locks can't cross loops (tests run several).
    loop = asyncio.get_running_loop()
    limiter = _limiters.get(loop)
    if limiter is None:
        _limiters.clear()
        limiter = _limiters[loop] = _Limiter(RATE_PER_SECOND)
    return limiter


def metres_between(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    r = 6371000.0
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dp, dl = p2 - p1, math.radians(lon2 - lon1)
    a = math.sin(dp / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
    return 2 * r * math.asin(min(1.0, math.sqrt(a)))


def _fold(text: str) -> str:
    """Lower case, accents dropped ("Musée" -> "musee"), punctuation as spaces."""
    import unicodedata
    plain = "".join(ch for ch in unicodedata.normalize("NFKD", str(text or ""))
                    if not unicodedata.combining(ch))
    return " ".join(re.sub(r"[^\w]+", " ", plain.casefold()).split())


def same_place(asked: str, found: str) -> bool:
    """Does a geocoder name plausibly name the place that was asked for?

    One name inside the other counts. Otherwise kind words ("museum", "kissa")
    are set aside and every remaining word of the asked name must be in the
    found one (DECISIONS 071). "Louvre Museum" ~ "Musée du Louvre"; "Eiffel
    Tower" ~ "Tour Eiffel"; "Fushimi Inari" ~ "Fushimi Inari-taisha"; but
    "Hanamiya Kissa" is not "Kissa Gobo Gobo", and "Arashiyama Monkey Park" is
    not "Arashiyama Station" (one shared word used to be enough). Two names
    made only of kind words ("National Museum") must contain one another.
    """
    a, b = _fold(asked), _fold(found)
    if not a or not b:
        return False
    if len(a) >= 4 and len(b) >= 4 and (a in b or b in a):
        return True
    words_a = {w for w in a.split() if len(w) >= 3 and w not in _KIND_WORDS}
    words_b = {w for w in b.split() if len(w) >= 3 and w not in _KIND_WORDS}
    if not words_a or not words_b:
        return False
    return words_a <= words_b


async def _geocode(params: dict) -> list:
    """One Geoapify geocoding request (lazy imports: see module docstring)."""
    import httpx
    from config import settings
    await _limiter().wait()
    async with httpx.AsyncClient(timeout=REQUEST_TIMEOUT_SECONDS) as client:
        resp = await client.get(f"{settings.GEOAPIFY_BASE_URL}/v1/geocode/search",
                                params={**params, "apiKey": settings.GEOAPIFY_API_KEY})
        resp.raise_for_status()
        data = resp.json()
    results = data.get("results") if isinstance(data, dict) else None
    return results if isinstance(results, list) else []


async def _lookup(name: str, lat: float, lon: float, radius_m: int,
                  exact: Optional[tuple]) -> dict:
    results = await _geocode({
        "text": name, "format": "json", "limit": 3, "lang": "en",
        "bias": f"proximity:{lon},{lat}",
        "filter": f"circle:{lon},{lat},{int(radius_m)}",
    })
    for r in results:
        if not isinstance(r, dict) or r.get("result_type") in _AREAS:
            continue
        rlat, rlon = r.get("lat"), r.get("lon")
        if not isinstance(rlat, (int, float)) or not isinstance(rlon, (int, float)):
            continue
        shown = r.get("name") or r.get("address_line1") or ""
        close = exact is not None and r.get("name") and \
            metres_between(exact[0], exact[1], rlat, rlon) <= EXACT_METRES
        if same_place(name, shown) or close:
            return {"name": shown or name, "place_id": r.get("place_id"),
                    "lat": float(rlat), "lon": float(rlon)}
    return {}  # cached "no match"


async def find_place(name: str, lat: float, lon: float, radius_m: int = 40000,
                     exact: Optional[tuple] = None) -> Optional[dict]:
    """The place `name` near (lat, lon): {name, place_id, lat, lon}, or None
    when Geoapify has no matching place there. Raises when the lookup itself
    fails (timeout, quota, offline), so callers can tell "not found" from
    "couldn't check"."""
    key = (norm(name), round(lat, 3), round(lon, 3), int(radius_m), exact is not None)
    found = await _cache.get_or_fetch(key, lambda: _lookup(name, lat, lon, radius_m, exact))
    return found or None


async def destination_centre(destination: str) -> Optional[dict]:
    """{lat, lon, radius_m} for the trip's destination via the shared, cached
    geocoder; None when it can't be found. Regions get a wider circle."""
    from routers.weather import _geocode_city  # lazy: see module docstring
    location = await _geocode_city(destination)
    lat, lon = location.get("lat"), location.get("lon")
    if not isinstance(lat, (int, float)) or not isinstance(lon, (int, float)):
        return None
    return {"lat": float(lat), "lon": float(lon),
            "radius_m": 80000 if location.get("region_id") else 40000}
