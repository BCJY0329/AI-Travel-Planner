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

## 020 - Chat-scoped Fredoka/Nunito typography (2026-10-18)

At the user's request, the Lemon.ai chat panel uses Fredoka for headings (panel title, trip brief label, itinerary card header) and Nunito for body text, buttons, chips and inputs, via `AppTheme.chatTheme()` wrapped around the panel only. The rest of the app keeps platform-default fonts, consistent with 019 and the emoji-fallback lesson in KNOWN_ISSUES. Fonts are bundled as static Latin-subset TTFs from Fontsource in `assets/fonts/` (SIL OFL 1.1, licence files alongside) rather than through `google_fonts`, so there is no new package, no runtime font download, and tests stay offline. Characters outside the Latin subset (emoji, arrows) fall back to platform fonts. Supersedes the "platform-default font families" clause of 019 for the chat panel only.

## 021 - App-wide Fredoka/Nunito typography (2026-10-18)

At the user's request, 020's chat-only typography now applies to the whole frontend and `AppTheme.chatTheme()` is removed. `AppTheme.lightTheme` sets Nunito (`bodyFont`) as the default family, maps display/headline/titleLarge text styles and the app bar title to Fredoka (`displayFont`), and gives button text styles an explicit Nunito family. Hand-styled headings opt in with `fontFamily: AppTheme.displayFont`: hero and section titles, brand name, card names, day headers, calendar month, flight times and prices. Long or descriptive text (activity descriptions, subtitles) stays Nunito. Fonts remain bundled Latin-subset TTFs with no package. This supersedes 019's platform-default font clause and 020's chat-only scope. Fredoka is bundled up to weight 700, so w800/w900 headings render at 700.

## 022 - Outfit/Plus Jakarta Sans replaces Fredoka/Nunito (2026-10-18)

At the user's request, the app-wide pairing from 021 is now Outfit (`AppTheme.displayFont`, weights 500–800) for headings and Plus Jakarta Sans (`AppTheme.bodyFont`, weights 400–800) for all other text. The mechanism from 021 is unchanged: the theme default plus explicit `displayFont` on hand-styled headings, as bundled Latin-subset OFL TTFs from Fontsource with no package. The Fredoka/Nunito files and pubspec entries were removed. Outfit includes weight 800, so 800 headings render at their set weight; w900 renders at 800.

## 023 - Revert to platform-default fonts (2026-10-18)

At the user's request, all bundled-font work from 020–022 is reverted while they review the base look. Flutter again uses platform defaults: Roboto on Web and Android, typically Segoe UI on Windows desktop. 019's typography clause is back in force. `assets/fonts/`, the pubspec `fonts:` block and `AppTheme.displayFont`/`bodyFont` are removed. `app_theme.dart`, the five views, `lemon_brand.dart` and `trip_date_dialog.dart` are restored to their committed versions. The chat panel's non-font polish (colours, corner grip, bubble styling) is kept. A future font choice should be made after the user's visual review.

## 024 - Trial: Playfair Display titles, Poppins headings, default body (2026-10-18)

At the user's request, after reviewing the platform-default look (023), headings get two bundled fonts while body text keeps the platform default (Roboto on Web/Android, typically Segoe UI on Windows desktop). No global `fontFamily` is set.
- **Playfair Display** (`AppTheme.titleFont`, 600–800): Discover hero and closing tagline, Itinerary trip title and empty-state heading, LemonTrip brand mark, and date-dialog title.
- **Poppins** (`AppTheme.headingFont`, 500–800): theme `titleLarge` and app bar title; section headings, result counts, hotel/attraction names, Discover card titles and trip line; flight times and prices; Itinerary "Day N"; calendar month; chat title, trip brief label and chat itinerary card header.

Fonts are Latin-subset OFL TTFs from Fontsource in `assets/fonts/`, with no package. This is a trial; the user decides after visual review.

