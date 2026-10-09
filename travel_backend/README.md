# Travel Planner Backend (v0.3 — data layer + Lemon.ai)

> **Documentation review, 2026-10-08:** Current contracts and verification limits
> are in [API](../docs/API.md), [Testing](../docs/TESTING.md), and
> [Known issues](../docs/KNOWN_ISSUES.md). Historical verification notes below
> have not been rerun. A secret-free `.env.example` is included; this machine's
> existing backend virtual environment points to a missing Python installation.
> Use the root [README](../README.md) for the updated PowerShell setup guidance.

View-only travel data API: weather, attractions, flights, hotels — plus Lemon.ai,
the AI itinerary planner. No booking or payment logic — this is intentional for
this stage of the project.

> **Note:** Amadeus for Developers' self-service portal was decommissioned on
> July 17, 2026. This backend no longer uses Amadeus — see the provider table below.

## Setup

```bash
cd travel_backend
python -m venv venv
source venv/bin/activate        # Windows: venv\Scripts\activate
pip install -r requirements.txt
test -e .env || cp .env.example .env  # preserve existing settings; fill keys privately
uvicorn main:app --reload
```

Open http://127.0.0.1:8000/docs to try every endpoint interactively.

## Getting API keys

| Data | Provider | Sign up | Cost |
|---|---|---|---|
| Weather | OpenWeatherMap | https://home.openweathermap.org/users/sign_up | Free, no card |
| Attractions & Hotels | Geoapify Places | https://www.geoapify.com/ | Free tier, no card |
| Flights (sandbox data) | Duffel (test mode) | https://duffel.com/ | Free test key, no card |
| Lemon.ai — Groq (`groq`) | Groq; `GROQ_API_KEY` | Provider account required | Current pricing not verified |
| Lemon.ai — Gemini (`gemini`) | Google; `GEMINI_API_KEY` | Provider account required | Current pricing not verified |
| Lemon.ai — OpenRouter (`openrouter`) | OpenRouter; `OPENROUTER_API_KEY` | Provider account required | Current pricing not verified |
| Lemon.ai — mock (`mock`) | Local demo | No model account | No model API call |
| Lemon.ai — automatic (`auto`) | Groq → Gemini → OpenRouter → mock | Registered with response validation | Offline fallback tests pass; live calls unverified |

## Endpoints

| Endpoint | Purpose |
|---|---|
| `GET /weather/forecast?city=Tokyo` | 5-day forecast for a city |
| `GET /places/attractions?city=Paris` | Points of interest near a city |
| `GET /hotels/search?city=Paris` | Hotel listings near a city (name/location only, no pricing) |
| `GET /flights/search?origin=KUL&destination=NRT&departure_date=2026-12-01` | Flight offers from Duffel sandbox data |
| `POST /lemon/plan` | Single-call AI itinerary generation (see below) |
| `POST /lemon/chat` | Full-history conversation intake; returns extracted trip fields, reply, ready, and next_field |

The Flutter client sends `auto`, now registered with guarded construction,
response validation, cooldowns, and task-appropriate local fallback (KI-01/KI-02).

## Known limitations for this stage

- Geoapify hotel data has no live pricing — acceptable for now since booking/payments
  are deliberately out of scope until later.
- Duffel test mode returns realistic but simulated data, not live fares.
- No caching yet — repeated identical requests will re-hit the external APIs. Fine for dev, worth
  adding (e.g. simple in-memory TTL cache) before heavier use.
- No auth/user accounts yet — all endpoints are open. Add before this touches real users.

## Lemon.ai — the AI planning layer

`POST /lemon/plan` generates a full itinerary in a single AI call. Request body:

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

Factory-supported `provider` values are `"auto"`, `"groq"`, `"gemini"`, `"openrouter"`, and
`"mock"`. Both request models default to `"mock"`. Auto retries failed real providers;
`"claude"` and `"gpt"` are no longer registered in the current working tree.
Use the corresponding `GROQ_API_KEY`, `GEMINI_API_KEY`, or `OPENROUTER_API_KEY`
for a real provider. Mock chat is local; mock itinerary generation still
attempts external weather/attraction context before returning canned data.

