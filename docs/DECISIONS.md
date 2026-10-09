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
