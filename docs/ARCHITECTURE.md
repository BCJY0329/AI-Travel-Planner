# Architecture

## Snapshot

Source inspection dated 2026-10-08, including pre-existing uncommitted changes. FastAPI and Flutter communicate using JSON over HTTP. No database integration was found in the inspected route/service flow.

## Backend

`travel_backend/main.py` creates the app, enables development CORS, registers five routers, and exposes `/health`.

| Path relative to `travel_backend/` | Responsibility |
|---|---|
| `routers/weather.py` | OpenWeatherMap geocoding and forecast |
| `routers/places.py` | Geoapify attractions using shared geocoding |
| `routers/hotels.py` | Geoapify hotel locations using shared geocoding |
| `routers/flights.py` | Duffel offer request and at most ten simplified offers |
| `routers/lemon.py` | Chat/plan endpoints, provider failures mapped to 502 |
| `models/chat.py`, `models/itinerary.py` | Pydantic contracts |
| `services/chat_parser.py` | Full-history AI extraction; explicit mock heuristic parser |
| `services/itinerary_builder.py` | Best-effort context, model call, JSON/Pydantic validation |
| `services/text_sanitize.py` | Chat reply Markdown cleanup |
| `services/llm_providers/` | Provider interface, implementations, registry, fallback class |
| `services/amadeus_client.py` | Legacy helper, not used by current flight/hotel routers |
| `config.py`, `requirements.txt` | Settings declarations and pinned dependencies |

`travel_backend/.env.example` documents the supported settings with blank keys and source defaults. Local `.env` files must not be inspected or committed.

## Frontend

Paths below are relative to `travel_planner_frontend/`.

- `lib/main.dart` creates `TravelPlannerApp`; `lib/screens/home_screen.dart` owns navigation and the shared Lemon controller.
- `lib/config/app_theme.dart` defines styling; `lib/config/api_config.dart` chooses loopback or Android emulator addressing.
- `lib/chat/lemon_chat_controller.dart` holds rendered messages, full transcript, extracted fields, and latest itinerary; a `ValueNotifier` announces updates.
- `lib/services/lemon_api_service.dart` posts chat/plan requests with 45/60-second timeouts.
- `lib/services/travel_api_service.dart` uses 15-second timeouts, preserves empty results, and propagates failures to retry UI; there are no fictional travel-list fallbacks.
- `lib/models/travel_models.dart` maps supplied travel data; hotel cards display only name/location and disclose unavailable price/rating/amenity details.
- `lib/screens/views/` contains the five views; `lib/widgets/` contains chat components.
- `test/widget_test.dart` checks that the app displays VoyageAI.

## Conversation and generation flow

The client sends the full transcript on every chat call. There is no backend conversation session. Responses include extracted fields, `reply`, `ready`, and `next_field`. Date UI follows `next_field`, with reply-text matching as fallback. When ready and destination/start/end are present, the controller requests an itinerary. Failures currently reset extracted state/history with a friendly message.

Itinerary building fetches weather and attractions concurrently, bounding each context lookup to ten seconds and passing radius_km=5 explicitly. Failed context is optional. Auto generation allows 12 seconds per provider and 36 seconds total; direct plan providers have a 36-second wait bound. This leaves margin within the frontend's 60-second plan timeout under a responsive event loop. JSON validation remains in place.

## Provider selection

`factory.py` registers `auto`, `groq`, `gemini`, `openrouter`, and `mock`, case-insensitively. The frontend selects `auto`. Neither `claude` nor `gpt` is registered.

`auto_provider.py` tries Groq → Gemini → OpenRouter with guarded construction, generation, and caller-supplied response validation. Failed real providers are skipped for five minutes using a monotonic clock. Exhaustion uses the local chat parser or mock itinerary; mock is never cooled down. Plans report the actual provider used. Cooldowns are shared across requests within one process.

## Boundaries

External APIs provide data, not bookings/payments. Hotel results have no live pricing contract. CORS allows all origins with credentials enabled; routes have no authentication. These are development settings. See `KNOWN_ISSUES.md` and `API.md` for limitations and contracts.
