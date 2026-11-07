# Tasks

## Scope

Reconstructed on 2026-10-08 from current source. The initial task authorized documentation only. Subsequent repairs were separately authorized; unchecked work remains a proposed backlog. KI identifiers refer to `KNOWN_ISSUES.md`. Sections are chronological; items completed by later batches were ticked on 2026-10-17 with a pointer to the batch that did them.

## Open work snapshot — 2026-11-07 (071 built) — next up: the user re-runs Script 5

- [x] Second Script 5 run (fresh chat) reproduced KI-35 and found three more problems; a live lookup showed "Hanamiya Kissa" matched **Kissa Gobo Gobo** (KI-36). All added to DECISIONS 071 with the user.
- [x] **DECISIONS 071 built** (the user said go ahead): Swap it / Continue without it, "plan it" waits, Lemon's own words while holding, spots wait, dates in words, stricter place matching, "Matched: …" under stops. Backend 204 of 204, frontend 167 of 167, analyze clean, web build passes. Not run in the app.
- [x] The user's third run found two problems (a place typed without Swap didn't count; spots landed under the dates question); both fixed, frontend 169 of 169.
- [x] Fourth run: made-up names typed while Lemon asks, and skipped places named again, fixed; frontend 171 of 171.
- [x] Fifth run: spot list moved to right before the brief, after the not-found questions; Swap keeps its buttons; frontend 173 of 173.
- [ ] **The user re-runs Script 5** (restart the backend and hot-restart the app first): expect Lemon to ask about Menya Yoshi Kitayama and Hanamiya Kissa (now not found) with Swap it / Continue without it, and to wait before planning.
- [ ] Then the scripts not yet reported (1–4, 6–9), then phase 3.

## Superseded — open work snapshot — 2026-11-07 — next up: build DECISIONS 071, then continue the user's app test

- [x] The user started testing phase 2 in the running app with test scripts from the agent (nine scripts: Paris normal path, Rome surprise me, Japan / Paris / Springfield destination checks, Lisbon wrong-city must-visit, Kyoto must-visits that may not fit, Barcelona → Madrid clears must-visits, noise and injection, guided mode, a 9-day London trip). Script 5 found KI-35.
- [ ] **Build DECISIONS 071** (fix KI-35): "plan it" never skips Lemon's question or a changed brief; Swap it / Continue without it for a must-visit not found; brief shown and confirmation awaited. Design settled and plan presented; the user said to record it and build next session (they did not yet say "go ahead" on the plan, so confirm before building).
- [ ] Check what "Hanamiya Kissa" matched to on the map in the Script 5 Kyoto plan (ask the user); fix place matching if wrong.
- [ ] Continue the user's app test: Script 5 again after the fix, then the scripts not yet reported (1–4, 6–9).
- [ ] Then phase 3 (below).

## Superseded — open work snapshot — 2026-11-06

- [x] **KI-34 fixed (DECISIONS 070):** a must-visit no planner fits no longer turns the plan into a demo; when none fit Lemon asks ("Yes, show my plan" / "No, stop here"); when some fit the plan shows and she names the missing ones; day edits preview with a note. Backend 202 of 202, frontend 153 of 153, web build passes; not run live.
- [ ] The user's look at phase 2 (and this) in the running app, then phase 3 (below).

## Superseded — open work snapshot — 2026-11-05 (phase 2 built) — next up: the user's look, then phase 3

