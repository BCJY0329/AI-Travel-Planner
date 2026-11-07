"""
Popular spots for a destination, for Lemon's must-visit suggestions (DECISIONS 069).

Why Wikidata: a live check (2026-11-05) showed Geoapify returns the places
inside a city in no useful order, so the Eiffel Tower, the Louvre and Sensō-ji
never came back. Wikidata knows which places sit inside a destination, and the
number of language Wikipedias covering a place (its "sitelinks") is a good
popularity measure: the Eiffel Tower has about 190, a street plaque none.

Steps for one destination (the result is cached for a day):
  1. Geoapify geocodes it. A whole country is "too_broad": Lemon asks for a
     city or area instead of searching.
  2. Wikidata's search finds the destination's item, picked as the first match
     whose coordinates are within MATCH_KM of Geoapify's point.
  3. One SPARQL query lists visitor places (attractions, museums, monuments,
     places of worship, parks, palaces, towers...) located anywhere inside it,
     most sitelinks first. Demolished places, national parks and office
     buildings are left out.
  4. Each spot is confirmed with Geoapify near Wikidata's coordinates, which
     also gives it the place_id the itinerary uses. Spots Geoapify can't find
     are dropped.

Wikimedia's bot policy requires contact details in the User-Agent
(`WIKIDATA_CONTACT`). Everything network-side is imported lazily, so offline
tests never load `config`.
"""
import asyncio
import logging
import re
from typing import List, Optional

from services.geo_results import norm, split_country_label
from services.ttl_cache import TTLCache

logger = logging.getLogger("lemon_ai")

WIKIDATA_API = "https://www.wikidata.org/w/api.php"
WIKIDATA_SPARQL = "https://query.wikidata.org/sparql"
SPARQL_TIMEOUT_SECONDS = 45.0   # Wikidata stops queries at 60 s; Paris took 33 s live
FETCH_LIMIT = 25                 # spots asked for (one Geoapify check each)
SHOW_MAX = 20                    # spots offered to the traveller
MATCH_KM = 60
VERIFY_RADIUS_M = 1500
LEMON_PICKS = 4

_cache = TTLCache(ttl_seconds=24 * 3600, max_entries=500)

# Wikidata classes counted as visitor places, with the kind shown to the app.
# Subclasses count too (an art museum is a museum).
KINDS = {
    "Q570116": "sight",        # tourist attraction
    "Q2319498": "sight",       # landmark
    "Q33506": "museum",
    "Q4989906": "monument",
    "Q1370598": "worship",     # place of worship
    "Q22698": "park",
    "Q1107656": "garden",
    "Q43501": "zoo",
    "Q16560": "palace",
    "Q23413": "castle",
    "Q12518": "tower",
    "Q1440300": "tower",       # observation tower
    "Q839954": "history",      # archaeological site
    "Q174782": "square",
    "Q12280": "bridge",
    "Q11303": "skyscraper",
}
# Skyscrapers count only when very popular: Petronas Towers (89 sitelinks) and
# Merdeka 118 (40) stay, office towers (NTT Docomo 21, Maxis 11) don't.
SKYSCRAPER_MIN_LINKS = 40
# At most this many spots of one kind before the others: Kuala Lumpur's list
# was otherwise mostly small mosques.
MAX_PER_KIND = 5
# Which kinds suit which interests, for Lemon's picks on "surprise me".
INTEREST_KINDS = {
    "culture & history": {"museum", "monument", "worship", "palace", "castle", "history"},
    "nature": {"park", "garden", "zoo"},
    "relaxation": {"park", "garden"},
    "family-friendly": {"zoo", "park", "museum"},
    "romantic spots": {"tower", "garden", "bridge", "square"},
    "adventure": {"tower"},
    "shopping": {"square"},
}

