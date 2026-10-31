"""Offline regressions for the in-memory API cache and Pixabay banner photos.
Every upstream (OpenWeatherMap, Geoapify, Pixabay, its CDN) is an httpx.MockTransport.
Run from travel_backend: python -m unittest discover -s tests -v
"""
import asyncio
import sys
import types
import unittest
from collections import Counter
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
for name in ('routers.weather', 'routers.places', 'routers.hotels', 'routers.photos'):
    sys.modules.pop(name, None)

from routers import hotels, photos, weather  # noqa: E402
from services.ttl_cache import TTLCache  # noqa: E402

PLACES = {'kyoto': ('Kyoto', 'JP'), 'osaka': ('Osaka', 'JP'), 'paris': ('Paris', 'FR'),
          'atlantis': ('Atlantis', 'ZZ')}


def geo(name, result_type='city', country='jp', **extra):
    """One Geoapify geocoding result."""
    return {"name": name, "result_type": result_type, "country_code": country,
            "lat": 1.0, "lon": 2.0, "place_id": f"{name}-{country}", **extra}


# Geoapify answers for (text, type); plain city names come from PLACES.
GEOAPIFY = {
    ('bali', None): [geo('Bali', 'state', 'id'), geo('Bali', 'city', 'bt')],
    ('bali', 'city'): [geo('Bali', 'city', 'bt'), geo('Balikpapan', 'city', 'id')],
    ('osaka', None): [geo('Osaka Prefecture', 'county', 'jp')],
    ('osaka', 'city'): [geo('Osaka', 'city', 'us'), geo('Osaka', 'city', 'jp', lat=34.69)],
    ('kyoto street', None): [geo('Kyoto Street', 'street', 'us'), geo('Kyoto')],
}


def pixabay_hits(query):
    return [{"id": 100 + i, "largeImageURL": f"https://cdn.pixabay.com/photo/{query}-{i}.jpg",
             "pageURL": f"https://pixabay.com/photos/{i}/", "user": "snapper", "user_id": 7,
             "tags": f"{query.lower()}, travel"} for i in range(3)]


class Upstream:
    """Fake upstream APIs that count every request by kind."""
    def __init__(self):
        self.calls = Counter()
        self.pixabay_status = 200
        self.empty_travel = False
        self.override = None  # request -> Response, or raise, for one failing path

    def __call__(self, request):
        url = request.url
        if self.override is not None:
            response = self.override(request)
            if response is not None:
                return response
        if url.path == '/v1/geocode/search':
            self.calls['geocode'] += 1
            text = url.params['text'].strip().lower()
            results = GEOAPIFY.get((text, url.params.get('type')))
            if results is None:
                name, country = PLACES[text]
                results = [geo(name, 'city', country.lower())]
            return httpx.Response(200, json={"results": results})
        if url.path == '/geo/1.0/direct':  # OpenWeatherMap, the fallback geocoder
            self.calls['owm_geocode'] += 1
            name, country = PLACES[url.params['q'].strip().lower()]
            return httpx.Response(200, json=[{"name": name, "lat": 1.0, "lon": 2.0, "country": country}])
        if url.path == '/data/2.5/forecast':
            self.calls['forecast'] += 1
            return httpx.Response(200, json={"list": []})
        if url.path == '/v2/places':
            self.calls['geoapify'] += 1
            return httpx.Response(200, json={"features": []})
        if url.host == 'pixabay.com':
            self.calls['pixabay'] += 1
            self.calls['pixabay:' + url.params.get('category', 'any')] += 1
            if self.pixabay_status != 200:
                return httpx.Response(self.pixabay_status, text='key ' + url.params['key'])
            if self.empty_travel and url.params.get('category') == 'travel':
                return httpx.Response(200, json={"hits": []})
            return httpx.Response(200, json={"hits": pixabay_hits(url.params['q'])})
        if url.host == 'cdn.pixabay.com':
            self.calls['download'] += 1
            return httpx.Response(200, content=b'jpeg-bytes', headers={'content-type': 'image/jpeg'})
        raise AssertionError(f'unexpected request {url}')


