# API reference

## Scope

Checked against `travel_backend/routers/`, `travel_backend/models/` and `travel_backend/services/` on 2026-10-17; photos and caching added 2026-10-20. Default development base URL: `http://127.0.0.1:8000`. Interactive schema: `/docs`; OpenAPI: `/openapi.json`. Runtime calls were not performed in this documentation pass.

Routes currently have no authentication. JSON field names use snake_case. Request validation errors normally return HTTP 422 with `detail`; application HTTP errors use a `detail` field. External-service failures are not handled uniformly.

## Travel routes

| Method and path | Query parameters | Response |
|---|---|---|
| `GET /health` | None | `{"status":"ok"}` |
| `GET /weather/forecast` | Required `city: string`, 1–120 characters | `city`, `forecast[]` |
| `GET /places/attractions` | Required `city`, 1–120 characters; `radius_km: integer = 5`, range 1–20 | `city`, `attractions[]` |
| `GET /hotels/search` | Required `city`, 1–120 characters; `radius_km: integer = 5`, range 1–20 | `city`, `hotels[]` |
| `GET /flights/search` | Required `origin`, `destination` (three-letter IATA codes, surrounding spaces allowed), `departure_date` (a real `YYYY-MM-DD` date); `adults: integer = 1`, range 1–9 | `offers[]`, at most ten |
| `GET /airports/search` | Required `place: string`, 1–120 characters | `place`, `airports[]`, at most three (added 2026-10-24) |
| `GET /photos/place` | Required `place: string`, 1–120 characters | `place`, `country_code`, `country`, `source` (`"Pixabay"`), `photos[]`, at most three |
| `GET /photos/featured` | None | `source` (`"Pixabay"`), `photos[]`, at most ten (editors' choice travel photos, falling back to any travel photo) |
| `GET /photos/image/{photo_id}` | Path `photo_id: integer` from `photos[]` | Image bytes (`image/*`), `Cache-Control: public, max-age=86400` |

Item fields:

- `forecast[]`: `datetime` (upstream date-time string), `temp_c` (number), `condition`, `description` (strings). Fetches the current five-day/three-hour forecast; no trip-date query exists.
- `attractions[]`: `name` (string), `category` (string or null), `categories` (string array), `lat`, `lon` (numbers), `place_id` (Geoapify id, string or null; added 2026-11-05, DECISIONS 069, so a plan stop at the place can carry it). At most 40 places; features without a name or numeric coordinates are excluded.
  - `categories` (added 2026-11-01, DECISIONS 052) is every category string Geoapify gives the place. It is `[]` when Geoapify sends none or something other than a list, and non-string entries are dropped. `category` is unchanged for older clients: the first string of that list, or null.
  - Since DECISIONS 053 (2026-11-01) the backend makes four Geoapify searches at once, one per app chip: `tourism.attraction`; `tourism.sights`; `heritage,entertainment.museum,entertainment.culture`; `entertainment`. Each asks for 20 places, nearest to the city centre first (`bias=proximity:lon,lat`). Up to 10 are kept per search, after places already listed by an earlier search. Memorials with no more specific tag (usually street plaques) come last within their search. The response lists the searches in that order. `radius_km` is unchanged.
  - If some searches fail, the others are returned, and that partial result is not cached. If all fail, the first failure becomes the error (upstream status, 504 on timeout, else 502).
  - The 24 h attractions cache is in-process; a backend restart (including a `--reload`) clears it.
  - `/lemon/plan` uses this response as context. Since DECISIONS 069 the prompt gets a compact "Known places" list (ref, name, coordinates, kind) built from must-visits, Lemon's popular spots and these attractions, at most 40 in all, instead of the raw JSON.
- `hotels[]`: `name` (string), `address` (string or null), `lat`, `lon` (numbers). Requests up to 20 results and excludes unnamed hotels. No price, rating, or amenity fields.
- `offers[]`: `price` (upstream amount string), `currency` (string), `duration` (upstream duration or null), `stops` (integer), `departure`, `departure_time`, `arrival`, `arrival_time`, `carrier` (strings), `arrival_city` (the arrival airport's `city_name`, string or null; added 2026-10-20 for banner photos).

- `airports[]` (`models/airports.py`): `iata_code`, `name` (strings), `city_name` (string or null). Duffel place suggestions are searched by name and only airports whose city is the place, or whose name contains it as a whole word, are kept. Otherwise the place is geocoded (OpenWeatherMap) and Duffel airports within 100 km are returned, nearest first. Unknown places give an empty list. Errors: 503 without `DUFFEL_API_KEY`, 504 on timeout, upstream status for Duffel HTTP errors, 502 for other failures. Cached 24 h per normalized place.

- `photos[]` (`models/photos.py`): `id` (integer), `image_url` (backend-relative path such as `/photos/image/123`; clients prefix the API base URL), `page_url`, `photographer`, `photographer_url`, `tags` (strings). Photos show the place's **country** (from the geocoded `country` code); when the code isn't in `services/countries.py`, the place name is searched instead. Pixabay must be credited wherever one is shown.

Photo errors: 503 when `PIXABAY_API_KEY` is not configured, 404 when the place can't be geocoded or an image id is unknown (image ids are learned from searches and forgotten on restart), 429 when Pixabay rate-limits, 502 for other Pixabay or download failures. Error details never include the request URL, which carries the key.

**Geocoding (2026-10-24, DECISIONS 039).** Every place-based route geocodes with Geoapify, falling back to OpenWeatherMap only when Geoapify fails. For a region (island, state, prefecture) without a same-named city in that country, `/hotels/search` and `/places/attractions` search the region's whole boundary and ignore `radius_km`; the response `city` is then the region's name (e.g. "Bali"). Unknown places return 404 as before.

**Caching (2026-10-20, DECISIONS 035).** Successful results are cached in memory per process; errors are never cached, and identical concurrent requests share one upstream call. A backend restart (including `uvicorn --reload`) empties every cache. Geocoding (shared by weather, places, hotels, photos): 24 h per normalized city name. Forecast: 30 min. Attractions and hotels: 24 h per city and radius. Flights: 5 min per origin, destination, date and adults. Pixabay searches: 24 h per country, and 24 h for the featured set (their terms require 24 h caching). Images: 24 h, at most 80 kept. `/lemon/chat` and `/lemon/plan` responses are not cached; plan context lookups use the cached weather and attraction routes.

Flight codes are trimmed and uppercased. Since 2026-10-24 malformed codes and dates are rejected with 422 before Duffel is called. Flights submit an economy, one-way offer request to Duffel with `return_offers=true`. Test versus live data depends on configured credentials/service behavior; no booking endpoint exists.

## POST /lemon/plan

JSON request:

| Field | Type | Required/default | Validation in model |
|---|---|---|---|
| `destination` | string | Required | Trimmed, 1–120 characters |
| `start_date` | string | Required | Valid calendar date in exact YYYY-MM-DD form |
| `end_date` | string | Required | Valid YYYY-MM-DD; end >= start; 1–30 inclusive days |
| `travelers` | integer | 1 | 1–20 |
| `budget_level` | string | `medium` | Enum: low, medium, high |
| `interests` | string array | `[]` | At most 12 trimmed, nonempty strings, each at most 120 characters |
| `pace` | string | `balanced` | Enum: relaxed (2–3 activities a day), balanced (3–5), packed (5–7). DECISIONS 069 |
| `must_visit` | array | `[]` | At most 10 items `{name (1–120), place_id?, lat?, lon?, matched_name? (≤ 200)}`; each must appear in the plan (DECISIONS 069). `matched_name` is the map's name from the chat check (DECISIONS 071) |
| `provider` | string | `mock` | Resolved by provider factory |

```json
{
  "destination": "Kyoto",
  "start_date": "2026-11-01",
  "end_date": "2026-11-03",
  "travelers": 2,
  "budget_level": "medium",
  "interests": ["food", "temples"],
  "pace": "relaxed",
  "must_visit": [{"name": "Fushimi Inari Taisha", "place_id": "51...", "lat": 34.967, "lon": 135.773}],
  "provider": "mock"
}
```

Response fields:

- Required `destination: string`, `provider_used: string`, `days: array`.
- `summary: string | null`, default null.
- Each day: required `day: integer`, required `activities: array`, optional `date: string | null` (default null).
- Each activity: required `time: string`, `activity: string`; optional `location: string | null`, `notes: string | null` (default null).
- Since DECISIONS 069, each activity also has `place_id: string | null`, `lat`, `lon: number | null` and `place_status: "verified" | "unverified" | null`, all set by the server, never taken from the model. `verified`: the stop is at a known place (the model's `place_ref` into the prompt's known places) or matched by a Geoapify lookup near the destination. `unverified`: it names a place no lookup matched. Null: no specific place (meals, free time, "your hotel", the city itself), a demo plan, or the check didn't run (no destination centre, lookup error, more than 100 distinct places, or past the 20 s grounding limit). The model's `place_ref` is never returned. Since DECISIONS 071, a `verified` activity also has `place_name: string | null`, the map's name for the place it was matched to (a must-visit's `matched_name` when it has one), also set only by the server; the app shows it when it differs from `location`. Matching needs every distinctive word of the asked name in the map's name (shop, food and Japanese place-type words like "kissa" don't count).
- Must-visits are spread over the days before writing: nearby ones (within 3 km) share a day where they can, and outdoor-sounding ones avoid days whose forecast says rain is likely. A window whose output leaves out its assigned must-visit fails validation (one corrective retry, then the next provider, as for any bad output). Since DECISIONS 070, if every provider still leaves them out, the window's otherwise-valid output is kept rather than making the plan demo, and the response's `missing_must_visits: string[]` (default `[]`) names the must-visits found nowhere in the plan. The app asks before showing a plan that has none of them.
- The prompt gets the weather as one line per forecast day (low/high, main condition, "rain likely"), instead of the raw forecast JSON. Popular spots and the destination centre are extra context lookups (10 s each); a demo plan skips them.