_SPOTS_QUERY = """
SELECT ?item ?itemLabel ?links ?kind ?coord WHERE {
  {
    SELECT ?item ?links (SAMPLE(?cls) AS ?kind) WHERE {
      hint:Query hint:optimizer "None" .
      ?item wdt:P131+ wd:%(place)s ;
            wikibase:sitelinks ?links .
      FILTER(?links >= 8)
      VALUES ?cls { %(classes)s }
      ?item wdt:P31/wdt:P279* ?cls .
    } GROUP BY ?item ?links
  }
  ?item wdt:P625 ?coord .
  FILTER NOT EXISTS { ?item wdt:P576 [] }
  FILTER NOT EXISTS { ?item wdt:P31 wd:Q46169 }
  FILTER NOT EXISTS { ?item wdt:P31 wd:Q1021645 }
  SERVICE wikibase:label { bd:serviceParam wikibase:language "en". }
} ORDER BY DESC(?links) LIMIT %(limit)d
"""
_COORDS_QUERY = "SELECT ?item ?coord WHERE { VALUES ?item { %s } ?item wdt:P625 ?coord . }"
_POINT_RE = re.compile(r"Point\(\s*(-?[\d.]+)\s+(-?[\d.]+)\s*\)")
_QID_RE = re.compile(r"(Q\d+)$")


class SpotsUnavailable(Exception):
    """Wikidata or Geoapify couldn't be reached, or returned something unusable."""


def _point(value: str) -> Optional[tuple]:
    match = _POINT_RE.search(value or "")
    return (float(match.group(2)), float(match.group(1))) if match else None  # (lat, lon)


def _qid(uri: str) -> Optional[str]:
    match = _QID_RE.search(uri or "")
    return match.group(1) if match else None


async def _wikidata(url: str, params: dict, timeout: float) -> dict:
    import httpx
    from config import settings
    headers = {"User-Agent": f"LemonTrip/0.1 ({settings.WIKIDATA_CONTACT}) python-httpx",
               "Accept": "application/sparql-results+json, application/json"}
    try:
        async with httpx.AsyncClient(timeout=timeout, headers=headers) as client:
            resp = await client.get(url, params=params)
            resp.raise_for_status()
            return resp.json()
    except (httpx.HTTPError, ValueError) as e:
        status = getattr(getattr(e, "response", None), "status_code", None)
        raise SpotsUnavailable(f"wikidata {type(e).__name__} {status}") from e


async def _sparql(query: str, timeout: float = SPARQL_TIMEOUT_SECONDS) -> list:
    data = await _wikidata(WIKIDATA_SPARQL, {"query": query, "format": "json"}, timeout)
    rows = ((data or {}).get("results") or {}).get("bindings")
    return rows if isinstance(rows, list) else []


async def _destination_item(name: str, lat: float, lon: float) -> Optional[str]:
    """The Wikidata item for the destination: the first search hit near Geoapify's point."""
    from services.poi_lookup import metres_between
    data = await _wikidata(WIKIDATA_API, {
        "action": "wbsearchentities", "search": name, "language": "en", "type": "item",
        "limit": 10, "format": "json"}, 15.0)
    ids = [hit.get("id") for hit in (data.get("search") or []) if isinstance(hit, dict)
           and isinstance(hit.get("id"), str) and hit["id"].startswith("Q")]
    if not ids:
        return None
    rows = await _sparql(_COORDS_QUERY % " ".join(f"wd:{q}" for q in ids), timeout=15.0)
    near = set()
    for row in rows:
        q, point = _qid(row.get("item", {}).get("value")), _point(row.get("coord", {}).get("value"))
        if q and point and metres_between(lat, lon, *point) <= MATCH_KM * 1000:
            near.add(q)
    return next((q for q in ids if q in near), None)


async def _ranked_spots(place: str) -> List[dict]:
    rows = await _sparql(_SPOTS_QUERY % {
        "place": place, "classes": " ".join(f"wd:{q}" for q in KINDS), "limit": FETCH_LIMIT + 15})
    spots, seen = [], set()
    for row in rows:
        q = _qid(row.get("item", {}).get("value"))
        label = (row.get("itemLabel") or {}).get("value") or ""
        point = _point((row.get("coord") or {}).get("value"))
        try:
            links = int((row.get("links") or {}).get("value"))
        except (TypeError, ValueError):
            links = 0
        # No English label comes back as the bare id ("Q123"): nothing to show.
        if not q or q in seen or not point or not label or _QID_RE.fullmatch(label):
            continue
        seen.add(q)
        kind = KINDS.get(_qid((row.get("kind") or {}).get("value")) or "", "sight")
        if kind == "skyscraper" and links < SKYSCRAPER_MIN_LINKS:
            continue
        spots.append({"name": label, "wikidata": q, "lat": point[0], "lon": point[1],
                      "popularity": links, "kind": "sight" if kind == "skyscraper" else kind})
    # Variety: past MAX_PER_KIND of one kind, the rest wait behind other kinds.
    counts, first, later = {}, [], []
    for spot in spots:
        counts[spot["kind"]] = counts.get(spot["kind"], 0) + 1
        (first if counts[spot["kind"]] <= MAX_PER_KIND else later).append(spot)
    return (first + later)[:FETCH_LIMIT]