class CachedApiTests(unittest.IsolatedAsyncioTestCase):
    def setUp(self):
        for cache in (weather._geocode_cache, weather._forecast_cache, hotels._hotels_cache,
                      photos._search_cache, photos._image_cache):
            cache.clear()
        photos._image_sources.clear()
        self.upstream = Upstream()
        real_client = httpx.AsyncClient
        patcher = patch.object(httpx, 'AsyncClient', lambda **kwargs: real_client(
            transport=httpx.MockTransport(self.upstream), **kwargs))
        patcher.start()
        self.addCleanup(patcher.stop)

    async def test_country_photos_are_searched_once_per_country(self):
        first = await photos.get_place_photos(place='Kyoto')
        again = await photos.get_place_photos(place=' kyoto ')
        sibling = await photos.get_place_photos(place='Osaka')
        self.assertEqual(first['country'], 'Japan')
        self.assertEqual(len(first['photos']), 3)
        self.assertEqual(first['photos'][0]['image_url'], '/photos/image/100')
        self.assertNotIn('source', first['photos'][0])  # CDN URL stays server-side
        self.assertEqual(again['photos'], first['photos'])
        self.assertEqual(sibling['place'], 'Osaka')
        self.assertEqual(sibling['photos'], first['photos'])
        self.assertEqual(self.upstream.calls['pixabay'], 1)
        # Kyoto, then Osaka, whose prefecture result needs a second, city-only lookup.
        self.assertEqual(self.upstream.calls['geocode'], 3)

    async def test_unknown_country_searches_the_place_and_travel_falls_back(self):
        self.upstream.empty_travel = True
        result = await photos.get_place_photos(place='Atlantis')
        self.assertIsNone(result['country'])
        self.assertIn('atlantis', result['photos'][0]['tags'])
        self.assertEqual(self.upstream.calls['pixabay:travel'], 1)
        self.assertEqual(self.upstream.calls['pixabay:any'], 1)

    async def test_images_are_served_from_backend_and_downloaded_once(self):
        await photos.get_place_photos(place='Paris')
        first = await photos.get_photo_image(100)
        second = await photos.get_photo_image(100)
        self.assertEqual(first.body, b'jpeg-bytes')
        self.assertEqual(first.media_type, 'image/jpeg')
        self.assertIn('max-age', first.headers['cache-control'])
        self.assertEqual(second.body, b'jpeg-bytes')
        self.assertEqual(self.upstream.calls['download'], 1)
        with self.assertRaises(HTTPException) as caught:
            await photos.get_photo_image(999)
        self.assertEqual(caught.exception.status_code, 404)

    async def test_rate_limit_is_reported_without_key_and_not_cached(self):
        self.upstream.pixabay_status = 429
        with self.assertRaises(HTTPException) as caught:
            await photos.get_place_photos(place='Paris')
        self.assertEqual(caught.exception.status_code, 429)
        self.assertNotIn('pixabay_offline', str(caught.exception.detail))
        self.upstream.pixabay_status = 200
        result = await photos.get_place_photos(place='Paris')
        self.assertEqual(len(result['photos']), 3)
        self.assertEqual(self.upstream.calls['pixabay'], 2)

    async def test_featured_prefers_editors_choice_and_is_cached(self):
        first = await photos.get_featured_photos()
        await photos.get_featured_photos()
        self.assertEqual(len(first['photos']), 3)  # the fake returns three hits
        self.assertEqual(self.upstream.calls['pixabay'], 1)
        image = await photos.get_photo_image(first['photos'][0]['id'])
        self.assertEqual(image.body, b'jpeg-bytes')

    async def test_missing_key_is_503_without_upstream_calls(self):
        with patch.object(photos.settings, 'PIXABAY_API_KEY', ''):
            with self.assertRaises(HTTPException) as caught:
                await photos.get_place_photos(place='Paris')
        self.assertEqual(caught.exception.status_code, 503)
        self.assertEqual(sum(self.upstream.calls.values()), 0)

    async def test_forecast_and_hotels_reuse_cached_results(self):
        await weather.get_forecast(city='Paris')
        await weather.get_forecast(city='paris')
        await hotels.search_hotels(city='Paris', radius_km=5)
        await hotels.search_hotels(city='Paris', radius_km=5)
        await hotels.search_hotels(city='Paris', radius_km=10)  # different search
        self.assertEqual(self.upstream.calls['forecast'], 1)
        self.assertEqual(self.upstream.calls['geoapify'], 2)
        self.assertEqual(self.upstream.calls['geocode'], 1)  # shared by both routers

    async def test_upstream_timeouts_and_outages_are_clean_http_errors(self):
        def geocode_timeout(request):  # both geocoders
            if request.url.path in ('/v1/geocode/search', '/geo/1.0/direct'):
                raise httpx.ReadTimeout('slow', request=request)
        self.upstream.override = geocode_timeout
        with self.assertRaises(HTTPException) as caught:
            await weather.get_forecast(city='Paris')
        self.assertEqual(caught.exception.status_code, 504)

        def geoapify_offline(request):
            if request.url.path == '/v2/places':
                raise httpx.ConnectError('geo_offline unreachable', request=request)
        self.upstream.override = geoapify_offline
        with self.assertRaises(HTTPException) as caught:
            await hotels.search_hotels(city='Paris', radius_km=5)
        self.assertEqual(caught.exception.status_code, 502)
        self.assertNotIn('geo_offline', str(caught.exception.detail))  # the API key

        def not_json(request):
            if request.url.path == '/data/2.5/forecast':
                return httpx.Response(200, text='<html>maintenance</html>')
        self.upstream.override = not_json
        with self.assertRaises(HTTPException) as caught:
            await weather.get_forecast(city='Paris')
        self.assertEqual(caught.exception.status_code, 502)

    async def test_malformed_items_are_skipped(self):
        good = {"properties": {"name": "Hotel Lemon", "formatted": "1 Rue"},
                "geometry": {"coordinates": [2.0, 1.0]}}
        def partial(request):
            if request.url.path == '/v2/places':
                return httpx.Response(200, json={"features": [
                    {"properties": {"name": "No geometry"}}, "junk", good]})
            if request.url.path == '/data/2.5/forecast':
                return httpx.Response(200, json={"list": [{"dt_txt": "x"}, {
                    "dt_txt": "2026-11-01 12:00:00", "main": {"temp": 18},
                    "weather": [{"main": "Clear", "description": "clear sky"}]}]})
        self.upstream.override = partial
        result = await hotels.search_hotels(city='Paris', radius_km=5)
        self.assertEqual([h['name'] for h in result['hotels']], ['Hotel Lemon'])
        forecast = await weather.get_forecast(city='Paris')
        self.assertEqual(len(forecast['forecast']), 1)


