# API reference

## Scope

Checked against `travel_backend/routers/` and `travel_backend/models/` on 2026-10-08. Default development base URL: `http://127.0.0.1:8000`. Interactive schema: `/docs`; OpenAPI: `/openapi.json`. Runtime calls were not performed in this documentation pass.

Routes currently have no authentication. JSON field names use snake_case. Request validation errors normally return HTTP 422 with `detail`; application HTTP errors use a `detail` field. External-service failures are not handled uniformly.

## Travel routes

| Method and path | Query parameters | Response |
|---|---|---|
| `GET /health` | None | `{"status":"ok"}` |
| `GET /weather/forecast` | Required `city: string` | `city`, `forecast[]` |
| `GET /places/attractions` | Required `city`; `radius_km: integer = 5`, range 1–20 | `city`, `attractions[]` |
| `GET /hotels/search` | Required `city`; `radius_km: integer = 5`, range 1–20 | `city`, `hotels[]` |
| `GET /flights/search` | Required `origin`, `destination`, `departure_date` strings; `adults: integer = 1`, range 1–9 | `offers[]`, at most ten |

Item fields:

- `forecast[]`: `datetime` (upstream date-time string), `temp_c` (number), `condition`, `description` (strings). Fetches the current five-day/three-hour forecast; no trip-date query exists.
- `attractions[]`: `name` (string), `category` (string or null), `lat`, `lon` (numbers). Requests up to 20 results and excludes features without a name.
- `hotels[]`: `name` (string), `address` (string or null), `lat`, `lon` (numbers). Requests up to 20 results and excludes unnamed hotels. No price, rating, or amenity fields.
- `offers[]`: `price` (upstream amount string), `currency` (string), `duration` (upstream duration or null), `stops` (integer), `departure`, `departure_time`, `arrival`, `arrival_time`, `carrier` (strings).

Flight codes are uppercased. Date format and IATA code shape are not validated by these route declarations. Flights submit an economy, one-way offer request to Duffel with `return_offers=true`. Test versus live data depends on configured credentials/service behavior; no booking endpoint exists.

## POST /lemon/plan

JSON request:

| Field | Type | Required/default | Validation in model |
|---|---|---|---|
| `destination` | string | Required | No minimum length |
| `start_date` | string | Required | Described as YYYY-MM-DD; not a date type |
| `end_date` | string | Required | No ordering validation |
| `travelers` | integer | 1 | 1–20 |
| `budget_level` | string | `medium` | Suggested low/medium/high, not an enum |
| `interests` | string array | `[]` | List of strings |
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

The builder sets destination from the request and provider_used from the provider instance, then validates the response. Mock returns one canned day with null date regardless of the requested trip length. Weather/attraction context is attempted even for mock; this endpoint is not inherently offline.

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

Factory options, matched case-insensitively: `auto`, `groq`, `gemini`, `openrouter`, `mock`. Auto tries Groq → Gemini → OpenRouter, validating JSON and the response model within each attempt. Construction, call, or validation failure triggers a five-minute process-local cooldown. Exhaustion uses the local mock chat parser or demo itinerary (`provider_used: mock`). Chat response fields are unchanged. Unknown names, including `claude` and `gpt`, map to **502**. Both auto routes passed isolated offline HTTP tests on 2026-10-08; historical live diagnostics are recorded separately in TESTING.md.

Lemon generation, JSON parsing, and response validation failures map to 502. Geocoding can return 404 for no city match, upstream status codes for HTTP failures, or 502 for transport failures. Missing Duffel credentials return 500. Data routes forward upstream HTTP status errors but do not uniformly catch transport errors or malformed upstream payloads, which may become 500 responses.

The Flutter travel service preserves empty results and displays failures with Retry. It does not substitute fictional listings. These are client behaviors; backend travel response fields are unchanged.

## Auto chat deadlines — 2026-10-08

POST /lemon/chat with provider=auto now allows 9 seconds per real-provider attempt and 30 seconds total across real-provider attempts. Each attempt receives the smaller of its allowance and the remaining budget. Timeout triggers the existing five-minute cooldown and next-provider/local-chat fallback. The frontend remains at 45 seconds. Direct chat-provider requests have no new deadline. Plan timing is described below. Response fields are unchanged.

## Itinerary deadlines — 2026-10-08

Plan context lookups run concurrently with ten-second wait bounds, using an explicit 5 km attraction radius. Auto generation gets 12 seconds per provider and a 36-second total real-provider budget, then validated mock fallback. Explicit plan providers get a 36-second generation wait bound and return the existing 502 on timeout. These roughly 46 seconds of asynchronous waits leave margin under the frontend's 60-second timeout. Event-loop blocking, local processing, and network delivery are not hard wall-clock guarantees. Late SDK cancellation may continue in the background. Response schemas are unchanged.
