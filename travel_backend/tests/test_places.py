"""Offline regressions for /places/attractions: one Geoapify search per chip
group, with the full category list reaching the client (DECISIONS 052, 053).
Geoapify is an httpx.MockTransport and the geocoder is stubbed, so no network
call or credential is involved.
Run from travel_backend: python -m unittest discover -s tests -v
"""
import asyncio
import sys
import types
import unittest
from unittest.mock import patch

import httpx
from fastapi import HTTPException

# Never import the real config: it loads credentials from .env. Other suites
# replace routers.weather/places with fakes, so load the real routers afresh.
config = types.ModuleType('config')
config.settings = types.SimpleNamespace(
    OPENWEATHER_API_KEY='owm_offline', OPENWEATHER_BASE_URL='https://owm.invalid',
    GEOAPIFY_API_KEY='geo_offline', GEOAPIFY_BASE_URL='https://geo.invalid',
    PIXABAY_API_KEY='pixabay_offline', PIXABAY_BASE_URL='https://pixabay.com')
sys.modules['config'] = config
for name in ('routers.weather', 'routers.places'):
    sys.modules.pop(name, None)

from routers import places  # noqa: E402

SIGHTSEEING, LANDMARKS, CULTURE, FUN = places.ATTRACTION_GROUPS


def feature(name, categories, lon=2.35, lat=48.85):
    return {"type": "Feature",
            "properties": {"name": name, "categories": categories},
            "geometry": {"type": "Point", "coordinates": [lon, lat]}}


CASTLE = feature("Château de Vincennes",
                 ["building", "heritage", "heritage.unesco", "tourism", "tourism.sights",
                  "tourism.sights.castle"], lon=2.43)
PLAQUE = ["tourism", "tourism.sights", "tourism.sights.memorial"]

# Realistic shapes; the real order from Geoapify is not verified offline.
GROUP_FEATURES = {
    SIGHTSEEING: [
        feature("Fontaine", ["tourism", "tourism.attraction",
                             "tourism.attraction.fountain"], lon=2.30),
        {"type": "Feature", "properties": {"categories": ["tourism.attraction"]},
         "geometry": {"type": "Point", "coordinates": [2.0, 48.0]}},  # no name
        feature("", ["tourism.attraction"]),                          # empty name
        feature("No categories", None, lon=2.31),
        feature("Odd categories", ["tourism.attraction", 7, None, "heritage"], lon=2.32),
        feature("Not a list", "tourism.attraction", lon=2.33),
        {"type": "Feature", "properties": {"name": "No geometry"}},  # incomplete
        feature("Bad coordinates", ["tourism.attraction"], lon="x"),
    ],
    # Twelve plaques first, then a tower and the castle: the plaques go last
    # and only ten places are kept.
    LANDMARKS: [feature(f"Plaque {i}", PLAQUE, lon=2.0 + i / 100) for i in range(12)] + [
        feature("Tour", ["tourism", "tourism.sights", "tourism.sights.tower"], lon=2.40),
        CASTLE,
    ],
    CULTURE: [
        CASTLE,  # also in the landmarks group: listed once
        feature("Musée Carnavalet", ["building", "building.tourism", "entertainment",
                                     "entertainment.museum"], lon=2.36),
    ],
    FUN: [feature("Zoo", ["entertainment", "entertainment.zoo"], lon=2.41)],
}


class AttractionsTestCase(unittest.TestCase):
    def setUp(self):
        places._attractions_cache.clear()
        self.requests = []
        self.fail_groups = {}  # group -> exception or status code

        def upstream(request):
            self.requests.append(request)
            group = request.url.params["categories"]
            failure = self.fail_groups.get(group)
            if isinstance(failure, Exception):
                raise failure
            if failure:
                return httpx.Response(failure, request=request)
            return httpx.Response(200, json={"type": "FeatureCollection",
                                             "features": GROUP_FEATURES[group]})

        real_client = httpx.AsyncClient
        client = patch.object(httpx, 'AsyncClient', lambda **kwargs: real_client(
            transport=httpx.MockTransport(upstream), **kwargs))

        async def geocode(city):
            return {"name": "Paris", "lat": 48.85, "lon": 2.35}

        geocoder = patch.object(places, '_geocode_city', geocode)
        client.start()
        geocoder.start()
        self.addCleanup(client.stop)
        self.addCleanup(geocoder.stop)
        self.addCleanup(places._attractions_cache.clear)

    def fetch(self):
        result = asyncio.run(places.get_attractions(city='Paris', radius_km=5))
        return result, [a["name"] for a in result["attractions"]]


