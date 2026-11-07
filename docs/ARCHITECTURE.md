# Architecture

## Snapshot

Current-state description, reconciled with source on 2026-10-17. FastAPI and Flutter communicate using JSON over HTTP. No database integration exists in the route/service flow; trips and chat live in frontend memory. Dated design changes and the reasons for them are in [DECISIONS.md](DECISIONS.md); verification evidence is in [TESTING.md](TESTING.md).

## Backend

`travel_backend/main.py` creates the app, enables development CORS, registers five routers, and exposes `/health`.

| Path relative to `travel_backend/` | Responsibility |
|---|---|
| `routers/weather.py` | OpenWeatherMap geocoding and forecast |
| `routers/places.py` | Geoapify attractions using shared geocoding |
| `routers/hotels.py` | Geoapify hotel locations using shared geocoding |
| `routers/flights.py` | Duffel offer request and at most ten simplified offers |
| `routers/lemon.py` | Chat, plan, day-edit (`/lemon/edit`) and popular-spots (`/lemon/spots`) endpoints; provider failures mapped to 502 |
| `models/chat.py`, `models/itinerary.py` | Pydantic contracts, including structured plan request validation |
| `services/chat_parser.py` | Pre-filter, one-shot AI extraction with intent, output checks; local heuristic parser for `mock` and fallback |
| `services/place_check.py` | Destination check against the shared Geoapify search: verified / not found / ambiguous (with options) / unverified |
| `services/itinerary_builder.py` | Best-effort context (weather, attractions, popular spots, destination centre), known places and must-visit assignment, windowed generation, validation (dates, must-visits), grounding, ordered assembly; `edit_day` for one-day edits |
| `services/popular_spots.py` | Popular spots per destination: Wikidata ranking (sitelinks), each spot confirmed with Geoapify; Lemon's "surprise me" picks (DECISIONS 069) |
| `services/poi_lookup.py` | Rate-limited (5/s), cached Geoapify lookups for one place near a point; name matching; destination centre |
| `services/text_sanitize.py` | Chat reply Markdown cleanup |
| `services/llm_providers/` | Provider interface, implementations, registry, auto fallback, diagnostics |
| `services/amadeus_client.py` | Legacy helper, not used by current flight/hotel routers |
| `tests/` | Offline unittest suites (auto provider, builder, guided-trip validation, chat intake) |
| `tools/` | Opt-in live provider diagnostics; consume quota |
| `config.py`, `requirements.txt` | Settings declarations and pinned dependencies |

`travel_backend/.env.example` documents the supported settings with blank keys and source defaults. Local `.env` files must not be inspected or committed.

## Frontend

Paths below are relative to `travel_planner_frontend/`.

- `lib/main.dart` creates `TravelPlannerApp` (titled LemonTrip). `lib/screens/home_screen.dart` owns navigation across Discover, Flights, Hotels, Attractions and Itinerary, the shared Lemon controller, and the chat panel size. Search tabs are created on first visit and keep their state afterward. Compact widths use a navigation menu; the desktop header scrolls horizontally when labels overflow.
- `lib/config/app_theme.dart` defines palette, text styles, and central motion durations (200/300/400 ms) and curve. Motion is bypassed when the platform requests reduced animations. `lib/config/api_config.dart` chooses loopback or Android emulator addressing.
- `lib/chat/lemon_chat_controller.dart` holds rendered messages, transcript, structured trip fields, and the latest itinerary, announced through a `ValueNotifier`. It sends `provider: auto`.
- `lib/services/lemon_api_service.dart` posts chat (45 s timeout) and plan (25 s + 75 s per wave of windows, times 3 for `auto` because each provider may get a full turn; `planTimeoutFor`) requests, day edits (`editTimeoutFor`: 25 s + 75 s, × 3 for `auto`) and popular-spot lookups (65 s; never throws). `lib/services/travel_api_service.dart` uses 15 s timeouts, preserves empty results, and propagates failures to Retry UI; there are no fictional travel-list fallbacks.
- `lib/models/` maps backend JSON; hotel cards display only name/location and disclose unavailable price/rating/amenity details.
- `lib/widgets/` contains the chat panel and launcher, avatar and brand mark, staged range calendar (`trip_date_dialog.dart`), map actions, and hover/reveal motion helpers.
- `test/` contains widget tests with fake services, including responsive checks at 360, 800 and 1440 px; `test/widget_test.dart` is the app smoke test (asserts LemonTrip).

