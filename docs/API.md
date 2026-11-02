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
- `attractions[]`: `name` (string), `category` (string or null), `categories` (string array), `lat`, `lon` (numbers). At most 40 places; features without a name or numeric coordinates are excluded.
  - `categories` (added 2026-11-01, DECISIONS 052) is every category string Geoapify gives the place. It is `[]` when Geoapify sends none or something other than a list, and non-string entries are dropped. `category` is unchanged for older clients: the first string of that list, or null.
  - Since DECISIONS 053 (2026-11-01) the backend makes four Geoapify searches at once, one per app chip: `tourism.attraction`; `tourism.sights`; `heritage,entertainment.museum,entertainment.culture`; `entertainment`. Each asks for 20 places, nearest to the city centre first (`bias=proximity:lon,lat`). Up to 10 are kept per search, after places already listed by an earlier search. Memorials with no more specific tag (usually street plaques) come last within their search. The response lists the searches in that order. `radius_km` is unchanged.
  - If some searches fail, the others are returned, and that partial result is not cached. If all fail, the first failure becomes the error (upstream status, 504 on timeout, else 502).
  - The 24 h attractions cache is in-process; a backend restart (including a `--reload`) clears it.
  - `/lemon/plan` passes this response as prompt context, so up to 40 places with their category lists reach the itinerary prompt (up to 20 before 053).
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
| `provider` | string | `mock` | Resolved by provider factory |

```json
{
  "destination": "Kyoto",
  "start_date": "2026-11-01",
  "end_date": "2026-11-03",
  "travelers": 2,
  "budget_level": "medium",
  "interests": ["food", "temples"],
  "provider": "mock"
}
```

Response fields:

- Required `destination: string`, `provider_used: string`, `days: array`.
- `summary: string | null`, default null.
- Each day: required `day: integer`, required `activities: array`, optional `date: string | null` (default null).
- Each activity: required `time: string`, `activity: string`; optional `location: string | null`, `notes: string | null` (default null).

The builder sets destination from the request and validates each generation window (see Timing and generation behavior below). `provider_used` names the provider when one real provider produced every window, `auto` when several real providers contributed, and `mock` if any window is demo output; demo responses carry a disclosure summary. Mock generation returns one placeholder activity per requested date. Validation failures in the request return 422. Weather/attraction context is attempted even for mock; this endpoint is not inherently offline.

## POST /lemon/chat

Request fields:

- Required `messages: array` ordered oldest first. Each item has required `role: string` and `content: string`.
- Optional `provider: string`, default `mock`.
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

Intended next_field values: destination, start_date, end_date, travelers, budget_level, interests, confirm, or null. These values are descriptive rather than enum-constrained. The response has no provider_used field. The frontend follows ready plus destination/start/end presence with a separate plan request. Full history must be sent each turn; the backend stores no conversation session.

## Providers and errors

Factory options, matched case-insensitively: `auto`, `groq`, `gemini`, `openrouter`, `mock`. Auto tries Groq → Gemini → OpenRouter, validating JSON and the response model within each attempt. Failed providers get a process-local cooldown by failure kind (DECISIONS 042): five minutes for hard failures (401/403, 404, 503, missing key, construction and other call errors); for 429 the `Retry-After` value (1 s–1 h), else five minutes; 30 seconds for a provider's own timeout or stall and for invalid JSON or a reply that fails validation; none when only the caller's shared budget ran out. Exhaustion uses the local mock chat parser or demo itinerary (`provider_used: mock`). Chat response fields are unchanged. Unknown names, including `claude` and `gpt`, map to **502**. Both auto routes passed isolated offline HTTP tests on 2026-10-08; historical live diagnostics are recorded separately in TESTING.md.

Lemon generation, JSON parsing, and response validation failures map to 502. Since 2026-10-24 the 502 `detail` is a fixed message ("Lemon couldn't build this itinerary right now. Please try again." / "Lemon had trouble understanding that. Please try again."); the exception is logged server-side only. Chat requests are validated: `role` must be `user` or `assistant`, `content` at most 2000 characters, at most 100 messages, `provider` at most 20 characters (422 otherwise).

Data routes (weather, places, hotels, flights, airports; 2026-10-24): upstream HTTP status errors are forwarded, timeouts return 504, transport failures and non-JSON bodies return 502 with a generic detail (never the request URL, which carries keys), and malformed items are skipped instead of failing the response. Geocoding returns 404 when no city matches. Missing Duffel credentials return 500 on flights and 503 on airports.

The Flutter travel service preserves empty results and displays failures with Retry. It does not substitute fictional listings. These are client behaviors; backend travel response fields are unchanged.

## Timing and generation behavior

Current values as of 2026-10-17; earlier 36/12/60-second plan values are superseded (see DECISIONS.md 015–016).

- **Chat with `auto`:** 9 seconds per real-provider attempt and 30 seconds total across attempts; each attempt receives the smaller of its allowance and the remaining budget. Timeout triggers a 30-second cooldown and next-provider/local-chat fallback. Direct chat providers have no extra deadline. Frontend chat timeout: 45 seconds.
- **Plan context:** weather and attraction lookups run concurrently with ten-second wait bounds, using an explicit 5 km attraction radius.
- **Plan generation:** the inclusive date range is divided into windows of up to three days, at most three concurrent. Each window gets 75 seconds from when it starts, under an overall cap of 75 seconds per wave of three windows (75/150/225/300 s for 1–9/10–18/19–27/28–30 days). Auto attempts stream: a provider is cut off only after 10 seconds without a new chunk (25 seconds before the first chunk), otherwise it may use the window's remaining budget; direct providers share the same window budget. Each real response must include exactly its requested dates and absolute day numbers in order, with nonempty activities; invalid partial responses are retried or fallback-validated, never returned as a successful complete plan. Frontend plan timeout: 25 seconds plus 75 seconds per wave (100/175/250/325 s).

These are asynchronous wait bounds. Event-loop blocking, local processing, and network delivery are not hard wall-clock guarantees, and late SDK cancellation may continue in the background. Restart both frontend and backend after changing coordinated timeout values.

## Client usage

The LemonTrip UI uses /lemon/chat only for destination interpretation, collects the remaining fields through structured controls, and calls /lemon/plan after explicit confirmation. The server accepts historical date ranges; the UI date picker starts at today.
