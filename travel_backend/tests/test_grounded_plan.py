"""Offline tests for DECISIONS 069: grounded plans, must-visits, pace, day edits,
popular spots and the chat's edit/question handling.
Run from travel_backend: python -m unittest tests.test_grounded_plan -v
"""
import asyncio
import json
import re
import sys
import types
import unittest
from datetime import date
from unittest.mock import patch

# Same isolation as test_auto_provider: no SDKs, no config, no network. When
# that suite already ran its imports, its stubs stay in place.
for module_name, class_name, name in [
    ('groq_provider', 'GroqProvider', 'groq'),
    ('gemini_provider', 'GeminiProvider', 'gemini'),
    ('openrouter_provider', 'OpenRouterProvider', 'openrouter'),
]:
    module = types.ModuleType('services.llm_providers.' + module_name)
    async def unavailable(self, *args):
        raise RuntimeError('offline')
    setattr(module, class_name, type(class_name, (), {'name': name, 'generate_json': unavailable}))
    sys.modules.setdefault(module.__name__, module)
for module_name, function_name in [('weather', 'get_forecast'), ('places', 'get_attractions')]:
    module = types.ModuleType('routers.' + module_name)
    async def context(**kwargs):
        return {}
    setattr(module, function_name, context)
    sys.modules.setdefault(module.__name__, module)

from models.chat import ChatTurn, LemonChatRequest, LemonChatResponse, MustVisitPlace
from models.itinerary import ItineraryDay, MustVisit, PlanEditRequest, TripRequest
from services import chat_parser, itinerary_builder as builder, poi_lookup, popular_spots
from services.chat_parser import _finalize, _mock_parse
from services.llm_providers import auto_provider as auto

TODAY = date(2026, 11, 5)


async def _offline(*args, **kwargs):
    raise RuntimeError('offline')


def trip(**extra):
    base = dict(destination='Paris, France', start_date='2026-11-10', end_date='2026-11-12', provider='fake')
    return TripRequest(**{**base, **extra})


def requested_days(prompt):
    return re.findall(r'(\d+): (\d{4}-\d{2}-\d{2})', prompt.split('Generate ONLY')[1])


class FakeProvider:
    """Answers each window with `make(day_number, date, prompt) -> activities`."""
    name = 'fake'

    def __init__(self, make):
        self.make = make
        self.prompts = []

    async def generate_json(self, system, prompt):
        self.prompts.append(prompt)
        return json.dumps({'summary': 'Yay!', 'days': [
            {'day': int(n), 'date': d, 'activities': self.make(int(n), d, prompt)}
            for n, d in requested_days(prompt)]})


class OfflineCase(unittest.IsolatedAsyncioTestCase):
    def setUp(self):
        auto.reset_cooldowns() if hasattr(auto, 'reset_cooldowns') else None
        self.patches = [
            patch.object(builder, '_spots_for', _offline),
            patch.object(builder, '_centre_for', _offline),
            patch.object(builder, '_find_place', _offline),
        ]
        for p in self.patches:
            p.start()

    def tearDown(self):
        for p in self.patches:
            p.stop()


