"""
Central configuration. Loads settings from a .env file (see .env.example).
Never commit your real .env file — only .env.example should be in version control.
"""
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    # Geoapify Places — free tier (3,000 req/day), no billing account required
    # Covers both attractions and hotel listings under one account/key.
    # Sign up: https://www.geoapify.com/
    GEOAPIFY_API_KEY: str = ""
    GEOAPIFY_BASE_URL: str = "https://api.geoapify.com"

    # Duffel — flight search, free test mode with sandbox data, no billing account required
    # Sign up: https://duffel.com/
    DUFFEL_API_KEY: str = ""  # test key starts with 'duffel_test_'
    DUFFEL_BASE_URL: str = "https://api.duffel.com"

    # OpenWeatherMap (free tier) — unaffected by the Amadeus shutdown
    # Sign up: https://openweathermap.org/api
    OPENWEATHER_API_KEY: str = ""
    OPENWEATHER_BASE_URL: str = "https://api.openweathermap.org"

    # --- Lemon.ai: three interchangeable, free-tier-friendly LLM providers ---
    # Fill in whichever ones you have keys for. Providers you don't configure will
    # simply fail with a clear error if selected — the "mock" provider always works
    # with no key, for local testing.

    # Groq — free tier, no credit card. OpenAI-compatible endpoint.
    # Sign up: https://console.groq.com/
    GROQ_API_KEY: str = ""
    GROQ_BASE_URL: str = "https://api.groq.com/openai/v1"
    GROQ_MODEL: str = "openai/gpt-oss-120b"  # check console.groq.com for current free-tier models

    # Google Gemini — free tier via AI Studio.
    # Sign up: https://aistudio.google.com/apikey
    GEMINI_API_KEY: str = ""
    GEMINI_MODEL: str = "gemini-3.6-flash"  # adjust to whatever model your account has access to

    # OpenRouter — free model catalog via an OpenAI-compatible gateway, no card.
    # Capped around 50 requests/day on ':free' models — fine here since
    # itinerary generation is already cached (see services/cache.py).
    # Sign up: https://openrouter.ai/settings/keys
    OPENROUTER_API_KEY: str = ""
    OPENROUTER_BASE_URL: str = "https://openrouter.ai/api/v1"
    OPENROUTER_MODEL: str = "openrouter/free"  # auto-routes to a currently-free model; avoids hardcoding an ID that can get retired (like deepseek's just did)

    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8")


settings = Settings()