- [x] **Phase 2 — grounded itinerary (DECISIONS 069):** design settled with the user, plan approved, built in one go. Popular spots (Wikidata + Geoapify) as buttons in Lemon's bubble, typed must-visits, "surprise me" picks, pace, known places and grounding (pin / Unverified), must-visits placed by distance and weather, day edits (regenerate / swap / adjust) from buttons and chat with a preview, "coming soon" for trip questions. Backend 196 of 196 offline, frontend 147 of 147, analyze clean, web build passes; live end-to-end check passed (TESTING 2026-11-05).
- [ ] **The user's look at phase 2 in the running app** (restart the backend: new routes `/lemon/edit`, `/lemon/spots`; hot-restart the app). Try a city, tap spots, say "surprise me", plan, then "make day 2 more relaxed", the day buttons, and a country like "Japan".
- [ ] Phase 3 — photos and links (HANDOVER queue). Phase 4 — videos. Phase 5 — extras (answering trip questions is now promised as "coming soon" in Lemon's reply).
- [ ] Providers, parked by the user (unchanged).
- [ ] Commit (only when the user asks): nothing since `ed0f4d3` is committed.

## Superseded — open work snapshot — 2026-11-05 (end of session) — next up: phase 2

Start a fresh session from `docs/HANDOVER.md`. Order agreed with the user:

- [x] Phase 1 done (DECISIONS 059, 068): tested by the user in the app, KI-30 live check done and its findings fixed.
- [x] Plan reliability (DECISIONS 060–067): the user confirmed real itineraries from the app.
- [ ] **Next: Phase 2 — grounded itinerary** (scope in DECISIONS 058; design questions listed in HANDOVER.md; settle them with the user and present a full plan before building).
- [ ] Phase 3 — photos and links; Phase 4 — videos; Phase 5 — extras (or 5 before 3–4 if those need paid tiers).
- [ ] Providers, parked by the user: paid Groq tier or other upgrades, Gemini 503, an OpenRouter model, a 10+ day live check.
- [ ] The user's look at "Not this one?" in the running app (restart the backend first).
- [ ] Commit (only when the user asks): nothing since `ed0f4d3` is committed.

## Open work snapshot — 2026-11-05 (plan reliability, KI-32)

Agreed with the user to go through these one at a time next session (DECISIONS 062). Each needs the user's decision before code changes.

- [x] Diagnosed from the user's third live log: Groq over its free per-minute token limit, then `json_validate_failed`; Gemini 503 every time; OpenRouter too slow every time. Recorded in DECISIONS 062 and KI-32.
- [x] **Step 1 (2026-11-05, DECISIONS 063):** the user chose the middle way: each window falls back on its own, a provider's running windows finish after it is benched, a fresh 75 s per provider per window, demo only for the whole plan. Backend 133 of 133 offline; not run live.
- [x] **Step 2 (DECISIONS 064, 066):** `json_validate_failed` is bad output (30 s). Its cause, found live, was gpt-oss reasoning until out of output; `GROQ_REASONING_EFFORT=low` fixes it.
- [x] **Step 3 (DECISIONS 065):** Groq takes one window at a time; 061's wait handles the remaining 429s. Live 9-day plan: fully Groq, 92 s.
- [x] **Step 4 (DECISIONS 065):** live check: key and model fine; 503 seen on the second of two windows at once, so Gemini takes one at a time too.
- [x] **Step 5 (DECISIONS 066):** tried the 6 free JSON-capable models live; none reliable, so `openrouter/free` stays and `.env` is untouched.
- [x] Follow-up (DECISIONS 067): the user's app plan still went demo (random Groq miss + Gemini 503 + OpenRouter bad output). One retry on the same provider after bad output, the user's choice. Backend 142 of 142 offline; live 6-day plan fully Groq in 37 s (no miss, so the retry wasn't exercised live).
- [x] **The user confirmed a real itinerary from the running app (2026-11-05)** after 067; the log showed one Groq per-minute 429 (32 s wait) and no demo fallback.
- [ ] Later (the user will return to it): change or upgrade providers (paid Groq tier, Gemini, a reliable OpenRouter model). A 10+ day trip through Groq is still unchecked live.

## Open work snapshot — 2026-11-05 (rate limits during a plan)

- [x] One Groq 429 no longer throws away Groq's plan (DECISIONS 061): the limited window waits Retry-After and retries the same provider if 15 s of budget would remain. 503 now benches a provider for 30 s, not 5 min. Backend 129 of 129 offline.
- [x] The user's next live plan: the wait works (38 s, then 2 s, then accepted), but the plan still went to demo for other reasons. Moved to the KI-32 steps above.
- [ ] OpenRouter model choice: now step 5 above.

## Open work snapshot — 2026-11-04 (plan restarts with the next provider)

- [x] Mixed demo and real days fixed (DECISIONS 060): with `auto`, one provider writes every window; any failed window cancels the rest and restarts the plan from day 1 with the next provider, with a fresh budget and no retry within a provider. All providers failing gives a whole demo plan. Frontend wait now 25 s + 3 × 75 s × waves for `auto`. Backend 125 of 125, frontend 116 of 116 offline.
- [ ] Live check of a plan through `auto` where the first provider fails (needs the user's go-ahead; spends quota). Folded into KI-27.

## Open work snapshot — 2026-11-02 (Lemon.ai feature roadmap)

Agreed with the user in discussion; nothing implemented yet. The full plan and reasoning are in DECISIONS 058. Each phase needs the user's go-ahead before code changes; dependency changes and live provider calls need separate authorization.

- [x] Discussed and agreed the roadmap and phase order (DECISIONS 058). Docs only; no code changed.
- [x] **Phase 1 — Smart intake and garbage gate** (2026-11-04, DECISIONS 059). Offline-tested; not yet seen in the running app.
  - [x] Modes agreed with the user: free text by default; guided controls offered (ask first) or chosen from the ⚙ settings menu or by plain words; mode saved with `shared_preferences`.
  - [x] One-shot extraction of every field from free text.
  - [x] Left-out details explained and shown as "Default" on the brief; guesses shown as "Assumed"; each editable before generating.
  - [x] Local pre-filter (empty, keyboard-mash, repeated characters, links, prompt-injection phrases).
  - [x] Model `intent` classification with a reply per kind.
  - [x] Destination must resolve through Geoapify; ambiguous names offer choices (KI-25 option 2), in both modes.
  - [x] Local parser with the same rules in simpler form; backend 120 of 120 and frontend 115 of 115 offline.
  - [x] **Live check (2026-11-05, user-authorized):** 20 chat cases; results in KI-30. Its findings fixed in DECISIONS 068.
  - [x] **Same-name places (DECISIONS 068, the user's design):** famous place goes ahead (importance gap 0.15), the brief shows the exact place, "Not this one?" pop-up only when the name is shared, plus "Somewhere else…"; islands found; Georgia the country offered; offline parser reads a place between commas and "me and my N kids". Backend 160 of 160, frontend 127 of 127, web build passes; live place checks match. Not yet seen in the running app.
  - **Phase 1 is complete.** Next: phase 2 in a fresh session (HANDOVER.md).
  - [x] **The user's look at the running app** (2026-11-05): tested by the user, no phase 1 issues found; the only problems were the provider/plan ones (KI-32, now fixed).
- [ ] **Phase 2 — Grounded itinerary:** optional `place_id`/coordinates per activity with unverified places flagged; `must_visit` on `TripRequest` checked by the validator; group nearby places; weather-aware placement; pace setting (relaxed/balanced/packed, not shorter content); regenerate one day / swap one activity; visible mock label.
- [ ] **Phase 3 — Photo detection and link previews:** photo/screenshot upload → candidates with evidence → Geoapify check → user confirms → `must_visit`. Links read through oEmbed / Open Graph only (caption first, then thumbnail, then ask for upload); private posts are not worked around. Before starting: confirm the Meta tokenless oEmbed and TikTok oEmbed details against official docs.
- [ ] **Phase 4 — Video detection:** 4–6 still frames pulled in the app, sent as images through the auto chain; raw video through Gemini only as a last resort (low resolution, about 60 s cap); cache by file fingerprint; daily cap per device; media not kept.
- [ ] **Phase 5 — Extras:** saved trips (device storage), a map of each day, export/share (PDF, .ics, link), follow-up questions after a plan.
- [ ] If phases 3–4 turn out to need paid AI tiers, do phase 5 first (the user's call).
- [ ] Prerequisites to raise with the user when their phase comes: `google-genai` upgrade, KI-14 (Gemini 404), a Flutter file-picker package, frame extraction on Flutter web, KI-07 (broken venv).

## Open work snapshot — 2026-11-02 (buttons and chat panel)

- [x] **Reviewed and approved by the user in the running app (2026-11-02).** Next session: Lemon.ai feature improvements (see HANDOVER.md).

- [x] Buttons (DECISIONS 056): one font for every button label (Outfit; 800 filled, 700 outlined/text/pill), including the chat panel and dialogs that used Roboto; a resting shadow on every filled button like Find Flights, a deeper edge and faint shadow on partner buttons; a few px more height. Frontend 89 of 89 (new `test/button_style_test.dart`); analyze clean. Approved by the user in the running app.
- [x] Lemon.ai chat polish built in Flutter (DECISIONS 057): rise-in messages, typing dots, planning card, pill chat box, budget option pills, interest icon pills; Lexend for Lemon's words (user's pick from six fonts on the canvas). Also: hover card without its pill, with new wording and fonts; search cards centred; "Explore places" filled with its outline colour ("Sign in" kept white). Frontend 98 of 98; analyze clean; web build passes. Approved by the user in the running app.
- [x] Deleted the unused Nunito font files (user's request). The four formatter-only files from earlier still need the user's `git checkout`.
- [ ] Next (user): Lemon.ai feature improvements, after the UI items.

## Open work snapshot — 2026-11-01 (page colours and chat panel)

- [x] Mocked on the canvas and approved by the user: one colour per page (Flights sky blue, Hotels peach, Attractions lilac, pre-plan Itinerary sand), with search buttons in the page colour and warm sand "Plan with Lemon" buttons (DECISIONS 044). Also approved: the chat panel from halo options A + C with coloured progress and two-colour bubbles (DECISIONS 045), and the Discover hero wording and buttons on the Flutter hero layout.
- [x] Built in Flutter: `PagePalette` and `PageTone`, page-coloured banner, search card, fields, steps and tiles; peach "Find Hotels" and lilac "Discover Attractions"; "Plan with Lemon" bands on Hotels and Attractions; the new pre-plan itinerary page; the Discover hero and "Ready when you are" changes; the chat header, progress bar and bubbles. Frontend 68 of 68 (new `test/page_colours_test.dart`).
- [ ] Look at all of it in the running app (the user has seen the mocks, not the Flutter build), especially the chat bubbles' contrast, the badge position on Lemon's avatar and the pre-plan page on a phone.
- [x] Follow-up after the user saw the build (DECISIONS 046): Hotels and Attractions back to sky blue (sand "Plan with Lemon" bands and the sand pre-plan itinerary kept); Outfit on the search buttons, Flights and Hotels search values, "Copy itinerary" and the nav tabs; tip names shuffled per day. Frontend 69 of 69.
- [x] Second follow-up (DECISIONS 047): only sky blue, lemon and sand on pages; the mock's rounded sky search button on Flights, Hotels and Attractions; Outfit in the Discover hero. Frontend 73 of 73.
- [x] Fourth follow-up (DECISIONS 049): attraction tiles rotate all three colours; the Attractions search card is compact; nav tabs are larger. Frontend 77 of 77.
- [x] Chat panel font: the user chose Nunito (DECISIONS 050), now used for message bubbles and the three typing boxes. Frontend 78 of 78; web build passes.
- [x] Fifth follow-up (DECISIONS 051): sky blue flight carriers, lemon "Direct" and sand stops; lemon icon tiles on Hotels and Attractions; Lemon's hover card restyled to match the chat panel. Frontend 79 of 79.
- [x] Attraction chips (KI-29, DECISIONS 052): backend returns the full Geoapify `categories` list and requests `heritage`; the app classifies from the whole list. Backend 83 of 83, frontend 87 of 87, offline.
- [x] KI-29 again (DECISIONS 053): one Geoapify search per chip, nearest first, plaques last; chips match the searches (museums to Culture & Heritage). Lemon's bubbles white with a lemon edge; full avatar back in the hover card; Hotels (940) and Flights (1080) search cards compact. Backend 89 of 89, frontend 87 of 87, offline.
- [x] Flights search button moved beside the fields: one row on wide screens, beside Departure and Travelers on medium, stacked on phones (DECISIONS 054). Frontend 87 of 87.
- [x] Lemon's chat bubbles plain white with a warm hairline, no yellow outline or stripe; slate Nunito 400 text (DECISIONS 055). Frontend 87 of 87; analyze clean. Not yet seen in the running app.
- [ ] KI-29 live check (needs authorization for live Geoapify calls): see how the four searches fill the chips for a few cities, and confirm the Culture search's categories are accepted. The backend reload clears the 24 h cache.
- [ ] More bold changes only when the user names them.
- [x] Third follow-up (DECISIONS 048): the three-colour rule covers the search pages only, so the itinerary and Discover pills have their old colours back; Hotels and Attractions use the earlier pill search button again; chat bubbles swapped (Lemon lemon → sand, traveller sky → lilac); KI-28 fixed. Frontend 75 of 75.
- [ ] Still queued: tidy the button icons (deferred by the user); KI-26 screen-reader items; the live long-plan check (KI-27).

## Open work snapshot — 2026-10-31 (provider timing)

- [x] Step 1: cooldown by failure kind: hard failures 5 min, 429 honours Retry-After (1 s–1 h), timeouts and invalid output 30 s, budget-only timeouts none (DECISIONS 042).
- [x] Step 2: plan budget scales with waves (75 s per window from slot start, cap 75 s × waves); frontend timeout 25 s + 75 s × waves.
- [x] Step 3: streaming for Groq, Gemini (own thread) and OpenRouter; plans cut a provider only after 10 s of silence (25 s before the first chunk); SDK retries off for Groq/OpenRouter. Backend 79 of 79, frontend 59 of 59. Itinerary content untouched (no token caps, prompt or window changes).
- [ ] **Live check (needs the user's authorization; spends quota):** generate a long plan (e.g. 20–30 days) with `auto` and read the `lemon_ai` log lines: `failure=` kinds, `cooldown=` values, whether any `stalled` appears before a first chunk, and whether the result is real or mock. See KNOWN_ISSUES KI-27.
- [ ] Optional: a "still working on long trips" message during long plan waits (UI change, not requested yet).

## Open work snapshot — 2026-10-31

- [x] Browser check of the trip-following tabs and airport chips: done by the user, no problems reported.
- [x] Accessibility audit (source inspection and computed contrast): 11 findings recorded as KI-26 in KNOWN_ISSUES.md. No fixes yet; runtime screen reader and keyboard checks not run.
- [x] KI-26 visual items for every user (DECISIONS 040): darker error red and secondary text, 3:1 input outlines, keyboard focus ring, Pixabay credit backing, faded unavailable calendar days. Frontend 56 of 56.
- [ ] **Deferred by the user (2026-10-31), do in a future session: KI-26 screen-reader items.** Label the search fields, announce results/loading/errors and new chat messages, mark headings, make the compact chat panel modal with focus moved in and back out, name repeated "View location"/"View details" buttons per item, announce in-range calendar days.
- [ ] KI-26 small leftovers: `lang="en"` in `web/index.html`; a non-drag way to resize the chat; delete the unused chat bubble types (itinerary card, loading, date picker, quick replies).
- [x] Lemon chat step buttons restyled as one lemon family with 10 px gaps and clearer labels (DECISIONS 041). Frontend 56 of 56.
- [x] **Implemented (DECISIONS 043):** Calm Sky Blue + lemon + warm sand balanced 60/30/10 across the app, and the Fredoka wordmark with a whole lemon and leaf on the "i" (play-once colour wave lemon → sand, no blue), replacing the lemon icon tile. Frontend 61 of 61 (new `test/lemon_brand_test.dart`). Not yet viewed in a browser.
- [x] User feedback after viewing the app: the sparkle icons looked like an AI/Gemini symbol, so "Plan a trip with Lemon" and "Plan with Lemon" now use a suitcase (`luggage_rounded`), "Generate my itinerary" and the "Planned by Lemon" badge a route (`route_rounded`), "Surprise me" a die (`casino_rounded`). Search fields (Flights, Hotels, Attractions) showed a second oval inside the card because the theme gave the inner text field its own outline; `SearchField` now turns that border and fill off for its child. Frontend 61 of 61; not yet re-viewed in a browser.
- [ ] Look at the new palette and wordmark in the running app; nudge the lemon's position over the "i" if it sits off.
- [x] ~~Design exploration~~ (history of how the palette was chosen): the user disliked lemon yellow on the chat buttons and picked "Calm Sky Blue" (main `#B5D3F2` + navy `#23395B`, partner `#E3EFFB`) from a mock, then asked for a full-app mock with Sky Mint swapped for sky blue, and a comparison of ways to tone the lemon down next to it (butter yellow, less yellow, an apricot bridge colour, butter + less). The user then proposed dropping yellow from the UI altogether and giving Lemon a new signature colour; mocked as leaf green, soft coral, lilac, lime sorbet, pistachio, lemon sorbet and warm sand (canvas page "Lemon's new colour"). Lemon's avatar artwork would stay yellow. Latest direction (user): keep sky blue and lemon, add warm sand `#F1E6D3` and lemon sorbet `#FBF6E3` as a third, balanced 60% warm neutrals / 30% sky blue (everything pressable) / 10% lemon (Lemon's own accents); mocked on canvas page "Sky blue · lemon · sand". The user also wants the lemon icon tile removed from the logo and the "LemonTrip" wordmark animated, lighting up in the three colours in turn; three styles mocked on the same page (glow pill, letter wave, shimmer sweep), then a colour-only slow wave in 1 vs 3 colours. The looping animations did not look right to the user; current direction: a display font just for the wordmark (Fredoka, Baloo 2 or Lilita One mocked, ~30px), a lemon-slice dot on the "i", more room and a divider before the tabs, and the colour wave played once on load and on hover instead of looping (board "New wordmark"). User prefers Fredoka; three lemon designs for the "i" dot mocked (whole lemon with leaf, juicy slice, lemon with sky blue sparkle; board "Fredoka: three lemons for the i"). In Flutter this must respect `disableAnimations` and use `AmbientMotion`-style test hooks. Mock canvas: https://claude.ai/artifact/L5nqavbdcThi8BAWxF8LCj. Final choice: Fredoka with the whole lemon and leaf, wave without blue.
- [x] User feedback after viewing the app (wordmark, search slots): the wordmark looked thinner and taller than the mock because the app used Fredoka 600 while the mock used 700; bundled `assets/fonts/Fredoka-700.ttf` (same Google Fonts v17 source; the downloaded 600 file is byte-identical to the bundled one) and `LemonBrand` now uses weight 700. `SearchField` (Flights, Hotels, Attractions) now holds its input in a warm cream slot (8 px corners, sand border; white with a deeper sand border while focused) so it is clear where to type; not oval and not blue, at the user's request. One flights test now scrolls to its targets because the taller fields push "Find Flights" below 600 px. Frontend 61 of 61; not yet re-viewed in a browser.
- [ ] Lemon.ai chat panel halo: the user finds the yellow halo clashes with the sky blue header; options A, C and D mocked on the canvas (page "Calm Sky Blue app", board "Lemon.ai halo: now, A, C, D"); awaiting the user's pick.
- [ ] Next session (user request): improve the search-field colours on Flights/Hotels/Attractions (two colours look dull), and give Flights, Hotels, Attractions and the pre-plan Itinerary page their own palette colours instead of all Calm Sky Blue. Mock first. The session itself starts with Lemon.ai and app feature improvements (see HANDOVER.md).
- [ ] **Deferred by the user (2026-10-31), do later: tidy the button icons.** Some buttons carry icons that were added without much thought; the user wants to revisit them in a session where they choose real icons or pictures for buttons. Not audited yet.
- [ ] Look at the new focus ring, colours and chat buttons in the browser (Tab through each page; walk through a full Lemon plan).
- [ ] Still open: KI-25 option 2 (deferred), KI-07 (left by the user), KI-12 before deployment, KI-14/15.

## Open work snapshot — 2026-10-24

- [x] Fixed the backend chat parser's budget matching (the known failing test); backend suite 51 of 51.
- [x] KI-10/KI-11/KI-09: uniform data-route errors, generic Lemon 502 details, chat and search input bounds (DECISIONS 038).
- [x] KI-21: Flights, Hotels and Attractions follow the planned trip; new `GET /airports/search` (DECISIONS 037). Frontend 56 of 56.
- [x] Pixabay photos: confirmed working by the user in the running frontend.
- [x] KI-25: Geoapify geocoding with region boundaries (DECISIONS 039); backend 56 of 56.
- [ ] Deferred by the user (2026-10-24), do later: KI-25 option 2, let users say which country they mean ("Did you mean…?" when a name matches several places). Starting notes in HANDOVER.md.
- [ ] Browser check of the trip-following tabs and airport chips.
- [ ] Accessibility audit; KI-07 Python environment (user chose to leave it for now); KI-12 CORS/auth before deployment; KI-14/15 live providers.
- [x] Repaired the four stale frontend tests (launcher copy, drag-resize grip, custom calendar dialog); suite 52 passed, 0 failed. Fixed the "1 days" chip in the trip date dialog.

## Open work snapshot — 2026-10-20

- [x] In-memory caching for OpenWeatherMap (geocode, forecast), Geoapify (attractions, hotels), Duffel (5 min) and Pixabay (DECISIONS 035).
- [x] Pixabay country photos on the itinerary banner, served through the backend with credit (`GET /photos/place`, `/photos/image/{id}`).
- [ ] User: create a Pixabay key and add `PIXABAY_API_KEY=` to `travel_backend/.env`, then restart the backend. Without it the banner stays plain (503 from `/photos/place`).
- [ ] Live check of Pixabay results for a few countries (quality of `travel` category hits) and of the banner in the browser.
- [x] Country photos on the Flights/Hotels/Attractions results banners, and a Pixabay slideshow in the Discover hero (DECISIONS 036).
- [ ] Browser check of the hero slideshow timing (9 s, 1.4 s fade) and of photo crops behind the hero text.

## Open work snapshot — 2026-10-19

- Next session: start from [HANDOVER.md](HANDOVER.md). Country photos for every country are requested but blocked on the user's choice of photo source and scope.

## Open work snapshot — 2026-10-17

- Rerun `flutter analyze` and `flutter test` (and backend tests if touched) after the untested 2026-10-17 calendar/chat-resize/readability pass.
- Local visual review of portrait, calendar, dashboard, resizable chat, desktop and Android layouts.
- Shared trip context across search tabs (KI-21); accessibility audit (contrast, focus, labels, touch targets, text scaling).
- Backend: repair Python environment (KI-07), chat/travel-search validation (KI-09), transport error handling and exception-detail exposure (KI-10, KI-11), Gemini 404 (KI-14).
- Flutter Web emoji fallback without app-wide typography change.
- Product decisions: persistence, deployment/auth/CORS (KI-12), hotel pricing, caching, locales/accessibility targets.

## UI/UX review and proposed backlog — 2026-10-09

- [x] Review the five frontend views, theme/navigation, assistant flow, frontend mappings, relevant backend contracts, and user-provided itinerary screenshot.
- [x] Record findings and reusable lessons in [KNOWN_ISSUES.md](KNOWN_ISSUES.md) and publish this agent handoff. Documentation-only update; no application changes or runtime tests for this review.

All unchecked items below are proposals awaiting implementation scope from the user. An overall interest in redesign and permission to document findings do not authorize implementing this entire backlog. Preserve existing uncommitted work. No design direction has been adopted in DECISIONS.md.

### First: reliable navigation and truthful interactions

- [x] Restore compact navigation for all five views (KI-17) and address existing layout overflows (KI-16); verify phone, tablet, desktop, intermediate widths, text scaling, and long content. (2026-10-16 batch; 360/800/1440px checks, not exhaustive text-scale verification.)
- [x] Prevent busy-time composer text loss (KI-18), including Enter submission. Preserve trip fields/history and provide retry on assistant failures (KI-11, also tracked under Next). (2026-10-16 / 2026-10-17.)
- [x] Resolve misleading attraction Save and flight View Deal actions (KI-19) with agreed behavior or accurate labels; do not imply bookings or persistence. (2026-10-16.)
- [x] Align itinerary copy content and success feedback (KI-20). (2026-10-16.)
- [x] Distinguish demo itineraries from personalized completion and correct duration plurals (KI-22). (2026-10-16.)
- [x] Correct Discover capability claims (KI-23) and flight currency/party-total presentation (KI-24). (2026-10-16.)

### Next: connected planning and visual structure

- [ ] Define shared destination, dates, and traveler context across search views, with explicit overrides and an airport-selection strategy (KI-21).
- [x] Establish reusable content widths, responsive spacing, typography, button sizing, and card styles; select a visual direction before broad implementation. (Decisions 013–019.)
- [x] Improve itinerary hierarchy with a concise trip summary, clear day/date headings, readable activities, and no redundant single-day filters. Consider a trip-details column on wide screens. (2026-10-16 batches; two-column day cards on wide screens.)
- [x] Improve the assistant with editable trip details, quick choices, a direct View itinerary action, truthful loading feedback, and a keyboard-aware compact layout. Consider preserving drafts across panel closure as well as request failures. (2026-10-16 guided planning.)
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
- [ ] Validate dates, ordering, budget, roles, and appropriate payload sizes (KI-09). Plan request validation done 2026-10-16; chat roles/payload sizes remain.
- [ ] Standardize transport/error behavior and preserve recoverable chat state (KI-10, KI-11). Recoverable chat state done 2026-10-16; transport errors and exception detail remain.
- [x] Expand automated coverage beyond the existing app-title smoke test. (Frontend and backend suites, 2026-10-08 onward.)
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
- [x] Investigate Flutter smoke-test layout overflows (KI-16). (Smoke test passes since 2026-10-16.)

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
- [x] Fix inconsistent activity widths when optional notes are absent; add a mixed-content regression case. (Completed authorized refinement batch, 2026-10-16.)
- [x] Refine face crop vertical position and reduce itinerary card height after visual review. (Same batch; local visual acceptance pending.)

## Authorized next batch - user feedback, 2026-10-16

Implementation authorized by the user; deferred before starting because the five-hour usage window was already 89% consumed and the user requested a clean stop near the limit. No application edits made in this checkpoint. All six items were completed in the next section (2026-10-16).

- [x] Make activity tips feel like advice from Lemon: sharp miniature portrait, friendly heading and cool tinted surface; preserve actual note content. Also fix inconsistent activity widths and reduce excess card padding.
- [x] Replace traveler dropdown with numeric entry; keep validation for whole numbers 1-20, helpful errors, keyboard submission and edit-state preservation.
- [x] Replace/reset-proof date selection: keep the selected start date when subsequent dates adjust the end date, provide an explicit Change start / Restart selection action, show a clear range and inclusive day count, and retain existing 1-30 day/future-date validation. Define earlier-than-start feedback and same-day selection explicitly; cancellation must preserve the previously accepted range.
- [x] Refine Discover with a cool mint/sky/lavender palette, remove yellow from dashboard surfaces/actions, improve composition and add restrained animation that respects reduced-motion preferences.
- [x] Correct the shared portrait crop to include Lemon's complete face; modestly enlarge the launcher and add restrained motion/hover feedback. Use original-resolution artwork with preserved proportions. Verify visually in launcher, chat and tip contexts.
- [x] Investigate incomplete long itineraries. Enforce complete requested dates/day numbering and nonempty days before reporting success; implement a bounded generation/retry strategy that can actually cover long trips without silently accepting a partial plan. Preserve demo labeling and avoid presenting canned completion as a real personalized result.

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

## Flutter Web emoji fallback - 2026-10-17

- [ ] Resolve Flutter Web missing-emoji fallback without changing the app-wide typography.

The bundled font and app-wide registration were reverted after text spacing changed across the UI. Keep the existing platform-default font and readable text sizes; evaluate a narrowly scoped fallback or image-based emoji only if the warning recurs.


## Calendar, chat resizing and readability pass - 2026-10-17

- [x] Replace single-date calendar with an accessible month grid, clear arrival/return summaries and a continuous highlighted selected range. Keep the 30-day cap and explicit Change start behavior.
- [x] Keep API budget enum values low/medium/high; show Budget-friendly, Comfortable and Premium in the chat and trip brief, and phrase the choice prompt with those labels.
- [x] Give new itinerary notes occasional relevant Lemon/travel emoji in the backend prompt; tip introductions remain varied and the model is told not to add an emoji to every note.
- [x] Make Surprise me a visible outlined action button.
- [x] Replace desktop expand/shrink with a top-left drag grip; bound width to 360-900px and height to 360-850px, further limited by the viewport. Compact/mobile chat remains full-screen.
- [x] Remove the forced Segoe UI override, set more readable platform-default text styles, and increase chat bubble size/line spacing.
- [x] Restore the launcher’s full-proportion Lemon artwork after the enlarged circular face crop looked pixelated; remove forced decode dimensions and return shared avatars to medium downsampling.

Dart format completed. No tests or analyzer run for this pass; desktop/browser and Android appearance remain unverified locally. No API schema or dependency changes.

## Chat panel visual polish - 2026-10-17

- [x] Replace the square mint resize tab with six dots painted as a triangle tucked inside the panel's rounded top-left corner; dots brighten on hover. Resize behavior, bounds, tooltip and semantics label are unchanged.
- [x] Give the chat panel a soft lavender outline and tinted shadow, a mint→sky→lavender header with a lemon-ringed avatar, an online dot and teal subtitle, and a lavender→cream message background so it stands apart from the page.
- [x] Refine chat typography within platform-default fonts (heavier, tighter-tracked title; slightly tracked bubble text). User bubbles use a periwinkle gradient; Lemon bubbles are white with a soft lift. The composer sits on a white bar with a tinted rounded field and a filled circular Send button.

`flutter analyze --no-pub`: no issues. `flutter test --no-pub`: 32 passed, 4 failed. The same two `lemon_redesign_test.dart` failures (Desktop chat expands…, Calendar end edits…) also fail with the pre-change widget files, so they predate this pass (stale finders: the test still taps an "Enlarge chat" control that the drag grip replaced). The two `lemon_personality_ui_test.dart` failures exercise the launcher bubble, which this pass did not change; they were not rerun against the original code. Visual appearance not yet reviewed in a running app. No dependency or API changes; no custom font added (see the emoji-fallback note in KNOWN_ISSUES).

## Chat panel fonts - 2026-10-18

- [x] Bundle Fredoka (500/600/700) and Nunito (400–800) static TTFs plus OFL licences in `travel_planner_frontend/assets/fonts/`, declare them in `pubspec.yaml`, and apply them to the chat panel only through `AppTheme.chatTheme()` (DECISIONS 020). No package added.

`flutter analyze --no-pub`: no issues. `flutter test --no-pub`: 32 passed, 4 failed (the same four pre-existing failures recorded in KNOWN_ISSUES "Stale frontend tests"; no new failures). `flutter build web --no-pub` succeeded and the output contains all eight font files. The fonts' appearance in a running app has not been reviewed yet.

## App-wide fonts - 2026-10-18

- [x] Apply Fredoka (headings) and Nunito (body, buttons, inputs) across the whole frontend via `AppTheme.lightTheme` and explicit `displayFont` on hand-styled headings in Discover, Flights, Hotels, Attractions, Itinerary, the brand mark and the date dialog; remove the chat-only theme wrapper (DECISIONS 021). `dart format` run on the touched files.

`flutter analyze --no-pub`: no issues. `flutter test --no-pub`: 32 passed, 4 failed (the same four known failures; no new ones). Not yet reviewed visually in a running app, including emoji fallback with the new default family (see KNOWN_ISSUES "Flutter Web emoji fallback").

## Font pairing swap - 2026-10-18

- [x] Replace Fredoka/Nunito with Outfit (headings) and Plus Jakarta Sans (body) across the whole frontend; swap bundled TTFs, licences and pubspec entries and update the two `AppTheme` font constants (DECISIONS 022).

`flutter analyze --no-pub`: no issues. `flutter test --no-pub`: 32 passed, 4 failed (the same four known failures). `flutter build web --no-pub` succeeded and bundles only the nine Outfit/Plus Jakarta Sans files. Not yet reviewed visually in a running app; emoji fallback check from KNOWN_ISSUES "App-wide font change" still applies.

## Font revert - 2026-10-18

- [x] Revert all custom fonts (DECISIONS 023): remove bundled TTFs and the pubspec `fonts:` block, restore the committed theme/views/brand/date dialog, and return the chat title, trip brief label and itinerary card header to their pre-font sizes and weights. Chat panel colours/grip/bubbles and the ✈️ greeting are kept.
- [ ] User to review the base platform-default look and decide on any font changes.

`flutter analyze --no-pub`: no issues. `flutter test --no-pub`: 32 passed, 4 failed (the same four known failures). Not reviewed visually.

## Font trial: Playfair Display + Poppins + Roboto - 2026-10-18

- [x] Bundle Playfair Display (600–800) and Poppins (500–800) with OFL licences, register them in pubspec, add `AppTheme.titleFont`/`headingFont`, and tag titles/headings across views, brand, date dialog and chat. Body text stays platform default (DECISIONS 024). `dart format` run on touched files.
- [ ] User visual review of the trial; keep, adjust or revert.

`flutter analyze --no-pub`: no issues. `flutter test --no-pub`: 32 passed, 4 failed (the same four known failures). `flutter build web --no-pub` succeeded and bundles the seven font files. Not reviewed visually.

## Poppins + Roboto - 2026-10-18

- [x] Remove Playfair Display (DECISIONS 025); its title spots return to the platform default. Extend Poppins to the Flights airline badge and airline name.
- [ ] User visual review after a full app restart; new font assets do not load on hot reload/restart.

`flutter analyze --no-pub`: no issues. `flutter test --no-pub`: 32 passed, 4 failed (the same four known failures). `flutter build web --no-pub` succeeded, and its `FontManifest.json` registers Poppins 500–800 only. Not reviewed visually.

## Hero font and nav bar tint - 2026-10-18

- [x] Discover hero ("A little curiosity…") and side-card tagline ("Less planning…") use Poppins at w700, to match the Poppins section headings.
- [x] Top navigation bar (logo, view tabs, Ask Lemon) gets a soft cool tint `AppTheme.navBar` (#E8EDF5) with a hairline bottom border, so it no longer blends into the page background. The selected tab pill is now white, since lavender would vanish on the tint. Inactive tab labels use `AppTheme.navBarText` (#475569, ~6.5:1 on the bar) because the previous grey would drop to ~4.0:1.

`flutter analyze --no-pub`: no issues. `flutter test --no-pub`: 32 passed, 4 failed (the same four known failures). Not reviewed visually. Contrast ratios are computed, not measured in-app.

## Sky Mint redesign - 2026-10-18

Agreed through an HTML design mockup with the user (Sky Mint palette, lemon yellow for Lemon.ai and the main action, Roboto body, Poppins headings). Supersedes the nav-bar tint above.

- [x] `AppTheme`: cream background, Sky Mint pastel (`skyMint`) for secondary buttons/selected tab/chips, deeper mint (`primary`) for links and focus only, lighter text ink, `chatText` for chat copy, lemon (`accentLemon`/`lemonInk`) for elevated buttons. The old `lavenderTint`/`lavenderSubtle` names now hold mint tints.
- [x] Discover rebuilt: photo hero with Lemon on a lemon halo and greeting bubble, "How Lemon plans" steps, photo explore cards, photo destination cards with hover "Plan with Lemon", "Ready when you are" band, photo credits. Constructor and callbacks unchanged.
- [x] Real destination photos (Wikimedia Commons, credited) in `assets/images/photos/`, listed in `lib/config/discover_content.dart` so they can be swapped for the user's own images.
- [x] Brand mark on a lemon tile with "Trip" in `skyMintBright`; nav selected tab uses the pastel; Ask Lemon shows Lemon's avatar.
- [x] Chat panel keeps its structure, avatar and copy; recoloured, with a Where/When/Who/Budget/Loves progress bar and lemon send button. User bubbles use the pastel with dark text.
- [x] Launcher is lemon with a white ring and a finite pulse. Flights/Hotels/Attractions search buttons use lemon.
- [x] Motion (`lib/widgets/lemon_motion.dart`): finite float, pulse and slow hero zoom; card lift, photo zoom, arrow slide and reveal on hover/focus; staggered hero entrance (`GentleReveal.delay`). All skipped with `disableAnimations`.
- [ ] User visual review on desktop, phone width and Android after a full restart (new assets do not load on hot reload).

## Flight search timeout - 2026-10-18

- [x] Handle Duffel timeouts and transport failures in `routers/flights.py` (DECISIONS 027); flights wait 50 s in the frontend; offline tests added.
- [ ] User: restart the backend and retry a flight search (live Duffel not verified).
- [ ] Investigate the failing `test_chat_exhaustion_matches_explicit_mock` (pre-existing).
- [ ] Apply the same error handling to weather, places and hotels (rest of KI-10).

## Sign-in placeholder and other-page mockups - 2026-10-18

- [x] Top-bar "Ask Lemon" pill replaced by a "Sign in" placeholder (`home_screen.dart`): tooltip and a "Sign in is coming soon." snackbar only; no accounts exist. Analyzer clean; suite 32 passed, 4 failed (same four known stale tests).
- [x] Design mockups for Flights, Hotels, Attractions and My itinerary (photo banners, Lemon tips, how-to steps, animated cards, Roboto headings) on the shared design canvas. Not yet built in Flutter; awaiting user review.
- [x] Fix the "Ready when you are" avatar being cut off while floating: the float now moves the whole yellow circle instead of the artwork inside the clip (`discover_view.dart` `_ReadyBand`). Analyzer clean; suite 32 passed, 4 failed (same four).

## Search and itinerary pages built in Flutter - 2026-10-18

- [x] Flights, Hotels, Attractions and My itinerary rebuilt from the approved mockups (DECISIONS 029), with the user's three changes: per-day itinerary colours, Lemon avatars matching their background (except the Discover hero), larger and emphasised Lemon tips.
- [x] Flights gets a "Plan with Lemon" band (opens the chat). Analyzer clean; suite 41 passed, 4 failed (same four).
- [ ] User: visual review in the browser.

## Trip-page typography - 2026-10-18

- [x] Unbounded headings, Outfit body and Caveat for Lemon's notes on Flights, Hotels, Attractions and Itinerary (DECISIONS 030); Discover unchanged. Analyzer clean; suite 41 passed, 4 failed (same four known stale tests).
- [ ] User: visual review in the browser, especially long hotel/attraction names in Unbounded at 360 px and Caveat readability.

## Nav bar, bubble tails and quick routes - 2026-10-18

- [x] Darker sand nav bar, Discover hero bubble tail toward Lemon, Flights quick-route labels no longer clipped (DECISIONS 031). Analyzer clean; suite 41 passed, 4 failed (same four known stale tests).
- [ ] User: visual check in the browser. Other labels still use '→' (U+2192), e.g. flight route text; check whether it renders cleanly in Outfit.

## Fredoka tips and livelier itinerary voice - 2026-10-18

- [x] Fredoka replaces Caveat for Lemon's notes; cheerful rotating tip labels; itinerary prompt asks for lively notes (DECISIONS 032). Frontend: analyzer clean, 41 passed, 4 failed (same four). Backend offline suite: 31 passed, 1 failed (known `test_chat_exhaustion_matches_explicit_mock`).
- [ ] User: generate a live itinerary to judge the new tip tone (not verified; needs live providers).

## Bubble tails toward Lemon's head - 2026-10-18

- [x] Lemon's tip bubble raised to her face; chat bubbles' sharp corner moved to the top beside her avatar (DECISIONS 033). Analyzer clean; suite 41 passed, 4 failed (same four).
- [ ] User: visual check of the tip bubble on wide and 360 px banners and of multi-line chat messages.

## Discover typography trial and mint nav bar - 2026-10-19

- [x] Discover on Unbounded/Outfit with a Fredoka greeting bubble; nav bar pale Sky Mint (DECISIONS 034). Analyzer clean; suite 41 passed, 4 failed (same four).
- [ ] User: decide whether Discover keeps Unbounded/Outfit; check the hero headline at narrow widths and the selected tab against the mint bar.
