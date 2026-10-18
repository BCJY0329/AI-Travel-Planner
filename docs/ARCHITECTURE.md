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
| `routers/lemon.py` | Chat/plan endpoints, provider failures mapped to 502 |
| `models/chat.py`, `models/itinerary.py` | Pydantic contracts, including structured plan request validation |
| `services/chat_parser.py` | Full-history AI extraction; local heuristic parser for `mock` and fallback |
| `services/itinerary_builder.py` | Best-effort context, windowed generation, completeness validation, ordered assembly |
| `services/text_sanitize.py` | Chat reply Markdown cleanup |
| `services/llm_providers/` | Provider interface, implementations, registry, auto fallback, diagnostics |
| `services/amadeus_client.py` | Legacy helper, not used by current flight/hotel routers |
| `tests/` | Offline unittest suites (auto provider, builder, guided-trip validation) |
| `tools/` | Opt-in live provider diagnostics; consume quota |
| `config.py`, `requirements.txt` | Settings declarations and pinned dependencies |

`travel_backend/.env.example` documents the supported settings with blank keys and source defaults. Local `.env` files must not be inspected or committed.

## Frontend

Paths below are relative to `travel_planner_frontend/`.

- `lib/main.dart` creates `TravelPlannerApp` (titled LemonTrip). `lib/screens/home_screen.dart` owns navigation across Discover, Flights, Hotels, Attractions and Itinerary, the shared Lemon controller, and the chat panel size. Search tabs are created on first visit and keep their state afterward. Compact widths use a navigation menu; the desktop header scrolls horizontally when labels overflow.
- `lib/config/app_theme.dart` defines palette, text styles, and central motion durations (200/300/400 ms) and curve. Motion is bypassed when the platform requests reduced animations. `lib/config/api_config.dart` chooses loopback or Android emulator addressing.
- `lib/chat/lemon_chat_controller.dart` holds rendered messages, transcript, structured trip fields, and the latest itinerary, announced through a `ValueNotifier`. It sends `provider: auto`.
- `lib/services/lemon_api_service.dart` posts chat (45 s timeout) and plan (100 s timeout) requests. `lib/services/travel_api_service.dart` uses 15 s timeouts, preserves empty results, and propagates failures to Retry UI; there are no fictional travel-list fallbacks.
- `lib/models/` maps backend JSON; hotel cards display only name/location and disclose unavailable price/rating/amenity details.
- `lib/widgets/` contains the chat panel and launcher, avatar and brand mark, staged range calendar (`trip_date_dialog.dart`), map actions, and hover/reveal motion helpers.
- `test/` contains widget tests with fake services, including responsive checks at 360, 800 and 1440 px; `test/widget_test.dart` is the app smoke test (asserts LemonTrip).

## Conversation and generation flow

1. `/lemon/chat` is used only to interpret the destination. The client sends the full transcript; there is no backend conversation session. Local greetings and obvious-noise recovery happen in the frontend without provider calls, and rejected destination turns are removed from the history before retrying.
2. Dates (staged month-grid range calendar, anchored start, 1–30 days, today or later), travelers (numeric 1–20), budget (`low`/`medium`/`high`, shown as Budget-friendly/Comfortable/Premium) and interests (including Other and Surprise me) are collected locally through guided controls.
3. After an editable review and explicit confirmation, the client posts the structured fields directly to `/lemon/plan`. Errors preserve the local session; retry repeats only the failed stage.
4. The builder fetches weather and attractions concurrently, each bounded to ten seconds, with `radius_km=5`. Failed context is optional.
5. Requested dates are divided into three-day windows. A semaphore limits active windows to three; each creates its own provider instance, and all share a 75-second monotonic generation deadline.
6. Each window's output must contain exactly its requested dates and absolute day numbers, in order, with nonempty activities. Direct providers get one bounded corrective retry; auto validates each candidate before accepting it. A failed aggregate request cancels outstanding windows.
7. Windows are assembled in request order. Any mock window labels the whole itinerary mock; mixed successful real providers report `auto`.

The frontend's 100-second plan timeout leaves room for the context phase and cleanup. These are asynchronous wait bounds, not hard wall-clock guarantees.

## Provider selection

`factory.py` registers `auto`, `groq`, `gemini`, `openrouter`, and `mock`, case-insensitively. Request models default to `mock`; the frontend selects `auto`. Neither `claude` nor `gpt` is registered.

`auto_provider.py` tries Groq → Gemini → OpenRouter with guarded construction, generation, and caller-supplied response validation. Chat allows 9 s per attempt and 30 s total; plan windows allow 25 s per attempt within the remaining shared deadline. Failed real providers are skipped for five minutes using a monotonic clock; cooldowns are process-local and shared across chat and plan. Exhaustion uses the local chat parser or a demo itinerary covering the requested dates; mock is never cooled down.

## Boundaries

External APIs provide data, not bookings/payments. Hotel results have no live pricing contract. Weather is a short-range forecast, not a forecast for arbitrary trip dates. CORS allows all origins with credentials enabled; routes have no authentication. These are development settings. See `KNOWN_ISSUES.md` and `API.md` for limitations and contracts.
