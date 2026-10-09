# Known issues

## Verification basis

Source-inspected on 2026-10-08 against the current working tree. The initial review made no application fixes; subsequent auto repairs are recorded below. Findings below are source-derived unless explicitly marked as a command observation; runtime reproduction remains pending.

## UI/UX review and lessons — 2026-10-09

Evidence: source inspection of the five frontend views, theme/navigation, assistant components, frontend models/services, relevant backend contracts, and the user-supplied desktop itinerary screenshot. No app launch, tests, or application changes were performed for this review. These findings are source-derived unless labeled as screenshot observations. Proposed work is tracked in [TASKS.md](TASKS.md); documentation authorization does not authorize implementing the proposals.

Frontend paths below are relative to `travel_planner_frontend/lib/`.

| ID | Finding and evidence | Impact / proposed resolution |
|---|---|---|
| KI-17 | `screens/home_screen.dart` hides the navigation tabs below 800px without replacement navigation. | Add access to all five views at compact widths. Related overflow work remains KI-16; this review did not reproduce those tests. |
| KI-18 | `widgets/lemon_chat_panel.dart` keeps Send/Enter active and clears the composer in `_send()`; `chat/lemon_chat_controller.dart` ignores submissions while busy. | A busy-time submission can discard the draft. Guard both button and keyboard submission and retain unsent text. |
| KI-19 | Attraction bookmarks in `screens/views/attractions_view.dart` only show a Saved notification. Flight View Deal in `screens/views/flights_view.dart` only shows a selected-flight notification. | Implement meaningful behavior within agreed scope or change the labels/affordances. Neither notification establishes persistence or booking capability. |
| KI-20 | `screens/views/itinerary_view.dart` copies summary/destination only but reports that the itinerary was copied. | Match the notification to the content, or explicitly implement full-itinerary copying. |
| KI-21 | `screens/home_screen.dart` passes the itinerary only to Discover and Itinerary. Hotels/Attractions independently default to Paris; Flights defaults to KUL–NRT. | Search tabs do not follow the planned trip. Consider shared destination/date/traveler context with explicit overrides and a deliberate airport-mapping solution. |
| KI-22 | Itinerary labels every result AI GENERATED and navigation marks any itinerary READY, including mock results. `travel_backend/services/llm_providers/mock_provider.py` returns one canned day with two activities regardless of requested dates; the screenshot matches this content. | Distinguish Demo itinerary from personalized completion. Sparse mock content is partly a data limitation. Correct the current 1 Days Trip label as well. |
| KI-23 | Discover promotes curated hotel amenities, live flight offers, and real weather in seconds. Hotel contracts supply name/location only, flight provenance is not exposed in the UI, and itinerary context is best-effort. | Align copy with supported capabilities; do not claim verified live results or guaranteed speed without evidence. |
| KI-24 | Flight cards prefix prices with `$` regardless of `FlightOffer.currency`. The wide card says per traveler, while the backend forwards the offer's `total_amount` without dividing by passenger count. | Display the returned currency and distinguish party total from per-person prices. Verify multi-passenger semantics; no live pricing check was performed. |

### Existing findings reconfirmed

- KI-11 remains open: `_handleSnagAndReloop()` clears extracted fields and backend conversation history after failures while rendered messages remain. Preserve recoverable context and offer retry. Provider timeout improvements did not fix this behavior.
- KI-16 already records runtime-observed smoke-test overflows from the earlier session. This review additionally identified rigid heading rows and card dimensions as responsive-layout risks, without new runtime verification.

### Design observations and reusable lessons

- Screenshot observation: the full-width banner and activity cards stretch sparse content across a wide monitor, leaving substantial unused space. Consider bounded content width, a compact trip header, readable typography, and a secondary trip-details column. A map needs suitable location data and additional implementation.
- The lavender palette is already consistent. Improve hierarchy, spacing, and behavior through shared design rules before adding more gradients, borders, and nested cards. The palette and Lemon character can be retained; no final visual direction has been chosen.
- Keep trip details visible and editable. Quick choices and a direct View itinerary action can improve the assistant journey; rendering the entire itinerary in the small chat panel duplicates the main view.
- Success messages must correspond to actual operations. Save, copy, select, and export labels should never imply state changes that did not occur.
- Review loading, empty, error, demo, and completed states separately. Preserve the existing travel-list empty/retry behavior and improve assistant recovery. Loading feedback should not invent progress percentages.
- Responsive verification must include navigation access, keyboard-open chat, long titles, text scaling, and intermediate widths. Small secondary text, pale colors, icon controls, and the image-based assistant launcher warrant contrast, focus, accessible-name, and touch-target checks; no accessibility conformance is claimed.
- Featured destinations currently render as static containers. Actionable destinations and authentic imagery could improve Discover. Do not invent amenities, ratings, descriptions, or route data to make result cards appear richer.
- Suggested implementation sequence: navigation/input reliability, shared trip context, layout/typography, itinerary/assistant usability, then richer discovery features. This is a proposal, not an adopted architectural decision.

## Current issues

