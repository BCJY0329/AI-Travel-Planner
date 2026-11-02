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