## 025 - Poppins headings with platform-default body (2026-10-18)

At the user's request, Playfair Display from 024 is removed: its fonts, pubspec entry and `AppTheme.titleFont`. The hero/title spots it covered (Discover hero and tagline, Itinerary title and empty state, LemonTrip brand mark, date-dialog title) return to the platform default. Poppins (`AppTheme.headingFont`) remains on the 024 heading set, now also covering the Flights airline badge and wide-card airline name. Body text stays platform default.

## 026 - Sky Mint palette, lemon primary action, photo Discover (2026-10-18)

After several mockup rounds the user chose: cream background; a light Sky Mint pastel (#C9EEE7) for supporting controls; lemon yellow (#F9D648, dark text) reserved for Lemon.ai and the primary action; a deeper mint (#2E7A73) only for small text links and focus; lighter text ink (#3F5A58 / #637775, both above 4.5:1 on cream). Dark teal/coral, saturated palettes and dark secondary shades on the hero heading were rejected as too dark or too colourful. Body text stays Roboto (platform default) for now; Poppins headings from 025 remain. The chat panel keeps its existing layout and avatar crop; only colours change plus a step progress bar. Discover uses real, credited Wikimedia Commons photos bundled in the app (no network dependency); CC BY/BY-SA terms require the visible credits. Idle animations are finite so the page settles and widget tests' `pumpAndSettle` completes.

## 027 - Flight search timeouts (2026-10-18)

Duffel test-mode offer requests with `return_offers=true` can take well over 15 s. The backend now allows 45 s to read (10 s to connect) and maps timeouts to 504 and transport/shape failures to 502. The frontend's flight request waits 50 s, slightly longer than the backend, so the user sees the backend's error rather than a client timeout. Hotels and attractions keep 15 s.

## 028 - Search and itinerary views back to Roboto headings (2026-10-18)

At the user's request, Flights, Hotels, Attractions and Itinerary drop `AppTheme.headingFont` so their headings use the platform default (Roboto on Web/Android) like their body text. The user will review this baseline before choosing a heading font for these views. Poppins stays on Discover, the brand mark, the theme `titleLarge`/app bar title and the chat panel. Supersedes 025 for these four views.

## 029 - Redesigned Flights, Hotels, Attractions and Itinerary pages (2026-10-18)

The four pages follow the approved mockup, built from shared pieces in `lib/widgets/page_parts.dart`: a photo banner with Lemon's tip and an overlapping search card, three how-to steps, a photo results banner, info chips that say where data comes from and what is missing, and hover cards. The user's review changed three things. (1) Each itinerary day has its own soft colour (mint, peach, lemon, light blue) on its header, number badge, time pills and timeline, like the original itinerary. (2) Lemon's avatar circles take the background colour of whatever they sit on (`LemonCircle`), instead of a yellow disc. This applies everywhere except the Discover hero, including Discover's "Ready when you are" band and the "Lemon builds your days" step. (3) Lemon's tips are larger and stand out more: a lemon-bordered bubble with a 16 px title and 15.5 px body, and a 15 px itinerary tip toggle with a 15.5 px note. Banner and results photos only appear for a city that one of the bundled photos actually shows (`DiscoverContent.photoForPlace`); other cities get a plain mint banner, and each page credits the photos it shows. Headings stay Roboto (028). On narrow screens Lemon's tip moves below the search card so the search stays near the top.

## 030 - Unbounded, Outfit and Caveat on the trip pages (2026-10-18)

At the user's request, Flights, Hotels, Attractions and Itinerary get their own typography; Discover is unchanged (Poppins headings, platform-default body). `TripTypography` (`lib/widgets/page_parts.dart`) wraps these four views in `home_screen.dart` with `AppTheme.tripTheme`, which threads **Outfit** (`AppTheme.tripBodyFont`, 400–800) through every theme text style, and a matching `DefaultTextStyle`; dialogs and pickers opened from these pages inherit it. Headings use the shared `tripHeading` style in **Unbounded** (`AppTheme.tripHeadingFont`, 500–700): page banner and results banner titles, the Lemon prompt band title, flight times and prices, hotel/attraction names, Itinerary trip title, empty-state title, "Day N" and day badge. Unbounded is wide, so these sizes are a few points smaller than before. Lemon's notes use **Caveat** handwriting (`AppTheme.noteFont`, `lemonNote` style) at large sizes (21–25 px) so they stay prominent: the Lemon's tip bubble, Lemon's overview summary, and the itinerary tip toggle and note. Fonts are static OFL TTFs from Google Fonts in `assets/fonts/`, with no package. Supersedes 028 for these four views.

## 031 - Sand nav bar, bubble tails face Lemon, icon arrows in quick routes (2026-10-18)

At the user's request the top bar is warm sand (`AppTheme.navBar` #F2EADB, border #E3D8C2) so it no longer blends into the cream page; unselected tab text darkens to #56696A (~4.9:1 on sand). Rule: a speech bubble's sharp corner points at Lemon. Only the Discover hero bubble broke it (sharp corner now bottom-right, toward her); chat bubbles (bottom-left beside her avatar) and `LemonTip` (bottom-right beside her circle) already complied. Flights quick-route chips draw the arrow as an icon instead of '➔' (U+2794), which no bundled font contains; the Web fallback font shifted and clipped some labels.

## 032 - Fredoka for Lemon's notes; livelier itinerary tips (2026-10-18)

At the user's request Caveat (030) is replaced by **Fredoka** (`AppTheme.noteFont`, 500–600): rounded and friendly but print-style, so tips read easily. Sizes return to reading sizes (tip title 18 px, tip text 16.5 px, overview 17.5 px, itinerary note 16 px, toggle 15.5 px). To give Lemon more personality in the itinerary: the itinerary prompt (`SYSTEM_PROMPT` in `itinerary_builder.py`) now asks for every note to carry her voice (a lively opener, one concrete action, a fun payoff, about one note in three with an emoji from the brand set), replacing "practical information first, personality second"; the honesty rules are unchanged. The tip toggle rotates cheerful labels by stop ("A little tip from Lemon", "Psst! Lemon has an idea", "Ooh, Lemon's secret for this one", "Lemon's happy hint"), and the opened note's sharp corner points up at Lemon in the toggle (031 rule). The mock itinerary's demo note stays a plain disclaimer. Supersedes the Caveat part of 030.

## 033 - Bubble tails point at Lemon's head (2026-10-18)

Refines 031 at the user's request: the sharp corner must sit beside Lemon's head, not just on her side. `LemonTip` lifts its bubble by 55% of the 84 px avatar (bottom padding), so the near-square bottom-right corner (3 px) is level with her face. Chat rows align Lemon's avatar to the top and her text and loading bubbles have a sharp top-left corner beside her head; the traveler's bubbles keep their bottom-right corner. The Discover hero bubble (bottom-right, above her head) and the itinerary note (top-left, under the toggle's avatar) already comply.

## 034 - Discover tries Unbounded/Outfit; pale Sky Mint nav bar (2026-10-19)

Trial at the user's request: Discover is wrapped in `TripTypography` too, so the whole app now uses Unbounded headings and Outfit body. Its `AppTheme.headingFont` uses become `tripHeadingFont` at slightly smaller sizes (hero headline scales `width / 24`, clamped 28–54 px, instead of `width / 20`, 32–64 px). The hero greeting bubble is one of Lemon's notes and uses Fredoka. Poppins remains only on the LemonTrip logo and the chat panel. Supersedes the "Discover unchanged" part of 030. The nav bar moves from sand (031) to pale Sky Mint #E8F7F3 with border #CBE8E1: lighter than the selected-tab pill #C9EEE7, so tabs and logo stay clear; unselected tab text stays #56696A (~5.2:1).