class ContextTests(unittest.TestCase):
    def test_known_places_put_must_visits_first_and_number_them(self):
        t = trip(must_visit=[MustVisit(name='Louvre', place_id='g1', lat=48.86, lon=2.33)])
        places = builder.known_places(
            t, [{'name': 'Eiffel Tower', 'lat': 48.858, 'lon': 2.294, 'place_id': 'g2'},
                {'name': 'louvre', 'lat': 1, 'lon': 1}],
            {'attractions': [{'name': 'Small plaque', 'lat': 48.85, 'lon': 2.35, 'place_id': 'g3'}]})
        self.assertEqual([(p['ref'], p['name'], p['source']) for p in places],
                         [('P1', 'Louvre', 'must_visit'), ('P2', 'Eiffel Tower', 'popular'),
                          ('P3', 'Small plaque', 'nearby')])

    def test_known_places_are_capped_but_must_visits_always_stay(self):
        spots = [{'name': f'Spot {i}', 'lat': 1, 'lon': 1} for i in range(60)]
        t = trip(must_visit=[MustVisit(name=f'Must {i}') for i in range(3)])
        places = builder.known_places(t, spots, {})
        self.assertEqual(len(places), builder.MAX_KNOWN_PLACES)
        self.assertEqual([p['source'] for p in places[:3]], ['must_visit'] * 3)

    def test_weather_by_day_flags_rainy_days(self):
        rows = [{'datetime': '2026-11-10 09:00:00', 'temp_c': 10, 'condition': 'Rain'},
                {'datetime': '2026-11-10 12:00:00', 'temp_c': 13, 'condition': 'Rain'},
                {'datetime': '2026-11-11 12:00:00', 'temp_c': 15, 'condition': 'Clear'},
                {'datetime': '2026-11-12 21:00:00', 'temp_c': 9, 'condition': 'Rain'},
                {'datetime': '2026-11-12 12:00:00', 'temp_c': 11, 'condition': 'Thunderstorm'}]
        days = builder.weather_by_day({'forecast': rows})
        self.assertEqual({d: w['wet'] for d, w in days.items()},
                         {'2026-11-10': True, '2026-11-11': False, '2026-11-12': True})
        self.assertEqual((days['2026-11-10']['lo'], days['2026-11-10']['hi']), (10, 13))
        self.assertIn('rain likely', builder._weather_block({'forecast': rows}))
        self.assertIn('unavailable', builder._weather_block({'error': 'x'}))

    def test_must_visits_group_nearby_and_keep_outdoor_ones_dry(self):
        places = [
            {'ref': 'P1', 'name': 'Louvre', 'lat': 48.8606, 'lon': 2.3376, 'source': 'must_visit'},
            {'ref': 'P2', 'name': 'Tuileries Garden', 'lat': 48.8635, 'lon': 2.3275, 'source': 'must_visit'},
            {'ref': 'P3', 'name': 'Sacré-Cœur', 'lat': 48.8867, 'lon': 2.3431, 'source': 'must_visit'},
            {'ref': 'P4', 'name': 'Eiffel Tower', 'lat': 48.858, 'lon': 2.294, 'source': 'popular'},
        ]
        dates = ['2026-11-10', '2026-11-11', '2026-11-12']
        plan = builder.assign_must_visits(places, dates, {'2026-11-10'}, 'balanced')
        names = {i: [p['name'] for p in ps] for i, ps in plan.items()}
        # The garden is outdoor, so not on the rainy first day; the Louvre next
        # to it joins it; Sacré-Cœur takes the emptiest remaining day.
        day_of = {n: i for i, ns in names.items() for n in ns}
        self.assertNotEqual(day_of['Tuileries Garden'], 0)
        self.assertEqual(day_of['Louvre'], day_of['Tuileries Garden'])
        self.assertNotIn('Eiffel Tower', day_of)
        self.assertEqual(sum(len(v) for v in names.values()), 3)

    def test_must_visits_overflow_spreads_instead_of_failing(self):
        places = [{'ref': f'P{i}', 'name': f'Museum {i}', 'lat': None, 'lon': None, 'source': 'must_visit'}
                  for i in range(5)]
        plan = builder.assign_must_visits(places, ['2026-11-10', '2026-11-11'], set(), 'relaxed')
        self.assertEqual(sorted(len(v) for v in plan.values()), [2, 3])

    def test_place_names_match_across_languages(self):
        self.assertTrue(poi_lookup.same_place('Louvre Museum', 'Musée du Louvre'))
        self.assertTrue(poi_lookup.same_place('Eiffel Tower', 'Tour Eiffel'))
        self.assertTrue(poi_lookup.same_place('Sensō-ji Temple', 'Senso-ji'))
        self.assertFalse(poi_lookup.same_place('National Museum', 'National Gallery'))
        self.assertFalse(poi_lookup.same_place('Louvre', 'Rue de Rivoli'))

    def test_one_shared_word_is_not_a_match(self):
        # DECISIONS 071: the Script 5 tea house matched a different café live.
        self.assertFalse(poi_lookup.same_place('Hanamiya Kissa', 'Kissa Gobo Gobo'))
        self.assertFalse(poi_lookup.same_place("Bob's Cafe", 'Cafe Nero'))
        self.assertFalse(poi_lookup.same_place('Menya Yoshi Kitayama', 'Menya Inoichi'))
        self.assertFalse(poi_lookup.same_place('Arashiyama Monkey Park', 'Arashiyama Station'))
        # Real matches still pass.
        self.assertTrue(poi_lookup.same_place('Fushimi Inari', 'Fushimi Inari-taisha'))
        self.assertTrue(poi_lookup.same_place('Kinkaku-ji Temple', 'Kinkaku-ji'))
        self.assertTrue(poi_lookup.same_place('Belém Tower', 'Torre de Belém'))
        self.assertTrue(poi_lookup.same_place('Sagrada Família', 'Basílica de la Sagrada Família'))
        self.assertTrue(poi_lookup.same_place('Nishiki Market food stalls', 'Nishiki Market'))