## Conversation and generation flow

1. The chat has two modes, saved on the device (`shared_preferences`, `lib/services/chat_settings.dart`) and switched from the gear menu in the chat header or by plain words ("switch to guided", "let me type"), which the app catches without a provider call (DECISIONS 059). The client sends the full transcript; there is no backend conversation session. Local greetings and obvious-noise recovery happen in the frontend without provider calls, and rejected turns are removed from the history.
   - **Free text (default):** each message goes to `/lemon/chat`, which pre-filters it, extracts every field in one pass (with `intent` and `inferred`), checks dates and bounds, and checks the destination with Geoapify (`services/place_check.py`). The app merges the non-null fields. Once destination and dates are known it shows the trip brief, says which optional details were left out, and tags them "Default" (1 traveler, Comfortable budget, surprise me) or "Assumed" (guessed from wording). Each brief item opens its guided control. Ambiguous places show buttons to pick from. Lemon *offers* the guided controls ("Switch to guided" / "Keep typing") when the backend's local parser answered, when the traveller sounds unhappy, or after two turns stuck on the same required detail; it never switches on its own.
   - **Guided:** `/lemon/chat` interprets only the destination (with the same not-found and which-one handling); the rest is collected locally, as in step 2.
2. Guided controls: dates (staged month-grid range calendar, anchored start, 1–30 days, today or later), travelers (numeric 1–20), budget (`low`/`medium`/`high`, shown as Budget-friendly/Comfortable/Premium) and interests (including Other and Surprise me).
3. After an editable review and explicit confirmation, the client posts the structured fields directly to `/lemon/plan`. Errors preserve the local session; retry repeats only the failed stage.
4. The builder fetches weather and attractions concurrently, each bounded to ten seconds, with `radius_km=5`. Failed context is optional.
5. Requested dates are divided into three-day windows. A semaphore limits active windows to three; each gets 75 seconds from when it takes a slot, under an overall cap of 75 seconds per wave (`generation_budget_seconds`).
6. Each window's output must contain exactly its requested dates and absolute day numbers, in order, with nonempty activities. Direct providers create one instance per window and get one bounded corrective retry. The first failed window cancels the others.
7. **With `auto`, each window falls back on its own (DECISIONS 063).** Every window tries Groq → Gemini → OpenRouter (each provider gets a fresh 75 s; bad output gets one corrective retry on the same provider if 15 s would be left, DECISIONS 067), skipping providers that are cooling down. A window that gets a 429 waits its Retry-After and asks the same provider again, if at least 15 s of its budget would be left (DECISIONS 061). Any other failure records that provider's cooldown and moves the window to the next provider; the provider's windows already running carry on, and windows starting later skip it. The plan is capped at 3 × 75 s × waves. If any window fails on every provider, the other windows are cancelled and the whole plan is the demo itinerary, so real and placeholder days are never mixed. `provider_used` is `"auto"` when more than one provider wrote the plan. Groq and Gemini take one window at a time (DECISIONS 065); queued windows start their 75 s when they get the provider. Groq is sent `reasoning_effort` from `GROQ_REASONING_EFFORT` (default `low`, DECISIONS 066).

