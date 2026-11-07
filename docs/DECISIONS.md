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

## 035 - In-memory API caching; Pixabay country photos for itinerary banners (2026-10-20)

At the user's request, external API results are cached in process memory so repeat visits don't spend quota. `services/ttl_cache.py` (`TTLCache`) stores only successful results, never errors; identical concurrent misses share one upstream call; a waiter that times out (itinerary context) doesn't cancel the shared fetch; callers get deep copies; entries expire by TTL and the oldest are evicted past `max_entries`. TTLs: geocoding 24 h (shared by all city routes), forecast 30 min, Geoapify attractions/hotels 24 h, Duffel flights 5 min (prices move), Pixabay search 24 h, images 24 h. LLM chat and plans are not cached: they are personal and should vary. No file or database cache: a restart starts empty, which costs at most one call per key.

Banner photos come from **Pixabay**. Pexels was the first choice, but new Pexels API keys have been paused since about 2026-09-30 with no reopening date. Unsplash new apps are capped at 50 requests/hour, and Wikimedia quality and credits vary. Pixabay's terms require caching searches for 24 h, crediting Pixabay, and no permanent hotlinking, so the backend downloads each image and serves it from `/photos/image/{id}`. Photos are searched per **country** (OpenWeatherMap geocoding `country` code → `services/countries.py` name; category `travel`, falling back to any photo), so every city in a country shares one search; the itinerary picks one of up to three per city for variety. The itinerary banner uses a bundled city photo when one exists, else the Pixabay photo with a "Banner photo by X on Pixabay" credit, else the plain mint banner (no key, offline, rate-limited or unknown place). Scope is the itinerary banner only; the Flights/Hotels/Attractions banners still use bundled photos.

## 036 - Pixabay photos on every page; Discover hero slideshow (2026-10-20)

Extends 035 at the user's request. `PlacePhotoSource` (`lib/services/place_photos.dart`), created once in `home_screen.dart`, is passed to Discover, Flights, Hotels, Attractions and Itinerary; it asks the backend once per place per app session and forgets failures so they are retried. `BannerPhoto` gives each view the photo for the place it shows: a bundled photo for that city first, else a Pixabay country photo once it arrives, else the existing fallback (mint banner, or the generic flights photo). Hotels and Attractions use the searched city; Flights uses `_airportCities` for bundled photos and otherwise the offers' new `arrival_city`; the page header banners keep their bundled photos. `DiscoverPhoto` gains `url` and `source`; banners draw it with `BannerImage`, which fades network photos in and falls back if they fail to load. `PhotoCredits` groups credits by source ("Photos (Wikimedia Commons): …  ·  Photos (Pixabay): …").

The Discover hero starts on the bundled Positano photo, then cross-fades every 9 s through up to 10 Pixabay editors' choice travel photos from `GET /photos/featured`, showing "Photo by X on Pixabay" in the corner while a Pixabay slide is up. No slideshow when animations are disabled. The Wikimedia destination cards are unchanged. Views given no photo source (most widget tests) behave as before.

## 037 - Search tabs follow the planned trip; Duffel airport lookup (2026-10-24)

Resolves KI-21 at the user's request. When an itinerary is generated, `LemonChatController.latestTrip` (`TripContext`: destination, start date, travelers) is passed from `home_screen.dart` to Flights, Hotels and Attractions. A view applies a trip once, when it is created or when a new plan arrives (a new object), and then keeps the user's own edits until the next plan: that is the explicit override. Hotels and Attractions search the trip's destination. Flights takes the start date and party size (capped at the dropdown's 6 adults, with a note when the trip has more), keeps the user's origin, and fills the destination from `GET /airports/search`. That endpoint was chosen over a bundled city table because it covers any city. It searches Duffel place suggestions by name, keeping only airports whose city is the place or whose name contains it, and otherwise geocodes the place and returns Duffel airports within 100 km, nearest first. The first airport is searched and up to three are offered as chips; with none, Flights clears the destination and asks for a code instead of searching a stale route. A demo itinerary still sets the trip, because the trip details are the user's own.

## 038 - Generic Lemon error details; uniform data-route errors (2026-10-24)

Resolves KI-10 and KI-11 and the rest of KI-09. `/lemon/chat` and `/lemon/plan` return fixed 502 messages and log the exception, since provider errors can echo prompts, trip details or upstream bodies. Weather, places, hotels and airports follow the flights pattern (KNOWN_ISSUES, 2026-10-18): 504 on timeout, generic 502 on transport or non-JSON failures, incomplete items skipped. Inputs are bounded: city/place 1–120 characters, IATA codes three letters, real ISO departure dates, chat roles `user`/`assistant`, at most 100 messages of 2000 characters.

## 039 - Geoapify geocoding; regions searched by boundary (2026-10-24)

Resolves KI-25 at the user's request (option 1; an explicit "which country?" choice, option 2, was deferred by the user for a later session). The shared geocoder (`_geocode_city` in `routers/weather.py`, used by weather, places, hotels, photos, airports and itinerary context) now asks Geoapify geocoding (`/v1/geocode/search`, existing `GEOAPIFY_API_KEY`) instead of OpenWeatherMap. Geoapify orders by relevance and knows islands and regions, so "Bali" is Indonesia's Bali, where OpenWeatherMap's first exact name match was the town in Bhutan. Streets, buildings, amenities and postcodes are skipped. When the top result is a region (`county`, `state`, `country`), a city with exactly that name in the same country wins, from the same results or one extra `type=city` request, because hotels and sights are searched around the point and a prefecture's centre can be far from town ("Osaka Prefecture" → Osaka). A same-named city in another country never wins, and names must match exactly ("Balikpapan" is not "Bali"). A place that really is a region gets a `region_id`, and Hotels/Attractions then search its whole boundary (`filter=place:<id>`) instead of a circle: Bali's centre is in the mountains, where a 5 km circle found two hotels. OpenWeatherMap stays as the fallback when Geoapify fails (not when it finds nothing). The geocode cache is unchanged (24 h).

## 040 - Contrast tokens and a keyboard focus ring (2026-10-31)

First batch of KI-26, the visual items that help every user; the screen-reader items were deferred by the user. Text and outline colours are chosen by computed WCAG contrast: `textSecondary`/`textMuted` darkened to #5B6F6D (4.5:1 or more on cream, white and the `sky` tint), `error` to #C62828 (5.6:1), and a new `fieldBorder` (#74918C, 3:1 or more) outlines inputs and search fields while `border` stays for decorative card edges. Keyboard focus is shown by a 2.5 px `focusRing` (`primaryDark`) outline: through `AppTheme.focusOutline` on the button and chip themes, and through the `FocusRing` widget around custom InkWell cards, chips, calendar days, the tip toggle and the logo. The ring follows Material's rule of not drawing focus after touch input; a mouse user can still see it when focus returns to a button after a dialog closes. Widgets that set their own `side` must merge `focusOutline` (as the Sign-in button and `PillButtonTheme` do) or they lose the ring. Unavailable calendar days are faded and past days struck through, relying on the contrast exemption for inactive controls.

## 041 - One button family in Lemon's chat steps (2026-10-31)

