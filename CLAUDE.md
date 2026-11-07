# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

**Read `AGENTS.md` first.** It holds the binding project rules: scope and permissions, no reading of `.env`/keys, no commits/installs/dependency changes without authorization, and the end-of-session documentation updates (`docs/TASKS.md`, `docs/KNOWN_ISSUES.md`, `docs/DECISIONS.md`, `docs/API.md`). This file adds the commands and architecture you need to work in the code.

LemonTrip is the app; Lemon.ai is its assistant. It is a FastAPI backend (`travel_backend/`) plus a Flutter frontend (`travel_planner_frontend/`) that talk JSON over HTTP on `127.0.0.1:8000` (Android emulator uses `10.0.2.2`, see `lib/config/api_config.dart`). There's no database and no auth, and CORS is wide open. These are development settings.

## Commands (PowerShell; quote paths with spaces)

### Frontend (run in `travel_planner_frontend/`)

```powershell
flutter analyze --no-pub
flutter test --no-pub                                   # full suite
flutter test --no-pub test/flights_view_test.dart       # one file
flutter test --no-pub test/flights_view_test.dart --plain-name "<test name>"   # one test
flutter run -d chrome          # or: flutter run -d web-server --web-hostname 127.0.0.1 --web-port 5187 --no-pub
flutter build web --no-pub
```

`--no-pub` skips dependency resolution. In the sandbox, Flutter has failed SDK ownership checks. The same command passes when run outside the sandbox, so don't change Git trust settings to work around it.

### Backend (run in `travel_backend/`)

Python is **not on PATH**, but `travel_backend/venv` works again as of 2026-11-05 (Python 3.11.9; the old one is kept untracked as `venv_old/`, KI-07). Use the venv's interpreter, from `travel_backend/`:

```powershell
.\venv\Scripts\python.exe -m unittest discover -s tests -v                          # full suite
.\venv\Scripts\python.exe -m unittest tests.test_auto_provider.AutoTests.<method>   # single test
.\venv\Scripts\python.exe -m uvicorn main:app --reload                              # docs at /docs, health at /health
```

The external interpreter recorded in `docs/TESTING.md` still runs the offline tests with the venv's site-packages appended, but it can't load the venv's compiled packages (pydantic-core, Pillow) for live tools.

The backend tests are offline by design. At import time, `tests/test_auto_provider.py` swaps fake modules into `sys.modules` for the SDK provider modules and for `routers.weather`/`routers.places`, so `config.py` (which loads `.env` credentials) is never imported. New backend tests should follow the same pattern. `tools/diagnose_providers.py` makes **live**, quota-consuming provider calls and should only be run with explicit authorization.

## Architecture

### Backend request flow
- `main.py` mounts the weather, places, hotels, flights, and lemon routers. Data routers wrap OpenWeatherMap (geocoding is shared by places and hotels), Geoapify, and Duffel. Hotels return only name and location: no prices, ratings, or amenities, and the UI must not invent them. `services/amadeus_client.py` is legacy and unused.
- `routers/lemon.py` has four endpoints. `POST /lemon/chat` calls `services/chat_parser.parse_chat`, `POST /lemon/plan` calls `services/itinerary_builder.build_itinerary`, `POST /lemon/edit` calls `itinerary_builder.edit_day` (one day: regenerate, swap one stop, adjust), and `GET /lemon/spots` returns `services/popular_spots` results (DECISIONS 069). Any provider, shape, or unexpected error becomes **HTTP 502**; spots never error (status `unavailable`).
- **Phase 2 (DECISIONS 069).** Popular spots: Wikidata ranks visitor places inside the destination by sitelinks, Geoapify confirms each (`services/poi_lookup.py`: one-place lookups, 5 per second, cached), 24 h cache, prefetched by `/lemon/chat`; a country is `too_broad`. Plans take `pace` (2–3 / 3–5 / 5–7 activities) and `must_visit` (≤ 10, each window must include its assigned ones; if every provider leaves them out, the otherwise-valid window is kept and `missing_must_visits` names them, and the app asks before showing a plan with none of them, DECISIONS 070); the prompt lists "known places" with refs; afterwards stops are grounded (`place_id`, `lat`, `lon`, `place_status` verified / unverified / null). Chat takes `plan_summary` once a plan exists and returns `pace`, `must_visit` (checked near the destination), `spots_to_lemon` and `edit` (intents `edit_plan`, `plan_question`; replies for both are fixed server-side). Wikidata's User-Agent carries `WIKIDATA_CONTACT`.
- The chat endpoint is stateless: the client sends the full transcript each turn and gets back extracted fields, `reply`, `ready`, `next_field`, `intent`, `inferred`, `destination_status`/`destination_options`, `destination_label`/`destination_alternatives` (the exact place, and other same-name places when Lemon picked the famous one, DECISIONS 068) and `fallback_used`. `chat_parser.py` pre-filters the latest message (no provider call for noise, links or injection), extracts with AI or the local heuristic parser (`mock` and fallback), then checks dates, bounds and the destination (`services/place_check.py`, Geoapify; result filtering in `services/geo_results.py`) before replying.
- **Itinerary windowing** (`itinerary_builder.py`):
  1. Weather and attraction context is fetched once, concurrently, with a 10 s limit per lookup. Context is optional, and attractions use `radius_km=5`.
  2. The date range is split into 3-day windows. At most 3 run concurrently (semaphore). Each window gets 75 s from when it takes a slot, under an overall cap of 75 s × waves (`generation_budget_seconds`).
  3. Each window's output is validated for exact dates, absolute day numbers, and non-empty activities, then all windows are assembled in request order.
  4. **With `auto`, each window falls back on its own (DECISIONS 063).** A window tries Groq → Gemini → OpenRouter, with a fresh 75 s per provider. Within a provider, a 429 waits out Retry-After and retries if 15 s of its budget would remain (DECISIONS 061), and bad output gets one corrective retry under the same 15 s rule (DECISIONS 067); other failures move on at once. A failure benches the provider for windows that start later; its running windows finish. Groq and Gemini take one window at a time (DECISIONS 065), and Groq gets `reasoning_effort` from `GROQ_REASONING_EFFORT` (default `low`; without it gpt-oss can think until it runs out of output and return nothing, DECISIONS 066). The plan cap is 3 × 75 s × waves. If any window fails on every provider, the rest are cancelled and the whole plan is demo. Real and placeholder days are never mixed; `provider_used` is `auto` when several providers wrote it.
