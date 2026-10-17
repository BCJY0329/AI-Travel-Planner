# Architecture decisions

## Record policy

Entries dated 2026-10-08 describe choices observed in source, not historical approval dates or newly authorized architecture changes. Append numbered entries when future approved work makes a substantive choice; distinguish proposals from accepted decisions.

## 001 — FastAPI backend and Flutter client

Status: observed implementation. The backend exposes JSON routes; Flutter services translate them into Dart models. Consequence: API contracts must remain aligned across two codebases. Evidence: `travel_backend/main.py` and `travel_planner_frontend/lib/services/`.

## 002 — Stateless chat requests

Status: observed implementation. The client sends complete conversation history each turn, and the backend extracts trip fields without session storage. Consequence: client reset loses context, and transcript payloads grow with the conversation. Evidence: `models/chat.py` and `services/chat_parser.py` in the backend, and `lib/chat/lemon_chat_controller.dart` in the frontend.

## 003 — Provider abstraction with explicit mock behavior

Status: observed implementation. A provider interface returns JSON text, and a factory selects Groq, Gemini, OpenRouter, or mock. Explicit mock chat uses a separate heuristic parser. Consequence: mock itinerary output is not a chat response. This initial snapshot was superseded by decision 007, which completed auto integration. Evidence: `travel_backend/services/llm_providers/`.

## 004 — Best-effort itinerary context

Status: observed implementation. Itinerary generation tolerates missing weather/attraction context and proceeds with general suggestions. Consequence: output can lack current external grounding; a successful itinerary response does not prove data lookups succeeded. Evidence: `travel_backend/services/itinerary_builder.py`. The original KI-08 direct-call issue was resolved by decision 012.

## 005 — View-only travel data with client demo fallbacks

Status: historical, superseded by 010 and 011. Flight/hotel/attraction screens use data APIs and substitute canned lists after failures or empty results. Hotel display models also synthesize attributes. Consequence: demo data needs explicit labeling; this record does not endorse treating it as live data. Evidence: `travel_planner_frontend/lib/services/travel_api_service.dart` and `lib/models/travel_models.dart` relative to the frontend.

## 006 — Documentation reflects the working tree

Status: applied documentation approach authorized for this task. Missing handover documents were reconstructed from current code, including existing uncommitted edits, rather than invented historical material. Source observations, proposed tasks, and runtime verification are kept distinct. The root README backup uses `README.old.md.bak`, already covered by `*.bak`, to avoid changing configuration or committing the backup.

## 007 — Validated auto fallback (2026-10-08)

Status: implemented for the authorized auto repair. Keep Groq → Gemini → OpenRouter priority. Guard construction, generation, and caller-supplied schema validation in each attempt. Use monotonic five-minute process-local cooldowns, including when every real provider is cooling down. Use the existing heuristic parser for chat exhaustion and labeled demo itinerary JSON for plan exhaustion. Preserve response contracts; plans expose provider_used while chat provenance remains a limitation. Log exception types rather than SDK exception text. Eight isolated offline tests pass; no live provider validation was performed.

## 008 — Safe provider diagnostics (2026-10-08)

Status: implemented under diagnostic-only authorization. Record attempt stage, elapsed time, exception type, numeric HTTP status, fixed status category, and allowlisted validation locations/types. Exclude raw exception text, validation inputs/context, and generated responses. Keep provider order, cooldowns, timeouts, models, and API response contracts unchanged. Add an opt-in synthetic live runner separate from offline tests. The diagnostic deadline does not change application behavior.

## 009 — Auto chat time budgets (2026-10-08)

Status: implemented under explicit authorization. Chat passes a 9-second attempt limit and 30-second real-provider budget to AutoProvider. Cancel overdue tasks without waiting indefinitely for SDK cancellation acknowledgement; retain and observe outstanding tasks to retrieve late exceptions. Close provider clients through supported public async methods, with a 250ms cleanup wait cap. Caller cancellation propagates without starting fallback or adding a cooldown. Timeouts use the existing five-minute cooldown. A cancellation-resistant SDK may continue briefly in the background, and upstream processing cannot be guaranteed to stop. Async deadlines require a responsive event loop; blocking synchronous work, local fallback processing, and network delivery are outside a hard end-to-end guarantee. Plan timing was subsequently updated in 012; direct chat timing remains unchanged.

## 010 — Hotel listings without invented offers (2026-10-08)

Status: implemented for the hotel-details repair. Supersedes the hotel portion of 005. Match the existing backend name/address/coordinates contract; remove unsupported commercial attributes and fictional fallback hotels. Empty responses remain empty, errors show retry, and cards identify the listing source and unavailable details. Remove the nonfunctional View Deal action. Live pricing integration remains a separate product decision; no backend contract or dependency changes.

## 011 — Travel listings without fictional fallbacks (2026-10-08)

Status: implemented under the user's repair request. Supersedes the remaining flight/attraction portion of 005. Preserve successful empty responses, propagate errors to Retry UI, and discard stale overlapping search completions. Remove the Live label because the data source may be sandbox-backed, and remove invented attraction descriptions. Inject HTTP clients for offline coverage; no response schemas or dependencies changed.

## 012 — Bound itinerary context and generation (2026-10-08)

