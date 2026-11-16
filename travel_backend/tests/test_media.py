"""Offline tests for places from photos and links (DECISIONS 073).
Provider modules and the place-based routers are replaced before the app
modules load, as in test_auto_provider; every network edge is faked.
Run from travel_backend: python -m unittest discover -s tests -v
"""
import asyncio
import base64
import json
import sys
import types
import unittest
from unittest.mock import patch

for module_name, class_name, name in [
    ('groq_provider', 'GroqProvider', 'groq'),
    ('gemini_provider', 'GeminiProvider', 'gemini'),
    ('openrouter_provider', 'OpenRouterProvider', 'openrouter'),
]:
    full = 'services.llm_providers.' + module_name
    if full not in sys.modules:
        module = types.ModuleType(full)
        async def unavailable(self, *args):
            raise RuntimeError('offline')
        setattr(module, class_name, type(class_name, (), {'name': name, 'generate_json': unavailable}))
        sys.modules[full] = module

for module_name, function_name in [('weather', 'get_forecast'), ('places', 'get_attractions')]:
    if 'routers.' + module_name not in sys.modules:
        module = types.ModuleType('routers.' + module_name)
        async def context(**kwargs):
            return {}
        setattr(module, function_name, context)
        sys.modules[module.__name__] = module

from pydantic import ValidationError

from models.chat import LemonChatRequest
from models.media import MediaImage, MediaRequest
from services import chat_parser, itinerary_builder as builder, link_preview, media_finder
from services.chat_parser import parse_chat

JPEG = b"\xff\xd8\xff\xe0" + b"0" * 64
PNG = b"\x89PNG\r\n\x1a\n" + b"0" * 64
KYOTO_CENTRE = {"lat": 35.0116, "lon": 135.7681, "radius_m": 40000}
NARA_CENTRE = {"lat": 34.6851, "lon": 135.8048, "radius_m": 40000}
FUSHIMI = {"name": "Fushimi Inari-taisha", "place_id": "g-fi", "lat": 34.9671, "lon": 135.7727}
TODAIJI = {"name": "Tōdai-ji", "place_id": "g-td", "lat": 34.6890, "lon": 135.8398}


def b64(body: bytes) -> str:
    return base64.b64encode(body).decode('ascii')


def places_json(*items):
    return json.dumps({"places": [dict(zip(("name", "city", "country", "confidence", "evidence"), i))
                                  for i in items]})


class Fakes:
    """Replaces every network edge of media_finder and link_preview."""

    def __init__(self, vision=None, text=None, previews=None, images=None, centres=None, places=None):
        self.vision_calls, self.text_calls, self.fetches = [], [], []
        self.vision, self.text = vision, text
        self.previews, self.images = previews or {}, images or {}
        self.centres = centres or {"Kyoto": KYOTO_CENTRE, "Kyoto, Japan": KYOTO_CENTRE, "Nara, Japan": NARA_CENTRE}
        self.places = places or {}

    async def _vision(self, system, text, images):
        self.vision_calls.append(images)
        if isinstance(self.vision, Exception):
            raise self.vision
        return self.vision or '{"places": []}'

    async def _text_places(self, system, user):
        self.text_calls.append(user)
        if isinstance(self.text, Exception):
            raise self.text
        return self.text or '{"places": []}'

    async def read_preview(self, url):
        self.fetches.append(url)
        value = self.previews.get(url)
        if isinstance(value, Exception):
            raise value
        return value

    async def fetch_image(self, url):
        return self.images.get(url)

    async def _centre(self, destination):
        return self.centres.get(destination)

    async def _find(self, name, centre):
        value = self.places.get((name, centre["lat"]))
        if isinstance(value, Exception):
            raise value
        return value

    def __enter__(self):
        self.patches = [patch.object(media_finder, n, getattr(self, n))
                        for n in ("_vision", "_text_places", "_centre", "_find")]
        self.patches += [patch.object(link_preview, n, getattr(self, n)) for n in ("read_preview", "fetch_image")]
        for p in self.patches:
            p.start()
        media_finder._photo_cache._entries.clear()
        media_finder._link_cache._entries.clear()
        return self

    def __exit__(self, *exc):
        for p in self.patches:
            p.stop()


