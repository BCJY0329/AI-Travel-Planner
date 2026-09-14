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

    # --- Lemon.ai: interchangeable LLM providers ---
    # Fill in whichever ones you have keys for. Providers you don't configure will
    # simply fail with a clear error if selected directly — but if `provider="auto"`
    # is used, an unconfigured/failing provider is silently skipped in favor of the
    # next one in the fallback chain (see services/llm_providers/auto_provider.py).
    # The "mock" provider always works with no key, for local testing.
    ANTHROPIC_API_KEY: str = ""
    ANTHROPIC_MODEL: str = "claude-sonnet-4-6"

    OPENAI_API_KEY: str = ""
    OPENAI_MODEL: str = "gpt-4.1-mini"  # adjust to whatever model your account has access to

    GEMINI_API_KEY: str = ""
    # gemini-2.5-flash is retired for new accounts — gemini-3.6-flash (GA as of the
    # Gemini 3 family) is the current flash-tier model. Note the Gemini 3 family also
    # dropped temperature/top-p/top-k params in favor of `thinking_level` — irrelevant
    # here since gemini_provider.py doesn't set those, but worth knowing if you tune
    # generation params later.
    GEMINI_MODEL: str = "gemini-3.6-flash"

    # Groq — free tier, no credit card required. OpenAI-compatible API.
    # Sign up: https://console.groq.com/keys
    # Model names churn faster here than other providers (open-source models get
    # deprecated on short notice) — check https://console.groq.com/docs/models if
    # requests start failing with a "model decommissioned" error.
    GROQ_API_KEY: str = ""
    GROQ_BASE_URL: str = "https://api.groq.com/openai/v1"
    GROQ_MODEL: str = "openai/gpt-oss-20b"

    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8")


settings = Settings()