Status: implemented under the user's repair request. Fetch context concurrently with ten-second limits and an explicit 5 km radius. Reuse the existing cancellation-aware bounded-wait helper. Auto generation allows 12 seconds per candidate and 36 seconds total; direct generation waits at most 36 seconds. This reserves headroom under the 60-second frontend timeout while retaining optional context and validated auto demo fallback. Async deadlines do not guarantee SDK cancellation or protect against synchronous event-loop blocking.

## 013 — LemonTrip guided intake and responsive UI (2026-10-16)

Status: implemented under explicit user authorization. LemonTrip is the product name; Lemon.ai remains the assistant with the tagline “Your personal travel companion.” Use a bounded desktop layout, compact navigation on small windows, and a contained assistant launcher. Load search tabs on first visit.

Use AI chat to interpret destination, then collect dates, travelers, budget and interests through deterministic controls. Other preferences remain optional bounded text. Always show an editable review and require explicit Generate confirmation; send the selected fields directly through the existing TripRequest contract. This intentionally trades unrestricted post-destination chat for predictable intake. Preserve local session state on failures and retry only the failed stage. No persistence, model changes, paid photo provider, or new dependencies were introduced. Location links use existing coordinates and do not claim verified entrances.

## 014 - Brighter surfaces and visual day cards (2026-10-16)

Implemented following explicit user feedback. Supersedes decision 013's initial visual treatment, not its guided intake. Use light lemon/mint/sky/peach surfaces with readable ink, a 1720px desktop cap, and two columns of complete day cards when space and text scale permit. Keep chronological order within each day. Expose optional notes through expandable tips; full-copy content remains complete. Frame the existing mascot face at its original aspect ratio rather than generating replacement artwork. No new dependencies or data contracts.
## 015 - Anchored dates and complete itinerary windows (2026-10-16)

Implemented following the user's explicit six-point request. Replace the full-screen range reset behavior with a compact staged calendar whose start remains anchored; an explicit Change start action unlocks it. Collect travelers through validated numeric entry. Use cool mint/sky/lavender surfaces on Discover, a shared proportional portrait and short entrance motion that honors reduced-motion preferences. This supersedes yellow dashboard treatment from decision 014.

Generate at most three days per provider response and at most three windows concurrently, with a shared 36-second budget rather than extending frontend timeouts. Validate exact requested dates, absolute day numbers and nonempty activities before ordered assembly. Permit one bounded corrective retry for direct-provider invalid output; use existing validation-aware fallback for auto. Mark the entire response mock if any section is demo. This trades extra provider calls and possible cross-window repetition for bounded output size and complete coverage; no provider settings, dependencies or response fields changed.

## 016 - Chat interaction feedback and longer plan budgets (2026-10-17)

Implemented at explicit user request. Desktop chat supports expansion, Enter sends and Shift+Enter provides multiline input. Use small hover/press scaling on requested interactive surfaces, with reduced-motion bypass. Tips retain source content inside a more expressive Lemon presentation.

Supersedes decision 015's timing values: auto plan attempts are 25 seconds, the shared generation budget is 75 seconds, and frontend plan timeout is 100 seconds. The ten-second context phase, date coverage validation, concurrency limit, fallback disclosures and chat budgets remain unchanged. Longer waits trade latency for a better opportunity for slow providers to finish; HTTP 503 failures are separate from timeout behavior.

## 017 - Conservative conversational recovery (2026-10-17)

Use three rotating local greetings, friendly current-step reminders, and nonblocking rejection of obvious malformed input. Keep accepted trip fields unchanged. Remove a rejected destination turn from model history before another extraction attempt. Apply conservative noise checks in mock destination replay as well; do not use an English place-name allowlist. Hide visual composer helper/counter without removing keyboard submission or size bounds. Keep the original portrait asset, enlarge small chat instances and use downsampling suited to small render sizes; final visual acceptance belongs to local review.

## 018 - Finite expressive motion and contextual invitations (2026-10-17)

At the user's request, use flutter_animate for finite entrance effects and built-in implicit widgets for interaction-driven resizing/scaling. Define motion durations (200-400ms) and curve centrally in AppTheme, bypass motion for disableAnimations, and avoid looping attention effects or auto-opening chat. No application-owned AnimationControllers are introduced.

Use a focusable/clickable launcher with rotating invitations and proportional original artwork; hover is optional and touch remains one-tap access. Vary tip introductions without mutating provider advice. Draw the citrus-route logo in Flutter for resolution-independent branding. Only flutter_animate is added from the suggested package list; Web/Android support verified at https://pub.dev/packages/flutter_animate before installation.


## 019 - Range calendar, bounded chat resize and presentation labels (2026-10-17)

Use a custom accessible month grid to show both trip endpoints and the days between them; preserve anchored-start correction and the existing 30-day limit. Keep `low`/`medium`/`high` in the API contract and map them to Budget-friendly/Comfortable/Premium only for user-facing chat. Render Surprise me as a visible button. On desktop, resize the chat from its upper-left grip within viewport constraints and fixed 360-900px width / 360-850px height bounds; compact devices keep full-screen chat. Use platform-default font families with a larger, spaced text theme. Preserve the original mascot artwork and enlarge its face crop on hover; request occasional, relevant emojis in generated notes, not every note. No API schema or dependency change.