def run(**request):
    return asyncio.run(media_finder.find_places(MediaRequest(**request)))


class Status:
    def __init__(self, code):
        self.status_code = code


class RateLimited(Exception):
    status_code = 429


class LinkTests(unittest.TestCase):
    def test_classify(self):
        for url, kind in [("https://www.instagram.com/p/abc/", "meta"), ("https://fb.watch/x", "meta"),
                          ("https://m.facebook.com/story", "meta"), ("https://www.tiktok.com/@a/video/1", "tiktok"),
                          ("https://vm.tiktok.com/xyz", "tiktok"), ("https://youtu.be/abc", "youtube"),
                          ("https://www.youtube.com/watch?v=1", "youtube"), ("www.timeout.com/kyoto", "web"),
                          ("https://bit.ly/abc", "unsupported"), ("https://localhost/x", "unsupported")]:
            with self.subTest(url=url):
                self.assertEqual(link_preview.classify(url), kind)

    def test_strip_links_keeps_the_trip_text(self):
        text, readable, other = link_preview.strip_links(
            "Kyoto in December, want to go here https://www.tiktok.com/@a/video/1.")
        self.assertEqual(text, "Kyoto in December, want to go here")
        self.assertEqual(readable, ["https://www.tiktok.com/@a/video/1"])
        self.assertEqual(other, [])
        self.assertEqual(link_preview.strip_links("see https://bit.ly/x")[2], ["https://bit.ly/x"])

    def test_private_and_odd_hosts_are_blocked(self):
        for url in ["http://127.0.0.1/admin", "http://10.0.0.5/", "http://[::1]/", "http://169.254.169.254/latest",
                    "ftp://example.com/x", "https://example.com:8443/", "https://user:pw@example.com/"]:
            with self.subTest(url=url):
                with self.assertRaises(link_preview.BlockedLink):
                    asyncio.run(link_preview._check_host(url))

    def test_hosts_resolving_to_private_addresses_are_blocked(self):
        async def fake_getaddrinfo(host, port, **kwargs):
            return [(2, 1, 6, "", ("192.168.1.10", 0))]
        async def check():
            loop = asyncio.get_running_loop()
            with patch.object(loop, "getaddrinfo", fake_getaddrinfo):
                await link_preview._check_host("https://intranet.example.com/")
        with self.assertRaises(link_preview.BlockedLink):
            asyncio.run(check())

    def test_open_graph_tags_are_read(self):
        page = """<html><head><title>Fallback</title>
        <meta property="og:title" content="Kyoto&#39;s best matcha">
        <meta content="Tea at Nakamura Tokichi, Uji" property="og:description">
        <meta property="og:image" content="/img/cover.jpg"></head><body>ignored</body></html>"""
        got = link_preview.parse_open_graph(page, "https://blog.example.com/post/1")
        self.assertEqual(got["title"], "Kyoto's best matcha")
        self.assertEqual(got["description"], "Tea at Nakamura Tokichi, Uji")
        self.assertEqual(got["image_url"], "https://blog.example.com/img/cover.jpg")

    def test_oembed_fields_are_read(self):
        async def fake_fetch(url, limit, accept):
            self.assertTrue(url.startswith("https://www.tiktok.com/oembed?url=https%3A%2F%2F"))
            return url, "application/json", json.dumps(
                {"title": "Sunset at Kiyomizu-dera #kyoto", "author_name": "trips", "thumbnail_url": "https://p16.x/t.jpg"}).encode()
        with patch.object(link_preview, "_fetch", fake_fetch):
            got = asyncio.run(link_preview.read_preview("https://www.tiktok.com/@trips/video/1"))
        self.assertEqual(got, {"title": "Sunset at Kiyomizu-dera #kyoto", "description": "", "author": "trips",
                               "image_url": "https://p16.x/t.jpg"})

    def test_tiktok_without_oembed_fields_reads_the_page_then_gives_up_on_its_bot_page(self):
        # Live 2026-11-08: TikTok's oEmbed returns only the iframe; the page
        # served to a server is the generic "TikTok - Make Your Day".
        pages = {
            "bot": "<title>TikTok - Make Your Day</title>",
            "real": '<meta property="og:description" content="Matcha in Uji at Nakamura Tokichi">',
        }
        for page, expected in [("bot", None), ("real", "Matcha in Uji at Nakamura Tokichi")]:
            async def fake_fetch(url, limit, accept, page=page):
                if "oembed" in url:
                    return url, "application/json", b'{"version": "1.0", "html": "<iframe></iframe>"}'
                return url, "text/html; charset=utf-8", pages[page].encode()
            with self.subTest(page=page), patch.object(link_preview, "_fetch", fake_fetch):
                got = asyncio.run(link_preview.read_preview("https://www.tiktok.com/@a/video/1"))
                self.assertEqual(got and got["description"], expected)

    def test_private_or_removed_post_gives_no_preview(self):
        async def fake_fetch(url, limit, accept):
            raise RuntimeError("404")
        with patch.object(link_preview, "_fetch", fake_fetch):
            self.assertIsNone(asyncio.run(link_preview.read_preview("https://youtu.be/gone")))


