from .base import LLMProvider
from .groq_provider import GroqProvider
from .gemini_provider import GeminiProvider
from .openrouter_provider import OpenRouterProvider
from .mock_provider import MockProvider
from .auto_provider import AutoProvider

_PROVIDERS = {
    "auto": AutoProvider,
    "groq": GroqProvider,
    "gemini": GeminiProvider,
    "openrouter": OpenRouterProvider,
    "mock": MockProvider,
}


def get_provider(name: str) -> LLMProvider:
    """
    Look up a provider by short name. Raises ValueError (caught by the router
    and turned into a 502) if the name isn't recognized — never fails silently.
    """
    provider_cls = _PROVIDERS.get(name.lower())
    if provider_cls is None:
        valid = ", ".join(_PROVIDERS.keys())
        raise ValueError(f"Unknown provider '{name}'. Valid options: {valid}")
    return provider_cls()
