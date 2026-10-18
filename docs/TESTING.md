# Testing and verification

## Current status — 2026-10-17

Latest recorded results (details in the dated entries below; entries are chronological and later ones supersede earlier ones):

- Frontend: latest run 2026-10-18 (trip-page typography): analyzer clean, 41 passed, 4 failed (four known stale tests). Earlier: 36 passed (Expressive UI checks, 2026-10-17). The four failures predate this change; three expect a removed launcher invitation or "Enlarge chat" tooltip; the calendar failure (`Bad state: No element`) was not investigated.
- Backend: latest run 2026-10-18: 32 run, 31 passed, 1 failed (known `test_chat_exhaustion_matches_explicit_mock`). Live prompt tone not verified.
- Not verified: live provider generation and tone, live travel APIs, interactive browser/Android visual acceptance, production web build of current source.

How to run:

- Frontend, from `travel_planner_frontend/`: `flutter analyze --no-pub`, `flutter test --no-pub`, a single file with `flutter test --no-pub test/<file>.dart`, or a single test with `--plain-name "<name>"`. In the agent sandbox Flutter can fail SDK ownership checks; the same command has passed outside the sandbox without changing Git trust settings.
- Backend: the project venv is broken (KI-07). Use the bundled-runtime command under "Auto repair verification" below; with a working interpreter, run `python -m unittest discover -s tests -v` from `travel_backend/`.

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
4. Test frontend-selected `auto` through the factory and both Lemon routes (done offline on 2026-10-08; unknown provider names return 502).
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

Original 2026-10-08 note: these commands were not run for that Markdown-only task. Since then the suite has grown to multiple widget-test files (see Current status). `test/widget_test.dart` is now a smoke test asserting that LemonTrip appears. Travel views initiate data loading; tests inject fake services rather than assume widget tests establish live backend correctness.

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

## LemonTrip first UI/UX batch — 2026-10-16

Passed: all 22 Flutter tests, including the formerly failing app smoke test. New tests exercise explicit confirmation, structured preference preservation, chat and generation retries without duplicate turns, invalid field guards, busy submission/draft preservation across panel recreation, interests with Other, itinerary day-filter reset, and dashboard/assistant layouts at 360, 800, and 1440px. Test services are fake; no live APIs were called.

Passed: all 23 isolated backend tests using the existing bundled runtime and existing site-packages, with provider/context stubs. Three new validation tests cover selected preferences, invalid dates/ranges/budget/destination/interests, and same-day/30-day boundaries. No private configuration or credentials were loaded.

Passed: Flutter web production build (`flutter build web --no-pub`), including its Wasm dry run. `git diff --check` passed with line-ending warnings only. The new test fixture initially had an async conditional return type error; it was corrected and the final full suite passed. Analyzer style warnings were corrected with brace-only fixes.

Not performed: interactive browser visual review, live AI generation, photo-provider integration, Android/macOS release builds, exhaustive accessibility checks, or deployment. Source edits after the production build started were limited to assistant editing/recovery details and brace fixes; final source is covered by the full Flutter test rerun. Rebuild before deploying. No dependencies were installed; pre-existing pubspec.lock edits were preserved.

Final frontend analyzer: flutter analyze --no-pub passed with no issues after all source edits.

## Brighter UI refinement - 2026-10-16

Final flutter test --no-pub: all 24 tests pass. Added phone/desktop itinerary card placement and tip expansion checks. Final flutter analyze --no-pub: no issues found. An intermediate tip-background assertion was fixed by removing the opaque decoration over Material; rerun passed. Source formatting passed after correcting an intermediate text encoding issue. No new production web build or interactive browser visual review performed for this refinement. Backend unchanged in this batch.

## Desktop browser visual review - 2026-10-16

Started current source with flutter run -d web-server --web-hostname 127.0.0.1 --web-port 5187 --no-pub. Inspected actual browser rendering at 1440x1000 and 1920x1080. Completed destination, dates, traveler, budget, interests, explicit generation and View itinerary for a three-day Bali sample; expanded an activity tip. Confirmed proportionate mascot portrait and side-by-side day cards, but found inconsistent activity widths and remaining density/crop issues documented in KNOWN_ISSUES.md. No application source changes in this review. Preview left running for the user; no new test/build claims.
## Six-point refinement verification - 2026-10-16

Passed: flutter test --no-pub (28 tests), flutter analyze --no-pub (no issues), isolated backend unittest suite (27 tests) with bundled Python and pre-existing packages. No secrets/config imported by the offline test harness. New regressions cover numeric traveler entry, anchored calendar edits, mixed-note card widths, reduced motion, 30-day demo coverage, ordered 11-day assembly with concurrent/out-of-order completion, and rejection of partial/missing-date/empty-activity results. Intermediate syntax and outdated-fixture failures were corrected before final successful runs.

No production web build or live long-trip provider validation for this batch. A new frontend dev server compiled successfully, but was stopped when the user asked to test locally; no claim of final visual acceptance. The user should restart frontend and backend and inspect the portrait/calendar/dashboard locally.

## Interaction polish checks - 2026-10-17

Passed: full frontend suite (31 tests), backend offline suite (27 tests), focused physical Enter check after adding an input-composition guard. New tests cover physical Enter, Shift+Enter not sending, busy draft retention, enlarge/shrink with draft preservation, hover scale and reduced-motion bypass. Backend tests assert updated attempt/deadline values while retaining bounded fallback coverage. A formatting-only lint was corrected afterward. No browser or live-provider test was run for this batch, per user preference; no production web build.
Final flutter analyze --no-pub: no issues found. git diff --check passed.

## Greeting and portrait checkpoint - 2026-10-17