class FetchAttractionsTests(AttractionsTestCase):
    def setUp(self):
        super().setUp()
        self.result, self.names = self.fetch()
        self.by_name = {a["name"]: a for a in self.result["attractions"]}

    def test_one_request_per_group_nearest_first(self):
        self.assertEqual(sorted(r.url.params["categories"] for r in self.requests),
                         sorted(places.ATTRACTION_GROUPS))
        for request in self.requests:
            params = request.url.params
            self.assertEqual(params["limit"], "20")
            self.assertEqual(params["filter"], "circle:2.35,48.85,5000")
            self.assertEqual(params["bias"], "proximity:2.35,48.85")
        self.assertIn("heritage", CULTURE.split(","))

    def test_full_category_list_and_first_entry(self):
        museum = self.by_name["Musée Carnavalet"]
        self.assertEqual(museum["categories"], [
            "building", "building.tourism", "entertainment", "entertainment.museum"])
        self.assertEqual(museum["category"], "building")  # unchanged: the first entry
        self.assertEqual(self.result["city"], "Paris")
        self.assertEqual((museum["lat"], museum["lon"]), (48.85, 2.36))

    def test_nameless_and_incomplete_places_are_skipped(self):
        for name in ("", "No geometry", "Bad coordinates"):
            self.assertNotIn(name, self.names)
        self.assertEqual(self.names[:4],
                         ["Fontaine", "No categories", "Odd categories", "Not a list"])

    def test_missing_or_malformed_categories(self):
        self.assertEqual(self.by_name["No categories"]["categories"], [])
        self.assertIsNone(self.by_name["No categories"]["category"])
        self.assertEqual(self.by_name["Not a list"]["categories"], [])
        self.assertEqual(self.by_name["Odd categories"]["categories"],
                         ["tourism.attraction", "heritage"])

    def test_plaques_go_last_and_each_group_keeps_ten(self):
        landmarks = self.names[4:14]
        self.assertEqual(landmarks[:2], ["Tour", "Château de Vincennes"])
        self.assertEqual(landmarks[2:], [f"Plaque {i}" for i in range(8)])

    def test_a_place_in_two_groups_is_listed_once(self):
        self.assertEqual(self.names.count("Château de Vincennes"), 1)
        self.assertEqual(self.names[14:], ["Musée Carnavalet", "Zoo"])

    def test_plain_memorial_test(self):
        self.assertTrue(places._is_plain_memorial(PLAQUE))
        self.assertFalse(places._is_plain_memorial(PLAQUE + ["tourism.sights.memorial.tomb"]))
        self.assertFalse(places._is_plain_memorial(PLAQUE + ["heritage"]))


class FailureTests(AttractionsTestCase):
    def test_one_failed_group_keeps_the_rest_but_is_not_cached(self):
        self.fail_groups[FUN] = 500
        with self.assertLogs(places.logger, 'WARNING') as logs:
            _, names = self.fetch()
        self.assertIn("status 500", logs.output[0])
        self.assertNotIn("geo_offline", "".join(logs.output))  # never the key
        self.assertIn("Musée Carnavalet", names)
        self.assertNotIn("Zoo", names)
        self.assertEqual(len(self.requests), 4)
        # Not cached: the next search asks Geoapify again and now gets the zoo.
        del self.fail_groups[FUN]
        _, names = self.fetch()
        self.assertIn("Zoo", names)
        self.assertEqual(len(self.requests), 8)
        # A full result is cached.
        self.fetch()
        self.assertEqual(len(self.requests), 8)

    def test_every_group_failing_is_an_error(self):
        for group in places.ATTRACTION_GROUPS:
            self.fail_groups[group] = 429
        with self.assertRaises(HTTPException) as caught:
            self.fetch()
        self.assertEqual(caught.exception.status_code, 429)

    def test_every_group_timing_out_is_a_504(self):
        for group in places.ATTRACTION_GROUPS:
            self.fail_groups[group] = httpx.ReadTimeout("slow")
        with self.assertRaises(HTTPException) as caught:
            self.fetch()
        self.assertEqual(caught.exception.status_code, 504)


if __name__ == '__main__':
    unittest.main()