class PlanTests(OfflineCase):
    async def test_pace_sets_activities_per_day_and_known_places_reach_the_prompt(self):
        provider = FakeProvider(lambda n, d, p: [{'time': '09:00', 'activity': 'Walk'}])
        attractions = {'attractions': [{'name': 'Musée Carnavalet', 'lat': 48.857, 'lon': 2.362}]}
        async def fake_attractions(**kwargs):
            return attractions
        with patch.object(builder, 'get_provider', return_value=provider), \
                patch.object(builder, 'get_attractions', fake_attractions):
            await builder.build_itinerary(trip(pace='packed'))
        prompt = provider.prompts[0]
        self.assertIn('with 5-7 concise activities per day', prompt)
        self.assertIn('Pace: packed', prompt)
        self.assertIn('P1 | Musée Carnavalet | 48.8570, 2.3620 | nearby', prompt)

    async def test_missing_must_visit_gets_one_corrective_retry(self):
        calls = []
        def make(n, d, prompt):
            calls.append(prompt)
            if 'CORRECTIVE' in prompt or 'every must-visit place on its day' in prompt:
                return [{'time': '10:00', 'activity': 'Visit the Louvre', 'place_ref': 'P1'}]
            return [{'time': '10:00', 'activity': 'Walk'}]
        provider = FakeProvider(make)
        t = trip(end_date='2026-11-10', must_visit=[MustVisit(name='Louvre', place_id='g1', lat=48.86, lon=2.33)])
        with patch.object(builder, 'get_provider', return_value=provider):
            result = await builder.build_itinerary(t)
        self.assertEqual(len(provider.prompts), 2)
        self.assertIn('- Day 1: P1 Louvre', provider.prompts[0])
        stop = result.days[0].activities[0]
        self.assertEqual((stop.place_status, stop.place_id, stop.lat), ('verified', 'g1', 48.86))
        self.assertNotIn('place_ref', result.model_dump()['days'][0]['activities'][0])

    async def test_must_visit_left_out_everywhere_keeps_the_plan_and_names_it(self):
        # DECISIONS 070: not a demo plan; the app asks before showing it.
        provider = FakeProvider(lambda n, d, p: [{'time': '10:00', 'activity': 'Walk'}])
        t = trip(end_date='2026-11-10', must_visit=[MustVisit(name='Louvre', lat=48.86, lon=2.33)])
        with patch.object(builder, 'get_provider', return_value=provider):
            result = await builder.build_itinerary(t)
        self.assertEqual(len(provider.prompts), 2)  # one corrective retry first
        self.assertEqual(result.provider_used, 'fake')
        self.assertEqual(result.days[0].activities[0].activity, 'Walk')
        self.assertEqual(result.missing_must_visits, ['Louvre'])

    async def test_auto_keeps_the_near_miss_after_every_provider(self):
        made = []
        class Omits:
            name = 'omits'
            async def generate_json(self, system, prompt):
                made.append(prompt)
                return json.dumps({'days': [{'day': int(n), 'date': d, 'activities': [
                    {'time': '10:00', 'activity': 'Walk'}]} for n, d in requested_days(prompt)]})
        class Broken:
            name = 'broken'
            async def generate_json(self, *args):
                raise RuntimeError('down')
        t = trip(provider='auto', end_date='2026-11-10',
                 must_visit=[MustVisit(name='Louvre'), MustVisit(name='Orsay')])
        with patch.object(auto, '_FALLBACK_ORDER', [Omits, Broken]):
            auto._cooldown_until.clear()
            result = await builder.build_itinerary(t)
        self.assertNotEqual(result.provider_used, 'mock')
        self.assertEqual(result.missing_must_visits, ['Louvre', 'Orsay'])

    async def test_partly_missing_must_visits_are_listed(self):
        provider = FakeProvider(lambda n, d, p: [{'time': '10:00', 'activity': 'Visit the Louvre'}])
        t = trip(end_date='2026-11-10', must_visit=[MustVisit(name='Louvre'), MustVisit(name='Orsay')])
        with patch.object(builder, 'get_provider', return_value=provider):
            result = await builder.build_itinerary(t)
        self.assertEqual(result.missing_must_visits, ['Orsay'])

    async def test_complete_plan_has_nothing_missing(self):
        provider = FakeProvider(lambda n, d, p: [{'time': '10:00', 'activity': 'Louvre', 'place_ref': 'P1'}])
        t = trip(end_date='2026-11-10', must_visit=[MustVisit(name='Louvre')])
        with patch.object(builder, 'get_provider', return_value=provider):
            result = await builder.build_itinerary(t)
        self.assertEqual(result.missing_must_visits, [])
        self.assertEqual(len(provider.prompts), 1)

    async def test_grounding_verifies_unverifies_and_skips_generic_places(self):
        provider = FakeProvider(lambda n, d, p: [
            {'time': '09:00', 'activity': 'Breakfast', 'location': 'Local café', 'place_status': 'verified'},
            {'time': '11:00', 'activity': 'Musée Rodin', 'location': 'Musée Rodin'},
            {'time': '15:00', 'activity': 'Hidden bar', 'location': 'Le Bar Imaginaire'},
            {'time': '18:00', 'activity': 'Stroll', 'location': 'Paris'},
        ])
        looked_up = []
        async def find(name, centre):
            looked_up.append(name)
            if name == 'Le Bar Imaginaire':
                return None
            return {'place_id': 'rodin', 'lat': 48.855, 'lon': 2.315}
        async def centre(destination):
            return {'lat': 48.85, 'lon': 2.35, 'radius_m': 40000}
        with patch.object(builder, 'get_provider', return_value=provider), \
                patch.object(builder, '_find_place', find), patch.object(builder, '_centre_for', centre):
            result = await builder.build_itinerary(trip(end_date='2026-11-10'))
        stops = result.days[0].activities
        self.assertEqual([s.place_status for s in stops], [None, 'verified', 'unverified', None])
        self.assertEqual(stops[1].place_id, 'rodin')
        self.assertEqual(sorted(looked_up), ['Le Bar Imaginaire', 'Musée Rodin'])

    async def test_must_visit_stop_shows_the_name_it_was_matched_to(self):
        provider = FakeProvider(lambda n, d, p: [
            {'time': '10:00', 'activity': 'Tea time', 'location': 'Hanamiya Kissa', 'place_ref': 'P1',
             'place_name': 'Made up by the model'}])
        must = MustVisit(name='Hanamiya Kissa', place_id='k1', lat=35.0175, lon=135.748,
                         matched_name='Kissa Gobo Gobo')
        with patch.object(builder, 'get_provider', return_value=provider):
            result = await builder.build_itinerary(trip(end_date='2026-11-10', must_visit=[must]))
        stop = result.days[0].activities[0]
        self.assertEqual((stop.place_status, stop.place_name), ('verified', 'Kissa Gobo Gobo'))

    async def test_place_check_failure_leaves_no_tag(self):
        provider = FakeProvider(lambda n, d, p: [{'time': '11:00', 'activity': 'Museum', 'location': 'Musée Rodin'}])
        async def centre(destination):
            return {'lat': 48.85, 'lon': 2.35, 'radius_m': 40000}
        with patch.object(builder, 'get_provider', return_value=provider), patch.object(builder, '_centre_for', centre):
            result = await builder.build_itinerary(trip(end_date='2026-11-10'))
        self.assertIsNone(result.days[0].activities[0].place_status)

    async def test_demo_plan_is_never_grounded_and_skips_spot_lookups(self):
        called = []
        async def spots(destination):
            called.append(destination)
            return []
        with patch.object(builder, '_spots_for', spots):
            result = await builder.build_itinerary(trip(provider='mock'))
        self.assertEqual(result.provider_used, 'mock')
        self.assertEqual(called, [])
        self.assertTrue(all(a.place_status is None for d in result.days for a in d.activities))