- **Providers** (`services/llm_providers/`): every provider implements `LLMProvider.generate_json(system, user) -> str` (raw JSON text). `factory.get_provider(name)` is the source of truth for valid names: `auto`, `groq`, `gemini`, `openrouter`, `mock`, matched case-insensitively. Request models default to `mock`, but the frontend sends `auto`.
- `auto_provider.py` tries Groq → Gemini → OpenRouter. It guards construction, the call, and caller-supplied validation for each one. A failed provider gets an in-process cooldown by failure kind: 5 min for hard failures, Retry-After for 429, 30 s for 503/timeouts/stalls/invalid output (including Groq's mid-stream `json_validate_failed`), none for budget-only timeouts. When all of them are exhausted it falls back to the local chat parser or a mock itinerary. Plans don't use `generate_json`: `itinerary_builder` calls `attempt_provider` per window and provider.
- Plans stream: providers expose `stream_text()` and auto cuts one off only after 10 s of silence (25 s before the first chunk). Gemini streams on its own thread because google-genai 0.3.0 blocks the event loop. Groq/OpenRouter use `max_retries=0`.
- Timing values (chat 9 s/30 s; plan 75 s per window × waves; 10 s idle / 25 s first chunk; frontend plan wait 25 s + 75 s × waves × 3 providers for `auto` in `LemonApiService.planTimeoutFor`; edits 25 s + 75 s × 3 for `auto` in `editTimeoutFor`; spots 60 s backend / 65 s app) are set in `docs/DECISIONS.md` #042, #060, #063 and #065. Keep the backend and frontend formulas consistent if you change them. Never shorten itinerary content (token caps, prompt trimming, smaller windows) to fix timing.

### Frontend
- `screens/home_screen.dart` owns navigation across the five views (Discover, Flights, Hotels, Attractions, Itinerary), the shared `LemonChatController` (`lib/chat/`), and the chat panel's expanded size. Search tabs are created on first visit and keep their state afterwards.
- **Two chat modes (DECISIONS 059),** saved on the device (`services/chat_settings.dart`, `shared_preferences`) and switched from the chat header's gear menu or by plain words. **Free text** (default): every message goes to `/lemon/chat`. The app merges non-null fields, shows the brief once destination and dates are known, and tags left-out details "Default" (1 traveler, medium, surprise me) and guesses "Assumed". Lemon *offers* guided controls (offline parser, unhappy, stuck twice) but never switches on its own. **Guided**: `/lemon/chat` interprets only the destination, and dates (staged range calendar, 30-day limit), travelers, budget and interests are collected with guided controls. Both post to `/lemon/plan` only after explicit confirmation. Errors keep the local session, and retry repeats only the failed stage.
- `services/travel_api_service.dart` and `lemon_api_service.dart` handle HTTP. Empty results stay empty and failures show Retry. Nothing substitutes fictional listings.
- `lib/models/*.dart` JSON mappings must stay aligned with the Pydantic models in `travel_backend/models/`. The API keeps budget as `low`/`medium`/`high`, and only the UI shows friendlier labels.
- `config/app_theme.dart` centralizes styling and motion durations/curves (`flutter_animate`). Motion must be skipped when `disableAnimations` is set.
- Widget tests inject fake services, and layout tests cover widths of 360, 800, and 1440 px. Never rely on a live backend in tests. API fakes must override `getPopularSpots` and `editPlan` too, or a test makes real HTTP calls.
- Backend tests: `test_auto_provider.py` also replaces the phase 2 network edges (`popular_spots._search_destination`/`_wikidata`, `poi_lookup._geocode`/`destination_centre`, the builder's `_spots_for`/`_centre_for`/`_find_place`, `chat_parser._default_spot_finder`) for every suite, because other suites leave the real geocoder loaded. New network code needs the same treatment.

## Documentation conventions

`docs/ARCHITECTURE.md` and `docs/API.md` describe the current state. TESTING, TASKS and KNOWN_ISSUES are dated logs that open with a current summary; DECISIONS is a numbered log. In all of them, later entries supersede earlier ones. When the docs and the code disagree, the routers, models, and `factory.py` win. When you record test results, separate passed, failed, and unrun checks, and never label source-inspected behavior as runtime-tested.