| ID | Finding and evidence | Impact / proposed resolution |
|---|---|---|
| KI-01 | Resolved 2026-10-08: factory registers `auto`; chat/plan validate each candidate and use appropriate local fallbacks. | Eight isolated offline tests pass, including both HTTP routes. Live SDK calls unverified. |
| KI-02 | Resolved 2026-10-08: construction is inside the guarded attempt. | Constructor, call, JSON/schema failure and cooldown regressions pass offline. |
| KI-03 | Resolved 2026-10-08: flight departure defaults to 14 calendar days after local today. Searches and picker initial dates are clamped to today through 365 calendar days ahead. | Four offline widget tests pass for initial requests, picker bounds, year/leap-day rollover, stale selections, and backward clock changes. Live flight API not tested. |
| KI-04 | Resolved 2026-10-08: hotel models/cards use only name and location; fabricated prices, ratings, amenities and View Deal removed. | Three offline service/widget tests pass. Live hotel API not tested. |
| KI-05 | Resolved 2026-10-08: no fictional flight, hotel, or attraction lists are substituted. | Empty results stay empty; failures show Retry. This does not certify upstream flight data as live. |
| KI-06 | Resolved 2026-10-08: secret-free `travel_backend/.env.example` added with all declared settings. | Static key/default parity verified; fresh environment setup remains unverified (KI-07). |
| KI-07 | Python absent from PATH; existing backend venv version command reports its base interpreter missing. | Runtime verification/setup blocked on this machine. Repair environment before backend execution. Command observation. |
| KI-08 | Resolved 2026-10-08: builder passes radius_km=5 explicitly. | Offline regression checks the numeric argument and context reaching the prompt. |
| KI-09 | Date/budget/role fields in `travel_backend/models/` are strings, not validated dates/enums. | Invalid ranges and semantic values may pass request validation. Add focused validation tests and constraints. |
| KI-10 | Weather, places, hotels, and flights do not uniformly catch transport failures after geocoding. | Timeouts or malformed provider payloads can produce raw server failures. Standardize error handling. |
| KI-11 | Lemon controller resets fields and transcript on errors; plan generation can expose backend exception detail through the API. | Recovery loses planning context; audit error presentation and preserve recoverable state. |
| KI-12 | `travel_backend/main.py` permits all CORS origins with credentials; no route authentication. | Development configuration requires review before deployment. |
| KI-13 | Resolved 2026-10-08: model/router provider lists and factory error-status comment updated. | Source descriptions now include auto and match the registered providers. |

## Limitations

- No persistent trip/chat storage was found in the inspected app flow.
- Mock itinerary output is one canned day; requested duration/dates do not drive it.
- Mock itinerary calls still attempt external context; mock chat uses local parsing.
- Auto now validates candidates and falls back to local chat parsing or demo itinerary JSON. Chat still has no provider provenance field; plans report provider_used. Cooldowns are process-local and shared across chat/plan.
- Mock confirmation uses substring matching across user messages; ambiguous confirmations and corrections need dedicated tests.
- Short-range forecasts do not provide weather for arbitrary trip dates.
- Backend coverage now includes 20 offline regressions; focused frontend tests cover flights, hotels, and travel failure/retry behavior. Full app smoke-test layout issues remain KI-16.

## Already present in source

- Chat has a next_field response signal and the frontend uses it for date prompts.
- Mock parser has budget and interest steps, plus no-preference handling.
- Explicit budget level names are checked before generic budget synonyms.
- Geocoding prefers an exact city-name match among up to five candidates and catches request errors.

These observations avoid reopening already implemented work; they are not claims of passing runtime tests. External provider pricing, model availability, and historical service retirement statements remain unverified.

## Live diagnostic findings — 2026-10-08

- KI-14: Gemini returned ClientError HTTP 404 in both synthetic runs, configured model gemini-2.5-flash. Sanitized classification is not_found; exact missing resource/model cause remains unresolved. Active credentials and historical quota charts do not explain this response.
- KI-15: Groq succeeded on synthetic Osaka/date intake, but a later auto request returned HTTP 429 after 16.58 seconds. Gemini then failed 404 in 0.55 seconds; OpenRouter succeeded in 17.59 seconds. Total 34.72 seconds, near the 45-second client timeout. Original ValidationError did not recur. No timeout changes made.
- KI-16: Existing Flutter widget smoke test fails with RenderFlex layout overflows, including discover_view.dart:216 (25 pixels right). Five exceptions reported. No frontend source edits made in this diagnostic task.
- Environment clarification: venv launcher still fails in the agent environment. The Python 3.11 executable used by the existing server works outside the sandbox with existing venv packages. Bundled Python cannot load the existing jiter binary; it remains suitable for stubbed offline tests.

Gemini follow-up: read-only metadata lookup for the configured model succeeded and advertised generateContent support. Model listing returned HTTP 501. A minimal hello generation request, without Lemon prompts or JSON configuration, still returned HTTP 404. This reproduces the failure independently of Lemon response validation, but does not establish the upstream cause or prove the model is retired. Added tools/diagnose_gemini_models.py; initial cleanup call was incompatible with installed SDK, then corrected to conditional cleanup and rerun successfully. No model/configuration changes made.

## Auto chat deadline update — 2026-10-08

KI-15 timing mitigation implemented: auto chat has 9-second per-attempt and 30-second overall real-provider budgets, cancellation and bounded client cleanup. Local chat fallback remains available when the budget expires. Seventeen offline regressions pass. No live API calls performed for this change. This does not fix provider quota/availability, frontend chat reset behavior, or provider availability. Itinerary timing was subsequently bounded; see API.md. Synchronous event-loop blocking and network delivery can still delay responses. Older Gemini SDKs without a public async close method skip explicit close; cancelled SDK tasks may take time to stop.
