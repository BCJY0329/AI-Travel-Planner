# Testing and verification

## Flight date repair — 2026-10-08

Passed: `flutter test --no-pub test/flights_view_test.dart` (four widget tests). Injected clock and recording API service verify the first request and picker bounds across ordinary, year-end, and leap-year dates, stale-date searches after time advances, and selection after a backward clock change. No external requests or dependency installation.

The initial sandbox run failed Flutter SDK ownership checks; the same command passed outside the sandbox without changing Git trust settings. Full app smoke test and live flight API were not rerun; existing KI-16 layout issues remain outside this change.

Also passed: `flutter analyze --no-pub lib/screens/views/flights_view.dart test/flights_view_test.dart` (no issues) and `git diff --check` (line-ending warnings only).

## Documentation verification — 2026-10-08

- Inspected routers, models, provider factory/fallback, itinerary/chat services, frontend controller/services/models, and existing smoke test.
- Compared API field names/defaults/ranges and provider names against actual source.
- Checked documented source locations; explicitly recorded the missing environment template.
- Confirmed `.env` and `README.old.md.bak` are ignored using `git check-ignore`; did not read `.env` or credentials.
- Found Flutter/Dart launchers using Get-Command, without running SDK initialization.
- Existing `travel_backend/venv/Scripts/python.exe --version` failed: the base Python executable is missing. Python was not found on PATH.
- Local Markdown links in the root documentation and seven new docs resolved successfully; Git whitespace checks on the two updated READMEs passed (only line-ending conversion warnings).

No backend API calls, real provider calls, dependency installation, Flutter builds, or application test runs were performed. Documentation checks do not establish runtime health. Existing uncommitted source changes were preserved.

## Documentation checks

From the project root in PowerShell:

```powershell
git diff --check -- README.md travel_backend/README.md
git status --short
git check-ignore travel_backend/.env README.old.md.bak
```

Verify Markdown links and referenced files without opening secrets. New untracked documents need separate content/link review because ordinary git diff does not include them.

## Backend setup prerequisite

Repair/install an appropriate Python interpreter in a separately authorized environment task. After repair, the intended commands from the project root are:

```powershell
Set-Location .\travel_backend
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
.\.venv\Scripts\python.exe -m uvicorn main:app --reload
```

These are unexecuted setup instructions. A secret-free `travel_backend/.env.example` is now available; copy it only when no `.env` exists. Do not overwrite existing credential files or load them for an offline verification run.

## Proposed isolated backend checks

The initial inventory found no backend test suite; subsequent repairs added travel_backend/tests/test_auto_provider.py. Tests substitute settings and HTTP/provider clients so they neither load the user's `.env` nor make external requests.

1. Validate health and request/response shapes using a test client.
2. Exercise explicit mock chat: greeting, destination, dates, travelers, budget, interests/no preference, confirmation, and corrections.
3. Stub weather and attractions before testing mock itinerary generation; a mock provider alone does not prevent external context lookups.
4. Test frontend-selected `auto` through the factory and both Lemon routes. Before repair, the expected current failure is 502; after repair, verify intended successful behavior.
5. Test constructor failures, provider-call failures, cooldown, all-real-provider failure, malformed JSON, and chat-compatible fallback separately.
6. Test direct attraction context collection with a numeric radius, request validation, and transport-error handling.

## Frontend checks

After dependencies/toolchain are ready, from the project root:

```powershell
Set-Location .\travel_planner_frontend
flutter analyze
flutter test
flutter run -d chrome
```

These commands were not run for this Markdown-only task. Existing `test/widget_test.dart` only asserts that VoyageAI appears. The home screen constructs travel views that initiate data loading; tests should inject fake services rather than assume widget tests establish live backend correctness.

Proposed manual scenarios: navigation, chat date prompts, completed itinerary, retry after failures, dynamic flight date bounds, and visible distinction between demo and external data. Record devices and exact checks when performed.

## Unverified claims

Current live provider/model availability, account quota/funding, external API success, Flutter build compatibility, and historical service-retirement claims are unverified. Earlier backend README success reports are historical notes, not results from this session.

## Auto repair verification — 2026-10-08

Passed: eight unittest cases in `travel_backend/tests/test_auto_provider.py`, covering factory lookup, constructor/call/JSON/schema failures, priority, cooldown skip/expiry, actual plan provider attribution, exhausted chat/plan fallback, invalid mock output, and HTTP chat/plan success plus unknown-provider 502.

Used the existing bundled Python runtime with existing backend site-packages appended for FastAPI/httpx; no installation or project environment repair. Tests substitute SDK adapter modules and weather/attraction modules before service imports, so configuration, credentials, and external services are never loaded.

Reproduction from the project root on this machine:

```powershell
& 'C:\Users\Acer\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe' -c "import sys, unittest; sys.path.insert(0, 'travel_backend'); sys.path.append('travel_backend/venv/Lib/site-packages'); suite = unittest.defaultTestLoader.discover('travel_backend/tests'); result = unittest.TextTestRunner(verbosity=2).run(suite); sys.exit(not result.wasSuccessful())"
```

