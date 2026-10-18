# Known issues

## Verification basis

Source-inspected on 2026-10-08 against the current working tree. The initial review made no application fixes; subsequent repairs are recorded below, and the dated sections are chronological (later entries supersede earlier ones).

**Open as of 2026-10-17:** KI-07 (Python environment), KI-09 (partial: chat roles/payload sizes and travel-search validation), KI-10 (travel route transport errors), KI-11 (backend exception detail in plan errors), KI-12 (CORS/auth), KI-14 (Gemini 404), KI-15 (provider quota/availability), KI-21 (search tabs ignore trip context), Flutter Web emoji fallback, and pending local visual review. All other numbered issues are resolved; see the status notes below. Findings below are source-derived unless explicitly marked as a command observation; runtime reproduction remains pending.

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
| KI-09 | Partially resolved 2026-10-16: `/lemon/plan` validates ISO dates, ordered 1–30-day ranges, budget enum, and bounded destination/interests. Chat roles and payload sizes remain unconstrained strings. | Add chat and travel-search validation with focused tests. |
| KI-10 | Weather, places, hotels, and flights do not uniformly catch transport failures after geocoding. | Timeouts or malformed provider payloads can produce raw server failures. Standardize error handling. |
| KI-11 | Frontend part resolved 2026-10-16: failures keep trip fields/history and retry only the failed stage. Plan/chat 502 responses still include backend exception detail. | Audit error detail exposure before deployment. |
| KI-12 | `travel_backend/main.py` permits all CORS origins with credentials; no route authentication. | Development configuration requires review before deployment. |
| KI-13 | Resolved 2026-10-08: model/router provider lists and factory error-status comment updated. | Source descriptions now include auto and match the registered providers. |

## Limitations

- No persistent trip/chat storage was found in the inspected app flow.
- Mock/demo itinerary output is one placeholder activity per requested date (since 2026-10-16); it is labelled demo, not personalized.
- Mock itinerary calls still attempt external context; mock chat uses local parsing.
- Auto now validates candidates and falls back to local chat parsing or demo itinerary JSON. Chat still has no provider provenance field; plans report provider_used. Cooldowns are process-local and shared across chat/plan.
- Mock confirmation uses substring matching across user messages; the guided UI now requires explicit confirmation itself, but the mock parser path remains loosely tested.
- Short-range forecasts do not provide weather for arbitrary trip dates.
- Long trips use more provider calls (one per three-day window) and independently generated windows can repeat suggestions.
- Latest recorded coverage: 28 offline backend tests and 36 frontend tests; see TESTING.md for which recent edits have not been rerun. The smoke-test overflows (KI-16) are resolved.

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

## LemonTrip implementation checkpoint — 2026-10-16

This status update supersedes the 2026-10-09 UI review where noted. User authorized implementation; original observations above are retained as history.

- KI-11: frontend context loss repaired. Request failures retain trip fields/history and offer retry or editing. Backend exception-detail exposure remains open.
- KI-16: original app smoke test now passes. New dashboard/assistant layout checks cover 360, 800, and 1440px; this is not exhaustive device, text-scale, or accessibility certification.
- KI-17: compact navigation menu now exposes all five views.
- KI-18: busy submissions are disabled/guarded; unsent drafts survive panel closure. Regression covered.
- KI-19: removed the false attraction Save notification; location actions open Google Maps on web (copyable link dialog on other platforms). View Deal replaced with a real flight details dialog. Persistent saves and bookings remain unimplemented.
- KI-20: copy now includes all days/activities and reports success after the clipboard call completes.
- KI-21: still open. Search tabs retain independent defaults; automatic trip-to-airport matching is not part of this batch.
- KI-22: mock output explicitly labeled Demo itinerary, with retry available in chat. One-day mock content is unchanged. Singular/plural duration copy corrected.
- KI-23: Discover copy no longer promises live flight offers, hotel amenities, or guaranteed generation speed.
- KI-24: flight cards use returned currency and label the amount as total for all travelers. Live upstream pricing semantics were not reverified.
- KI-09: partially addressed for /lemon/plan: ISO calendar dates, ordered 1–30-day range, bounded destination/interests, and budget enum. Chat roles/payload sizes and travel-search validation remain open. Server accepts historical date ranges; the UI picker requires today or later.

Lessons: guided values should remain structured rather than be round-tripped through AI. A model-ready flag must not substitute for explicit user confirmation. Failed request retries must not duplicate the user turn or restart intake. Responsive cards should size to content instead of fixed aspect ratios. Display demo provenance and avoid showing successful saves that do not exist.

Current limitations: destination interpretation still uses /lemon/chat and depends on provider/local parser behavior. The guided UI deliberately asks users to confirm dates and preferences even if included in their initial message. Typed conversation after destination is replaced by structured controls plus Other preferences; unrestricted travel Q&A is not implemented. Photo integration and shared search context remain future work. Existing backend issues outside structured intake are unchanged.