class GeocodeTests(unittest.IsolatedAsyncioTestCase):
    """KI-25: well-known places win over same-named towns elsewhere."""
    setUp = CachedApiTests.setUp

    async def test_region_beats_same_named_town_abroad_and_is_searched_whole(self):
        filters = []
        def record(request):
            if request.url.path == '/v2/places':
                filters.append(request.url.params['filter'])
        self.upstream.override = record
        location = await weather._geocode_city('Bali')
        self.assertEqual((location['name'], location['country']), ('Bali', 'ID'))
        await hotels.search_hotels(city='Bali', radius_km=5)
        self.assertEqual(filters, ['place:Bali-id'])  # the island's boundary, not a circle

    async def test_region_prefers_its_own_city(self):
        location = await weather._geocode_city('Osaka')
        self.assertEqual((location['name'], location['country'], location['lat']), ('Osaka', 'JP', 34.69))
        self.assertIsNone(location['region_id'])  # a city is searched by radius

    async def test_streets_are_skipped(self):
        location = await weather._geocode_city('Kyoto Street')
        self.assertEqual(location['name'], 'Kyoto')

    async def test_geoapify_failure_falls_back_to_openweathermap(self):
        def geoapify_down(request):
            if request.url.path == '/v1/geocode/search':
                return httpx.Response(503)
        self.upstream.override = geoapify_down
        location = await weather._geocode_city('Paris')
        self.assertEqual((location['name'], location['country']), ('Paris', 'FR'))
        self.assertEqual(self.upstream.calls['owm_geocode'], 1)

    async def test_unknown_place_is_404_without_fallback(self):
        def nothing(request):
            if request.url.path == '/v1/geocode/search':
                return httpx.Response(200, json={"results": []})
        self.upstream.override = nothing
        with self.assertRaises(HTTPException) as caught:
            await weather._geocode_city('Atlantis')
        self.assertEqual(caught.exception.status_code, 404)
        self.assertEqual(self.upstream.calls['owm_geocode'], 0)


class TTLCacheTests(unittest.IsolatedAsyncioTestCase):
    async def test_hits_expiry_errors_and_eviction(self):
        cache, calls = TTLCache(ttl_seconds=60, max_entries=2), Counter()

        async def fetch(key):
            calls[key] += 1
            if key == 'bad':
                raise RuntimeError('upstream down')
            return {'key': key}

        first = await cache.get_or_fetch('a', lambda: fetch('a'))
        first['key'] = 'mutated'  # callers get copies, not the cached object
        self.assertEqual(await cache.get_or_fetch('a', lambda: fetch('a')), {'key': 'a'})
        for _ in range(2):
            with self.assertRaises(RuntimeError):
                await cache.get_or_fetch('bad', lambda: fetch('bad'))
        self.assertEqual(calls['bad'], 2)  # failures are retried, never stored
        await cache.get_or_fetch('b', lambda: fetch('b'))
        await cache.get_or_fetch('c', lambda: fetch('c'))  # evicts 'a', the oldest
        await cache.get_or_fetch('a', lambda: fetch('a'))
        self.assertEqual(calls['a'], 2)

        expired = TTLCache(ttl_seconds=-1)
        await expired.get_or_fetch('x', lambda: fetch('x'))
        await expired.get_or_fetch('x', lambda: fetch('x'))
        self.assertEqual(calls['x'], 2)

    async def test_concurrent_misses_share_one_call_and_survive_a_timeout(self):
        cache, calls, release = TTLCache(ttl_seconds=60), Counter(), asyncio.Event()

        async def slow():
            calls['slow'] += 1
            await release.wait()
            return 'done'

        impatient = asyncio.create_task(asyncio.wait_for(cache.get_or_fetch('k', slow), 0.01))
        patient = asyncio.create_task(cache.get_or_fetch('k', slow))
        with self.assertRaises(asyncio.TimeoutError):
            await impatient
        release.set()
        self.assertEqual(await patient, 'done')
        self.assertEqual(await cache.get_or_fetch('k', slow), 'done')
        self.assertEqual(calls['slow'], 1)


if __name__ == '__main__':
    unittest.main()
