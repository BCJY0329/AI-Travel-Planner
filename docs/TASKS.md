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

## LemonTrip UI and guided planning — 2026-10-16

User authorized the LemonTrip name, dashboard tagline “Your personal travel companion,” palette refresh, compact assistant, and guided planning. This entry supersedes the earlier proposal-only status for the completed items below. Work stopped at a coherent first batch to respect the user's usage-limit request.

- [x] Rename the web app/dashboard to LemonTrip; retain Lemon.ai as the assistant.
- [x] Add a bounded 1280px desktop layout, indigo/warm-white/teal/lemon palette, compact Discover cards, responsive navigation menu, and a 56px assistant launcher.
- [x] Lazy-create search tabs on first visit, preserving their state afterward.
- [x] Guide dates (1–30 days), travelers, budget, and interests with explicit controls; include Other preferences, Surprise me, editable review, and explicit Generate confirmation. Selected fields reach /lemon/plan directly rather than being reinterpreted by a model.
- [x] Preserve drafts across panel closure and busy submissions; preserve context after request failures and retry only the failed stage.
- [x] Simplify itinerary hierarchy, reset stale day selection, hide redundant single-day filters, label demos, and copy the full itinerary.
- [x] Replace nonfunctional Save/View Deal actions with location links and flight detail dialogs; show returned currency and party-total labels. Move unavailable hotel attributes to one list-level notice.
- [x] Validate structured plan request dates/ranges, destination length, budget enum, and bounded interests in the backend.

Remaining separate work: shared trip context across search tabs (KI-21), verified listing photos/provider integration, persistent saved trips, full category normalization, date-appropriate weather, and remaining backend/provider issues. No dependencies installed or changed; the pre-existing pubspec.lock modification belongs to the user. No commits or pushes performed. See TESTING.md for verification and limitations.

## Brighter visual refinement - 2026-10-16

- [x] Replace dark hero/chat surfaces with lemon, mint and sky; use peach and pastel day headers while keeping readable dark text and action colors.
- [x] Widen desktop canvas from 1280 to 1720px and arrange multiple itinerary days in two columns on wide screens, stacking on compact screens or larger text.
- [x] Frame Lemon's face from original artwork without forced square decoding; use a 64px launcher.
- [x] Add time badges, numbered stops, location icons and expandable tips to itinerary cards. No fabricated activity metadata or images.

## Desktop visual follow-up - 2026-10-16

- [x] Inspect current app in desktop browser with a populated three-day itinerary and expandable tips.
- [ ] Fix inconsistent activity widths when optional notes are absent; add a mixed-content regression case.
- [ ] Refine face crop vertical position and reduce itinerary card height after visual review.

## Authorized next batch - user feedback, 2026-10-16

Implementation authorized by the user; deferred before starting because the five-hour usage window was already 89% consumed and the user requested a clean stop near the limit. No application edits made in this checkpoint.

- [ ] Make activity tips feel like advice from Lemon: sharp miniature portrait, friendly heading and cool tinted surface; preserve actual note content. Also fix inconsistent activity widths and reduce excess card padding.
- [ ] Replace traveler dropdown with numeric entry; keep validation for whole numbers 1-20, helpful errors, keyboard submission and edit-state preservation.
- [ ] Replace/reset-proof date selection: keep the selected start date when subsequent dates adjust the end date, provide an explicit Change start / Restart selection action, show a clear range and inclusive day count, and retain existing 1-30 day/future-date validation. Define earlier-than-start feedback and same-day selection explicitly; cancellation must preserve the previously accepted range.
- [ ] Refine Discover with a cool mint/sky/lavender palette, remove yellow from dashboard surfaces/actions, improve composition and add restrained animation that respects reduced-motion preferences.
- [ ] Correct the shared portrait crop to include Lemon's complete face; modestly enlarge the launcher and add restrained motion/hover feedback. Use original-resolution artwork with preserved proportions. Verify visually in launcher, chat and tip contexts.
- [ ] Investigate incomplete long itineraries. Enforce complete requested dates/day numbering and nonempty days before reporting success; implement a bounded generation/retry strategy that can actually cover long trips without silently accepting a partial plan. Preserve demo labeling and avoid presenting canned completion as a real personalized result.

Verification needed: mixed-note card widths, numeric input invalid/valid/edit cases, repeated end-date clicks and deliberate start changes, reduced-motion behavior, desktop browser screenshots, and backend partial/duplicate/missing-date/long-range cases. Review provider output limits, fallback behavior and timeout budgets before choosing batching or repair; do not simply increase all timeouts.
## Completed authorized refinement batch - 2026-10-16

Supersedes the pending implementation status above; browser visual acceptance remains with the user at their request.

- [x] Lemon portrait and mint surface on expandable tips; consistent full-width activities and tighter padding.
- [x] Numeric traveler entry with whole-number 1-20 validation and keyboard submission.
- [x] Anchored start date, repeated end-date adjustments, explicit Change start, Just this day, range summary and validation; cancellation does not submit changes.
- [x] Cool dashboard palette without yellow surfaces, new planning panel in the hero, and short reduced-motion-aware entrance animation.
- [x] Wider original-resolution portrait framing, 76px mint launcher, short entrance animation.
- [x] Three-day generation windows, at most three concurrent windows, complete date/day/activity validation, bounded direct-provider corrective retry, auto fallback and ordered assembly. Any demo section labels the entire response mock.
- [x] Offline checks: 28 Flutter tests, 27 backend tests, Flutter analysis clean.
- [ ] User visual review of updated portrait, calendar and dashboard in local browser; live long-trip generation/provider quota behavior is not verified by offline tests.

No dependencies changed, commits or pushes. New preview on port 5188 stopped after the user requested local browser testing. Restart the user's frontend and backend to load these changes.

