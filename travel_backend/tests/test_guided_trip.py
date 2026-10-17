"""Validation for structured LemonTrip intake; no settings or network imports."""
import unittest
from pydantic import ValidationError
from models.itinerary import TripRequest

class GuidedTripValidationTests(unittest.TestCase):
    def request(self, **changes):
        data = dict(destination='Kyoto', start_date='2026-11-01', end_date='2026-11-05', travelers=2, budget_level='medium', interests=['Food', 'Gentle walks'])
        data.update(changes)
        return TripRequest(**data)

    def test_selected_preferences_preserved(self):
        trip = self.request(destination=' Kyoto ')
        self.assertEqual(trip.destination, 'Kyoto')
        self.assertEqual(trip.interests, ['Food', 'Gentle walks'])

    def test_invalid_dates_ranges_and_fields_rejected(self):
        for changes in [dict(start_date='2026-02-30'), dict(start_date='20261101'),
                        dict(end_date='2026-10-31'), dict(end_date='2026-12-01'),
                        dict(destination=' '), dict(travelers=0), dict(travelers=21),
                        dict(budget_level='whatever'), dict(interests=[' ']),
                        dict(interests=['x' * 121]), dict(interests=['food'] * 13)]:
            with self.subTest(changes=changes), self.assertRaises(ValidationError):
                self.request(**changes)

    def test_same_day_and_thirty_days_allowed(self):
        self.request(end_date='2026-11-01')
        self.request(end_date='2026-11-30')