## Visual refinement lessons - 2026-10-16

User feedback supersedes the dark hero and narrow desktop direction of the first batch. Light pastel surfaces now carry the visual identity; dark colors remain for readable text. Desktop itinerary days share rows rather than stretching each activity across the page. Preserve portrait aspect ratio: specifying both square cacheWidth and cacheHeight distorted the rectangular Lemon artwork. The shared avatar now frames the face from the original source without forced decode dimensions. Photos, real route maps and activity categories still need verified data; icons and stop numbers are presentational only. Browser visual review remains outstanding.

## Desktop browser review - 2026-10-16

Observed in the running frontend at 1440x1000 and 1920x1080 using a generated three-day Bali sample through normal guided intake. Two-column days and tip expansion work. Remaining visual issues: activities without notes can shrink into centered narrow cards while other activities fill their column; stretch the day activity Column consistently. Cards with tips remain tall (roughly three stops per viewport). Lemon's portrait is proportionate but sits low in the circular frame, favoring hair over chin; adjust the vertical crop after visual comparison. These are observed findings, not fixes. The sample content was not fact-checked.

## User-reported refinement and long-trip issue - 2026-10-16

User reports that longer trips sometimes stop after day 3 or 4. Source inspection of itinerary_builder.py confirms validation currently checks the ItineraryResponse structure but does not compare returned days/dates with the requested inclusive date range. The prompt supplies dates but does not explicitly specify the required count. This explains why incomplete output can be accepted, but does not prove the original truncation cause; provider token limits, output and fallback paths still need investigation. No runtime reproduction or backend fix in this checkpoint.

Additional user feedback: tips need Lemon's portrait and warmer presentation; traveler count should be typed; another calendar click should adjust the end rather than reset the entire range; dashboard should use cool colors without yellow and have more visual character; mascot crop must include the full face, with a slightly larger animated launcher. These requests are authorized and tracked in TASKS.md. Preserve validation and reduced-motion support when implementing.
## Refinement implementation follow-up - 2026-10-16

Implemented the six authorized requests. Tipless cards now stretch like cards with tips; regression test covers mixed content. Tips use the shared original image portrait in a mint expandable section. Portrait viewport widened to include more of the face and launcher increased to 76px; visual acceptance is pending the user's local review, not claimed verified from tests.

Long itineraries now generate in three-day windows, up to three concurrent calls, sharing a 36-second generation budget after best-effort context. Every window must include exact dates, absolute day numbers and nonempty activities. Direct providers get one corrective retry for invalid output within the same budget; auto validates before accepting each provider. Any mock window marks the full response mock, so mixed demo results never masquerade as wholly personalized. Offline tests cover 30-day demo output, 11-day ordered assembly with out-of-order completion, partial rejection, missing dates and empty activities. This fixes incomplete-output acceptance; it does not guarantee live availability or establish the original provider-side cause. Long trips use more API calls and may hit quotas; independently generated windows can repeat suggestions across sections. Live long-trip quality remains to be assessed.

Calendar dates are staged locally until Use these dates. Repeated end selection preserves the start, earlier dates show feedback, Change start explicitly begins a new range, and Just this day supports same-day travel. Entrance animation is brief and bypassed when reduced motion is enabled.

## Timeout screenshot and interaction follow-up - 2026-10-17

User screenshot shows real Groq/OpenRouter attempts timing out at about 12 seconds, plus Gemini HTTP 503 (unavailable), not a mock-provider timeout. Plan attempts now allow 25 seconds inside a shared 75-second generation deadline; frontend waits 100 seconds to leave room for context and cleanup. This may help slow providers but does not repair availability, rate limits or exhausted quotas. Five-minute process cooldown remains. Offline budget/fallback tests pass; live success has not been verified.

Multiline destination composer now explicitly handles physical Enter and numpad Enter, preserving Shift+Enter and guarding active input composition. Enlarging chat preserves the mounted panel/draft. Hover effects wrap existing controls rather than replacing their semantics or click handlers; reduced-motion users get no scale effect.

## Greeting/recovery checkpoint - 2026-10-17

Three local greeting responses now rotate without provider calls. Clearly malformed messages and a limited set of unrelated request patterns get friendly recovery while preserving trip fields/current step; a parser response without a destination also triggers recovery. This is conservative filtering, not comprehensive semantic validation. The backend mock bare-place heuristic remains permissive for short alphabetic nonsense and needs follow-up. Prompt instructions were strengthened but not runtime-verified this batch.

Composer hint/counter hidden with Enter sending and 600-character limit retained. Original avatar dimensions confirmed 675x856; chat avatars enlarged and downsampling changed to medium with antialiasing. Pixelation improvement awaits local visual confirmation. Work paused at user's request after 32 frontend tests passed.

## Recovery follow-up - 2026-10-17

