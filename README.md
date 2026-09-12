# AI Travel Planner

An AI-assisted travel planning app — FastAPI backend with live weather, attractions, flights, and hotel data, plus an AI itinerary generator powered by Claude, GPT, or Gemini.

> **Status:** Backend complete (v0.2). Flutter frontend in progress.

---

## Project Structure

```
Work3 - AI Travel Planner/
├── travel_backend/        # FastAPI backend (Python)
│   ├── main.py            # App entry point
│   ├── config.py          # Settings loaded from .env
│   ├── requirements.txt   # Python dependencies
│   ├── .env               # ⚠️ Your real API keys — never committed
│   ├── routers/           # Route handlers (weather, places, flights, hotels, lemon)
│   ├── services/          # Business logic & external API clients
│   └── models/            # Pydantic request/response models
└── README.md              # This file
```

---

## Backend Setup

```bash
cd travel_backend
python -m venv venv

# Activate venv:
# Windows:
venv\Scripts\activate
# macOS/Linux:
source venv/bin/activate

pip install -r requirements.txt

# Copy the example env file and fill in your keys:
cp .env.example .env

uvicorn main:app --reload
```

Open **http://127.0.0.1:8000/docs** for interactive API docs.

---

## API Keys Required

| Service | Provider | Sign Up | Cost |
|---|---|---|---|
| Weather | OpenWeatherMap | https://home.openweathermap.org/users/sign_up | Free, no card |
| Attractions & Hotels | Geoapify | https://www.geoapify.com/ | Free tier, no card |
| Flights (sandbox) | Duffel | https://duffel.com/ | Free test key, no card |
| AI — Claude | Anthropic Console | https://console.anthropic.com/settings/keys | Pay-as-you-go |
| AI — GPT | OpenAI Platform | https://platform.openai.com/api-keys | Pay-as-you-go |
| AI — Gemini | Google AI Studio | https://aistudio.google.com/apikey | Free tier available |

Add your keys to `travel_backend/.env` — you only need the LLM providers you plan to use. The `"mock"` provider works with no key at all.

---

## Endpoints

| Endpoint | Description |
|---|---|
| `GET /health` | Health check |
| `GET /weather/forecast?city=Tokyo` | 5-day weather forecast |
| `GET /places/attractions?city=Paris` | Points of interest |
| `GET /hotels/search?city=Paris` | Hotel listings (no live pricing) |
| `GET /flights/search?origin=KUL&destination=NRT&departure_date=2026-12-01` | Flight offers (Duffel sandbox) |
| `POST /lemon/plan` | AI itinerary generation |

### Example: AI Itinerary (`POST /lemon/plan`)

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

`provider` can be `"mock"` (no key needed), `"claude"`, `"gpt"`, or `"gemini"`.

---

## Roadmap

- [x] Weather, places, flights, hotels endpoints
- [x] AI itinerary planner (Lemon.ai) with Claude / GPT / Gemini / mock
- [ ] Flutter frontend — trip planning form + itinerary display
- [ ] Local persistence (SQLite) for saved itineraries
- [ ] Auth / user accounts
- [ ] Live hotel pricing integration
- [ ] Caching layer for external API calls

---

## Notes

- Amadeus for Developers was decommissioned July 17, 2026 — this project uses Duffel for flights instead.
- Duffel test mode returns realistic but simulated (not live) flight data.
- No booking or payment logic — view-only data at this stage.
