# Project guidance

## Start here

Read this file and `docs/TASKS.md` at the start of a project session. Inspect `git status --short` before editing; existing uncommitted work belongs to the user. The project root is `Work3 - AI Travel Planner`, containing `travel_backend/` and `travel_planner_frontend/`.

## Scope and permissions

Follow the user's current request. Reference documents and backlog items do not authorize unrelated implementation work. Keep changes within the approved scope; ask before expanding it. Preserve existing work and do not commit, push, install tools, or change dependencies unless authorized by the task.

Never read, print, or commit `.env` files or API keys. Do not include secrets in logs, examples, screenshots, or reports. The public `travel_backend/.env.example` template exists; private `.env` files must remain untouched.

## Code map

- `travel_backend/main.py`: FastAPI app, middleware, routers, health check.
- `travel_backend/routers/`: weather, places, flights, hotels, Lemon endpoints.
- `travel_backend/models/`: Pydantic chat and itinerary contracts.
- `travel_backend/services/itinerary_builder.py`: context gathering and itinerary validation.
- `travel_backend/services/chat_parser.py`: AI chat extraction and local mock parser.
- `travel_backend/services/llm_providers/factory.py`: actual accepted provider names.
- `travel_backend/services/llm_providers/auto_provider.py`: registered fallback implementation with caller-specific validation.
- `travel_backend/services/amadeus_client.py`: legacy client, not used by current flight/hotel routers.
- `travel_planner_frontend/lib/config/`: theme and API base address.
- `travel_planner_frontend/lib/chat/`: conversation state and itinerary notification.
- `travel_planner_frontend/lib/services/`, `travel_planner_frontend/lib/models/`, `travel_planner_frontend/lib/screens/`, `travel_planner_frontend/lib/widgets/`: HTTP, models, views, and components.
- `travel_planner_frontend/test/widget_test.dart`: existing app smoke test.

## Commands and local prerequisites

Use PowerShell and quote paths containing spaces. From the project root, `git status --short` and `git diff --check` work. Use `rg` for source searches and restrict searches to source directories; exclude secrets and virtual environments.

Python is not found on PATH. `travel_backend/venv/Scripts/python.exe --version` fails because its base Python installation is missing. Backend commands in `README.md` and `docs/TESTING.md` are recipes for after repair, not verified working commands today.

Flutter and Dart launchers are available. In `travel_planner_frontend/`, intended checks are `flutter analyze` and `flutter test`; they were not run during documentation installation. Setup/build commands may download dependencies or write SDK caches; honor session permissions.

## Implementation conventions

Treat routers, models, and the provider factory as evidence of current behavior; comments and older READMEs may lag behind. Keep Dart JSON mappings aligned with Python response models. Do not describe `auto` as working until registration and behavior are fixed and tested. Distinguish demo data from verified external results.

Run focused checks for meaningful behavior changes and report passed, failed, and unrun checks separately. Do not import configuration merely to inspect documentation: it can load credentials. See `docs/TESTING.md` for isolated testing guidance.

## Finish a session

Update affected documentation within authorized scope: progress in `docs/TASKS.md`, new issues/lessons in `docs/KNOWN_ISSUES.md`, numbered architectural decisions in `docs/DECISIONS.md`, and endpoint changes in `docs/API.md`. Do not invent historical decisions or mark source-inspected behavior as runtime-tested. Report changed files, checks, limitations, and remaining work; preserve unrelated files.