class RequestTests(unittest.TestCase):
    def test_limits(self):
        with self.assertRaises(ValidationError):
            MediaRequest(images=[MediaImage(mime="image/jpeg", data=b64(JPEG))] * 4)
        with self.assertRaises(ValidationError):
            MediaRequest(links=["https://a.com", "https://b.com", "https://c.com"])
        with self.assertRaises(ValidationError):
            MediaImage(mime="image/gif", data=b64(JPEG))

    def test_images_must_be_what_they_say(self):
        with Fakes():
            for image in [MediaImage(mime="image/png", data=b64(JPEG)), MediaImage(mime="image/jpeg", data="!!notbase64!!")]:
                with self.subTest(mime=image.mime):
                    with self.assertRaises(ValueError):
                        run(images=[image])


class PhotoTests(unittest.TestCase):
    def test_photo_places_are_checked_on_the_map(self):
        with Fakes(vision=places_json(("Fushimi Inari Shrine", "Kyoto", "Japan", "high", "sign reads 伏見稲荷大社"),
                                      ("Tōdai-ji", "Nara", "Japan", "maybe", "giant wooden hall"),
                                      ("Secret Cafe", "Kyoto", "Japan", "maybe", "cup with a logo")),
                   places={("Fushimi Inari Shrine", KYOTO_CENTRE["lat"]): FUSHIMI,
                           ("Tōdai-ji", NARA_CENTRE["lat"]): TODAIJI}) as fakes:
            r = run(images=[MediaImage(mime="image/jpeg", data=b64(JPEG))], destination="Kyoto")
        self.assertEqual(r.status, "ok")
        self.assertIn("3 places", r.reply)
        fushimi, todaiji, cafe = r.candidates
        self.assertEqual((fushimi.status, fushimi.in_destination, fushimi.place_id), ("verified", True, "g-fi"))
        self.assertEqual(fushimi.matched_name, "Fushimi Inari-taisha")
        self.assertEqual(fushimi.evidence, "sign reads 伏見稲荷大社")
        # Nara is a day trip from Kyoto: found near its own city, marked outside.
        self.assertEqual((todaiji.status, todaiji.in_destination), ("verified", False))
        self.assertGreater(todaiji.distance_km, 25)
        self.assertEqual(cafe.status, "not_found")
        self.assertEqual(len(fakes.vision_calls), 1)
        self.assertIsNone(r.suggested_destination)

    def test_no_destination_suggests_the_city(self):
        with Fakes(vision=places_json(("Fushimi Inari Shrine", "Kyoto", "Japan", "high", "torii")),
                   places={("Fushimi Inari Shrine", KYOTO_CENTRE["lat"]): FUSHIMI}):
            r = run(images=[MediaImage(mime="image/jpeg", data=b64(JPEG))])
        self.assertEqual(r.suggested_destination, "Kyoto, Japan")
        self.assertIn("plan a trip to Kyoto", r.reply)
        self.assertIsNone(r.candidates[0].in_destination)

    def test_three_photos_go_in_one_request_and_are_cached(self):
        images = [MediaImage(mime="image/jpeg", data=b64(JPEG)), MediaImage(mime="image/png", data=b64(PNG)),
                  MediaImage(mime="image/jpeg", data=b64(JPEG + b"1"))]
        with Fakes(vision=places_json(("Kinkaku-ji", "Kyoto", "Japan", "high", "golden pavilion"))) as fakes:
            run(images=images, destination="Kyoto")
            run(images=images, destination="Kyoto")
        self.assertEqual(len(fakes.vision_calls), 1)
        self.assertEqual([m for m, _ in fakes.vision_calls[0]], ["image/jpeg", "image/png", "image/jpeg"])

    def test_nothing_recognisable_is_said_plainly(self):
        with Fakes(vision='{"places": []}'):
            r = run(images=[MediaImage(mime="image/jpeg", data=b64(JPEG))], destination="Kyoto")
        self.assertEqual((r.status, r.candidates), ("nothing_found", []))

    def test_rate_limit_says_busy_and_is_not_cached(self):
        with Fakes(vision=RateLimited()) as fakes:
            r = run(images=[MediaImage(mime="image/jpeg", data=b64(JPEG))])
            self.assertEqual(r.status, "busy")
            fakes.vision = places_json(("Kinkaku-ji", "Kyoto", "Japan", "high", "golden pavilion"))
            r = run(images=[MediaImage(mime="image/jpeg", data=b64(JPEG))])
        self.assertEqual(r.status, "ok")

    def test_model_failure_or_bad_output_is_unavailable(self):
        for vision in [RuntimeError("boom"), "not json at all"]:
            with self.subTest(vision=str(vision)), Fakes(vision=vision):
                r = run(images=[MediaImage(mime="image/jpeg", data=b64(JPEG))])
                self.assertEqual(r.status, "unavailable")

    def test_map_failure_leaves_the_place_unchecked(self):
        with Fakes(vision=places_json(("Kinkaku-ji", "Kyoto", "Japan", "high", "golden pavilion")),
                   places={("Kinkaku-ji", KYOTO_CENTRE["lat"]): RuntimeError("quota")}):
            r = run(images=[MediaImage(mime="image/jpeg", data=b64(JPEG))], destination="Kyoto")
        self.assertEqual(r.candidates[0].status, "unchecked")

    def test_candidate_fields_are_bounded(self):
        raw = json.dumps({"places": [{"name": "X" * 500, "confidence": "certain", "evidence": "e" * 500}]
                                    + [{"name": f"P{i}"} for i in range(20)]})
        places = media_finder.parse_places(raw, "photo")
        self.assertEqual(len(places), media_finder.MAX_CANDIDATES)
        self.assertEqual((len(places[0]["name"]), len(places[0]["evidence"]), places[0]["confidence"]),
                         (120, 160, "maybe"))


