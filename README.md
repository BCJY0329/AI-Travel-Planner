# LemonTrip / Lemon.ai

An AI-assisted travel planner with a FastAPI backend and Flutter frontend. LemonTrip is the app; Lemon.ai is its conversational assistant. Project folder: `Work3 - AI Travel Planner`.

Your personal travel companion.

## Status

Documentation reconciled with source on **2026-10-17**. This is a development prototype. The frontend includes Discover, Flights, Hotels, Attractions, Itinerary, and Lemon chat views, with guided trip planning (destination via chat, then structured dates, travelers, budget and interests, explicit confirmation) and responsive phone/desktop layouts.

The factory accepts `auto`, which tries Groq → Gemini → OpenRouter with response validation, deadlines and local fallback. Long trips are generated in validated three-day windows. Offline suites cover backend fallback/validation and frontend behavior; live providers and final visual acceptance are not verified by them. See [testing](docs/TESTING.md), [tasks](docs/TASKS.md) and [known issues](docs/KNOWN_ISSUES.md).

## Project structure

```text
Work3 - AI Travel Planner/
  README.md
  AGENTS.md
  CLAUDE.md
  docs/
    PRD.md
    ARCHITECTURE.md
    API.md
    TASKS.md
    DECISIONS.md
    TESTING.md
    KNOWN_ISSUES.md
  travel_backend/
    main.py
    config.py
    requirements.txt
    routers/
    models/
    services/
    tests/
    tools/
  travel_planner_frontend/
    pubspec.yaml
    lib/
    test/
```

## Setup on Windows / PowerShell

Run commands from the project root unless a step changes directory. Python is currently unavailable on PATH, and the existing backend virtual environment points to a missing Python installation. Repair/install Python before using this setup recipe; it was not executed during documentation work. Do not overwrite an existing environment without checking it first.

```powershell
python --version
Set-Location .\travel_backend
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
.\.venv\Scripts\python.exe -m uvicorn main:app --reload
```

Using the environment interpreter directly avoids PowerShell activation. API documentation is at `http://127.0.0.1:8000/docs`, with health at `/health`.

Use [travel_backend/.env.example](travel_backend/.env.example) as the configuration template. From `travel_backend`, run the following only for initial setup; an existing `.env` is preserved. Fill in keys privately, then restart the backend. See [provider setup](travel_backend/README.md#adding-or-changing-providers) for adding integrations.

```powershell
if (-not (Test-Path -LiteralPath .env)) {
    Copy-Item -LiteralPath .env.example -Destination .env
}
```

Configure credentials before starting uvicorn. Credential variables:

| Feature | Credential variable |
|---|---|
| Weather and city geocoding | `OPENWEATHER_API_KEY` |
| Attractions and hotel locations | `GEOAPIFY_API_KEY` (also needs weather geocoding) |
| Flights | `DUFFEL_API_KEY` |
| Groq | `GROQ_API_KEY` |
| Gemini | `GEMINI_API_KEY` |
| OpenRouter | `OPENROUTER_API_KEY` |

Explicit `mock` chat makes no external calls. Mock itinerary generation still attempts weather and attraction lookups before returning placeholder days; it is not an offline test by itself.

Offline backend tests (`travel_backend/tests/`) avoid credentials and network access; until the environment is repaired they have been run with a separate interpreter, as recorded in [testing](docs/TESTING.md).

In a second PowerShell terminal, from the project root:

```powershell
Set-Location .\travel_planner_frontend
flutter pub get
flutter run -d chrome
```

Frontend checks: `flutter analyze --no-pub` and `flutter test --no-pub` from `travel_planner_frontend/` (latest results in [testing](docs/TESTING.md)). API addresses in `lib/config/api_config.dart` are loopback for web/desktop and `10.0.2.2` for Android emulator. Physical-device networking needs separate configuration.

## Data and provider behavior

- Data routes use OpenWeatherMap, Geoapify, and Duffel. No bookings or payments are implemented.
- Hotel API results contain name/location, not prices, ratings, or amenities. The frontend displays supplied listings, preserves empty results, and shows errors with Retry. It does not invent hotel details or substitute fictional travel listings.
- Factory-supported providers: `auto`, `groq`, `gemini`, `openrouter`, `mock`; request models default to `mock` and the frontend sends `auto`.
- `auto` tries Groq → Gemini → OpenRouter with guarded construction and validation, a five-minute in-memory cooldown for failed providers, and local fallback (heuristic chat parser or a demo itinerary that is labelled as such).
- Itineraries are generated in three-day windows (at most three concurrent, shared 75-second deadline) and must cover every requested date before success is reported.
- External provider availability, pricing, quotas, and lifecycle claims are not verified.

## Documentation

| Document | Purpose |
|---|---|
| [AGENTS.md](AGENTS.md) | Rules for coding-agent sessions |
| [CLAUDE.md](CLAUDE.md) | Commands and architecture overview for Claude Code |
| [PRD](docs/PRD.md) | Product scope and proposed acceptance criteria |
| [Architecture](docs/ARCHITECTURE.md) | Components and data flow |
| [API](docs/API.md) | Routes, request fields, and response shapes |
| [Tasks](docs/TASKS.md) | Suggested work and completed implementation |
| [Decisions](docs/DECISIONS.md) | Observed architectural choices |
| [Testing](docs/TESTING.md) | Verification record and future checks |
| [Known issues](docs/KNOWN_ISSUES.md) | Source-backed defects and limitations |

`implementation_plan.md` and `travel_planner_frontend/EXTRACT_ME_README.md` retain historical context. Prefer this documentation set for the current state; within `docs/`, later dated entries supersede earlier ones.