Not run: live SDK/provider requests, full configured application startup, Flutter checks. The project venv remains broken (KI-07). An initial bundled-runtime dependency probe lacked FastAPI; existing project packages supplied it for the passing tests. These isolated tests do not establish production SDK compatibility.

## Provider diagnostics execution — 2026-10-08

Passed: py_compile for diagnostics.py and auto_provider.py; 10 isolated unittest cases including input redaction, status classification, and validation-stage logging; git diff --check; flutter build web --no-pub.

Live runner: travel_backend/tools/diagnose_providers.py, launched from travel_backend with the installed Python 3.11 executable and existing venv packages. Normal application settings were used only for authorized execution; no credential files or keys were inspected or printed. Full app started under TestClient: /health 200 and mock /lemon/chat 200. Synthetic provider service calls used Osaka and 2026-10-15.

Run 1: Groq passed in 2.48s, Gemini 404 in 0.61s, auto/Groq passed in 1.50s. Run 2: Groq passed in 1.69s, Gemini 404 in 0.55s; auto chain Groq 429 → Gemini 404 → OpenRouter success in 34.72s. Live calls consume quota; the runner is opt-in and has a 50-second diagnostic-only deadline. No production timeout changes. No original Groq ValidationError reproduced.

Failed: flutter test --no-pub (existing smoke test, five exceptions including RenderFlex overflows). Initial sandbox Flutter build failed SDK ownership checks; escalated build passed without changing Git trust settings. Project venv launcher failed; bundled-runtime live SDK probe failed jiter import; installed Python 3.11 succeeded outside sandbox.

Not performed: interactive browser UI verification or live itinerary generation. No dependencies installed.

Gemini follow-up: read-only metadata lookup for the configured model succeeded and advertised generateContent support. Model listing returned HTTP 501. A minimal hello generation request, without Lemon prompts or JSON configuration, still returned HTTP 404. This reproduces the failure independently of Lemon response validation, but does not establish the upstream cause or prove the model is retired. Added tools/diagnose_gemini_models.py; initial cleanup call was incompatible with installed SDK, then corrected to conditional cleanup and rerun successfully. No model/configuration changes made.

## Auto chat deadline verification — 2026-10-08

Passed: 17 offline unittest cases (10 prior plus 7 deadline/cleanup cases), Python compilation, and git diff --check. New coverage: timed-out provider cancellation/close followed by success; remaining-budget truncation with later provider skipped; local chat response after timeout and exact 9/30 configuration; caller cancellation propagation without fallback/cooldown; cancellation-resistant task does not hold up response; cleanup failure preserves success; stalled cleanup is bounded. Timing tests use shortened budgets and scheduling tolerance, without network or credentials.

An intermediate total-budget test exposed an early timer wake at platform timer resolution; consuming the final allocated timeout now exhausts the budget explicitly. Final suite passes. Live SDK deadline behavior, interactive frontend checks, and frontend builds were not rerun for this backend-only change. Existing Flutter layout failures are unrelated.

## Hotel details repair — 2026-10-08

Passed: `flutter test --no-pub test/hotels_view_test.dart` (three offline tests): successful listing presentation, missing address, absence of invented deal/rating UI, empty results, HTTP/malformed/transport/timeout failures, and retry recovery. Initial card overflow was corrected by removing fixed card height; rerun passed. Flutter required execution outside the sandbox due to SDK ownership checks. No dependency installation.

Not run: live hotel API and full app smoke test (existing KI-16). Backend contract unchanged.

Also passed: focused Flutter analysis of the three changed source files and hotel test file (no issues); git diff --check (line-ending warnings only).

## Environment template — 2026-10-08

Passed: static comparison of all 14 `.env.example` assignments with `config.py` declarations/defaults, duplicate detection, and blank checks for all six API keys. Git confirms `.env` is ignored and `.env.example` is visible as an untracked file. README whitespace checks passed. Checks read source and the public template only; configuration was not imported and the private `.env` was not opened or modified.

Not run: fresh environment setup, application startup, or live provider requests. No runtime code/dependency changes.
## Remaining review fixes — 2026-10-08

Passed: 20 offline backend unittest cases with the bundled Python runtime and existing packages (`-B`, without credential/configuration imports); 11 focused Flutter tests across travel_results_test.dart, flights_view_test.dart, and hotels_view_test.dart; focused Flutter analysis of travel service/models, flight/attraction views, and the new test file (no issues).

New backend checks verify numeric attraction radius and context in the prompt, bounded slow-context/provider fallback, and plan budget configuration. Frontend checks verify empty responses, HTTP/JSON/transport failures, URL encoding, and error-to-retry recovery for flights and attractions. Existing hotel and flight-date regressions still pass.

Flutter's initial sandbox test failed SDK ownership checks; the same focused command passed with approved execution outside the sandbox. No Git trust settings, dependencies, credentials, or provider models were changed. No live requests, full-app smoke test, or production build were run in this repair; the previously recorded full-app layout issue remains outside scope.