Full flutter test --no-pub passed all 32 tests; dart format passed. New coverage checks three distinct local greetings, no provider calls for greetings/obvious noise, and retained destination/date step after invalid input. Final analysis, backend tests for prompt changes, and visual avatar confirmation were not run before the user's requested pause. Previous batch's clean analysis/backend results must not be treated as verification of these latest edits.

## Resumed recovery verification - 2026-10-17

Backend offline suite: 28 passed, including invalid mock destination recovery to a Unicode place name. Frontend suite at the prior checkpoint: 32 passed; subsequent frontend change was brace-only lint correction. git diff --check passed before documentation update. No live-provider, image-quality or browser verification this session.
Final flutter analyze --no-pub: no issues found after brace correction.

## Expressive UI checks - 2026-10-17

`flutter analyze --no-pub`: no issues. `flutter test --no-pub`: 36 tests passed. New coverage exercises launcher invitation rotation, no accidental opening on hover, keyboard activation, reduced-motion bypass, direct touch activation and desktop layout. Existing layout tests cover 360/800/1440 widths. `git diff --check`: passed. No browser or live-provider session was run; user will review locally. Backend unchanged in this batch.

## Sky Mint redesign - 2026-10-18

Baseline before edits: `flutter test --no-pub` 32 passed, 4 failed (the four known stale tests). After edits: `flutter analyze --no-pub` no issues; `flutter test --no-pub` 32 passed, 4 failed (same four). One new 360px overflow in the hero checklist was found by the suite and fixed before the final run. `git diff --check`: line-ending warnings only. Bundled photos load in widget tests. Not run: browser/Android visual review, `flutter build web`, live providers. Contrast ratios are computed, not measured in-app.

## Flight timeout fix - 2026-10-18

Backend (bundled interpreter + venv site-packages, offline): new `tests/test_flights.py` 4 passed (timeout → 504, connect error → 502, Duffel 422 passed through, incomplete offer skipped and read timeout > 15 s). Existing suites: 28 run, 27 passed, 1 failed (`test_chat_exhaustion_matches_explicit_mock`), and it fails the same way without the new file. Frontend: `flutter analyze --no-pub` no issues; `flights_view_test.dart` + `travel_results_test.dart` 8 passed. Not run: a live Duffel search.

## Launcher, hero spacing and endless idle motion - 2026-10-18

Collapsed launcher now shares the expanded card's white surface and mint border; hero greeting bubble inset 32 px from the top with a 32 px gap from the headline; Lemon's float, pulse and hero zoom loop endlessly in the app (tests limit them via `test/flutter_test_config.dart`). `flutter analyze --no-pub` no issues; `flutter test --no-pub` 32 passed, 4 failed (same four known stale tests). Not reviewed visually.

## Roboto headings on search/itinerary views - 2026-10-18

`flutter analyze --no-pub` no issues; `flutter test --no-pub` 32 passed, 4 failed (same four known stale tests). Not reviewed visually.

## Redesigned search and itinerary pages - 2026-10-18

`flutter analyze --no-pub` no issues. `flutter test --no-pub` 41 passed, 4 failed (the same four known stale tests). New `test/page_redesign_test.dart` (9 tests): Flights banner, tip, route banner, single "Lowest price" tag and "Plan with Lemon" at 360/800/1440 px; Hotels and Attractions results and the category filter at those widths; four itinerary days get four different header colours and the tip label is at least 15 px; `LemonCircle` uses the given background; photos only match the right places. Existing tests changed only for the taller pages: `hotels_view_test.dart` scrolls to Retry, the 360 px itinerary test scrolls to the tip, and the tip-width test waits for entrance animations. A 360 px overflow in Lemon's tip bubble was found by the suite and fixed. Not run: visual review in a browser, live providers.

## Trip-page typography - 2026-10-18

`flutter analyze --no-pub` no issues; `flutter test --no-pub` 41 passed, 4 failed (the same four known stale tests: two launcher-invitation tests in `lemon_personality_ui_test.dart`, "Desktop chat expands without losing its draft" and the calendar end-edit test in `lemon_redesign_test.dart`). Two tests broke because larger Caveat tips made the pages taller, and were fixed to scroll to their tap target first: the flights retry test in `travel_results_test.dart` and the category chip tap in `page_redesign_test.dart` at 360 px. Widget tests render with the test font, so the real Unbounded/Outfit/Caveat glyph widths are not exercised. Not run: visual review in a browser.

## Nav bar, bubble tails and quick routes - 2026-10-18

`flutter analyze --no-pub` no issues; `flutter test --no-pub` 41 passed, 4 failed (same four known stale tests). The quick-route clipping was diagnosed from the user's screenshot and the label glyph, not reproduced in a browser; visual review not run.

## Fredoka tips and livelier itinerary voice - 2026-10-18

Frontend: `flutter analyze --no-pub` no issues; `flutter test --no-pub` 41 passed, 4 failed (same four known stale tests). Backend: isolated offline unittest suite (external interpreter, see "How to run") 32 run, 31 passed, 1 failed — `test_chat_exhaustion_matches_explicit_mock` (`budget_level` != `confirm`), already recorded in KNOWN_ISSUES as failing before these changes. The prompt change is not covered by offline tests; live generation tone not run.

## Bubble tails toward Lemon's head - 2026-10-18

`flutter analyze --no-pub` no issues; `flutter test --no-pub` 41 passed, 4 failed (same four known stale tests). Visual placement against the avatar artwork not checked in a browser.

## Discover typography trial and mint nav bar - 2026-10-19

`flutter analyze --no-pub` no issues; `flutter test --no-pub` 41 passed, 4 failed (same four known stale tests), run after the Discover font change; the nav colour change is a constant swap and was not rerun separately. Visual review not run.
