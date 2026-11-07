"""
Checks a chat destination against the shared Geoapify geocoder (DECISIONS 059, 068).

- No results: the place is refused ('not_found'), never planned.
- One place, or the user already named the region/country ("Paris, France"): 'verified'.
- The same name in several countries or states: when one is clearly the famous
  one (Geoapify importance ahead by IMPORTANCE_GAP or more: Paris, Rome, Lisbon)
  it is 'verified' with the others as `alternatives`, so the app can show the
  exact place and offer "Not this one?". When the choices are close (Portland,
  Cambridge, Georgia) it is 'ambiguous', with labels the traveller picks from.
- Every verified place carries a `label` with its country ("Kyoto, Japan").
- Lookup unavailable (timeout, quota, offline): 'unverified'. The chat goes on;
  the plan step geocodes again and reports its own errors.

The geocoder is imported lazily so offline tests, which replace
`routers.weather` with a stub, never import `config` (and so never load keys).
"""
import asyncio
import logging
from dataclasses import dataclass, field
from typing import Awaitable, Callable, List, Optional

from services.geo_results import COUNTRY_SUFFIX, norm as _norm
from services.ttl_cache import TTLCache

logger = logging.getLogger("lemon_ai")

# Search candidates: dicts with name/city/state/country/country_code/result_type.
Lookup = Callable[[str], Awaitable[List[dict]]]

LOOKUP_TIMEOUT_SECONDS = 8.0
_cache = TTLCache(ttl_seconds=24 * 3600, max_entries=1000)
# Place kinds that can stand for a destination name on their own.
_NAMED_PLACES = {"city", "state", "country", "county", "district", "suburb", "postcode", None}
# How far ahead (Geoapify rank.importance, 0-1) the top same-name place must be
# to go ahead without asking. Measured live: Paris .37, Rome .33, Lisbon .30,
# Valencia .18 skip; Portland .11, Cambridge .03, Springfield .00 ask.
IMPORTANCE_GAP = 0.15


@dataclass
class PlaceCheck:
    status: str  # 'verified' | 'unverified' | 'not_found' | 'ambiguous'
    options: List[str] = field(default_factory=list)
    # Verified only: the exact place ("Paris, France") and, when it was picked
    # from several same-name places, the others ("Paris, Texas, United States").
    label: Optional[str] = None
    alternatives: List[str] = field(default_factory=list)


async def _default_lookup(text: str) -> List[dict]:
    """Ordinary search plus a country-only search, which is the only way
    Geoapify returns the country Georgia next to the US state. A country is
    added only when its name matches exactly."""
    from routers.weather import _geoapify_search  # lazy: see module docstring
    places, countries = await asyncio.gather(
        _geoapify_search(text), _geoapify_search(text, type="country"), return_exceptions=True)
    if isinstance(places, BaseException):
        raise places
    if isinstance(countries, BaseException):
        return places  # the ordinary search still answers
    have = {_norm(r.get("country_code")) for r in places if r.get("result_type") == "country"}
    wanted = _norm(text)
    return places + [r for r in countries if r.get("result_type") == "country"
                     and _norm(r.get("name")) == wanted and _norm(r.get("country_code")) not in have]


def _importance(result: dict):
    value = (result.get("rank") or {}).get("importance") if isinstance(result.get("rank"), dict) else None
    return value if isinstance(value, (int, float)) else None


def _label(result: dict, with_state: bool, shown_name: Optional[str] = None) -> str:
    if result.get("result_type") == "country":
        # "Georgia (country)": the geocoder knows to search countries only.
        return (result.get("name") or result.get("country") or "") + COUNTRY_SUFFIX
    parts = [shown_name or result.get("name") or result.get("city") or result.get("state") or ""]
    if with_state:
        parts.append(result.get("state") or "")
    parts.append(result.get("country") or (result.get("country_code") or "").upper())
    seen, label = set(), []
    for part in parts:
        if part and _norm(part) not in seen:
            seen.add(_norm(part))
            label.append(part)
    return ", ".join(label)


def _matches(wanted: str, r: dict) -> bool:
    return (r.get("result_type") in _NAMED_PLACES
            and wanted in {_norm(r.get("name")), _norm(r.get("city")), _norm(r.get("state"))})


def classify(name: str, results: List[dict]) -> PlaceCheck:
    """Pure decision over geocoder candidates; separated so it is testable offline."""
    if not results:
        return PlaceCheck("not_found")
    if "," in name:
        # The traveller already said which one.
        return PlaceCheck("verified", label=name.strip())
    wanted = _norm(name)
    pool = [r for r in results if _matches(wanted, r)]
    top = results[0]
    # "London" comes back as "Greater London": the top result counts when its
    # name contains the word, and is shown as the traveller wrote it.
    if (top not in pool and top.get("result_type") in _NAMED_PLACES
            and f" {wanted} " in f" {_norm(top.get('name'))} "):
        pool.insert(0, top)
    if not pool:
        # An island or another near match: the geocoder's best guess, shown in full.
        return PlaceCheck("verified", label=_label(top, with_state=False))
    groups: dict = {}
    for r in pool:
        groups.setdefault((_norm(r.get("country_code")), _norm(r.get("state"))), r)
    chosen = list(groups.values())
    if all(_importance(r) is not None for r in chosen):
        chosen.sort(key=lambda r: -_importance(r))
    countries = [_norm(r.get("country_code")) for r in chosen]

    def label_of(r):
        shown = name.strip() if _norm(r.get("name")) != wanted and r is top else None
        return _label(r, with_state=countries.count(_norm(r.get("country_code"))) > 1, shown_name=shown)

    labels = []
    for r in chosen:
        label = label_of(r)
        if label and label not in labels:
            labels.append(label)
    if len(labels) < 2:
        return PlaceCheck("verified", label=labels[0] if labels else None)
    first, second = _importance(chosen[0]), _importance(chosen[1])
    if first is not None and second is not None and first - second >= IMPORTANCE_GAP:
        return PlaceCheck("verified", label=labels[0], alternatives=labels[1:5])
    return PlaceCheck("ambiguous", labels[:4])


async def check_destination(name: str, lookup: Optional[Lookup] = None) -> PlaceCheck:
    lookup = lookup or _default_lookup
    try:
        results = await _cache.get_or_fetch(
            _norm(name), lambda: asyncio.wait_for(lookup(name), LOOKUP_TIMEOUT_SECONDS))
    except Exception as e:  # timeout, quota, offline, stubbed router in tests
        logger.warning("Destination check unavailable (%s); continuing unverified", type(e).__name__)
        return PlaceCheck("unverified")
    return classify(name, results if isinstance(results, list) else [])