**Destination check (chat, DECISIONS 059/068).** `services/place_check.py` runs an ordinary and a country-only Geoapify search (24 h cache), then: not found → refused; one place, or a famous one ahead of same-name places by Geoapify importance ≥ 0.15 → verified with `destination_label` ("Paris, France") and any `destination_alternatives`; close same-name places → ambiguous with options. `services/geo_results.py` holds the shared result filter (islands filed as `amenity` kept when nothing else matches) and the "(country)" label suffix the geocoder understands. The app shows the label on the brief, offers "Not this one?" when alternatives exist, and sends the label as the plan's destination.
8. Windows are assembled in request order.

**Phase 2: grounded plans (DECISIONS 069).**
- **Popular spots.** Once the destination is verified, `/lemon/chat` starts `popular_spots` in the background and the app asks `/lemon/spots`. Wikidata lists visitor places inside the destination by number of language Wikipedias; Geoapify confirms each. Lemon shows them as buttons in her chat bubble (free mode: once per destination; guided: at the must-visit step). Tapped spots, places typed in chat (checked near the destination) and Lemon's picks on "surprise me" become the brief's must-visit chips. A whole country is too broad: Lemon asks for a city or area.
- **Pace** (relaxed / balanced / packed) is a brief line (default Balanced) and a guided step; it sets 2–3 / 3–5 / 5–7 activities a day.
- **Plan prompt.** Must-visits, popular spots and nearby attractions are listed as known places with refs; must-visits are assigned to days before writing (nearby ones together, outdoor ones off rainy forecast days); the weather is one line per forecast day. Each window must contain its must-visits.
- **Grounding.** After assembly, stops with a valid ref take that place's id and coordinates; other named places are looked up near the destination (at most 100, 5 per second, 20 s). The itinerary shows a filled pin for verified stops and a grey "Unverified" tag for unmatched ones.
- **Edits.** Regenerate a day, swap one stop, or adjust a day from the traveller's words: from buttons on the itinerary, or by chat once a plan exists (the app sends a numbered `plan_summary`; Lemon returns an `edit`). `/lemon/edit` writes one day as a one-day window through the same chain; the app shows a preview with "Use this" / "Keep old" and replaces the day only on "Use this". A failed edit leaves the plan unchanged; demo plans can't be edited. Questions about the trip get a fixed "coming soon" reply.

The frontend's plan timeout (25 s + 75 s per wave, × 3 providers for `auto`) leaves room for the context phase and cleanup. These are asynchronous wait bounds, not hard wall-clock guarantees.

## Provider selection

`factory.py` registers `auto`, `groq`, `gemini`, `openrouter`, and `mock`, case-insensitively. Request models default to `mock`; the frontend selects `auto`. Neither `claude` nor `gpt` is registered.

`auto_provider.py` tries Groq → Gemini → OpenRouter with guarded construction, generation, and caller-supplied response validation. Chat allows 9 s per attempt and 30 s total. Plan windows stream: each provider exposes `stream_text()` (Groq/OpenRouter via `openai_stream.py`, Gemini on its own thread because google-genai 0.3.0 blocks the event loop), and auto cuts it only after 10 s without a chunk (25 s before the first), within the window budget; plans call one provider at a time through `attempt_provider` (above) rather than `AutoProvider.generate_json`; `generate_json()` joins the stream into the same raw JSON string. Failed real providers are skipped for a cooldown that depends on the failure kind (5 min hard failures, Retry-After for 429, 30 s for 503/timeouts/stalls/invalid output, none for budget-only timeouts; DECISIONS 042, 061), using a monotonic clock; cooldowns are process-local and shared across chat and plan. Groq and OpenRouter clients use `max_retries=0` so auto sees 429s directly. Exhaustion uses the local chat parser or a demo itinerary covering the requested dates; mock is never cooled down.

## Boundaries

External APIs provide data, not bookings/payments. Hotel results have no live pricing contract. Weather is a short-range forecast, not a forecast for arbitrary trip dates. CORS allows all origins with credentials enabled; routes have no authentication. These are development settings. See `KNOWN_ISSUES.md` and `API.md` for limitations and contracts.
