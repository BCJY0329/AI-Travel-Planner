"""
Pure helpers over Geoapify geocoding results, shared by the geocoder
(`routers/weather.py`) and the chat's destination check (`services/place_check.py`).
No settings or network imports, so offline tests can use them directly.
"""
from typing import List, Tuple

# Geoapify results that are a spot, not a destination ("Bali Street").
NOT_A_DESTINATION = {"street", "building", "amenity", "postcode"}
# A choice like "Georgia (country)" names the country, not the US state (DECISIONS 068).
COUNTRY_SUFFIX = " (country)"


def norm(value) -> str:
    return " ".join(str(value or "").lower().split())


def split_country_label(text: str) -> Tuple[str, bool]:
    """("Georgia", True) for "Georgia (country)"; otherwise (text, False)."""
    if text.strip().lower().endswith(COUNTRY_SUFFIX):
        return text.strip()[:-len(COUNTRY_SUFFIX)].strip(), True
    return text, False


def keep_destinations(results, text: str) -> List[dict]:
    """Results with coordinates that can be a destination.

    Streets, buildings, amenities and postcodes are dropped. Geoapify files
    islands as "amenity" (Santorini), so when nothing else is left, an amenity
    whose name matches the search exactly is kept (DECISIONS 068).
    """
    valid = [r for r in results if isinstance(r, dict)
             and isinstance(r.get("lat"), (int, float)) and isinstance(r.get("lon"), (int, float))]
    kept = [r for r in valid if r.get("result_type") not in NOT_A_DESTINATION]
    if kept:
        return kept
    wanted = norm(text.split(",")[0])
    return [r for r in valid if r.get("result_type") == "amenity" and norm(r.get("name")) == wanted]