def current_days():
    return [ItineraryDay(day=1, date='2026-11-10', activities=[
                {'time': '09:00', 'activity': 'Visit the Louvre', 'location': 'Louvre', 'place_id': 'g1',
                 'lat': 48.86, 'lon': 2.33, 'place_status': 'verified'},
                {'time': '13:00', 'activity': 'Lunch'}]),
            ItineraryDay(day=2, date='2026-11-11', activities=[
                {'time': '10:00', 'activity': 'Eiffel Tower', 'location': 'Eiffel Tower'}])]


class EditTests(OfflineCase):
    async def test_regenerate_keeps_must_visits_and_avoids_other_days(self):
        provider = FakeProvider(lambda n, d, p: [{'time': '10:00', 'activity': 'Louvre again', 'place_ref': 'P1'},
                                                 {'time': '15:00', 'activity': 'Marais walk'}])
        t = trip(must_visit=[MustVisit(name='Louvre', place_id='g1', lat=48.86, lon=2.33)])
        req = PlanEditRequest(trip=t, days=current_days(), action='regenerate_day', day=1)
        with patch.object(builder, 'get_provider', return_value=provider):
            result = await builder.edit_day(req)
        prompt = provider.prompts[0]
        self.assertIn('Day 2: Eiffel Tower', prompt)
        self.assertIn('Keep these must-visit places on this day', prompt)
        self.assertEqual(requested_days(prompt), [('1', '2026-11-10')])
        self.assertEqual(result.day.day, 1)
        self.assertEqual(len(result.day.activities), 2)

    async def test_edit_that_drops_a_must_visit_is_previewed_with_a_note(self):
        provider = FakeProvider(lambda n, d, p: [{'time': '10:00', 'activity': 'Marais walk'}])
        t = trip(must_visit=[MustVisit(name='Louvre', place_id='g1', lat=48.86, lon=2.33)])
        req = PlanEditRequest(trip=t, days=current_days(), action='regenerate_day', day=1)
        with patch.object(builder, 'get_provider', return_value=provider):
            result = await builder.edit_day(req)
        self.assertEqual(len(provider.prompts), 2)
        self.assertEqual(result.day.activities[0].activity, 'Marais walk')
        self.assertEqual(result.missing_must_visits, ['Louvre'])

    async def test_auto_edit_near_miss_is_previewed_too(self):
        class Omits:
            name = 'omits'
            async def generate_json(self, system, prompt):
                return json.dumps({'days': [{'day': 1, 'date': '2026-11-10', 'activities': [
                    {'time': '10:00', 'activity': 'Marais walk'}]}]})
        t = trip(provider='auto', must_visit=[MustVisit(name='Louvre', place_id='g1', lat=48.86, lon=2.33)])
        req = PlanEditRequest(trip=t, days=current_days(), action='adjust_day', day=1, instruction='less museums')
        with patch.object(auto, '_FALLBACK_ORDER', [Omits]):
            auto._cooldown_until.clear()
            result = await builder.edit_day(req)
        self.assertEqual(result.missing_must_visits, ['Louvre'])

    async def test_swap_replaces_one_stop_and_keeps_its_time(self):
        provider = FakeProvider(lambda n, d, p: [{'time': '12:00', 'activity': 'Picnic in the Tuileries'}])
        req = PlanEditRequest(trip=trip(), days=current_days(), action='swap_activity', day=1, stop=2)
        with patch.object(builder, 'get_provider', return_value=provider):
            result = await builder.edit_day(req)
        stops = result.day.activities
        self.assertEqual([s.activity for s in stops], ['Visit the Louvre', 'Picnic in the Tuileries'])
        self.assertEqual(stops[1].time, '13:00')
        self.assertEqual((stops[0].place_status, stops[0].place_id), ('verified', 'g1'))

    async def test_swap_rejects_the_same_activity(self):
        provider = FakeProvider(lambda n, d, p: [{'time': '13:00', 'activity': 'Lunch'}])
        req = PlanEditRequest(trip=trip(), days=current_days(), action='swap_activity', day=1, stop=2)
        with patch.object(builder, 'get_provider', return_value=provider):
            with self.assertRaises(ValueError):
                await builder.edit_day(req)
        self.assertEqual(len(provider.prompts), 2)  # one corrective retry, then fail

    async def test_adjust_passes_the_request_as_data(self):
        provider = FakeProvider(lambda n, d, p: [{'time': '10:00', 'activity': 'Slow morning'}])
        req = PlanEditRequest(trip=trip(), days=current_days(), action='adjust_day', day=2,
                              instruction='make it more relaxed')
        with patch.object(builder, 'get_provider', return_value=provider):
            result = await builder.edit_day(req)
        self.assertIn('Request: make it more relaxed', provider.prompts[0])
        self.assertEqual(result.day.date, '2026-11-11')

    async def test_auto_edit_failing_everywhere_raises_and_never_returns_demo(self):
        class Broken:
            name = 'broken'
            async def generate_json(self, *args):
                return '{"days": []}'
        req = PlanEditRequest(trip=trip(provider='auto'), days=current_days(), action='regenerate_day', day=1)
        with patch.object(auto, '_FALLBACK_ORDER', [Broken]):
            auto._cooldown_until.clear()
            with self.assertRaises(builder.EditFailed):
                await builder.edit_day(req)

    async def test_mock_edit_is_a_demo_day(self):
        req = PlanEditRequest(trip=trip(provider='mock'), days=current_days(), action='swap_activity', day=1, stop=1)
        result = await builder.edit_day(req)
        self.assertEqual(result.provider_used, 'mock')
        self.assertEqual(result.day.activities[1].activity, 'Lunch')

    def test_edit_request_checks_day_and_stop(self):
        with self.assertRaises(ValueError):
            PlanEditRequest(trip=trip(), days=current_days(), action='regenerate_day', day=5)
        with self.assertRaises(ValueError):
            PlanEditRequest(trip=trip(), days=current_days(), action='swap_activity', day=2, stop=3)
        with self.assertRaises(ValueError):
            PlanEditRequest(trip=trip(), days=current_days(), action='adjust_day', day=2, instruction=' ')