class LinkFlowTests(unittest.TestCase):
    TIKTOK = "https://www.tiktok.com/@a/video/1"

    def test_instagram_asks_for_a_screenshot_without_fetching(self):
        with Fakes() as fakes:
            r = run(links=["https://www.instagram.com/reel/abc/"])
        self.assertEqual(r.status, "needs_screenshot")
        self.assertIn("screenshot", r.reply)
        self.assertEqual(fakes.fetches, [])

    def test_caption_is_read_first(self):
        preview = {"title": "Matcha at Nakamura Tokichi in Uji", "description": "", "author": "a",
                   "image_url": "https://img/t.jpg"}
        with Fakes(previews={self.TIKTOK: preview},
                   text=places_json(("Nakamura Tokichi", "Uji", "Japan", "high", 'caption: "Matcha at Nakamura"'))) as fakes:
            r = run(links=[self.TIKTOK], destination="Kyoto")
        self.assertEqual(r.status, "ok")
        self.assertEqual((r.candidates[0].name, r.candidates[0].source), ("Nakamura Tokichi", "link"))
        self.assertEqual(fakes.vision_calls, [])
        self.assertIn("Matcha at Nakamura Tokichi in Uji", fakes.text_calls[0])

    def test_empty_caption_falls_back_to_the_thumbnail(self):
        preview = {"title": "pov: you're here", "description": "", "author": "", "image_url": "https://img/t.jpg"}
        with Fakes(previews={self.TIKTOK: preview}, images={"https://img/t.jpg": ("image/jpeg", JPEG)},
                   vision=places_json(("Kiyomizu-dera", "Kyoto", "Japan", "high", "wooden stage"))) as fakes:
            r = run(links=[self.TIKTOK], destination="Kyoto")
        self.assertEqual((r.status, r.candidates[0].name, r.candidates[0].source), ("ok", "Kiyomizu-dera", "link"))
        self.assertEqual(len(fakes.vision_calls), 1)

    def test_nothing_readable_asks_for_a_screenshot(self):
        for preview in [None, {"title": "x", "description": "", "author": "", "image_url": None},
                        RuntimeError("timeout")]:
            with self.subTest(preview=str(preview)), Fakes(previews={self.TIKTOK: preview}):
                r = run(links=[self.TIKTOK])
                self.assertEqual(r.status, "needs_screenshot")

    def test_photo_plus_instagram_link_mentions_the_screenshot(self):
        with Fakes(vision=places_json(("Kinkaku-ji", "Kyoto", "Japan", "high", "golden pavilion"))):
            r = run(images=[MediaImage(mime="image/jpeg", data=b64(JPEG))],
                    links=["https://instagram.com/p/x"], destination="Kyoto")
        self.assertEqual(r.status, "ok")
        self.assertIn("Instagram", r.reply)

    def test_links_are_cached(self):
        preview = {"title": "Nishiki Market eats", "description": "", "author": "", "image_url": None}
        with Fakes(previews={self.TIKTOK: preview},
                   text=places_json(("Nishiki Market", "Kyoto", "Japan", "high", "caption"))) as fakes:
            run(links=[self.TIKTOK])
            run(links=[self.TIKTOK])
        self.assertEqual(len(fakes.fetches), 1)