The builder sets destination from the request and validates each generation window (see Timing and generation behavior below). `provider_used` names the provider that produced every window, or is `auto` when an `auto` plan was written by more than one provider (each window falls back on its own, DECISIONS 063). `mock` means every day is demo output (any window that fails on every provider makes the whole plan demo); demo responses carry a disclosure summary. Mock generation returns one placeholder activity per requested date. Validation failures in the request return 422. Weather/attraction context is attempted even for mock; this endpoint is not inherently offline.

## POST /lemon/edit

Added 2026-11-05 (DECISIONS 069). Changes one day of an existing plan and returns only that day, for the app to preview.

Request: `trip` (the plan's TripRequest, as above), `days` (the whole current plan, 1–30 days, as returned by `/lemon/plan`), `action` (`regenerate_day`, `swap_activity` or `adjust_day`), `day` (absolute day number, must be in `days`), `stop` (1-based stop on that day; required for `swap_activity`), `instruction` (at most 300 characters; required, non-blank, for `adjust_day`). Inconsistent requests are 422.

Response: `day` (one day, same shape as a plan day, with grounding fields), `provider_used`, and `missing_must_visits` (must-visits the day had before and no longer has, when every provider left them out; DECISIONS 070, default `[]`).

- The day is one window through the same chain as a plan (`auto`: Groq → Gemini → OpenRouter, 75 s each, with the 429 wait and the one corrective retry). The prompt lists the places other days already use, to avoid repeats, and keeps the day's must-visits (except a stop the traveller asked to swap).
- `swap_activity`: the model returns one replacement, which must differ from the old stop; the server puts it in the stop's place with the stop's time and keeps the other stops as they were.
- If every provider fails: **502** "Lemon couldn't change that day right now. Your plan is unchanged." A real plan never gets a demo day. With `provider: mock`, the day is a placeholder (`provider_used: mock`).

## GET /lemon/spots

Added 2026-11-05 (DECISIONS 069). Query: `destination` (1–120 characters), optional repeated `interests` (at most 12).

Response: `status` (`ready`, `none`, `too_broad` for a whole country, or `unavailable`), `destination`, `spots` (most popular first: `name`, `wikidata`, `place_id`, `lat`, `lon`, `popularity` = number of language Wikipedias, `kind` such as `museum`, `tower`, `worship`, `park`), `picks` (names Lemon chooses on "surprise me": the most popular, with up to half swapped for spots suiting the interests).

- Geoapify geocodes the destination (a country is `too_broad`, no further calls); Wikidata's search finds its item near that point; one Wikidata SPARQL query lists visitor places located anywhere inside it with at least 8 sitelinks, leaving out demolished places, national parks and office buildings (skyscrapers only with 40+ sitelinks), and at most 5 of one kind before the rest; each of up to 25 spots is confirmed with a Geoapify lookup within 1.5 km of Wikidata's coordinates (unconfirmed ones dropped); at most 20 returned.
- Cached 24 h per destination; errors are not cached. The route waits up to 60 s (Paris took 27 s live, Kuala Lumpur 12 s, Lisbon 14 s) and keeps loading in the background after that, so a later request is quick. `/lemon/chat` starts this lookup in the background whenever it verifies a destination.
- Wikidata needs no key; its User-Agent carries `WIKIDATA_CONTACT` (Wikimedia bot policy). Cost per new destination: about 25 Geoapify credits plus 3 Wikidata requests.

## POST /lemon/chat

Request fields:

- Required `messages: array` ordered oldest first. Each item has required `role: string` and `content: string`.
- Optional `provider: string`, default `mock`.
- Optional `plan_summary: string` (at most 8000 characters) and `plan_days: integer` (1–30), sent once a plan exists (DECISIONS 069): the plan as numbered lines per day, so Lemon can read edit requests.
- Role descriptions suggest user/assistant, but no enum enforces this. Empty histories are accepted by the model.

```json
{
  "messages": [{"role": "user", "content": "I want to go to Kyoto"}],
  "provider": "mock"
}
```

Response fields:

| Field | Type | Default in response model |
|---|---|---|
| `reply` | string | Required |
| `destination`, `start_date`, `end_date` | string or null | null |
| `travelers` | integer or null | null |
| `budget_level` | string or null | null |
| `interests` | string array | `[]` |
| `ready` | boolean | false |
| `next_field` | string or null | null |
| `intent` | string | `trip` |
| `inferred` | string array | `[]` |
| `destination_status` | string or null | null |
| `destination_options` | string array | `[]` |
| `destination_label` | string or null | null |
| `destination_alternatives` | string array | `[]` |
| `fallback_used` | boolean | false |
| `pace` | string or null | null |
| `must_visit` | array of `{name, status, place_id, lat, lon, matched_name}` | `[]` |
| `spots_to_lemon` | boolean | false |
| `edit` | object or null | null |

Since 2026-11-05 (DECISIONS 069):

- **`pace`**: `relaxed`, `balanced` or `packed` when said (or inferred, listed in `inferred`), else null.
- **`must_visit`**: places the traveller named. The server checks each one near the destination with a Geoapify lookup (10 s): `verified` (with `place_id` and coordinates), `not_found`, or `unverified` (the check didn't run: destination not verified, explicit `mock`, or the lookup failed). The destination itself and duplicates are dropped; at most 10.
- **`spots_to_lemon`**: the latest message leaves the choice of spots to Lemon ("up to you", "surprise me").
- **New intents** `edit_plan` and `plan_question`. `edit` is `{action, day, stop, instruction}` only for a usable `edit_plan`; the server checks it against `plan_days` and fixes the reply: "On it! …" when usable, otherwise a question (which day, which stop, what to change), or "Let's build your plan first!" without a plan. `plan_question` always gets a fixed "coming soon" reply. A model can't set `edit` with any other intent.

Since 2026-11-04 (DECISIONS 059):

- **Required vs optional.** Only destination, start_date and end_date are required. `next_field` is the first missing of `destination`, `start_date`, `end_date`; `confirm` once all three are known; null when `ready`. The server recomputes it, whatever the model said. Travelers, budget and interests stay null when never mentioned; the app shows defaults (1 traveler, medium, surprise me).
- **`intent`** of the latest user message: `trip`, `small_talk`, `off_topic`, `gibberish`, `unsafe`, `unhappy`, `switch_to_guided`, `switch_to_free` (and since 069 `edit_plan`, `plan_question`). Unknown values from a model become `trip`.
- **`inferred`**: fields guessed from wording rather than stated, any of `travelers`, `budget_level`, `interests`, `end_date`; only fields that are filled are listed.
- **Pre-filter.** A latest user message that is empty, keyboard-mash, repeated characters, contains a link, or matches a prompt-injection phrase never reaches a provider. The response then has that intent, a fixed reply, and null fields (`next_field` null); the client keeps what it has.
- **Checks on the output.** Dates must be valid ISO dates, from today, ordered, and at most 30 days (else both are cleared and the reply asks again). Travelers outside 1–20 become null with a question. `budget_level` is normalised to lowercase `low`/`medium`/`high` or null. Interests are trimmed, de-duplicated, at most 12 of at most 120 characters.
- **Destination check** through the shared Geoapify search (24 h cache, 8 s limit): `verified`; `not_found` (destination set to null, reply asks again); `ambiguous` (same name in several countries or states whose Geoapify importance is within 0.15 of each other, or unscored; destination null, `destination_options` such as `Paris, France`, at most 4); `unverified` when the check is unavailable or the provider is explicit `mock` (which stays offline). A name that already includes a comma ("Paris, France") is not asked about again. Since DECISIONS 068: a famous same-name place (importance ahead by 0.15 or more) is `verified` with the others in `destination_alternatives` (at most 4); every verified place carries `destination_label` with its country ("Kyoto, Japan"; a comma-qualified name keeps the traveller's words), which the app shows and sends as the plan's `destination`. A country offered next to a same-name region is labelled "Georgia (country)", and the geocoder searches countries only for that suffix. Islands that Geoapify files as `amenity` are found when nothing else matches. The check makes an ordinary and a country-only Geoapify search together.
- **`fallback_used`** is true when the local parser answered (explicit `mock`, or auto with every provider exhausted). Models cannot set it, `destination_status`, `destination_options`, `destination_label` or `destination_alternatives`.
- When a check finds a problem, `reply` is replaced by a fixed question about it and `ready` is false.

The response has no provider_used field. Full history must be sent each turn; the backend stores no conversation session.

## Providers and errors

Factory options, matched case-insensitively: `auto`, `groq`, `gemini`, `openrouter`, `mock`. Auto tries Groq → Gemini → OpenRouter, validating JSON and the response model within each attempt. Failed providers get a process-local cooldown by failure kind (DECISIONS 042): five minutes for hard failures (401/403, 404, missing key, construction and other call errors); for 429 the `Retry-After` value (1 s–1 h), else five minutes; 30 seconds for 503 unavailable (DECISIONS 061), a mid-stream `json_validate_failed` (DECISIONS 064), a provider's own timeout or stall, and invalid JSON or a reply that fails validation; none when only the caller's shared budget ran out. Exhaustion uses the local mock chat parser or demo itinerary (`provider_used: mock`). Chat response fields are unchanged. Unknown names, including `claude` and `gpt`, map to **502**. Both auto routes passed isolated offline HTTP tests on 2026-10-08; historical live diagnostics are recorded separately in TESTING.md.

Lemon generation, JSON parsing, and response validation failures map to 502. Since 2026-10-24 the 502 `detail` is a fixed message ("Lemon couldn't build this itinerary right now. Please try again." / "Lemon had trouble understanding that. Please try again." / since 069 "Lemon couldn't change that day right now. Your plan is unchanged."); the exception is logged server-side only. Chat requests are validated: `role` must be `user` or `assistant`, `content` at most 2000 characters, at most 100 messages, `provider` at most 20 characters (422 otherwise).

Data routes (weather, places, hotels, flights, airports; 2026-10-24): upstream HTTP status errors are forwarded, timeouts return 504, transport failures and non-JSON bodies return 502 with a generic detail (never the request URL, which carries keys), and malformed items are skipped instead of failing the response. Geocoding returns 404 when no city matches. Missing Duffel credentials return 500 on flights and 503 on airports.

The Flutter travel service preserves empty results and displays failures with Retry. It does not substitute fictional listings. These are client behaviors; backend travel response fields are unchanged.

## Timing and generation behavior

Current values as of 2026-10-17; earlier 36/12/60-second plan values are superseded (see DECISIONS.md 015–016).

- **Chat with `auto`:** 9 seconds per real-provider attempt and 30 seconds total across attempts; each attempt receives the smaller of its allowance and the remaining budget. Timeout triggers a 30-second cooldown and next-provider/local-chat fallback. Direct chat providers have no extra deadline. Frontend chat timeout: 45 seconds.
- **Plan context:** weather, attraction, popular-spot and destination-centre lookups run concurrently with ten-second wait bounds, using an explicit 5 km attraction radius (spots and centre skipped for demo plans). After generation, grounding lookups run at most 5 per second, at most 100 per plan, within 20 s.
- **Day edits** (`/lemon/edit`): one window; 75 s per provider, at most 3 × 75 s with `auto`. Frontend edit timeout: 25 s + 75 s, times 3 for `auto` (250 s; 100 s for one named provider), `LemonApiService.editTimeoutFor`.
- **Spots** (`/lemon/spots`): the route waits up to 60 s; the frontend waits 65 s.
- **Plan generation:** the inclusive date range is divided into windows of up to three days, at most three concurrent. Each window gets 75 seconds from when it starts, under an overall cap of 75 seconds per wave of three windows (75/150/225/300 s for 1–9/10–18/19–27/28–30 days). Auto attempts stream: a provider is cut off only after 10 seconds without a new chunk (25 seconds before the first chunk), otherwise it may use the window's remaining budget; direct providers share the same window budget. Each real response must include exactly its requested dates and absolute day numbers in order, with nonempty activities; invalid partial responses are never returned as a successful complete plan. Direct providers get one corrective retry per window. With `auto`, a window that gets a 429 waits its Retry-After and asks the same provider again if at least 15 s of its budget would remain (DECISIONS 061); any other failed window ends that provider's turn: the rest of its windows are cancelled and the whole plan restarts with the next provider (Groq → Gemini → OpenRouter), each turn with a fresh budget; if all fail, the whole plan is demo. Frontend plan timeout: 25 seconds plus 75 seconds per wave, times 3 for `auto` (250/475/700/925 s); a single named provider gets one turn (100/175/250/325 s).

These are asynchronous wait bounds. Event-loop blocking, local processing, and network delivery are not hard wall-clock guarantees, and late SDK cancellation may continue in the background. Restart both frontend and backend after changing coordinated timeout values.

## Client usage

The LemonTrip UI has two chat modes (DECISIONS 059). **Free text** (default): every user message goes to /lemon/chat, and the app merges the non-null fields it gets back. **Guided**: /lemon/chat interprets only the destination, and the rest is collected through structured controls. Both call /lemon/plan after explicit confirmation, filling travelers 1, budget `medium`, pace `balanced` and empty interests for anything left out. Since DECISIONS 069 the app also calls /lemon/spots once the destination is known, sends the chosen must-visits with the plan, keeps the chat open after the plan (sending `plan_summary`), and calls /lemon/edit for day edits, replacing a day only after the traveller accepts the preview. /lemon/plan itself still accepts historical date ranges; /lemon/chat and the UI date picker start at today.