def turns(*texts):
    return [ChatTurn(role='user', content=t) for t in texts]


class ChatTests(unittest.IsolatedAsyncioTestCase):
    def test_offline_parser_reads_pace_must_visits_and_surprise(self):
        r = _mock_parse(turns('5 days in Paris from Dec 3, we must see the Louvre and Eiffel Tower, relaxed pace'),
                        today=TODAY)
        self.assertEqual(r.pace, 'relaxed')
        self.assertEqual([m.name for m in r.must_visit], ['Louvre', 'Eiffel Tower'])
        self.assertFalse(r.spots_to_lemon)
        self.assertTrue(_mock_parse(turns('Paris Dec 3-5', 'up to you Lemon'), today=TODAY).spots_to_lemon)
        self.assertEqual(_mock_parse(turns('Paris Dec 3-5', 'pack it in please'), today=TODAY).pace, 'packed')

    def test_offline_parser_reads_edit_commands_only_with_a_plan(self):
        cases = {
            'regenerate day 2': {'action': 'regenerate_day', 'day': 2},
            'swap stop 3 on day 1': {'action': 'swap_activity', 'day': 1, 'stop': 3},
            'on day 2, replace activity 1': {'action': 'swap_activity', 'day': 2, 'stop': 1},
            'make day 3 more relaxed': {'action': 'adjust_day', 'day': 3},
        }
        for text, expected in cases.items():
            with self.subTest(text=text):
                r = _mock_parse(turns('Paris Dec 3-5', text), today=TODAY, has_plan=True)
                self.assertEqual(r.intent, 'edit_plan')
                got = r.edit.model_dump()
                self.assertEqual({k: got[k] for k in expected}, expected)
        self.assertIsNone(_mock_parse(turns('Paris Dec 3-5', 'regenerate day 2'), today=TODAY).edit)

    async def test_questions_get_the_coming_soon_reply(self):
        r = await _finalize(_mock_parse(turns('Paris Dec 3-5', 'what should I wear on day 2?'), today=TODAY,
                                        has_plan=True), check_place=False, today=TODAY, has_plan=True)
        self.assertEqual(r.intent, 'plan_question')
        self.assertEqual(r.reply, chat_parser.PLAN_QUESTION_REPLY)
        self.assertIn("coming soon", r.reply)

    async def test_edit_replies_check_the_day(self):
        def edit_result(**edit):
            return LemonChatResponse(reply='Done!', intent='edit_plan', edit=edit or None)
        r = await _finalize(edit_result(action='regenerate_day', day=2), check_place=False, today=TODAY,
                            has_plan=True, plan_days=3)
        self.assertEqual((r.edit.day, r.reply), (2, 'On it! 🍋 Let me rework day 2 for you.'))
        r = await _finalize(edit_result(action='regenerate_day', day=5), check_place=False, today=TODAY,
                            has_plan=True, plan_days=3)
        self.assertIsNone(r.edit)
        self.assertIn('Your plan has 3 days', r.reply)
        r = await _finalize(edit_result(action='swap_activity', day=1), check_place=False, today=TODAY,
                            has_plan=True, plan_days=3)
        self.assertIsNone(r.edit)
        self.assertIn('Which stop on day 1', r.reply)
        r = await _finalize(edit_result(action='adjust_day', day=1), check_place=False, today=TODAY,
                            has_plan=True, plan_days=3, latest='day 1 with more food')
        self.assertEqual(r.edit.instruction, 'day 1 with more food')
        r = await _finalize(edit_result(action='regenerate_day', day=1), check_place=False, today=TODAY)
        self.assertEqual((r.edit, r.reply), (None, chat_parser.EDIT_NEEDS_PLAN_REPLY))

    async def test_model_cannot_set_an_edit_outside_edit_intent(self):
        r = await _finalize(LemonChatResponse(reply='Hi', intent='trip', edit={'action': 'regenerate_day', 'day': 1}),
                            check_place=False, today=TODAY, has_plan=True)
        self.assertIsNone(r.edit)

    async def test_must_visits_are_checked_near_the_destination(self):
        from services import place_check
        place_check._cache.clear()  # other suites cache their own "Paris"
        async def lookup(name):
            return [{'name': 'Paris', 'result_type': 'city', 'country': 'France', 'country_code': 'fr'}]
        checked = []
        async def spots(name, destination):
            checked.append((name, destination))
            if name == 'Nowhere Café':
                return None
            if name == 'Slow Place':
                raise RuntimeError('offline')
            return {'name': 'Musée du Louvre', 'place_id': 'g1', 'lat': 48.86, 'lon': 2.33}
        result = LemonChatResponse(reply='ok', destination='Paris', must_visit=[
            'Louvre', 'louvre', 'Nowhere Café', 'Slow Place', 'Paris'])
        r = await _finalize(result, check_place=True, lookup=lookup, spot_lookup=spots, today=TODAY)
        self.assertEqual([(m.name, m.status) for m in r.must_visit],
                         [('Louvre', 'verified'), ('Nowhere Café', 'not_found'), ('Slow Place', 'unverified')])
        self.assertEqual(r.must_visit[0].place_id, 'g1')
        self.assertEqual(r.must_visit[0].matched_name, 'Musée du Louvre')
        self.assertEqual({d for _, d in checked}, {'Paris, France'})

    async def test_unchecked_destination_skips_must_visit_checks(self):
        async def spots(name, destination):
            raise AssertionError('must not be called')
        r = await _finalize(LemonChatResponse(reply='ok', destination='Paris', must_visit=['Louvre']),
                            check_place=False, spot_lookup=spots, today=TODAY)
        self.assertEqual([(m.name, m.status) for m in r.must_visit], [('Louvre', 'unverified')])

    def test_chat_request_carries_the_plan(self):
        req = LemonChatRequest(messages=turns('hi'), plan_summary='Day 1: Louvre', plan_days=3)
        self.assertEqual(req.plan_days, 3)
        self.assertEqual(LemonChatResponse(reply='x', pace='CHILL').pace, None)
        self.assertEqual(LemonChatResponse(reply='x', pace='Packed').pace, 'packed')

    def test_ai_prompt_lists_the_new_fields(self):
        prompt = chat_parser.SYSTEM_PROMPT_TEMPLATE.format(today='2026-11-05', interest_labels='Food')
        for word in ('"must_visit"', '"pace"', '"spots_to_lemon"', 'edit_plan', 'plan_question'):
            self.assertIn(word, prompt)


