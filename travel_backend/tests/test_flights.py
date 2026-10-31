"""Offline flight-search regressions: Duffel is replaced by httpx.MockTransport.
Run from travel_backend: python -m unittest discover -s tests -v
"""
import json
import sys
import types
import unittest
from unittest.mock import patch

import httpx
from fastapi import HTTPException

# Never import the real config: it loads credentials from .env.
config = types.ModuleType('config')
config.settings = types.SimpleNamespace(
    DUFFEL_API_KEY='duffel_test_offline', DUFFEL_BASE_URL='https://duffel.invalid')
sys.modules['config'] = config

from routers import flights  # noqa: E402

OFFER = {
    "total_amount": "120.00",
    "total_currency": "USD",
    "slices": [{"duration": "PT7H", "segments": [{
        "origin": {"iata_code": "KUL"},
        "departing_at": "2026-11-20T09:00:00",
        "destination": {"iata_code": "NRT", "city_name": "Tokyo"},
        "arriving_at": "2026-11-20T17:00:00",
        "operating_carrier": {"iata_code": "ZZ"},
    }]}],
}


class FlightSearchTests(unittest.IsolatedAsyncioTestCase):
    def setUp(self):
        flights._offers_cache.clear()  # Every test repeats the same search.

    async def test_repeat_search_is_served_from_cache(self):
        calls = []
        def handler(request):
            calls.append(request)
            return httpx.Response(201, json={"data": {"offers": [OFFER]}})
        first, _ = await self.search(handler)
        second, _ = await self.search(handler)
        self.assertEqual(first, second)
        self.assertEqual(len(calls), 1)

    async def search(self, handler):
        real_client = httpx.AsyncClient
        seen = {}

        def client(**kwargs):
            seen.update(kwargs)
            return real_client(transport=httpx.MockTransport(handler), **kwargs)

        with patch.object(flights.httpx, 'AsyncClient', client):
            result = await flights.search_flights(
                origin='kul', destination='nrt', departure_date='2026-11-20', adults=1)
        return result, seen

    async def test_slow_duffel_returns_504_instead_of_crashing(self):
        def handler(request):
            raise httpx.ReadTimeout('slow sandbox', request=request)
        with self.assertRaises(HTTPException) as caught:
            await self.search(handler)
        self.assertEqual(caught.exception.status_code, 504)

    async def test_connection_failure_returns_502(self):
        def handler(request):
            raise httpx.ConnectError('offline', request=request)
        with self.assertRaises(HTTPException) as caught:
            await self.search(handler)
        self.assertEqual(caught.exception.status_code, 502)

    async def test_duffel_error_status_is_passed_through(self):
        with self.assertRaises(HTTPException) as caught:
            await self.search(lambda request: httpx.Response(422, json={"errors": []}))
        self.assertEqual(caught.exception.status_code, 422)

    async def test_incomplete_offer_is_skipped_and_read_timeout_is_long(self):
        body = {"data": {"offers": [{"total_amount": "1"}, OFFER]}}
        result, seen = await self.search(lambda request: httpx.Response(201, json=body))
        self.assertEqual(len(result["offers"]), 1)
        self.assertEqual(result["offers"][0]["carrier"], "ZZ")
        self.assertEqual(result["offers"][0]["arrival_city"], "Tokyo")
        self.assertGreater(seen["timeout"].read, 15)

    def test_bad_codes_and_dates_are_rejected_before_duffel(self):
        from fastapi import FastAPI
        from fastapi.testclient import TestClient
        app = FastAPI()
        app.include_router(flights.router)
        calls = []
        real_client = httpx.AsyncClient
        def client(**kwargs):
            def handler(request):
                calls.append(request)
                return httpx.Response(201, json={"data": {"offers": []}})
            return real_client(transport=httpx.MockTransport(handler), **kwargs)
        with patch.object(flights.httpx, 'AsyncClient', client), TestClient(app) as http:
            for query in ('origin=Kuala%20Lumpur&destination=NRT&departure_date=2026-11-20',
                          'origin=KUL&destination=NRT&departure_date=20-11-2026',
                          'origin=KUL&destination=NRT&departure_date=2026-02-31'):
                self.assertEqual(http.get('/flights/search?' + query).status_code, 422, query)
            self.assertEqual(calls, [])
            ok = http.get('/flights/search?origin=%20kul%20&destination=nrt&departure_date=2026-11-20')
        self.assertEqual(ok.status_code, 200)
        sent = json.loads(calls[0].content)
        self.assertEqual(sent['data']['slices'][0]['origin'], 'KUL')


if __name__ == '__main__':
    unittest.main()