The mock replay now skips obvious invalid destination turns before broad field extraction. Offline coverage confirms garbage followed by a valid non-English place recovers correctly. This closes the obvious-noise fallback gap from the checkpoint; plausible alphabetic nonsense is still not geographically validated. AI prompt guidance and conservative frontend checks do not guarantee rejection of every irrelevant input. Portrait rendering changes still need the user's local visual check; source resolution was preserved, not artificially increased.
## Lemon tone follow-up - 2026-10-17

Local chat copy and backend generation prompts now ask for a cheerful, playful travel companion rather than brochure-style advice. This affects newly generated content; existing itinerary notes are not rewritten. Prompt guidance cannot guarantee every provider follows the desired tone, and live responses still need local review. Practical facts, uncertainty and safety/accessibility advice must remain clear.

## Expressive UI follow-up - 2026-10-17

Tip subtitles now vary deterministically by day/stop with restrained emoji, including existing itineraries; stored/generated advice is preserved rather than rewritten with invented information. Six variants repeat on longer itineraries. Launcher invitations rotate on hover/focus entry, not on a timer; touch users can open chat directly. Original artwork is shown proportionally when expanded, not rigged into a talking/animated character.

Regression testing caught a zero-duration AnimatedSize layout assertion under reduced motion; bypassing that widget fixes it. Header navigation now scrolls horizontally when its labels exceed available desktop space. Flutter animation entrances require the smoke test to settle before teardown. 36 frontend tests and analyzer pass; actual desktop/Android visual review remains pending with the user.

Launcher tooltip lesson: removing Tooltip.message alone violates Flutter's tooltip content requirement. Remove the Tooltip wrapper to suppress the popup, while retaining Semantics for accessibility.


## Calendar and chat usability follow-up - 2026-10-17

The custom calendar uses a seven-column grid and custom month paging; locale weekday order is respected. Check range continuity, screen-reader date labels and month navigation during local review, especially at narrow widths and large text scale. Chat resizing is available on desktop via its upper-left corner, bounded by viewport and 900x850 maximum; compact/mobile layout remains fullscreen. Enlarging the launcher into a circular face crop made the original 675x856 artwork look pixelated at close range. Keep the original full-proportion illustration in the expanded launcher, avoid forced decode dimensions, and judge visual quality at the actual rendered size. No runtime analysis or test suite was run in this pass.

## Flutter Web emoji fallback - 2026-10-17

Flutter Web warned that it could not find a Noto font for some emoji. An app-wide bundled emoji fallback changed the UI's text spacing and was reverted. Preserve platform-default typography; if the warning returns, use a narrowly scoped fallback or image-based emoji and verify the result before applying a global font setting.

## Stale frontend tests - 2026-10-17 (command observation)

`flutter test --no-pub` fails four tests. Two of them in `test/lemon_redesign_test.dart` also fail against the committed `lemon_chat_panel.dart`/`chat_bubble.dart`. "Desktop chat expands without losing its draft" taps an "Enlarge chat" tooltip that no longer exists since the drag-grip resize replaced expand/shrink. "Calendar end edits preserve start…" finds no matching calendar element at line 216. The two `test/lemon_personality_ui_test.dart` launcher hover/focus failures were not investigated. Update the tests to the current UI rather than restoring the removed controls.

## App-wide font change - 2026-10-18

The frontend now defaults to bundled Nunito/Fredoka (DECISIONS 021), which is the kind of global font change the emoji-fallback note warns about. The difference from the reverted attempt is that these are Latin text fonts, not an emoji font, so emoji should still come from platform fallback. This is unverified: check emoji rendering and text spacing in Flutter Web and Android during local review. If emoji break, scope the fallback rather than reverting typography.

Update 2026-10-18: the app-wide font change above was reverted (DECISIONS 023). The emoji-fallback check no longer applies to custom fonts.

## Discover photo licensing - 2026-10-18

Discover photos are from Wikimedia Commons under CC BY, CC BY-SA or CC0 (see `lib/config/discover_content.dart`). The attribution line at the foot of Discover must stay while these photos are used; replacing a photo means updating or clearing its credit. Lesson: endless idle animations make `pumpAndSettle` time out; `AmbientMotion.loopForever` keeps them endless in the app and `test/flutter_test_config.dart` limits them to two cycles in tests.

## Flight search timeout - 2026-10-18

User-reported traceback: `/flights/search` raised `httpcore.ReadTimeout` because Duffel's `return_offers=true` call exceeded the 15 s httpx timeout and only `HTTPStatusError` was caught. Fixed: 45 s read / 10 s connect timeout, 504 on timeout, 502 on transport or malformed responses, incomplete offers skipped; the frontend waits 50 s for flights. KI-10 is now resolved for flights only; weather, places and hotels are unchanged. Also observed: `test_chat_exhaustion_matches_explicit_mock` in `tests/test_auto_provider.py` fails (`budget_level` != `confirm`) with or without the flight changes; not investigated.