## Interaction polish and provider wait windows - 2026-10-17

- [x] Physical Enter/numpad Enter sends destination text; Shift+Enter remains available for new lines. Keep busy/error/IME-composition guards and drafts.
- [x] Desktop chat Enlarge/Shrink control preserves state; compact layouts already fill available space.
- [x] Tips have a portrait medallion, friendly subtitle and inset speech-style note surface, preserving generated text.
- [x] Launcher, Discover service cards and destination chips scale slightly on hover/press; reduced motion disables scaling.
- [x] Auto plan provider attempts increased from 12s to 25s; shared generation deadline from 36s to 75s, frontend plan timeout from 60s to 100s. Chat budgets and five-minute cooldown unchanged.
- [x] Frontend suite 31 passes; backend suite 27 passes; final physical Enter check passes after composition guard.

Visual and live-provider verification remains with local testing per user preference. No browser launched, dependencies changed, commits or pushes in this batch.

## Paused at user request - 2026-10-17

Latest request: three greeting variations, recoverable unclear/off-topic input handling, hide composer helper/counter, improve pixelated avatar. Implementation so far: local rotating greetings, conservative obvious-noise/off-topic checks, friendly retry without field reset, rejected destination turn removed from extraction history, backend prompt guidance against invented destinations, hidden composer hint/counter, larger chat portraits and medium downsampling filter on the original image. Enter behavior and input length limit remain.

Verification: dart format completed; full frontend suite passed 32 tests including greeting rotation/no-network and step preservation after noise. No final analyzer/backend rerun or visual review for this latest batch. User explicitly requested stopping near usage limit.

Resume: inspect current diff; run analyzer and isolated backend suite; review mock parser's permissive bare-destination heuristic (it can still accept arbitrary short alphabetic strings), extend conservative recovery without rejecting unfamiliar/non-English places, and document/test remaining gaps. Confirm avatar improvement locally with the user; source is 675x856, downsampling and display-size changes are not proof of visual quality. Do not claim universal nonsense detection. Preserve all existing uncommitted work; no commit/push/dependency changes.

## Greeting and recovery batch resumed - 2026-10-17

- [x] Three rotating local greeting responses with current-step reminders; obvious-noise recovery preserves trip state and permits another attempt.
- [x] Hide composer hint and character count while retaining Enter/Shift+Enter and length enforcement.
- [x] Increase chat portrait size and use medium downsampling/antialiasing on the original 675x856 asset; local visual acceptance remains pending.
- [x] Harden mock destination replay against obvious keyboard noise, repeated characters, symbols and selected unrelated request patterns. Confirm correction to a non-English destination works.
- [x] Backend suite passes 28 tests; frontend suite passed 32 at the checkpoint, with only a brace-formatting fix afterward.

No universal semantic nonsense detector or geographic verification is claimed. Arbitrary plausible alphabetic strings may still be accepted by mock mode; avoiding false rejection of valid unfamiliar names remains intentional. No browser launched, dependency change, commit or push.
## Lemon personality follow-up - 2026-10-17

- [x] Rewrite local greetings, guided planning prompts, recovery and completion messages with a cheerful travel-buddy voice.
- [x] Align backend chat and itinerary prompts with varied, practical, personable language; allow occasional light asides and restrained emoji without invented facts.
- [x] Update the tip subtitle to a conversational invitation. Existing generated notes remain unchanged; regenerate to receive the new tone.
- [x] Frontend suite: 32 tests passed; Flutter analysis clean; isolated backend suite: 28 tests passed. Live provider tone and local visual acceptance remain unverified.

## Expressive Lemon and Discover polish - 2026-10-17

- [x] Six stable tip introductions with emoji, varied by day/stop; factual note content retained.
- [x] Launcher expands on hover or keyboard focus, reveals the original full artwork, and cycles four invitations on subsequent entries. Click/Enter opens chat; touch opens it directly.
- [x] Citrus-and-route vector brand mark, teal wordmark, postcard hero, stronger primary action and numbered service cards with entrance/hover feedback.
- [x] Add flutter_animate 4.5.2 using flutter pub add after verifying Web and Android support on pub.dev. flutter_shaders is its transitive dependency; no other suggested packages added.
- [x] Centralize 200/300/400ms motion durations and curve in AppTheme. Reduced motion bypasses entrances and launcher resizing, and disables hover scaling.
- [x] Flutter analyze clean; 36 frontend tests pass, including launcher hover rotation, keyboard activation, touch, reduced motion and existing responsive layouts. git diff --check clean.

No browser launched per user preference. Local visual acceptance remains pending. Backend behavior and live AI tone were not changed or re-tested in this frontend batch. Usage checked at 62% of the five-hour allowance before completing the batch.

## Launcher tooltip removal - 2026-10-17

Removed the redundant Ask Lemon hover tooltip; retained the screen-reader label, expanded invitation and activation behavior. Preserved user-edited invitation wording and updated existing test selectors/copy expectations accordingly.

## Restrained greeting emoji - 2026-10-17

Added one relevant waving-hand emoji to the first welcome sentence; surrounding sentences and other welcome alternatives remain emoji-free. Preserved the user's three welcome variants and fixed their invalid three-argument _bot call by selecting one string at a time. No new dependency or backend change.

Save-conflict recovery: reapplied the single waving-hand emoji to the opening greeting. Preserved the user's latest greetings list (which now holds the alternative welcomes) and revised budget wording, adding the missing separator between its adjacent strings. No duplicate welcome rotation added.

## Compact hotel results - 2026-10-17

Hotel results now match Attractions: two columns above 750px of available content width, one column on narrower layouts, with 16px gaps and content-sized cards. Existing addresses, map actions, search and unavailable-data disclosure retained.