async def _verify(spots: List[dict]) -> List[dict]:
    """Keep spots Geoapify confirms near Wikidata's coordinates, in order."""
    from services.poi_lookup import find_place

    async def check(spot):
        try:
            return await find_place(spot["name"], spot["lat"], spot["lon"],
                                    radius_m=VERIFY_RADIUS_M, exact=(spot["lat"], spot["lon"]))
        except Exception as e:  # one failed check drops one spot, not the list
            logger.info("Spot check failed for one spot (%s)", type(e).__name__)
            return None

    found = await asyncio.gather(*(check(s) for s in spots))
    kept = []
    for spot, match in zip(spots, found):
        if match:
            kept.append({**spot, "place_id": match.get("place_id"),
                         "lat": match["lat"], "lon": match["lon"]})
    if spots and not kept and all(f is None for f in found):
        logger.warning("Geoapify confirmed none of %d popular spots", len(spots))
    return kept[:SHOW_MAX]


async def _search_destination(text: str) -> list:
    from routers.weather import _geoapify_search  # lazy: see module docstring
    return await _geoapify_search(text)


async def _fetch(destination: str) -> dict:
    name, country_only = split_country_label(destination)
    if country_only:
        return {"status": "too_broad", "destination": name, "spots": []}
    try:
        results = await _search_destination(destination)
    except Exception as e:
        raise SpotsUnavailable(f"geocoding {type(e).__name__}") from e
    if not results:
        raise SpotsUnavailable("destination not found")
    top = results[0]
    shown = top.get("name") or top.get("city") or top.get("state") or top.get("country") or name
    if top.get("result_type") == "country":
        return {"status": "too_broad", "destination": shown, "spots": []}
    item = await _destination_item(destination.split(",")[0].strip(), top["lat"], top["lon"])
    if item is None:
        raise SpotsUnavailable("no Wikidata item near the destination")
    spots = await _verify(await _ranked_spots(item))
    return {"status": "ready" if spots else "none", "destination": shown, "spots": spots}


async def popular_spots(destination: str) -> dict:
    """{status, destination, spots}. status: 'ready' (spots listed, most
    popular first), 'none' (nothing found), 'too_broad' (a whole country).
    Raises SpotsUnavailable when a service fails; that is not cached."""
    return await _cache.get_or_fetch(norm(destination), lambda: _fetch(destination))


def prefetch(destination: str) -> None:
    """Start the lookup in the background so the spots are ready when the app
    asks; errors are only logged (the app's own request reports them)."""
    async def run():
        try:
            await popular_spots(destination)
        except Exception as e:
            logger.info("Popular spots prefetch failed (%s)", type(e).__name__)
    try:
        asyncio.get_running_loop().create_task(run())
    except RuntimeError:
        pass  # no running loop (called from sync code): skip


def lemon_picks(spots: List[dict], interests: List[str], count: int = LEMON_PICKS) -> List[dict]:
    """Lemon's choice on "surprise me": the most popular spots, with up to half
    of them swapped for popular spots that suit the traveller's interests."""
    wanted = set()
    for interest in interests or []:
        wanted |= INTEREST_KINDS.get(str(interest).strip().casefold(), set())
    top = spots[:max(10, count)]
    suited = [s for s in top if s.get("kind") in wanted][:count // 2] if wanted else []
    picks = list(suited)
    for spot in spots:
        if len(picks) >= count:
            break
        if spot not in picks:
            picks.append(spot)
    return sorted(picks, key=lambda s: -s.get("popularity", 0))
