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

    # --- Lemon.ai: three interchangeable LLM providers ---
    # Fill in whichever ones you have keys for. Providers you don't configure will
    # simply fail with a clear error if selected — the "mock" provider always works
    # with no key, for local testing.
    ANTHROPIC_API_KEY: str = ""
    ANTHROPIC_MODEL: str = "claude-sonnet-4-6"

    OPENAI_API_KEY: str = ""
    OPENAI_MODEL: str = "gpt-4.1-mini"  # adjust to whatever model your account has access to

    GEMINI_API_KEY: str = ""
    GEMINI_MODEL: str = "gemini-3.6-flash"  # adjust to whatever model your account has access to

    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8")


settings = Settings()