class SpotsTests(unittest.IsolatedAsyncioTestCase):
    def setUp(self):
        popular_spots._cache.clear()

    def row(self, q, label, links, kind='Q570116', point='Point(2.2945 48.8584)'):
        return {'item': {'value': f'http://www.wikidata.org/entity/{q}'}, 'itemLabel': {'value': label},
                'links': {'value': str(links)}, 'kind': {'value': f'http://www.wikidata.org/entity/{kind}'},
                'coord': {'value': point}}

    async def test_ranked_spots_parse_rows_and_drop_unlabelled_ones(self):
        rows = [self.row('Q243', 'Eiffel Tower', 191, 'Q12518'), self.row('Q243', 'Eiffel Tower', 191),
                self.row('Q19675', 'Louvre Museum', 170, 'Q33506', 'Point(2.3376 48.8606)'),
                self.row('Q999', 'Q999', 50)]
        async def sparql(query, timeout=0):
            self.assertIn('wd:Q90', query)
            self.assertIn('FILTER NOT EXISTS { ?item wdt:P576 [] }', query)
            return rows
        with patch.object(popular_spots, '_sparql', sparql):
            spots = await popular_spots._ranked_spots('Q90')
        self.assertEqual([(s['name'], s['kind'], s['popularity']) for s in spots],
                         [('Eiffel Tower', 'tower', 191), ('Louvre Museum', 'museum', 170)])
        self.assertEqual((spots[0]['lat'], spots[0]['lon']), (48.8584, 2.2945))

    async def test_office_towers_drop_and_one_kind_cannot_fill_the_list(self):
        rows = ([self.row('Q1', 'Petronas Towers', 89, 'Q11303'), self.row('Q2', 'Maxis Tower', 11, 'Q11303')]
                + [self.row(f'Q{10 + i}', f'Mosque {i}', 30 - i, 'Q1370598') for i in range(7)]
                + [self.row('Q50', 'Bird Park', 19, 'Q43501')])
        async def sparql(query, timeout=0):
            return rows
        with patch.object(popular_spots, '_sparql', sparql):
            names = [s['name'] for s in await popular_spots._ranked_spots('Q1865')]
        self.assertNotIn('Maxis Tower', names)
        self.assertEqual(names[:7], ['Petronas Towers', 'Mosque 0', 'Mosque 1', 'Mosque 2', 'Mosque 3',
                                     'Mosque 4', 'Bird Park'])
        self.assertEqual(names[7:], ['Mosque 5', 'Mosque 6'])

    async def test_country_is_too_broad_without_any_search(self):
        r = await popular_spots.popular_spots('Georgia (country)')
        self.assertEqual(r['status'], 'too_broad')

    async def test_whole_flow_keeps_only_spots_geoapify_confirms(self):
        async def search(text, **extra):
            return [{'name': 'Paris', 'result_type': 'city', 'lat': 48.85, 'lon': 2.35}]
        async def item(name, lat, lon):
            return 'Q90'
        async def ranked(place):
            return [{'name': 'Eiffel Tower', 'lat': 48.858, 'lon': 2.294, 'popularity': 191, 'kind': 'tower'},
                    {'name': 'Gone Place', 'lat': 48.0, 'lon': 2.0, 'popularity': 100, 'kind': 'sight'}]
        async def find(name, lat, lon, radius_m=0, exact=None):
            return {'place_id': 'eiffel', 'lat': lat, 'lon': lon} if name == 'Eiffel Tower' else None
        with patch.object(popular_spots, '_search_destination', search), \
                patch.object(popular_spots, '_destination_item', item), \
                patch.object(popular_spots, '_ranked_spots', ranked), patch.object(poi_lookup, 'find_place', find):
            r = await popular_spots.popular_spots('Paris')
        self.assertEqual(r['status'], 'ready')
        self.assertEqual([(s['name'], s['place_id']) for s in r['spots']], [('Eiffel Tower', 'eiffel')])

    async def test_country_result_is_too_broad(self):
        async def search(text, **extra):
            return [{'name': 'Japan', 'result_type': 'country', 'lat': 36, 'lon': 138}]
        with patch.object(popular_spots, '_search_destination', search):
            r = await popular_spots.popular_spots('Japan')
        self.assertEqual((r['status'], r['destination']), ('too_broad', 'Japan'))

    def test_lemon_picks_mix_interests_and_popularity(self):
        spots = [{'name': n, 'popularity': p, 'kind': k} for n, p, k in [
            ('Tower', 190, 'tower'), ('Museum A', 170, 'museum'), ('Church', 120, 'worship'),
            ('Arch', 86, 'monument'), ('Park', 50, 'park'), ('Garden', 48, 'garden')]]
        self.assertEqual([s['name'] for s in popular_spots.lemon_picks(spots, [])],
                         ['Tower', 'Museum A', 'Church', 'Arch'])
        self.assertEqual([s['name'] for s in popular_spots.lemon_picks(spots, ['Nature'])],
                         ['Tower', 'Museum A', 'Park', 'Garden'])


