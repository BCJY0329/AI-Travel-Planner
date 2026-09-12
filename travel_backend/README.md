# Travel Planner Backend (v0.3 — data layer + Lemon.ai)

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
cp .env.example .env            # then fill in your real API keys
uvicorn main:app --reload
```

Open http://127.0.0.1:8000/docs to try every endpoint interactively.

## Getting API keys

| Data | Provider | Sign up | Cost |
|---|---|---|---|
| Weather | OpenWeatherMap | https://home.openweathermap.org/users/sign_up | Free, no card |
| Attractions & Hotels | Geoapify Places | https://www.geoapify.com/ | Free tier, no card |
| Flights (sandbox data) | Duffel (test mode) | https://duffel.com/ | Free test key, no card |
| Lemon.ai — Claude | Anthropic Console | https://console.anthropic.com/settings/keys | Pay-as-you-go |
| Lemon.ai — GPT | OpenAI Platform | https://platform.openai.com/api-keys | Pay-as-you-go |
| Lemon.ai — Gemini | Google AI Studio | https://aistudio.google.com/apikey | Free tier available |

## Endpoints

| Endpoint | Purpose |
|---|---|
| `GET /weather/forecast?city=Tokyo` | 5-day forecast for a city |
| `GET /places/attractions?city=Paris` | Points of interest near a city |
| `GET /hotels/search?city=Paris` | Hotel listings near a city (name/location only, no pricing) |
| `GET /flights/search?origin=KUL&destination=NRT&departure_date=2026-12-01` | Flight offers from Duffel sandbox data |
| `POST /lemon/plan` | Single-call AI itinerary generation (see below) |

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

`provider` is one of `"claude"`, `"gpt"`, `"gemini"`, or `"mock"`. Use `"mock"` while
developing the Flutter UI — it returns a valid canned itinerary instantly, with zero
API keys and zero cost, so you can build/test the frontend before wiring up real
billing on any provider. Add `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, and/or
`GEMINI_API_KEY` to `.env` to enable the real ones — only the providers you actually
select need a key configured.

Weather/attraction lookups feed into the prompt as context automatically; if either
fails (bad city name, API down), the itinerary is still generated using general
knowledge instead of crashing the whole request.

### Verified so far
- `/health`, `/weather`, `/places`, `/hotels`, `/flights`, `/lemon/plan` (mock provider) — all run and return either correct data or a clean HTTP error, never a crash.
- Found and fixed two real bugs during this verification pass: Gemini's SDK erroring at construction with an empty key, and `_geocode_city` (shared by weather/places/hotels) not catching its own HTTP errors — both now fail cleanly with a proper status code and message.
- All three real LLM provider classes instantiate cleanly and raise a clear, catchable error when their API key is missing.

### Not yet verified (needs real API keys + network access to test)
- Actual output quality/JSON-validity from real Claude/GPT/Gemini calls.
- The success path (valid data returned) for Geoapify, Duffel, and OpenWeatherMap — only the failure/error paths were exercised here, since this environment has no network access to those domains and no keys.

## Next steps

1. Get the four data-provider keys (see table above) and confirm each endpoint's *success* path, not just its error path.
2. Add your real LLM API keys and manually test `/lemon/plan` with each of `claude`, `gpt`, `gemini` — compare output quality/consistency, since each model may need its own small prompt tweak.
3. Connect the Flutter frontend: a WHAT/WHEN/WHERE/HOW form (no AI tokens spent here) that POSTs straight to `/lemon/plan`, plus a provider picker.
4. Add local persistence (SQLite) so itineraries/preferences survive app restarts.