At the user's request: the chat's guided-step buttons used lemon (primary) next to Sky Mint (secondary) and plain text links, sat flush against each other, and were easy to miss. In `lemon_chat_panel.dart` they now come from two helpers: `_primaryAction` (full-width lemon, 52 px, bold label with an icon, soft lemon shadow) for the one main action per step, and `_secondaryAction` (pale `lemon` fill, `accentLemon` outline, lemonInk text) for alternatives, budget choices and post-plan actions; `_spaced` keeps 10 px between stacked buttons. Selected interest chips turn pale lemon to match. Labels: "Pick my travel dates", "Go with these interests" (with a hint while nothing is picked), "View my itinerary"; "Continue", "Generate my itinerary" and "Retry personalized generation" (matching the mock itinerary's note) are unchanged. Both helpers keep the keyboard focus ring (DECISIONS 040).

## 042 - Slow providers are not failures: cooldown kinds, per-wave budgets, streaming with a silence limit (2026-10-31)

At the user's request: long itineraries often fell back to the mock plan because a slow but working provider was treated as failed. Hard constraint from the user: no reduction of itinerary content (no `max_tokens`, no prompt trimming, no smaller windows, `SYSTEM_PROMPT` unchanged). Supersedes the timing values of 016 and the "five-minute cooldown for every failure" rule.

1. **Cooldown by failure kind** (`auto_provider._classify_failure`). Hard failures (401/403, 404, 503, missing key, construction and other call errors) keep 5 minutes. 429 uses `Retry-After` (seconds or HTTP date; `retry-after-ms` also read), clamped to 1 s–1 h, else 5 minutes. A provider's own timeout or stall, and invalid JSON or a reply that fails validation, get 30 s (the user chose 30 s for bad output too). A timeout caused only by the caller's shared budget running out gets no cooldown. The log line names `failure=<kind> cooldown=<s>`.
2. **Budget scales with waves** (`itinerary_builder.generation_budget_seconds`). Windows stay 3 days, 3 at a time. Each window gets a full 75 s from the moment it takes a slot, under an overall cap of 75 s × waves (1–9 days 75 s, 10–18 days 150 s, 19–27 days 225 s, 28–30 days 300 s). The frontend plan timeout mirrors this as 25 s + 75 s × waves (100/175/250/325 s), in `LemonApiService.planTimeoutFor`; keep the two formulas in step.
3. **Streaming with an inactivity limit.** Groq and OpenRouter stream through `openai_stream.stream_chat_json`; Gemini runs the SDK's synchronous stream on its own daemon thread, because google-genai 0.3.0's "async" stream does blocking reads on the event loop. Each provider exposes `stream_text()` and its `generate_json()` joins that stream, so callers still get the same complete raw JSON string. For plans, auto cuts a provider only after 10 s with no new chunk (`STREAM_IDLE_SECONDS`), with 25 s allowed before the first chunk (`STREAM_FIRST_CHUNK_SECONDS`), so slow time-to-first-token on long prompts or thinking models is not mistaken for a stall. Every chunk, including ones without answer text (reasoning, role headers), counts as activity. The fixed 25 s per-attempt cap for plans is removed; a steadily streaming provider may run up to its window budget. Chat is unchanged (9 s per attempt, 30 s total, 45 s frontend).
4. **No hidden SDK retries** for Groq and OpenRouter (`max_retries=0`). Otherwise the OpenAI SDK would silently sleep out a 429 before streaming, which the silence limit would misread as a stall; auto now sees the 429 at once, applies Retry-After and moves on. Direct (non-auto) use of those providers no longer retries.

Consequences: a 30-day plan can take up to about 5½ minutes before the client gives up. A provider that streams slowly for its whole window budget leaves no time for a fallback provider in that window. Live behaviour (first-chunk times, reasoning chunks, Retry-After headers) is not yet verified; see KNOWN_ISSUES 2026-10-31 "Provider timing".

## 043 - Calm Sky Blue, lemon and warm sand; Fredoka wordmark with a lemon dot (2026-10-31)

Chosen by the user after a series of mocks (canvas https://claude.ai/artifact/L5nqavbdcThi8BAWxF8LCj). Sky Mint is replaced by Calm Sky Blue and a warm-neutral third colour is added, balanced 60/30/10 in `app_theme.dart`: 60% warm neutrals (cream page, `sorbet` #FBF6E3, `sand` #F1E6D3) carry Lemon's halo, her tip boxes, step numbers, tags and badges; 30% sky blue marks everything pressable (`cta` #B5D3F2 with `ctaInk` #23395B for the main action, `ctaSoft` #E3EFFB for partners, `skyBlue` #CFE1F6 for the selected tab and chips, `primary` #2F5F98 for links and icons); 10% lemon yellow belongs to Lemon only (avatar ring, a rim round her sorbet halo, a slim "adventure." underline, her tip bulb, the lemon on the wordmark). Supersedes the lemon CTA buttons of DECISIONS 026 and 041. Old Sky Mint names were renamed (`skyMint`→`skyBlue`, `skyMintBright`→`skyBlueBright`, `teal`→`primary`, `mint`→`paleBlue`) and pale `lemon` removed; secondary text darkened to #52637A so it keeps 4.5:1 on the blue chips and sand. Itinerary days cycle sky, peach, sand and lilac.

The lemon icon tile is gone. `LemonBrand` is now a Fredoka 600 wordmark at 26–29px whose "i" is a dotless ı with a painted lemon and leaf as its dot (positioned from Fredoka's x-height, 0.5 em). It plays one colour wave (dark → lemon → sand → dark, per letter, about 2.9 s with the lemon wiggle) when it first appears and again on hover; it never loops, honours `disableAnimations`, and exposes the semantics label "LemonTrip". The nav bar gives it room and a divider before the tabs.

## 044 - Page colours for the search buttons; warm sand for "Plan with Lemon" (2026-11-01)

**Partly superseded by 046:** Hotels and Attractions are sky blue again. The sand pre-plan itinerary and the sand "Plan with Lemon" bands stay.

Approved by the user on the mock canvas (page "Page colours", https://claude.ai/artifact/L5nqavbdcThi8BAWxF8LCj). **Implemented in Flutter on 2026-11-01** (`PagePalette` in `app_theme.dart`, `PageTone` and `planWithLemonStyle` in `page_parts.dart`). This narrows the "sky blue marks everything pressable" rule of DECISIONS 043 in two places only:

- Each search page has its own palette colour, and its search button takes that colour. Flights stays sky blue ("Find Flights": `cta` #B5D3F2 with `ctaInk` #23395B). On Hotels, "Find Hotels" is peach (#FFC9AE with ink #5A2A12, about 8:1). On Attractions, "Discover Attractions" is lilac (#CFC6F2 with ink #2F2566, about 7.9:1). The pre-plan Itinerary page is sand and has no search button. The page colour also tints that page's hero, search card, step numbers and result tiles in the mock.
- "Plan with Lemon" calls to action are warm sand (#E8D3AC fill, #D9BF92 border, ink #4E3B22, about 7.4:1). This covers the strip at the foot of Flights, Hotels and Attractions, the hero button on the pre-plan Itinerary page, and "Plan a trip with Lemon" and "Start planning" on Discover. The strip's card stays sorbet with a sand border.

Every other pressable item stays sky blue as DECISIONS 043 says. That includes "View details", "View location", chips, filters, tabs, swap, "Explore places" and Lemon's chat buttons. Lemon yellow stays reserved for Lemon.

In Flutter the page colour reaches the shared parts through `PageTone`: the banner's tint and eyebrow pill, the search card's fill, and each field's label and outline. Fields are white boxes whose outline keeps 3:1 on white (`PagePalette.field`). It also reaches the how-to step numbers. Hotel bed tiles and attraction tiles and tags take the page colour too. Outside a `PageTone`, as on the planned itinerary, `HowToSteps` keeps its earlier sky, peach and lilac tints. Hotels and Attractions gained the "Plan with Lemon" band that Flights already had. The pre-plan itinerary is now a sand page with:

- Lemon's invitation
- her five questions
- four placeholder days in the day colours

On Discover, the hero has a sorbet eyebrow pill and the single headline "A little curiosity." (the underlined "A whole new adventure." line is gone). The new subtitle is "Tell Lemon where you'd like to go and she'll shape the days around what you love.". The three steps are coloured pills, "Explore places" is white with a sky edge, and the "Ready when you are" card is sand.

## 045 - Lemon.ai chat panel: sorbet header, lemon badge, coloured progress and bubbles (2026-11-01)

Chosen by the user from the halo mocks (option A combined with C; canvas board "Chosen: A + C, progress colours, lemon-to-sand messages"). Implemented in `lemon_chat_panel.dart` and `chat_bubble.dart`.

- **Header:** a sorbet gradient header with a thin lemon ring and soft glow around Lemon. The wordmark's lemon (`LemonMark`) sits on her shoulder as a badge. The green online dot stays, and the word "Online" is not added. The panel edge is sand.
- **Step progress:** grey (`stepTodo`) before a step, warm sand (`stepCurrent`) while it waits for an answer, and lemon once answered. Grey and sand are close in lightness, so answered steps also get a tick and the current label is bold. Each step's semantics label still says "done", "current step" or "to do".
- **Bubbles:** the traveller's bubbles fade lemon → pale lemon → sand with `lemonInk` text. Lemon's fade sky blue (`cta`) → lilac with `ctaInk` text. Both use weight 600 on a pale cream message area. This supersedes the white Lemon bubble and the sky blue traveller bubble.
- **Chat buttons:** the panel's buttons, send button and message box stay sky blue (DECISIONS 041 and 043).

## 046 - Search pages back to sky blue; Outfit on named controls; shuffled tip names (2026-11-01)

After seeing the Flutter build, the user found peach and lilac cards next to sky blue buttons looked unnatural.

- **Colours:** Hotels and Attractions return to the sky blue look Flights has, with no `PageTone`. That covers the banner, search card, fields, "Find Hotels" and "Discover Attractions", the how-to steps (back to their rotating tints), the hotel bed tiles and the per-category attraction tiles. The rest of DECISIONS 044 stays: the pre-plan itinerary is sand, and every search page ends with the warm sand and lemon "Plan with Lemon" band. `PagePalette.peach` and `PagePalette.lilac` remain in `app_theme.dart` but are unused by pages.
- **Bold text:** text that sets its own style without naming a font falls back to Roboto, which Flutter on the web shows without a real bold, so it looked slim. The user chose the bundled Outfit font for these controls only: the Find Flights, Find Hotels and Discover Attractions buttons (700); the Flights Departure and Travelers values and the Hotels search radius value (600, up from 500); the "Copy itinerary" button (700); and the top navigation tabs (600, or 700 for the open tab, at 14.5 px). Any other text change waits for the user to ask.
- **Tip names:** a planned day no longer labels its stops' tips in the same order every day. `tipLabelFor(day, stop)` in `itinerary_view.dart` picks from the 24 orderings of the four labels, shuffled once with a fixed seed. The result is stable across rebuilds, no two days in a row share an order, and no label repeats within a day's first four stops.

## 047 - Three colours only; the mock's search button; Outfit in the Discover hero (2026-11-01)

**Partly superseded by 048:** the three-colour rule covers Flights, Hotels and Attractions only, and the Hotels and Attractions search buttons are back to their earlier pill style.

The user asked that pages use only the app's three colours, calm sky blue, lemon yellow and warm sand, balanced between them. They also asked for the mock's search button design and the mock's Outfit type in the Discover hero.

- **Colours:** `AppTheme.softTones` is now sky blue, lemon (new `lemonTint` and `lemonAccent`) and warm sand; peach and lilac are gone from it. Anything that rotates through it follows: hotel bed tiles, attraction tiles and tags, flight carrier dots and itinerary days (which now repeat every three days). `HowToSteps` outside a `PageTone` uses sky, lemon and sorbet. The Discover hero's step pills are sky, lemon and sand. `PagePalette.peach`, `PagePalette.lilac`, `AppTheme.peach`, `peachAccent` and `lilacAccent` were removed. `AppTheme.lilac` remains only as the far end of Lemon's chat bubble fade (DECISIONS 045). The chat panel was not part of this request.
- **Search button:** the shared `SearchButton` in `page_parts.dart` replaces each page's own button. It is sky blue (`cta`) with `ctaInk` text in Outfit 800 at 16 px, has 18 px corners, a soft blue shadow (the mock's rgba(110,160,220,.4), 10 px blur, 3 px down) and is at least 66 px tall. On Flights it takes its own full-width row under the fields. On Hotels and Attractions it ends the field row at the fields' height, at least 240 or 280 px wide. Attractions now uses the search icon, as in the mock. `searchRowFits` scales each page's row breakpoint (900, 700, 600 px) by the text size, so large text stacks the fields with the button underneath.
- **Discover hero:** the eyebrow, subtitle, step pills and both buttons use Outfit; "Plan a trip with Lemon" is Outfit 800 at 16 px and "Explore places" Outfit 700. The title stays Unbounded and Lemon's greeting bubble stays Fredoka.

## 048 - Three colours on the search pages only; chat bubbles swapped; KI-28 fixed (2026-11-01)

The user clarified that the sky blue, lemon and warm sand rule from 047 was meant for the Flights, Hotels and Attractions pages only.

- **Itinerary and Discover keep their earlier colours.** Itinerary days rotate sky blue, peach, warm sand and lilac again, and the planned itinerary's how-to steps use sky, peach and lilac. The Discover hero's step pills are sky, peach and lilac, as in the approved mock. `AppTheme.peach`, `peachAccent` and `lilacAccent` are back. `softTones` stays sky blue, lemon and sand; only the search pages use it. `HowToSteps` takes a `tints` list, which defaults to `searchTints` (sky, lemon, sorbet); the itinerary passes its own.
- **Search buttons:** the rounded `SearchButton` made the Hotels and Attractions search bars look bulky, because the row stretched the fields to the button's height. Those two pages are back to the theme's sky blue pill button (Outfit 700) at its natural height in a plain row. Flights keeps `SearchButton` on its own row under the fields. `searchRowFits` stays on all three, so large text stacks the fields.
- **Chat bubbles** (replaces the colours in 045): Lemon's bubbles fade lemon yellow → pale lemon → warm sand with `lemonInk` text (over 10:1). The traveller's fade sky blue (`cta`) → lilac with `ctaInk` text (7.5:1 or more). The shadows swapped to match.
- **KI-28 fixed:** `ResultsBanner` was a fixed 150 px tall. It is now at least 150 px and grows with its text. The photo and shade are `Positioned.fill` layers behind a `Container` with `minHeight: 150`, 18 px top and bottom padding, and the text centred on the left.

## 049 - Attraction tiles rotate; compact one-field search; larger nav tabs (2026-11-01)

- **Attraction tiles:** colours came from each result's category (`toneFor`). A search that returns only "Sightseeing" therefore showed every card in sky blue. Tiles and tags now rotate sky blue, lemon and sand by card position, as hotel tiles do. `toneFor` still colours the flight carrier dots.
- **One-field search card:** on Attractions, the only search page with a single field, the search card is capped at 760 px and sits to the left in the banner instead of stretching across it. Pages with two or more fields keep the full width.
- **Nav tabs:** the top navigation labels went from 14.5 to 16 px (Outfit, 600, or 700 for the open tab) and their icons from 18 to 20 px.

## 050 - Nunito for Lemon.ai chat messages and typing (2026-11-01)

The chat's message bubbles and typing boxes fell back to Roboto, which on Flutter web shows no real bold and looked slim. From the options offered (Nunito, Outfit, Lexend), the user chose **Nunito**: rounded and friendly to match Lemon's voice and her Fredoka tips, and readable at chat size.

- **Files:** `assets/fonts/Nunito-400/600/700/800.ttf` are static Latin-subset TTFs from Fontsource (jsDelivr CDN), the same source used for Nunito in DECISIONS 021. The licence, `OFL-Nunito.txt` (SIL OFL 1.1), sits beside them. They are registered as the `Nunito` family in `pubspec.yaml`, with no new package, so tests stay offline. Characters outside the Latin subset fall back to platform fonts.
- **Where:** `AppTheme.chatFont`. It covers both voices' message bubbles (`chat_bubble.dart`, weight 600) and the panel's three typing boxes: destination, number of travellers and other interests. In those boxes, `_ChatTyping` in `lemon_chat_panel.dart` sets the typed text (600), label, hint, helper and error text.
- **Unchanged:** the panel title (Poppins), the subtitle, the step labels, the buttons and the interest chips.
- Nunito has no italic file, so the few italic bubbles use a slanted regular.

## 051 - One role per colour on result cards; Lemon's hover card matches the chat (2026-11-01)

The search pages' result cards now give each colour one job instead of rotating colours.

- **Flights:** every carrier circle is sky blue (`cta`). The "Direct" pill is lemon (`lemonAccent` with `lemonInk`), and stop pills stay warm sand. "Lowest price" is unchanged.
- **Hotels and Attractions:** every icon tile is lemon (`lemonAccent`), and so is the attraction category tag (`lemonTint` with a `lemonAccent` edge), as it always matched its tile. The "View location" button is the existing sky blue pill, and the card number stays sand. This supersedes the card rotation in 049.
- `AppTheme.softTones` and `toneFor` had no callers left, so they were removed.
- **Lemon's hover card** (`lemon_bubble.dart`), the launcher grown on hover or focus, now matches the chat panel:
  - The chat header's sorbet fade, a sand edge and a sand-tinted shadow.
  - "Hey, explorer!" in Poppins 700 `sandInk`, with the invitation in Nunito 600 `sorbetInk`.
  - "Let's plan together" as a sky blue pill label (the whole card stays the one button).
  - Lemon's round avatar on a sorbet disc with the panel's lemon ring and glow, in place of the full-length picture.
  - The small round launcher and its pulse are unchanged.

## 052 - Classify attractions from Geoapify's full category list (2026-11-01)

Almost every attraction landed in the "Sightseeing" chip. The backend returned only the first entry of Geoapify's per-place `categories` array. That is often a broad parent such as `building`, though Geoapify's real ordering was not checked against a live response. The app then classified from that one string.

- **Backend** (`routers/places.py`): each attraction carries `categories`, the full list of strings. `category` is kept as the first entry for older clients. The Geoapify request adds `heritage` (`ATTRACTION_CATEGORIES` = `tourism.sights,tourism.attraction,entertainment,heritage`), so castles, monuments and protected sites without a tourism tag are found. `limit` (20) and `radius_km` are unchanged. The response is a plain dict, so no Pydantic model was involved.
- **App** (`AttractionItem` in `models/travel_models.dart`): `categories` is parsed from JSON. When it is absent (older responses or cache entries), the list falls back to `[category]`. `AttractionItem.classify`, a pure static helper, checks every entry, most specific first:
  1. any entry starting with `entertainment` → Entertainment;
  2. any entry starting with `heritage` or containing `culture` → Culture & Heritage;
  3. any entry starting with `tourism.sights` or `tourism.attraction` → Landmark & Sights;
  4. otherwise Sightseeing.
- Because every entry is checked, the result doesn't depend on Geoapify's order. Heritage now outranks sights, where the old single-string check ranked sights first. A castle tagged both is Culture & Heritage, and a museum tagged `entertainment.museum` is Entertainment.
- Chip labels and icons in `attractions_view.dart` are unchanged.
- **Side effect:** the itinerary builder JSON-dumps the attractions response into the plan prompt, so the new lists add some prompt length. Plan output and the prompt's instructions are unchanged.

## 053 - One attractions search per chip; white Lemon bubbles; full hover avatar; compact search cards (2026-11-01)

**Attractions (KI-29).** After 052 the user still saw almost no variety. The backend and app were both running the 052 code (uvicorn reloaded at 17:38, the app started at 20:29). The Paris response the app had already fetched, read back from the local cache with no new Geoapify call, held 14 named places. Nine were memorial plaques or monuments. None came from `entertainment`, and none were museums. One search for 20 places in no useful order is dominated by whatever is most numerous. The user chose one search per chip.

- **Backend** (`routers/places.py`): `ATTRACTION_GROUPS` holds four Geoapify searches, run at once: `tourism.attraction`; `tourism.sights`; `heritage,entertainment.museum,entertainment.culture`; `entertainment`.
  - Each search asks for 20 places, nearest to the centre first (`bias=proximity`).
  - Up to 10 are kept per search. A place already listed by an earlier search is skipped. Plain memorials (`tourism.sights.memorial` with no more specific memorial, heritage or entertainment tag) go last.
  - A search that fails is logged, with type and status only, as httpx messages carry the URL and `apiKey`. The rest are returned without being cached, so the next request tries again. If every search fails, the first failure becomes the error, as before.
  - This is up to 4 Geoapify requests per city and radius on a cache miss, where there was 1.
- **App** (`AttractionItem.classify`): the chips now match the four searches. The page tip already says Culture & Heritage is "great for museums and monuments", so museums move there from Entertainment:
  1. `heritage`, `entertainment.museum` or anything containing `culture` → Culture & Heritage;
  2. other `entertainment` (zoos, theme parks, cinemas) → Entertainment;
  3. `tourism.sights` (monuments, towers, ruins, memorials) → Landmark & Sights;
  4. everything else, including `tourism.attraction` artworks, viewpoints and fountains → Sightseeing.
- This supersedes 052's ranking, which put entertainment first and counted `tourism.attraction` as a landmark, and its single search.
- **Prompt:** up to 40 places, not 20, now reach the plan prompt as context. Plan output and instructions are unchanged.

**Lemon's chat bubbles** are white, with a pale lemon border (`lemonBubbleEdge`), a 4 px `accentLemon` stripe on the left and the same soft lemon shadow. Yellow emoji were lost on the lemon-to-sand fade. The user asked for a recommendation, and this keeps Lemon's colour on the edge while the emoji sit on white. Text stays `lemonInk`. The traveller's sky-to-lilac bubble is unchanged. This supersedes 048's Lemon bubble; `AppTheme.lemonBubble` is removed.

**Lemon's hover card** shows her full, uncropped avatar again (`lemon_avatar.png`, 88 × 116, `BoxFit.contain`), as before 051. The user preferred it to the 051 circle crop. The rest of the 051 look (sorbet fade, sand edge, fonts, sky blue call to action) stays.

**Search cards:** `SearchCard` takes an optional `maxWidth` and left-aligns itself within it. Attractions keeps 760, Hotels is 940 and Flights 1080. Those still leave room for every field on one row at desktop width: 700 and 900 px inside the card. Narrow screens and large text stack as before. This extends 049's compact card to Hotels and Flights, at the user's request.

## 054 - Flights search button beside the fields (2026-11-01)

The user asked to move search buttons beside the fields wherever a card has several fields, to remove empty space. Hotels and Attractions already did this, so only Flights changed: its "Find Flights" `SearchButton` no longer takes its own full-width row under the fields.

- **Wide** (row fits 960 px inside the card, scaled for large text): From, swap, To, Departure, Travelers and the button sit on one row. The card keeps its 1080 cap (1052 px inside).
- **Medium** (fits 600 px): two rows. From, swap and To on the first; Departure, Travelers and the button on the second.
- **Narrow** (phones, large text): stacked as before, with the button last.

This supersedes the full-width Flights button row from 047/053.

## 055 - Lemon's chat bubbles: plain white, no yellow outline (2026-11-01)

The user found the 053 bubbles unattractive: the 1.5 px lemon border, the 4 px `accentLemon` stripe and the lemon shadow put a yellow frame round every message, so lemon took far more than its 10% share, and the 🍋 emoji sat right beside a stripe of the same yellow.

- Lemon's bubble is plain white with a 1 px warm hairline (`lemonBubbleEdge`, now `#EDE6D6`) and a soft warm-grey shadow (`bubbleShadow` at 8%, blur 10). The stripe and its clip are removed. Her yellow stays on her avatar, the header badge and the wordmark.
- White gives yellow, blue and other emoji the most contrast. Her text is `chatText` slate (9:1 on white) at Nunito 400, matching the app's slate-blue ink, where it was near-black `lemonInk` at 600.
- The traveller's sky-to-lilac bubble is unchanged apart from a slightly softer shadow; its text stays `ctaInk` at 600.

This supersedes 053's Lemon bubble.

## 056 - One button font, slightly taller and solid buttons (2026-11-02)

The user found button fonts inconsistent, some buttons a little short, and some flat and dull next to "Find Flights" (sky fill, soft blue shadow, extra bold label), which they named as the model for every button.

- **Font:** every button label uses `AppTheme.buttonFont` (Outfit) through `AppTheme.buttonText()`: 800 on filled buttons (theme `ElevatedButton`, `SearchButton`, `planWithLemonStyle`), 700 on outlined, text and pill buttons. The theme sets it whether or not a body font is given, so the light theme (app frame, Lemon's chat panel, dialogs) no longer falls back to Roboto. Hotels' and Attractions' search buttons move from 700 to 800 to match Find Flights. Outfit was chosen because it already carries the search buttons, nav tabs and trip pages and is bundled at 400–800.
- **Solid:** `AppTheme.solidElevation()` gives filled buttons a resting shadow (elevation 3, 6 on hover or focus, 0 when disabled) in `ctaShadow` (the Find Flights blue at 50%), or warm sand on "Plan with Lemon". Outlined partner buttons keep their pale sky fill with a deeper `ctaEdge` outline (`#9CC2EA`) and a faint shadow (1, 3 on hover). Result-card pills ("View location") get a light shadow too. `SearchButton` keeps its own decorated shadow (elevation 0 on the button itself so it isn't doubled).
- **Height, a few px only:** theme filled buttons 14 → 16 px vertical padding with a 48 px minimum; outlined 12 → 14 (44 minimum); pills 12 → 14; "View details" 14 → 15; Itinerary's "Copy itinerary" and "Change with Lemon" 16 → 17; chat panel actions 52 → 54 and 48 → 50 tall. Buttons that were already 18–22 px padded are unchanged.

Colours and shapes are unchanged: sky blue stays the pressable colour and sand stays "Plan with Lemon" (044, 047, 048).

## 057 - Lemon.ai chat polish, Lexend, hover card, centred search, filled partner button (2026-11-02)

Built from the canvas page "Chat panel polish" (https://claude.ai/artifact/L5nqavbdcThi8BAWxF8LCj), which the user approved, plus the user's follow-up requests. New pieces live in `lib/widgets/chat_parts.dart`. Every animation is skipped when animations are turned off.

- **Messages rise in:** each new message fades in while rising 12 px (380 ms). Messages already there when the panel opens show at once. Each step's controls rise in 120 ms after Lemon's question.
- **Typing dots:** while Lemon reads the destination (`/lemon/chat`), three bobbing dots show in a Lemon bubble, replacing the spinner and "Finding your destination…". Screen readers hear "Lemon is finding your destination…". The guided steps answer locally and at once, so they get no artificial delay.
- **Planning card:** while the plan builds, a sorbet card replaces the spinner. It holds Lemon's face floating in a pulsing lemon ring, "Lemon is planning your trip", a status line that changes every 2.5 s and holds on the last one, a sliding lemon-to-sky bar, and "Longer trips can take over a minute. You can keep browsing while you wait." The lines run on a timer, not on progress (the backend sends none), so they stay general. Browsing is safe because the controller lives in `HomeScreen`, not in the panel.
- **Pill chat box:** the destination field is a white pill with the sky blue send button (arrow up) inside it, a deeper sky edge and a soft sky glow while focused. The hint is "Try Kyoto, or a beach trip in Bali". The send button is enabled whenever Lemon can take a message, and an empty box sends nothing.
- **Budget pills (`OptionPill`):** icon tile, Outfit label, Lexend hint ("Simple stays, local food, free sights" / "Mid-range stays and a few treats" / "Top hotels and special experiences") and a tick circle. White with a pale sky edge at rest, lifting on hover, solid sky blue with a shadow once picked.
- **Interest pills (`InterestPill`):** each interest has an icon. Picked pills fill sky blue with a shadow, and the icon pops into a tick. A "N picked · tap again to remove" line appears under them. The "Other interests" field is keyed so it keeps focus as that line and the hint come and go (see KNOWN_ISSUES).
- **Lexend for Lemon's words:** `AppTheme.chatFont` is now Lexend (bundled 400/600/700 Latin TTFs from Fontsource, OFL licence in `assets/fonts/OFL-Lexend.txt`), compared against Nunito, Figtree, Plus Jakarta Sans, DM Sans and Atkinson Hyperlegible on the canvas. It is used for both bubbles, the typing boxes, pill hints, the planning card and the hover card's invitation. This supersedes 050. Nunito is no longer in `pubspec.yaml`, and its font files were deleted at the user's request.
- **Hover card:** the sky blue "Let's plan together →" pill is removed, since the whole card opens the chat. The title is "Hi, I'm Lemon!" in Fredoka 700 (it was "Hey, explorer! ✨" in Poppins; the sparkle had read as an AI symbol before), and the invitations are rewritten in Lexend 400. Lemon's full, uncropped avatar stays (053).
- **Search cards centred:** `SearchCard` keeps its width caps (Attractions 760, Hotels 940, Flights 1080) and now centres within the page instead of aligning left.
- **"Explore places"** (Discover hero) was white. It is now filled with its own outline colour (`ctaEdge`) and has the filled-button shadow (3, 6 on hover). The user kept "Sign in" white.

**Approved:** the user reviewed the running app on 2026-11-02 and approved this round, including 056's buttons ("i like it now").

## 058 - Lemon.ai feature roadmap: smarter intake, grounded plans, photo/link/video place detection (2026-11-02)

Status: **accepted direction, not implemented.** Agreed in discussion with the user. No code was changed. Each phase still needs its own go-ahead, and dependency changes and live provider calls need separate authorization (AGENTS.md). The user referenced Paths-style planners, where the traveller gives simple details and the AI does the rest.

**Principle:** "fully reliable" comes from checking the model's output, not from trusting it. Every phase adds a check around the model: schema validation, geocoding, the user's confirmation, or labelled fallbacks.

**Phase order (agreed):**

1. **Smart intake and a garbage gate.**
   - **One-shot extraction:** one free-text message fills as many fields as it can. Example: "4 days in Tokyo with my wife next month, we love ramen, mid budget".
   - **Visible inference:** "me and my wife" → 2 travelers, "long weekend" → 3 days, "honeymoon" → pace and budget, "with kids" → family-friendly. Each inferred value shows as an editable chip ("I assumed 2 travelers"), never a silent guess.
   - **A layered gate:**
     - a free local pre-filter for empty text, keyboard-mash, repeated characters, spam links and obvious prompt-injection phrases;
     - an `intent` from the model (trip request / small talk / off-topic / gibberish / unsafe), each with its own reply;
     - a destination that must resolve through the shared geocoder (Geoapify since 039). Unresolvable places are refused, not planned.
   - **Ambiguous places** ("Paris", "Georgia") ask which one is meant. This picks up KI-25 option 2.
   - The local heuristic parser stays as the mock/offline fallback, with simpler versions of the same rules.
   - **Modes:** the user wants **free-text mode and guided-controls mode as two separate modes the traveller can choose**. How they're split will be designed when phase 1 starts.
2. **A grounded itinerary.**
   - Activities can carry an optional Geoapify `place_id` and coordinates. Model-named places that can't be matched are flagged as unverified.
   - A `must_visit` list on `TripRequest` (from chat, Attractions, or media detection), which the validator checks is in the plan.
   - Nearby places grouped on the same day; weather-aware placement (outdoor activities on dry days).
   - A pace setting (relaxed / balanced / packed) replaces the fixed "3–5 activities". It changes how full a day is, not how detailed it is (042's rule against shortening content stands).
   - Regenerate one day / swap one activity / adjust a day, reusing the per-window generation.
   - The mock label stays honest and visible.
3. **Photo detection and link previews (cheap, works with any provider).**
   - **Uploads:** photos/screenshots → a vision model returns candidates: name, city, country, confidence and *evidence* (visible signage, distinctive landmark).
   - **Links:** read the post's public preview data (oEmbed / Open Graph: caption, author, thumbnail). Never download or scrape the video itself. The caption is often enough on its own (text extraction). If it isn't, the thumbnail goes through photo detection. If that fails, Lemon asks for an upload or screenshot. Private or blocked posts are not worked around.
   - **Every candidate** is checked against Geoapify, and **the user confirms** before it joins `must_visit`. Nothing is added automatically.
   - **A place in another city** is offered as a day trip, or Lemon asks. Several places in one post → a list. Nothing recognisable → said plainly.
4. **Video detection, frames first.**
   - The app pulls 4–6 still frames and sends them as images (about 1–2k tokens instead of about 8–10k for a 30-second clip as raw video). Images work on more providers (Groq `llama-4-scout` takes images), so the existing auto chain shares the load instead of draining Gemini's free tier.
   - Raw video only as a last resort, through Gemini at low resolution, capped at about 60 s.
   - Results cached by file fingerprint, and a daily cap per device on media analysis.
   - Uploaded media is not kept (deleted from provider file storage after analysis), and the UI says so.
5. **Extras:** saved trips (device storage first, since there's no database), a map of each day, export/share (PDF, .ics, link), and follow-up questions after the plan exists.

**Fallback agreed by the user:** if phases 3–4 turn out to need paid tiers, phase 5 goes before them. The current assessment is that they don't, provided frames and link previews come first. The hard part is pulling frames from video in Flutter web, which is engineering effort, not a tier limit.

**Research notes (2026-11-02 web search, not verified against official pages; confirm before building):**
- Gemini counts video at about 258 tokens per frame at 1 fps, plus audio. Google no longer publishes free-tier quotas as fixed numbers; they show per project in AI Studio.
- A Meta developer blog post (2026-06-15) says Instagram/Facebook oEmbed can be called without an access token; Meta's older oEmbed docs still say a token is needed.
- TikTok's public oEmbed endpoint is believed to need no auth, but the search didn't confirm it.
- Gemini can take public YouTube URLs directly, but that spends video tokens.
- Groq documents `meta-llama/llama-4-scout-17b-16e-instruct` for image input; free-tier limits weren't found from an official source.

**Known prerequisites and risks:**
- `google-genai==0.3.0` is old and likely needs an upgrade for file uploads (a dependency change).
- KI-14 (Gemini 404) must be resolved before relying on Gemini for media.
- Flutter needs a file-picker package (a dependency change); frame extraction on web needs work in the browser (HTML video + canvas) or a package.
- Server-side frame extraction would need ffmpeg (a new tool).
- KI-07 (broken venv) slows backend work.
- New request/response fields must stay aligned between `travel_backend/models/` and `lib/models/`.

## 059 - Lemon.ai phase 1: free-text mode by default, guided mode on request, garbage gate (2026-11-04)

Status: **implemented, offline-tested; not yet seen in the running app or with live providers.** Phase 1 of 058. Design agreed with the user before building.

**The user's choices:**
- **Free text is the default mode.** Guided controls are the second mode.
- **Fallback asks first.** When free text struggles, Lemon offers "Switch to guided" / "Keep typing" and switches only on a yes. This also covers the AI being down.
- **Left-out details:** travelers, budget and interests are optional. Lemon says which ones were left out and what it will use (1 traveler, Comfortable/medium budget, surprise-me interests); the brief tags them "Default" so they can be changed before generating. Guesses from wording are tagged "Assumed".
- **Switching:** a ⚙ gear in the chat header opens a settings menu (Chat mode: Free text / Guided), built so more settings can join later. Plain words ("switch to guided", "use the buttons", "let me type") also switch.
- **Remembered:** the mode is saved on the device with `shared_preferences` (dependency added with the user's authorization).

**Backend (`/lemon/chat`):**
1. `prefilter` on the latest user message: empty or punctuation-only, repeated characters, keyboard-mash, links (phase 3 will read link previews; for now Lemon asks for the place in words), prompt-injection phrases. A flagged message never reaches a provider. Digits pass ("2", "2026-12-01").
2. One-shot extraction prompt: every field at once, `intent`, `inferred`, no questions about optional fields, vague dates ("next month") left null and asked about, destination kept as written (no added country, so the ambiguity check sees what the traveller said).
3. `_finalize` checks whatever the extractor returned: dates (valid, from today, ordered, at most 30 days), travelers 1–20, budget normalised to lowercase, interests bounded like `TripRequest`, `next_field` recomputed, `ready` only with all required fields and no problem. A problem replaces the reply with a fixed question.
4. `services/place_check.py`: the destination goes through the shared `_geoapify_search` (lazy import, 24 h cache, 8 s limit). No results → refused. The same exact name in several country/state groups → `ambiguous` with up to 4 labels. A name with a comma is taken as already specific. Lookup failure → `unverified`, and the chat goes on (the plan step geocodes again). Explicit `mock` skips the check so it stays offline.
5. The local parser (mock and auto's fallback) got the same rules in simpler form: month names, ranges ("Dec 3-7", "3 to 7 December", across a year end), lengths (days, nights, weeks, weekend, long weekend), "this/next weekend", "tomorrow"; travelers from "me and my wife", "solo", "family of 4", "with 2 friends", "honeymoon"; budget synonyms ("mid-range", "backpacking", "luxury"); interests by keyword onto the app's eight labels, plus "Family-friendly" (kids) and "Romantic spots" (honeymoon); intents by phrase; corrections ("actually", "make it") win; a place picked from the options ("Paris, France") replaces the earlier name.
6. New response fields: `intent`, `inferred`, `destination_status`, `destination_options`, `fallback_used`. Models cannot set the last three.

**Frontend:**
- `LemonChatController` takes a `ChatMode` and a `ChatSettingsStore`. With no mode given it starts in free text and applies the saved mode if it arrives before the traveller speaks.
- Free text merges non-null fields (a value the model drops is kept), drops rejected turns (gibberish, unsafe, off-topic) from the history, shows the brief once destination and dates are known, and plans on a typed "yes" only when the brief was already up.
- Offers to switch: the backend's local parser answered (once per session after "Keep typing"), the traveller sounds unhappy, or two turns stuck on the same required detail. Never an automatic switch.
- Switching keeps every detail and continues from the next missing one. Guided mode is unchanged apart from not-found and which-one handling for the destination.
- Panel: gear menu, free-mode chat box always visible while chatting, place option buttons, the offer's two buttons, brief tags, "Keep it as is" to close an opened brief item, and a progress bar that ticks whatever is known in free mode.

**Not done (later phases or follow-ups):** live checks of extraction quality and of Geoapify's same-name results; pace setting and `must_visit` (phase 2); link previews (phase 3).

## 060 - One provider writes the whole plan; a failure restarts it from day 1 (2026-11-04)

At the user's request. A plan came back with demo days 1–3 ("Placeholder demo activity") and real days 4+ from a different provider. Cause: each 3-day window ran its own Groq → Gemini → OpenRouter chain, so one window could exhaust every provider and fall to the demo while its neighbour succeeded, and the two were stitched together. The user wanted the earlier behaviour back: if a provider can't finish, start over with the next one instead of carrying on where it was cut off. Supersedes the per-window auto fallback of 015 and the "any mock window labels the whole plan mock" rule; the timing values of 042 stay, but apply per provider turn.

1. **One provider at a time** (`itinerary_builder._whole_plan_with_fallback`). With `auto`, Groq gets every window first, still 3-day windows, 3 at a time. Each window is one call through the new `auto_provider.attempt_provider`, which keeps the same streaming limits, validation, failure kinds and cooldowns as before. `AutoProvider.generate_json` now uses the same helper, so chat is unchanged.
2. **Any failed window ends that provider's turn.** Its other windows are cancelled at once, its cooldown is recorded (`record_failure`), everything it wrote is dropped, and the plan restarts from day 1 with the next provider. **No retry within a provider** (the user's choice over one corrective retry). Providers already cooling down are skipped.
3. **Fresh budget per provider** (the user's choice over one shared budget). Each turn gets the full 75 s per wave of windows (`generation_budget_seconds`) again. The frontend wait becomes 25 s + 75 s × waves × 3 for `auto` (250/475/700/925 s for 1–9/10–18/19–27/28–30 days); a single named provider keeps one turn (100/175/250/325 s), in `LemonApiService.planTimeoutFor`.
4. **All-or-nothing demo.** If every provider fails, the whole plan is the demo itinerary (`provider_used: "mock"`), never a mix. Direct providers (`groq`, `gemini`, `openrouter`) keep one corrective retry per window, and any window that still fails fails the request (502) as before.

Consequences: a plan is now always from a single provider. A provider that finishes 8 of 9 windows and fails the last throws all of its work away, and spends quota for it. Worst-case waits are three times longer (about 4 minutes for a trip of up to 9 days, about 15 minutes for 30 days), reached only when providers fail slowly; fast failures (no key, 429, quick bad output) restart at once. The app shows the same planning card throughout and can't say which provider is writing. Live behaviour is not verified (KI-27).

## 061 - A rate-limited window waits and retries; 503 is a short bench (2026-11-05)

At the user's request, after the first live run of DECISIONS 060 gave a whole demo plan. Backend log: Groq `429 rate_limit` after 0.7 s (Retry-After 33 s), Gemini `503 unavailable` after 4.7 s (benched 5 min), OpenRouter (`openrouter/free`) used its full 75 s window without finishing (`failure=budget`). Groq's free tier limits tokens per minute, and three windows sent at once push it over, so one window gets a 429 while the others would succeed. Under 060 that single 429 threw away all of Groq's work. The same pattern most likely produced the original mixed plan (days 1–3 demo, 4+ real).

1. **Rate limit inside a provider's turn** (`itinerary_builder._whole_plan_with_fallback`, the user's choice over sending windows one at a time). A window that gets a 429 waits the Retry-After time and asks the same provider again; its sibling windows carry on. It only waits if at least 15 s of the window's 75 s budget would be left afterwards (`RATE_LIMIT_MIN_LEFT_SECONDS`), and it may wait more than once while that holds. No cooldown is recorded while waiting. A 429 without Retry-After (treated as 5 minutes), a wait that doesn't fit, or any other failure ends the turn as in 060. Broken output still restarts at once (060's "no retry").
2. **503 "unavailable" cools down for 30 s** (`auto_provider._classify_failure`, kind `unavailable`), like a timeout, instead of 5 minutes. Supersedes 503 in 042's hard-failure list; 401/403, 404, a missing key, construction and other call errors keep 5 minutes. This also applies to chat.

Consequences: a rate-limited window adds its wait (about 33 s on Groq's free tier in the log) to the plan time, still inside the existing budgets, so the frontend wait is unchanged. Gemini returns 30 s after an overload instead of sitting out the next 5 minutes. Not addressed: `openrouter/free` routing to models too slow for a 75 s window (KNOWN_ISSUES 2026-11-05).

## 062 - Plan reliability: diagnosis and fix order agreed, decisions pending (2026-11-05)

Status: **all five steps done on 2026-11-05: step 1 as DECISIONS 063, steps 2–5 as 064–066; follow-up retry as 067.** The user asked for the changes so far and the causes to be written down, to go through the fixes one step at a time next session.

**What changed since commit `ed0f4d3` on the plan path (all uncommitted):**
1. DECISIONS 060: with `auto`, one provider writes the whole plan; any failed window restarts the plan from day 1 with the next provider; all failing gives a whole demo plan; the frontend waits 25 s + 3 × 75 s × waves. **This is what turned the earlier half-real plan into an all-demo one**: before it, each window ran its own Groq → Gemini → OpenRouter chain, so Groq's lucky window survived beside a demo window.
2. DECISIONS 061: a 429'd window waits Retry-After and retries the same provider (confirmed working in the user's third log: waits of 38 s, then 2 s, then accepted); 503 benches for 30 s instead of 5 min.
3. Diagnostics only (no behaviour change): `error_details` logs mid-stream `code`/`type` labels as `provider_code`/`provider_type`; a failed plan window logs its first day and prompt sizes.
Phase 1 (DECISIONS 059, chat) does not touch plan generation.

**Diagnosis from the user's third live log (Busan, 4 days, 2 windows):**
- **Groq:** `429 rate_limit_exceeded` (`provider_type: tokens`) twice, then `APIError` `json_validate_failed` (`invalid_request_error`) at 7.5 s, classified `hard` (5 min) because it has no HTTP status. Each window's prompt is 12,875 + 3,022 characters (roughly 4–5k tokens); Groq's free tier for `gpt-oss-120b` is reportedly about 8k tokens per minute, so two windows at once exceed it before any answer. After the waits, Groq's JSON mode rejected the model's output mid-stream.
- **Gemini** (`gemini-3.6-flash`): `503 unavailable` on three plans in a row, so not a passing blip: the model is persistently busy or limited for this key.
- **OpenRouter** (`openrouter/free`): out of the 75 s window budget on three plans in a row.
The provider failures existed before 060; 060 removed the partial result that hid them.

**Agreed order for next session, one step at a time, each needing the user's decision:**
1. Keep "one provider for the whole plan" (060), go back to per-window fallback, or a middle way (real providers may share windows; demo only for the whole plan, and only if a window can't be written at all).
2. Treat Groq's `json_validate_failed` as bad output (30 s bench), not a hard 5-minute failure.
3. Groq's tokens-per-minute limit (the main fix). Options: Groq windows one at a time, less context per window (conflicts with 042's no-prompt-trimming rule, so the user's call), or a paid Groq tier.
4. Gemini: find why it is always 503 (model name or key limits); needs one live check (quota).
5. OpenRouter: pin a specific faster free model in `.env` instead of `openrouter/free` (the user's `.env`; the agent doesn't read it).

## 063 - Each plan window falls back on its own; demo only for the whole plan (2026-11-05)

Step 1 of 062, the user's choice of the middle way (option c) over keeping 060 or going back to plain per-window fallback. Supersedes 060's "one provider writes the whole plan" and "restart from day 1"; keeps 060's all-or-nothing demo and 061's rate-limit wait.

1. **Per-window chain** (`itinerary_builder._window_with_fallback`). With `auto`, every 3-day window tries Groq → Gemini → OpenRouter on its own, still 3 at a time, skipping providers that are cooling down. A failure on one provider (other than a 429 wait that fits, per 061) moves that window straight to the next provider; there is still no corrective retry within a provider.
2. **Running siblings finish** (the user's choice over moving them all over). A failed window records its provider's cooldown (`record_failure`), so windows that start later skip it, but windows already running on that provider carry on and their days are kept. A sibling's later success does not lift a bench recorded during the same plan.
3. **Fresh 75 s per provider per window** (the user's choice over one 75 s shared across providers). The overall cap for `auto` is one plan budget per provider in the chain (3 × 75 s × waves), so the frontend wait of 25 s + 3 × 75 s × waves (060) is unchanged.
4. **All-or-nothing demo.** If any window fails on every provider, its other windows are cancelled and the whole plan is the demo itinerary (`provider_used: "mock"`). Real and placeholder days are never mixed.
5. **Labels.** `provider_used` is the provider's name when one provider wrote every window, and `"auto"` when several did; the summary comes from the first window. Named providers, `mock` and chat are unchanged.

Consequences: a plan can now be written by two or three different models, so style may differ between windows. One bad window no longer throws away the other windows' work, and Groq's per-minute token limit (step 3) costs only the windows it hits. Not verified live (KI-27, KI-32).

## 064 - Groq's `json_validate_failed` counts as bad output (2026-11-05)

Step 2 of 062; the user authorized steps 2–5 without asking each. A mid-stream OpenAI-compatible error with `code == "json_validate_failed"` (no HTTP status) is now kind `invalid_output` with the 30 s bench, not `hard` with 5 minutes (`auto_provider._BAD_OUTPUT_CODES`). Other unlabelled call errors stay hard. Applies to chat as well. The live cause of this error turned out to be the reasoning budget (066).

## 065 - Groq and Gemini take one plan window at a time (2026-11-05)

Step 3 of 062. Under `auto`, `itinerary_builder.PROVIDER_MAX_CONCURRENT_WINDOWS = {"groq": 1, "gemini": 1}`: windows queue for that provider (one semaphore per plan), and each window's 75 s starts when it gets the provider, not while it queues. A window that was queued re-checks the cooldown and skips the provider if it was benched meanwhile. OpenRouter keeps three at once. Chosen over trimming context (forbidden by 042) and a paid tier (the user's cost).

- **Groq:** its free tier counts tokens per minute, and one window (12,880 + 3,022 characters) uses most of a minute's allowance. One at a time, later windows still get a 429, but 061's wait handles it: live, a 9-day plan waited 33 s and 45 s and finished with Groq in 92 s.
- **Gemini** (step 4): the live check showed the key and `gemini-3.6-flash` work (minimal call and a real 3-day window both succeeded, the window in 25 s). In a two-window plan, the window sent alongside got `503 unavailable`, the error from all of the user's earlier plans. So Gemini also goes one at a time. One observation only; it could also be Google-side load.

The plan cap (3 × 75 s × waves) and the app's wait are unchanged. Serial windows make long Groq plans slower: about 30–45 s per window after the first under the free tier, so roughly 7 minutes for 30 days, inside the 900 s cap.

## 066 - Groq gets low reasoning effort; no OpenRouter model pinned (2026-11-05)

Steps 2 and 5 of 062, from live probes.

1. **Groq reasoning effort.** The live probe showed `json_validate_failed` was not malformed JSON: `openai/gpt-oss-120b` (a reasoning model) spent its whole output allowance on hidden reasoning and finished with `finish_reason: "length"` and 0 characters of answer, with or without JSON mode. With `reasoning_effort: "low"` it wrote a complete, valid 3-day window in 3.6 s (`finish_reason: "stop"`). New setting `GROQ_REASONING_EFFORT` (default `low`, blank to send nothing, for models that don't take it) in `config.py` and `.env.example`, sent through `extra_body` because the pinned openai SDK 1.54 rejects the keyword. Only the model's hidden thinking is cut; the itinerary prompt, windows and output are unchanged, so 042 holds. Chat uses the same setting.
2. **OpenRouter: no model pinned.** Of the 12 `:free` models in OpenRouter's public list, the 6 with JSON mode were each tried with one real 3-day window: `google/gemma-4-26b-a4b-it` and `google/gemma-4-31b-it` returned 429 twice each, `xingchen-agi/xing4.0-29b-a4b` 429, `nvidia/nemotron-3.5-super-vl` an incomplete plan after 35 s, `recursive/flint-v1.0` ran out of the 75 s budget, and `dots-studio/dots-3-note-preview` finished in 73 s, too close to the limit to rely on. `openrouter/free` stays (the user's `.env` was not read or changed). OpenRouter is now a last resort behind a working Groq.

## 067 - One retry on the same provider after bad output (2026-11-05)

At the user's request, after their first plan with 063–066 still came back fully demo. Their log: Groq `json_validate_failed` after 3.45 s (benched 30 s as per 064, with low reasoning effort sent), Gemini `503` after 2.4 s on a **single** window, OpenRouter an incomplete plan after 56 s. Supersedes 060's "no retry within a provider" (the user's earlier choice, revisited with them) for bad output only.

**Evidence (live probes by the agent, low reasoning effort, labels only).** Groq loose JSON mode: 12 valid windows, 1 `json_validate_failed` (the user's), 1 reply that parsed but failed the day/date check. Groq strict mode (`json_schema`, `strict: true`, non-streaming; documented as never failing): 4 valid, 2 `json_validate_failed`. So Groq misses about one try in six or seven at random, in either mode; strict mode is not used.

1. **Retry** (`itinerary_builder._window_with_fallback`). A window whose attempt fails as `invalid_output` (rejected JSON, invalid JSON or a failed check) asks the same provider once more, with the corrective note that direct providers already use (`CORRECTIVE_NOTE`), if at least 15 s of its budget is left (`RATE_LIMIT_MIN_LEFT_SECONDS`). A recovered retry records no cooldown. A second bad output, or no time left, benches the provider and moves on as in 063. Timeouts, stalls, 503s, 429s (061's wait still applies) and hard failures are not retried.
2. **Correction to 065:** Gemini's 503 is not only from two windows at once; the user's log shows it on a single window, so it is most likely load on Google's side. Gemini stays one window at a time (harmless), but it isn't a fix for 503.

Consequences: a Groq miss now usually costs 3–5 s plus a possible per-minute wait (25–45 s), instead of the window falling to Gemini and OpenRouter, which are both unreliable on their free tiers right now. A provider that always returns bad output costs one extra call per window.

## 068 - Same-name places: go ahead when obvious, show the exact place, "Not this one?" (2026-11-05)

At the user's request, after the KI-30 live check (20 chat cases through `auto` plus Geoapify). Supersedes 059's "the same name in several countries or states always offers choices". Closes phase 1.

**Found live:** Lemon asked "which one?" for Paris, Rome and Lisbon; "Santorini" was not found (Geoapify files islands as `amenity`, which the shared search dropped); "Georgia" found only the US state (Geoapify returns the country only for a country-only search); the offline parser missed "Bali" in "me and my two kids, Bali, sometime in March" and didn't count "me and my two kids" as 3.

1. **Go ahead when obvious** (the user's choice over always asking). `place_check.classify` ranks same-name places by Geoapify `rank.importance`. If the top one is ahead by `IMPORTANCE_GAP = 0.15` or more, it is `verified` and the others become `alternatives`. If either score is missing (US states have none) or the gap is smaller, it is `ambiguous` as before. Measured gaps: Paris .37, Bali .37, Rome .33, Lisbon .30, Valencia .18 go ahead; Portland .11, Cambridge .03, Springfield .00 and Georgia (no score for the state) ask.
2. **The exact place is shown and used** (the user's request). New chat response fields `destination_label` (every verified place, e.g. "Paris, France", "Kyoto, Japan"; a name the traveller already qualified with a comma keeps their words) and `destination_alternatives` (only when Lemon picked one of several). Both are server-owned. The app's brief shows the label; the plan request and the search tabs use it (`LemonChatController.placeName`), so the plan never geocodes a different Paris. Without a label (check unavailable, mock), the name as typed is used.
3. **"Not this one?"** (the user's request: a pop-up only when the name is shared). Under the brief's destination, only when `destination_alternatives` is non-empty. It opens a dialog: "Which Paris, France did you mean?", one option per alternative, then "Somewhere else…". An alternative replaces the place at once with no backend call; "Somewhere else…" works like the edit button (Lemon asks for a new place, which goes through the usual checks, including not-found).
4. **"London"**: Geoapify's top result is "Greater London", which the exact-name match missed (only London, Ontario matched). The top result now counts when its name contains the word, and its label uses the traveller's word: "London, United Kingdom", with "London, Canada" as an alternative.
5. **Islands** (`services/geo_results.keep_destinations`, used by the shared geocoder): when no city, region or country is left after dropping streets/buildings/amenities/postcodes, an `amenity` whose name matches the search exactly is kept. Santorini is now found in the chat, and plans get its weather and attractions. A café named "Santorini Cafe" is never kept.
6. **Countries** (`place_check._default_lookup`): an ordinary search and a country-only search run together; a country is added only when its name matches exactly, and a failed country search keeps the ordinary results. A country's label is "Georgia (country)"; the geocoder (`routers/weather._lookup_geoapify`) strips that suffix and searches countries only, so a plan for it goes to GE. This adds one Geoapify call per new destination (cached 24 h).
7. **Offline parser**: a capitalised place standing between commas is read as the destination (`_comma_place`), and "me/I and (my) N kids/children/friends/…" counts as N + 1, marked as assumed.

Consequences: fewer questions for famous cities, and a wrong guess is visible on the brief and one tap to change. Two Geoapify calls per new destination instead of one. Live after the fix: Paris→France, Rome→Italy, Lisbon→Portugal, London→United Kingdom, Bali→Indonesia, Valencia→Spain go ahead with alternatives; Portland, Cambridge, Georgia ask; Santorini is found; "Georgia (country)" geocodes to GE. Not yet seen in the running app.


## 069 - Lemon.ai phase 2: grounded plans, popular spots, pace and day edits (2026-11-05)

Status: **accepted and implemented.** Every design choice below was the user's, settled in questions before the build (their rule), then approved as one plan ("go ahead and complete phase 2"). Scope from 058's phase 2. Live checks, dependency-free: Wikidata needs no key or package (httpx was already there).

**Choices the user made:**
1. **Grounding: hybrid.** The prompt lists known places with refs (`P1`…): must-visits, popular spots, nearby attractions (at most 40). The model sets `place_ref` for a stop at one of them; any other named place is looked up in Geoapify near the destination afterwards. Unmatched places are flagged.
2. **Unverified look:** a small grey "Unverified" tag beside the location; verified stops get a filled pin ("Checked on the map"). Meals and free time get neither.
3. **Pace:** a brief item like budget (default "Balanced", tagged Default; free text picks it up from words like "chill" or "pack it in"; guided mode gets a three-pill step). Relaxed 2–3, balanced 3–5, packed 5–7 activities a day; each stays as detailed as before (042).
4. **Must-visits** come from chat and from **popular spots**, which Lemon recommends in her chat bubble as buttons (the user's design: Lemon asks either way, her bubble carries the buttons, a tap adds the spot to the brief). She recommends without being asked, once per destination, until the traveller says "up to you" / "surprise me"; then she picks on her own (3–4 spots tagged **"Lemon's pick"**, removable) and stops recommending, also for a later destination.
5. **Popularity: Wikidata**, over the whole destination (the user: "not by distance from the centre, popular spots in that place", at least 10). A live check found Geoapify returns places inside a city in no useful order (no Eiffel Tower, Louvre or Sensō-ji among 200), while Wikidata's sitelink count ranks them well. The User-Agent carries the user's repo URL (`WIKIDATA_CONTACT`), as Wikimedia's bot policy requires; the user chose the repo.
6. **A whole country is too broad** (the user's wording): Lemon says so and asks for a city or area there; no spots are searched.
7. **Regenerate a day: only that day**, as a one-day window through the same provider chain; other days are untouched and listed in the prompt to avoid repeats.
8. **All three edits** (regenerate, swap one activity, adjust a day by text), also **through chat** ("make day 2 more relaxed"), so Lemon works as an assistant and a planner.
9. **Chat edits preview, then confirm** ("Use this" / "Keep old"). Button edits use the same preview.
10. **Questions about the trip** are not answered yet: Lemon replies cheerfully that the feature is coming soon (fixed text, with emojis), and offers edits.
11. **Built all at once**, not in two parts.

**How it works** (details in API.md, ARCHITECTURE.md):
- `services/popular_spots.py`: Geoapify geocode (country → `too_broad`) → Wikidata search for the destination's item (first hit within 60 km) → one SPARQL query for visitor classes (attraction, landmark, museum, monument, place of worship, park, garden, zoo, palace, castle, tower, archaeological site, square, bridge; skyscrapers only with 40+ sitelinks) located anywhere inside it with ≥ 8 sitelinks, minus demolished (P576), national parks and office buildings, most sitelinks first, at most 5 of a kind before the rest → each of 25 confirmed with Geoapify within 1.5 km (unconfirmed dropped) → at most 20. Cached 24 h. `/lemon/chat` prefetches it whenever it verifies a destination; `/lemon/spots` waits up to 60 s. `picks` = the most popular, up to half swapped for spots suiting the interests.
- `services/poi_lookup.py`: one-place Geoapify lookups (1 credit each), a shared 5-per-second limiter (free plan limit), 24 h cache including "no match", name matching across languages ("Louvre Museum" ~ "Musée du Louvre"), area results never count.
- Chat: new fields `pace`, `must_visit` (each checked near the destination: verified / not_found / unverified), `spots_to_lemon`, `edit`; new intents `edit_plan`, `plan_question`; request `plan_summary` and `plan_days`. Replies for edits and questions are fixed server-side, so Lemon never claims a change she hasn't made. The offline parser reads pace words, "surprise me", "must see X", and "regenerate day N" / "swap stop N on day M" / "make day N more …".
- Plan: `TripRequest.pace`, `must_visit` (≤ 10). Must-visits are assigned to days first (outdoor ones off rainy forecast days, then within 3 km of another on the same day, else the emptiest day); each window must include its own (validation → one corrective retry → next provider). Weather is summarised per day. Grounding after assembly sets `place_id`, `lat`, `lon`, `place_status` (≤ 100 lookups, 20 s); a check that couldn't run leaves no tag.
- `/lemon/edit`: regenerate / swap / adjust one day; a swap returns one different activity, put in the stop's place with its time; never a demo day for a real plan (502 and the plan stays).
- App: spot pills in Lemon's bubble (labels shrink on phones), must-visit chips with remove and tags, pace line and step, a must-visit guided step ("Continue" / "Skip for now" / "Surprise me"), the chat box stays open after the plan, preview cards, Regenerate / Adjust buttons on each day card and Swap on each stop (hidden on demo plans), a "Keep my plan as it is" choice after a failed edit.

**Interpretations I made, stated in the plan:** spots are recommended once per destination (not on every message); a new destination clears the old must-visits; at most 10 must-visits; a must-visit missing from a window is treated like bad output (it can, in the worst case, end in a demo plan if every provider keeps leaving it out; see KI-34); trip-detail changes after a plan go through "Edit trip details" (Lemon says so) rather than silently changing the brief.

**Live checks (agent, user-authorized, 2026-11-05):** Wikidata ranking for Paris, Tokyo, Lisbon, Kuala Lumpur (before and after the class and variety fixes); a full flow in one process through `auto`: chat → Lisbon verified, pace relaxed, Belém Tower verified; 20 spots; a 3-day plan by Groq in 4.9 s, 3 stops a day, all 9 verified, Belém Tower in, Belém sights on one day; "swap stop 2 on day 1" read as an edit; a trip question got the coming-soon reply; the swap replaced only stop 2. Roughly 115 Geoapify credits after the build and about 170 in all with the design checks (a places search costs 1 credit per 20 results, so the 200-place boundary searches cost 10 each), well under the 3,000-a-day free plan.

Consequences: about 25 Geoapify credits and 3 Wikidata requests per new destination for spots, plus up to 100 credits per plan for places outside the known list (in the live run, none were needed). Plans start with must-visits placed, and stops show whether they were checked. Not yet seen in the running app by the user.

## 070 - A must-visit no planner fits never turns the plan into a demo; Lemon asks (2026-11-06)

At the user's request, fixing KI-34. Supersedes 069's "a must-visit missing from a window is treated like bad output" for the last step only.

- **Backend:** each window remembers its latest output that was fine apart from missing must-visits. The corrective retry and the provider chain run as before; if every provider still leaves them out, that output is used instead of failing the window (so no demo plan for this reason). `ItineraryResponse.missing_must_visits` lists the must-visits that aren't anywhere in the plan (a place moved to another day counts as in). Same for `/lemon/edit`: a regenerated or adjusted day that lost a must-visit is returned with `missing_must_visits` instead of a 502. A window that fails for any other reason on every provider still makes the plan demo (063).
- **When none of the must-visits fit** (the user's choice): Lemon doesn't show the plan; she says "I couldn't fit … into your plan, even after trying all my planners. Would you like to see the plan without them?" with **Yes, show my plan** / **No, stop here** (typed yes/no work too; anything else asks again). Yes shows the plan already written (the user's choice: no second generation). No: Lemon stops, says so, and the brief stays so the traveller can change the must-visits or try again. Editing the brief also drops the held plan.
- **When some fit** (the user's choice): the plan shows without asking. Lemon's "your plan is ready" message names the ones that didn't fit, so it isn't hidden (my addition, stated to the user).
- **Day edits** (the user's choice): the preview says "I couldn't keep … on it. Shall I use it anyway?" and the card notes "Not on this day any more: …"; "Use this" / "Keep old" decides.

Offline: backend 202 of 202, frontend 153 of 153. Not run live (it needs a provider that keeps leaving a must-visit out, which the live run didn't produce).

## 071 - "Plan it" never skips a question or a changed brief (2026-11-07)

Status: **built 2026-11-07** (the user said "go ahead and build 071", with the additions below). Fixes KI-35 and KI-36. Offline-tested only; not yet re-run by the user in the app.

**What happened (the user's app test, Script 5):** with a brief already showing in the same chat (most likely Script 4's Lisbon trip), the user sent one message that switched to Kyoto, named three must-visits and ended "Go ahead and plan it". Lemon replied "Let me create the itinerary", said "I couldn't find Menya Yoshi Kitayama near Kyoto, Japan on the map… Could you check the spelling?", then planned at once without waiting for an answer or showing the new brief. Cause (source-inspected): `_applyFree` in `lemon_chat_controller.dart` (around line 1053) starts the plan when `result.ready` and the brief was showing before the message (`before == 'confirm'`); it doesn't check whether the message changed the trip or raised a not-found must-visit. The not-found message (around line 1046) never holds the plan. The AI's "let me create it" reply is shown as is.

**The user's choices:**
1. **Ask first, then plan; no assuming.** When a message says "plan it" but Lemon has something to ask, she says "Sure thing! But before that, I have a question:" (or "some questions:") and asks, one at a time.
2. **A must-visit not found:** Lemon tells the traveller, then asks whether to **swap it** for another place or **continue without it** (buttons; typing works too).
3. **Swap:** the city's popular-spot buttons, and the traveller can type a corrected or different name; a typed name is checked on the map as before (asks again if still not found).
4. **After the questions are answered:** Lemon shows the updated brief and **waits for confirmation** (Generate or "go ahead"). No automatic plan.
5. **"Plan it" in a message that changed the trip (e.g. Lisbon → Kyoto) with nothing to ask:** Lemon shows the new brief and **waits** for confirmation.

**Plan presented to the user (to build next session, frontend only; no backend or API change):**
- Rule: in free text, "plan it" starts the plan only when the brief was showing **and** the message changed nothing **and** nothing is waiting to be asked. Otherwise Lemon asks or shows the brief, then waits.
- `lemon_chat_controller.dart`: snapshot the brief before applying a reply and compare after; a queue of not-found must-visits worked through one at a time ("Swap it" / "Continue without it"; typed "skip it" / "continue without it" = continue, anything else = the replacement name); when the plan is held, Lemon's own text replaces the AI's "let me create it" reply; once the queue is empty she says "All set! 🎯 Here's your updated brief. Have a look, then tap Generate or say go ahead." A changed trip with nothing to ask: "Sure thing! I've updated your trip. 🎯 Here's the new brief. Have a look first, then tap Generate or say go ahead."
- The same Swap / Continue question also appears for a not-found must-visit in a message without "plan it" (my addition, stated in the plan: one behaviour everywhere).
- Unchanged: brief showing + a plain "go ahead" (or Generate) plans at once; guided mode (must-visits there come from buttons).
- `lemon_chat_panel.dart`: a new `unfound` control (two buttons; the spot pills plus "or type a name" on Swap).
- Tests (`lemon_phase2_test.dart`): changed destination + "plan it" → no plan request, brief shown again; not-found + "plan it" → no plan request, question and buttons, Continue → brief without planning; Swap → spot tap → brief; Swap → typed name not found → asked again; two not-found places asked in turn; brief + "go ahead" still plans. Then full frontend suite, analyze, web build.

**Also to check (raised with the user):** "Hanamiya Kissa" from the same message was not reported as missing, so the map matched it to something; whether that match was right is unknown. If wrong, place matching (`poi_lookup` / `place_check`) needs a separate fix.


**Second app run (Script 5 in a fresh chat, 2026-11-07, screenshots from the user):** KI-35 reproduced without any earlier trip in the chat. It also showed three more problems, added to 071 with the user's agreement: (a) Lemon's first reply said "Shall I go ahead and plan it?" and the next bubble asked for a spelling; (b) the popular-spots list arrived after the second message, just before the plan started (Wikidata is slow, KI-33, and the app offered spots whenever they arrived); (c) "I assumed a trip until 2026-12-12" printed the raw date.

**"Hanamiya Kissa" (live lookup on the user's authorization, 2 Geoapify credits):** near Kyoto (35.0116, 135.7681, 40 km), Geoapify's only result for "Hanamiya Kissa" was **Kissa Gobo Gobo**, a real café on Matsuyamachi street, Kamigyō Ward (35.0175, 135.7484), and `same_place` accepted it because both names contain "kissa" (Japanese for café). "Menya Yoshi Kitayama" had no result. Recorded as KI-36.

**Added to 071 (the user's choices):**
- **Stricter place matching** (`services/poi_lookup.py`, `same_place`): one name inside the other still counts; otherwise kind words are set aside and *every* remaining word of the asked name must be in the found one (it used to need one shared word). Shop and food words were added to the kind words, in English (cafe, tea, house, shop, restaurant, bar, bakery, noodle, hotel, ...) and Japanese (kissa, kissaten, menya, ramen, sushi, izakaya, udon, soba, jinja, taisha, jingu, dera, tera). A first try that also accepted the reverse direction (found ⊆ asked) let "Arashiyama Station" match "Arashiyama Monkey Park", so only asked ⊆ found is used.
- **"Matched: ..." under a stop** (the user chose to include it, "for better testing and easier correction"): the server now returns the map's name for each verified stop (`place_name` on activities) and for each found must-visit (`matched_name` in chat, carried back in `TripRequest.must_visit`). The itinerary shows "Matched: <name>" in small italics when that name isn't just the stop's own name (neither contains the other, ignoring case and punctuation).
- (a) whenever Lemon holds a plan or asks about a place, her own words replace the model's reply; (b) spots are never offered during a chat turn, while a question waits, or when a plan is about to start; they are offered after the turn or once the questions are answered; (c) dates in Lemon's sentences read "12 December".

**As built (frontend `lemon_chat_controller.dart`, `lemon_chat_panel.dart`, `itinerary_view.dart`, models; backend `poi_lookup.py`, `itinerary_builder.py`, `chat_parser.py`, models):**
- New control `unfound` with **Swap it** / **Continue without it**. Typed answers: "skip it", "continue without it", "no", "never mind" … continue; "swap it" opens the swap. While swapping, typed text is the new name, sent to `/lemon/chat` as "Instead of X, we must visit Y." and checked on the map like any must-visit (not found → "I couldn't find Y near … either"; no place name read → asked again). A spot tap while swapping adds that spot. Any other message is an ordinary chat turn; Lemon then asks the same question again. Generate is blocked while she waits.
- Several not-found places are asked one at a time ("Next one!"). After the last answer: "All set! 🎯 Here's your updated brief…" (or the first brief's own announcement, which waits for the answers). Never an automatic plan.
- A changed brief + "plan it": Lemon shows the new brief once. A second "go ahead" plans even if the model re-reads a value differently, so the traveller can't get stuck in a loop.
- A first message with "plan it" (no brief yet): "Sure thing! Let me show you your trip brief first. 🎯", then the brief.

**Fixes after the user's third run (2026-11-07, screenshots):**
- Typing a place while Lemon asks, without tapping Swap ("fushimi castle"), was added to the trip but the question was asked again. Now a found place typed while she asks counts as the swap ("Got it! I've added Fushimi Castle instead of sensen cafe."). This was a bug against choice 2 ("typing works too").
- In a new chat, after "Seoul" Lemon asked for the dates and the spots list landed right under the question. Following rule (b), in free text the list now waits until the brief is ready (destination and dates known); a "too broad" country message still shows at once, because it is itself the question.
- **Fourth run:** a made-up place typed without Swap ("Hanamiya Tea House") was queued as a new question and the same question was repeated; typing it again did nothing new, because a not-found name was only ever reported once. Now, while Lemon asks, a typed place the map doesn't know gets "I couldn't find … either" and opens the swap (spot buttons); and a place reported before is reported again whenever the latest message names it (not while it is the question being asked). So a skipped place named again in a later message is asked about again (the user's Test 3, sent in the same trip after "Edit trip details"); skipped places not named again stay skipped.
- **Fifth run (user's choice, 2026-11-07):** the spot list now comes once, after every not-found place is cleared up, right before the brief: "All set! 🎯", the list, then the brief (or "Here's your updated brief…"). Swap keeps its spot buttons (the user's choice), but they no longer count as the list. A first brief in free text also gets the list just before it when the spots are ready; if they are still loading, the brief comes first and the list follows, as before.
- Seen and working as designed: a must-visit typed as a normal message ("sensen cafe") raised the question; Swap → typed "Kyoto Tower" was added and the brief shown without planning.