class LookupTests(unittest.IsolatedAsyncioTestCase):
    def setUp(self):
        poi_lookup._cache.clear()

    async def test_lookup_ignores_areas_and_other_names(self):
        answers = [
            [{'name': 'Paris', 'result_type': 'city', 'lat': 48.85, 'lon': 2.35},
             {'name': 'Rue de Rivoli', 'result_type': 'street', 'lat': 48.86, 'lon': 2.34},
             {'name': 'Musée du Louvre', 'result_type': 'amenity', 'lat': 48.8606, 'lon': 2.3376, 'place_id': 'g1'}],
        ]
        calls = []
        async def geocode(params):
            calls.append(params)
            return answers[0]
        with patch.object(poi_lookup, '_geocode', geocode):
            found = await poi_lookup.find_place('Louvre Museum', 48.85, 2.35)
            again = await poi_lookup.find_place('louvre museum', 48.85, 2.35)
        self.assertEqual(found['place_id'], 'g1')
        self.assertEqual(again, found)
        self.assertEqual(len(calls), 1)  # cached
        self.assertTrue(calls[0]['filter'].startswith('circle:2.35,48.85,'))

    async def test_exact_coordinates_accept_a_close_differently_named_result(self):
        async def geocode(params):
            return [{'name': '東京国立博物館', 'result_type': 'amenity', 'lat': 35.7188, 'lon': 139.7765, 'place_id': 't'}]
        with patch.object(poi_lookup, '_geocode', geocode):
            self.assertIsNone(await poi_lookup.find_place('Tokyo National Museum', 35.7, 139.7))
            found = await poi_lookup.find_place('Tokyo National Museum', 35.7188, 139.7766,
                                                radius_m=1500, exact=(35.7188, 139.7766))
        self.assertEqual(found['place_id'], 't')