class ChatLinkTests(unittest.IsolatedAsyncioTestCase):
    async def test_link_only_message_makes_no_provider_call(self):
        r = await parse_chat(LemonChatRequest(provider='mock', messages=[
            {'role': 'user', 'content': 'https://www.tiktok.com/@a/video/1'}]))
        self.assertEqual(r.reply, chat_parser.LINK_ONLY_REPLY)
        self.assertIsNone(r.destination)

    async def test_trip_text_around_a_link_is_still_read(self):
        r = await parse_chat(LemonChatRequest(provider='mock', messages=[
            {'role': 'user', 'content': 'Kyoto https://youtu.be/abc'}]))
        self.assertEqual(r.destination, 'Kyoto')

    async def test_shorteners_stay_blocked(self):
        r = await parse_chat(LemonChatRequest(provider='mock', messages=[
            {'role': 'user', 'content': 'go here https://bit.ly/abc'}]))
        self.assertEqual(r.intent, 'off_topic')


class DayTripTests(unittest.TestCase):
    def test_far_must_visit_is_a_day_trip_with_its_own_day(self):
        places = [
            {'ref': 'P1', 'name': 'Tōdai-ji', 'lat': TODAIJI['lat'], 'lon': TODAIJI['lon'], 'source': 'must_visit'},
            {'ref': 'P2', 'name': 'Kinkaku-ji', 'lat': 35.0394, 'lon': 135.7292, 'source': 'must_visit'},
            {'ref': 'P3', 'name': 'Nijo Castle', 'lat': 35.0142, 'lon': 135.7482, 'source': 'must_visit'},
        ]
        builder.mark_day_trips(places, KYOTO_CENTRE)
        self.assertGreater(places[0]['day_trip_km'], 25)
        self.assertNotIn('day_trip_km', places[1])
        plan = builder.assign_must_visits(places, ['2026-12-01', '2026-12-02'], set(), 'packed')
        day_of = {p['name']: i for i, ps in plan.items() for p in ps}
        self.assertNotEqual(day_of['Tōdai-ji'], day_of['Kinkaku-ji'])
        self.assertNotEqual(day_of['Tōdai-ji'], day_of['Nijo Castle'])
        self.assertIn('day trip about', builder._places_block(places))
        self.assertIn('plan the travel there and back', builder._must_visit_lines(plan, [0, 1]))

    def test_no_centre_no_day_trips(self):
        places = [{'ref': 'P1', 'name': 'Tōdai-ji', 'lat': 34.68, 'lon': 135.83, 'source': 'must_visit'}]
        builder.mark_day_trips(places, None)
        self.assertNotIn('day_trip_km', places[0])


if __name__ == '__main__':
    unittest.main()
