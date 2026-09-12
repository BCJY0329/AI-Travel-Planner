from .base import LLMProvider
from .anthropic_provider import AnthropicProvider
from .openai_provider import OpenAIProvider
from .gemini_provider import GeminiProvider
from .mock_provider import MockProvider

_PROVIDERS = {
    "claude": AnthropicProvider,
    "gpt": OpenAIProvider,
    "gemini": GeminiProvider,
    "mock": MockProvider,
}


def get_provider(name: str) -> LLMProvider:
    """
    Look up a provider by short name. Raises ValueError (caught by the router
    and turned into a clean 400) if the name isn't recognized — never fails silently.
    """
    provider_cls = _PROVIDERS.get(name.lower())
    if provider_cls is None:
        valid = ", ".join(_PROVIDERS.keys())
        raise ValueError(f"Unknown provider '{name}'. Valid options: {valid}")
    return provider_cls()
