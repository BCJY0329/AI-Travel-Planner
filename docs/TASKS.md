# Tasks

## Scope

Reconstructed on 2026-10-08 from current source. The initial task authorized documentation only. Subsequent repairs were separately authorized; unchecked work remains a proposed backlog. KI identifiers refer to `KNOWN_ISSUES.md`.

## UI/UX review and proposed backlog — 2026-10-09

- [x] Review the five frontend views, theme/navigation, assistant flow, frontend mappings, relevant backend contracts, and user-provided itinerary screenshot.
- [x] Record findings and reusable lessons in [KNOWN_ISSUES.md](KNOWN_ISSUES.md) and publish this agent handoff. Documentation-only update; no application changes or runtime tests for this review.

All unchecked items below are proposals awaiting implementation scope from the user. An overall interest in redesign and permission to document findings do not authorize implementing this entire backlog. Preserve existing uncommitted work. No design direction has been adopted in DECISIONS.md.

### First: reliable navigation and truthful interactions

- [ ] Restore compact navigation for all five views (KI-17) and address existing layout overflows (KI-16); verify phone, tablet, desktop, intermediate widths, text scaling, and long content.
- [ ] Prevent busy-time composer text loss (KI-18), including Enter submission. Preserve trip fields/history and provide retry on assistant failures (KI-11, also tracked under Next).
- [ ] Resolve misleading attraction Save and flight View Deal actions (KI-19) with agreed behavior or accurate labels; do not imply bookings or persistence.
- [ ] Align itinerary copy content and success feedback (KI-20).
- [ ] Distinguish demo itineraries from personalized completion and correct duration plurals (KI-22).
- [ ] Correct Discover capability claims (KI-23) and flight currency/party-total presentation (KI-24).

### Next: connected planning and visual structure

- [ ] Define shared destination, dates, and traveler context across search views, with explicit overrides and an airport-selection strategy (KI-21).
- [ ] Establish reusable content widths, responsive spacing, typography, button sizing, and card styles; select a visual direction before broad implementation.
- [ ] Improve itinerary hierarchy with a concise trip summary, clear day/date headings, readable activities, and no redundant single-day filters. Consider a trip-details column on wide screens.
- [ ] Improve the assistant with editable trip details, quick choices, a direct View itinerary action, truthful loading feedback, and a keyboard-aware compact layout. Consider preserving drafts across panel closure as well as request failures.
- [ ] Audit contrast, focus, accessible labels, touch targets, text scaling, and floating-assistant overlap; verify rather than assume accessibility from theme settings.

### Later: product choices and richer features

- [ ] Make featured destinations actionable and consider authentic destination imagery and Continue trip emphasis on Discover.
- [ ] Consider airport-name search, flight sorting, clearer date/time presentation, and useful hotel/attraction location actions using supplied or explicitly derived data.
- [ ] Define itinerary editing/reordering, saving, export, and wish-list behavior before implementation; coordinate with the existing persistence/retention backlog.
- [ ] Decide whether maps and richer activity details are in scope. Current itinerary activities contain place-name text but no coordinates, costs, or durations; these additions may require data/contract changes.

Future implementation should use focused behavior tests for affected issues and visual checks for loading, empty, error, demo, and completed states. This review supplies no new runtime-test evidence.

## Now

- [ ] Repair the local Python environment for runtime validation (KI-07). Preserve existing environments and credentials; choose setup changes with the user.
- [x] Fix frontend/backend `auto` compatibility and add isolated factory/chat/plan checks (KI-01). Cover constructor failures (KI-02), exhausted real providers, and chat-appropriate mock behavior before treating fallback as reliable.
- [x] Replace the fixed flight date and test picker bounds across dates (KI-03). Completed 2026-10-08: default to 14 calendar days ahead; clamp dates before searches and picker opening. Four isolated widget tests pass.
- [x] Remove simulated hotel attributes and fictional hotel fallbacks (KI-04, hotel portion of KI-05). Completed 2026-10-08; three focused offline tests pass.
- [x] Remove fictional flight/attraction fallbacks; distinguish empty results and retryable failures (KI-05, 2026-10-08).
- [x] Pass a numeric attraction radius and test that context reaches the itinerary prompt (KI-08, 2026-10-08).

Auto compatibility repaired on 2026-10-08. The latest offline suite passes using the bundled runtime and existing packages; the project environment remains unrepaired. Historical live diagnostics are recorded in TESTING.md.

## Next

- [x] Add a secret-free environment template matching config.py, with provider extension instructions (KI-06, 2026-10-08).
- [ ] Verify fresh backend setup on a working environment (KI-07); template addition does not repair Python.
- [ ] Validate dates, ordering, budget, roles, and appropriate payload sizes (KI-09).
- [ ] Standardize transport/error behavior and preserve recoverable chat state (KI-10, KI-11).
- [ ] Expand automated coverage beyond the existing app-title smoke test.
- [x] Correct stale provider/schema descriptions in Python source when code edits are authorized (KI-13).

## Later / product decisions required

- [ ] Decide persistence, saved-trip behavior, and retention requirements.
- [ ] Define deployment target, authentication, CORS policy, and usage controls (KI-12).
- [ ] Decide whether live hotel pricing is in scope and select an integration if needed.
- [ ] Review caching and external service reliability with measured usage.
- [ ] Decide supported locales, accessibility targets, and success metrics.

## Done / present in source

- [x] Travel data routes and Lemon plan/chat route implementations exist.
- [x] Flutter travel views, Lemon controller, and itinerary notification are implemented.
- [x] next_field supports date UI; mock intake includes budget and interests.
- [x] Groq, Gemini, OpenRouter, and mock are registered in the provider factory.
- [x] Root guidance and seven documentation files were created from source; README updated and handover copied.

Implementation presence is not proof of successful runtime behavior. See `TESTING.md` for actual verification and limitations.

## Provider diagnostics — 2026-10-08

- [x] Add safe stage/status/validation diagnostics and regression coverage.
- [x] Compile backend changes, run 10 offline tests, build Flutter web, and run live synthetic chat diagnostics.
- [ ] Diagnose Gemini HTTP 404 for configured gemini-2.5-flash; do not change models without approval.
- [ ] Investigate original Groq ValidationError if it recurs; not reproduced in two live runs. Groq later returned HTTP 429.
- [x] Bound auto chat fallback latency with 9-second provider attempts and a 30-second total real-provider budget; 17 offline tests pass. Plan generation now has separate 10-second concurrent context and 36-second provider budgets.
- [ ] Investigate Flutter smoke-test layout overflows (KI-16).

- [x] Bound itinerary latency and reconcile stale documentation (2026-10-08).
