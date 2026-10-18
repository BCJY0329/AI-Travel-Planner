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

Python is **not on PATH**, and `travel_backend/venv` is broken because its base interpreter is missing (KI-07). Past test runs used an external interpreter with the venv's site-packages appended. From the project root:

```powershell
& '<python.exe>' -B -c "import sys, unittest; sys.path.insert(0, 'travel_backend'); sys.path.append('travel_backend/venv/Lib/site-packages'); suite = unittest.defaultTestLoader.discover('travel_backend/tests'); r = unittest.TextTestRunner(verbosity=2).run(suite); sys.exit(not r.wasSuccessful())"
```

`docs/TESTING.md` records the interpreter used before (`C:\Users\Acer\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe`). Once the environment works, the intended commands are:

```powershell
python -m unittest discover -s tests -v                          # from travel_backend/
python -m unittest tests.test_auto_provider.AutoTests.<method>   # single test
python -m uvicorn main:app --reload                              # docs at /docs, health at /health
```

The backend tests are offline by design. At import time, `tests/test_auto_provider.py` swaps fake modules into `sys.modules` for the SDK provider modules and for `routers.weather`/`routers.places`, so `config.py` (which loads `.env` credentials) is never imported. New backend tests should follow the same pattern. `tools/diagnose_providers.py` makes **live**, quota-consuming provider calls and should only be run with explicit authorization.

## Architecture

### Backend request flow
- `main.py` mounts the weather, places, hotels, flights, and lemon routers. Data routers wrap OpenWeatherMap (geocoding is shared by places and hotels), Geoapify, and Duffel. Hotels return only name and location: no prices, ratings, or amenities, and the UI must not invent them. `services/amadeus_client.py` is legacy and unused.
- `routers/lemon.py` has two endpoints. `POST /lemon/chat` calls `services/chat_parser.parse_chat` and `POST /lemon/plan` calls `services/itinerary_builder.build_itinerary`. Any provider, shape, or unexpected error becomes **HTTP 502**.
- The chat endpoint is stateless: the client sends the full transcript each turn and gets back extracted fields, `reply`, `ready`, and `next_field`. The chat parser has an AI extraction path and a local heuristic parser used for `mock` and as the fallback.
- **Itinerary windowing** (`itinerary_builder.py`):
  1. Weather and attraction context is fetched once, concurrently, with a 10 s limit per lookup. Context is optional, and attractions use `radius_km=5`.
  2. The date range is split into 3-day windows. At most 3 run concurrently (semaphore), each with its own provider instance, all sharing one 75 s monotonic deadline.
  3. Each window's output is validated for exact dates, absolute day numbers, and non-empty activities, then all windows are assembled in request order.
  4. If any window falls back to mock, the whole itinerary is labelled mock.
- **Providers** (`services/llm_providers/`): every provider implements `LLMProvider.generate_json(system, user) -> str` (raw JSON text). `factory.get_provider(name)` is the source of truth for valid names: `auto`, `groq`, `gemini`, `openrouter`, `mock`, matched case-insensitively. Request models default to `mock`, but the frontend sends `auto`.
- `auto_provider.py` tries Groq → Gemini → OpenRouter. It guards construction, the call, and caller-supplied validation for each one. A failed provider gets a 5-minute in-process cooldown. When all of them are exhausted it falls back to the local chat parser or a mock itinerary.
- Timing values (25 s per auto attempt, 75 s plan budget, 100 s frontend wait) are set in `docs/DECISIONS.md` #016. Keep the backend and frontend timeouts consistent if you change them.

### Frontend
- `screens/home_screen.dart` owns navigation across the five views (Discover, Flights, Hotels, Attractions, Itinerary), the shared `LemonChatController` (`lib/chat/`), and the chat panel's expanded size. Search tabs are created on first visit and keep their state afterwards.
- **Guided flow:** `/lemon/chat` is used only to interpret the destination. Dates (staged range calendar, 30-day limit), travelers, budget, and interests are collected locally with guided controls. After the user explicitly confirms, the app posts directly to `/lemon/plan`. Errors keep the local session, and retry repeats only the failed stage.
- `services/travel_api_service.dart` and `lemon_api_service.dart` handle HTTP. Empty results stay empty and failures show Retry. Nothing substitutes fictional listings.
- `lib/models/*.dart` JSON mappings must stay aligned with the Pydantic models in `travel_backend/models/`. The API keeps budget as `low`/`medium`/`high`, and only the UI shows friendlier labels.
- `config/app_theme.dart` centralizes styling and motion durations/curves (`flutter_animate`). Motion must be skipped when `disableAnimations` is set.
- Widget tests inject fake services, and layout tests cover widths of 360, 800, and 1440 px. Never rely on a live backend in tests.

## Documentation conventions

`docs/ARCHITECTURE.md` and `docs/API.md` describe the current state. TESTING, TASKS and KNOWN_ISSUES are dated logs that open with a current summary; DECISIONS is a numbered log. In all of them, later entries supersede earlier ones. When the docs and the code disagree, the routers, models, and `factory.py` win. When you record test results, separate passed, failed, and unrun checks, and never label source-inspected behavior as runtime-tested.
