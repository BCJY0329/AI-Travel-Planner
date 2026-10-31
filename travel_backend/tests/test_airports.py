"""Offline regressions for the trip-to-airport lookup (GET /airports/search).
Duffel and OpenWeatherMap are an httpx.MockTransport.
Run from travel_backend: python -m unittest discover -s tests -v
"""
import sys
import types
import unittest
from collections import Counter
from unittest.mock import patch

import httpx
from fastapi import HTTPException

# Never import the real config: it loads credentials from .env. Other suites
# replace routers.weather with a fake, so load the real routers afresh.
config = types.ModuleType('config')
config.settings = types.SimpleNamespace(
    OPENWEATHER_API_KEY='owm_offline', OPENWEATHER_BASE_URL='https://owm.invalid',
    GEOAPIFY_API_KEY='geo_offline', GEOAPIFY_BASE_URL='https://geo.invalid',
    DUFFEL_API_KEY='duffel_test_offline', DUFFEL_BASE_URL='https://duffel.invalid')
sys.modules['config'] = config
for name in ('routers.weather', 'routers.airports'):
    sys.modules.pop(name, None)

from routers import airports, weather  # noqa: E402


def airport(code, city, lat, lon):
    return {"type": "airport", "iata_code": code, "name": f"{code} International",
            "city_name": city, "latitude": lat, "longitude": lon}


TOKYO = {"type": "city", "iata_code": "TYO", "name": "Tokyo", "airports": [
    airport("HND", "Tokyo", 35.55, 139.78), airport("NRT", "Tokyo", 35.77, 140.39)]}
# Near Kyoto (35.01, 135.77): Itami is closer than Kansai.
KANSAI = [airport("KIX", "Osaka", 34.43, 135.24), airport("ITM", "Osaka", 34.78, 135.44)]


class Upstream:
    def __init__(self):
        self.calls = Counter()
        self.override = None

    def __call__(self, request):
        url = request.url
        if self.override is not None:
            response = self.override(request)
            if response is not None:
                return response
        if url.path == '/v1/geocode/search':  # Geoapify
            self.calls['geocode'] += 1
            if url.params['text'] == 'Atlantis':
                return httpx.Response(200, json={"results": []})
            return httpx.Response(200, json={"results": [{"name": "Kyoto", "result_type": "city",
                                                          "lat": 35.01, "lon": 135.77, "country_code": "jp"}]})
        if url.path == '/places/suggestions':
            self.calls['duffel'] += 1
            assert request.headers['Authorization'] == 'Bearer duffel_test_offline'
            if url.params.get('query') == 'Tokyo':
                return httpx.Response(200, json={"data": [TOKYO]})
            if url.params.get('query') == 'Bali':
                return httpx.Response(200, json={"data": [
                    airport("DPS", "Denpasar", -8.75, 115.17) | {"name": "Ngurah Rai (Bali) International"}]})
            if url.params.get('query') == 'Kyoto':
                # Only a place that contains the word, which must not be used.
                return httpx.Response(200, json={"data": [airport("XXX", "Kyotango", 35.6, 135.0)]})
            if 'lat' in url.params:
                self.calls['nearby'] += 1
                return httpx.Response(200, json={"data": [*KANSAI, {"type": "airport"}, "junk"]})
            return httpx.Response(200, json={"data": []})
        raise AssertionError(f'unexpected request {url}')


class AirportTests(unittest.IsolatedAsyncioTestCase):
    def setUp(self):
        airports._airports_cache.clear()
        weather._geocode_cache.clear()
        self.upstream = Upstream()
        real_client = httpx.AsyncClient
        patcher = patch.object(httpx, 'AsyncClient', lambda **kwargs: real_client(
            transport=httpx.MockTransport(self.upstream), **kwargs))
        patcher.start()
        self.addCleanup(patcher.stop)

    async def test_city_name_returns_its_airports_and_is_cached(self):
        first = await airports.search_airports(place='Tokyo')
        await airports.search_airports(place=' tokyo ')
        self.assertEqual([a['iata_code'] for a in first['airports']], ['HND', 'NRT'])
        self.assertEqual(self.upstream.calls['duffel'], 1)
        self.assertEqual(self.upstream.calls['geocode'], 0)

    async def test_place_without_airport_uses_nearest_airports(self):
        result = await airports.search_airports(place='Kyoto')
        self.assertEqual([a['iata_code'] for a in result['airports']], ['ITM', 'KIX'])
        self.assertEqual(self.upstream.calls['nearby'], 1)

    async def test_airport_named_after_the_place_counts(self):
        result = await airports.search_airports(place='Bali')
        self.assertEqual([a['iata_code'] for a in result['airports']], ['DPS'])
        self.assertEqual(self.upstream.calls['geocode'], 0)

    async def test_unknown_place_is_empty(self):
        result = await airports.search_airports(place='Atlantis')
        self.assertEqual(result['airports'], [])

    async def test_failures_are_clean_and_not_cached(self):
        def offline(request):
            if request.url.path == '/places/suggestions':
                raise httpx.ConnectError('duffel_test_offline down', request=request)
        self.upstream.override = offline
        with self.assertRaises(HTTPException) as caught:
            await airports.search_airports(place='Tokyo')
        self.assertEqual(caught.exception.status_code, 502)
        self.assertNotIn('duffel_test_offline', str(caught.exception.detail))
        self.upstream.override = None
        result = await airports.search_airports(place='Tokyo')
        self.assertEqual(len(result['airports']), 2)

    async def test_missing_key_is_503_without_upstream_calls(self):
        with patch.object(airports.settings, 'DUFFEL_API_KEY', ''):
            with self.assertRaises(HTTPException) as caught:
                await airports.search_airports(place='Tokyo')
        self.assertEqual(caught.exception.status_code, 503)
        self.assertEqual(sum(self.upstream.calls.values()), 0)


if __name__ == '__main__':
    unittest.main()