class RouteTests(unittest.TestCase):
    def test_spots_and_edit_routes(self):
        from fastapi import FastAPI
        from fastapi.testclient import TestClient
        from routers import lemon
        app = FastAPI()
        app.include_router(lemon.router)
        client = TestClient(app)
        with patch.object(lemon.spots_service, 'popular_spots', _offline):
            body = client.get('/lemon/spots', params={'destination': 'Paris'}).json()
        self.assertEqual((body['status'], body['picks']), ('unavailable', []))
        async def ready(destination):
            return {'status': 'ready', 'destination': 'Paris', 'spots': [
                {'name': 'Tower', 'popularity': 190, 'kind': 'tower'},
                {'name': 'Museum', 'popularity': 170, 'kind': 'museum'},
                {'name': 'Park', 'popularity': 60, 'kind': 'park'}]}
        with patch.object(lemon.spots_service, 'popular_spots', ready):
            body = client.get('/lemon/spots', params={'destination': 'Paris', 'interests': ['Nature']}).json()
        self.assertEqual(body['picks'], ['Tower', 'Museum', 'Park'])
        async def fail(req):
            raise builder.EditFailed('x')
        payload = {'trip': trip().model_dump(), 'days': [d.model_dump() for d in current_days()],
                   'action': 'regenerate_day', 'day': 1}
        with patch.object(lemon, 'edit_day', fail):
            resp = client.post('/lemon/edit', json=payload)
        self.assertEqual(resp.status_code, 502)
        self.assertEqual(resp.json()['detail'], "Lemon couldn't change that day right now. Your plan is unchanged.")


if __name__ == '__main__':
    unittest.main()