Weather/attraction lookups feed into the prompt as context automatically; if either
fails (bad city name, API down), the itinerary is still generated using general
knowledge instead of crashing the whole request.

### Historical verification notes (not current test results)
- `/health`, `/weather`, `/places`, `/hotels`, `/flights`, `/lemon/plan` (mock, gemini providers) — all run and return either correct data or a clean HTTP error, never a crash.
- Found and fixed several real bugs during this verification pass:
  - Gemini's SDK erroring at construction with an empty key.
  - `_geocode_city` (shared by weather/places/hotels) not catching its own HTTP errors.
  - `_geocode_city` occasionally resolving a city name to an unrelated place (e.g. "Osaka" → "Orsk") due to OpenWeatherMap's free-tier geocoding ranking; now prefers an exact name match among the top 5 candidates.
  - `gemini-2.5-flash` was retired for new users as of mid-2026; updated the default model to `gemini-3.6-flash`.
  - `/lemon/plan` returned a raw 500 traceback on any provider SDK failure (bad key, no credits, retired model, etc.) instead of a clean error; added a catch-all handler that returns a 502 with a readable message and logs the full traceback server-side.
- All three real LLM provider classes instantiate cleanly and raise a clear, catchable error when their API key is missing.
- `gemini` provider confirmed working end-to-end with real output (tested with a 6-traveler, 7-day Osaka itinerary).
- `claude` provider code path confirmed correct — currently blocked only by low Anthropic account credit balance, not a code issue.

### Not yet verified (needs real API keys + network access to test)
- Actual output quality/JSON-validity from real GPT calls (Claude and Gemini are confirmed; GPT still needs a funded key to test).
- The success path (valid data returned) for Duffel (flights) — only weather, places, and hotels have been confirmed returning real data so far.

## Historical next steps

The current proposed backlog is [docs/TASKS.md](../docs/TASKS.md). The older
list below is retained as historical context; its provider list and setup
assumptions do not describe the current working tree.

1. Get the four data-provider keys (see table above) and confirm each endpoint's *success* path, not just its error path.
2. Add your real LLM API keys and manually test `/lemon/plan` with each of `claude`, `gpt`, `gemini` — compare output quality/consistency, since each model may need its own small prompt tweak.
3. Connect the Flutter frontend: a WHAT/WHEN/WHERE/HOW form (no AI tokens spent here) that POSTs straight to `/lemon/plan`, plus a provider picker.
4. Add local persistence (SQLite) so itineraries/preferences survive app restarts.

## Adding or changing providers

The [.env.example](.env.example) template lists every setting currently declared in `config.py`, with blank API keys and matching model/base-URL defaults. It does not verify that your account can access those models. Run the backend from `travel_backend` so it finds `.env`; process environment variables override file values. Restart after changes.

For an existing provider, edit its key/model in your private `.env`. When updating an existing installation, manually add only missing settings from the template; do not replace your `.env`. Choose the LLM through the request `provider` field (`auto`, `groq`, `gemini`, `openrouter`, or `mock`), not an environment variable.

For a new integration:

1. Declare its settings in `config.py` and add matching empty key entries and nonsecret defaults to `.env.example`. Arbitrary undeclared dotenv entries are rejected by the current Settings configuration.
2. For an LLM, implement `LLMProvider.generate_json` in `services/llm_providers/` and register its name in `factory.py`. Add it to `_FALLBACK_ORDER` in `auto_provider.py` only if it should participate in automatic fallback. For a travel data API, wire settings into the relevant service/router instead.
3. Update provider descriptions, any frontend selection UI, and isolated tests. Add a dependency only if the adapter requires it. Never log keys or raw credential-bearing requests.
4. Put the actual key only in your private `.env`, restart, and verify the integration. Keep `.env.example` synchronized whenever settings change.

OpenWeather credentials also power geocoding for hotel and attraction city searches; Geoapify alone is insufficient for those searches. No Amadeus variables are included because the legacy helper is not used by current routes.
