"""Offline flight-search regressions: Duffel is replaced by httpx.MockTransport.
Run from travel_backend: python -m unittest discover -s tests -v
"""
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
        "destination": {"iata_code": "NRT"},
        "arriving_at": "2026-11-20T17:00:00",
        "operating_carrier": {"iata_code": "ZZ"},
    }]}],
}


class FlightSearchTests(unittest.IsolatedAsyncioTestCase):
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
        self.assertGreater(seen["timeout"].read, 15)


if __name__ == '__main__':
    unittest.main()
