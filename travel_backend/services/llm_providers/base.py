"""
Common interface every LLM provider must implement, so the rest of the app
(itinerary_builder, the /lemon/plan endpoint) never needs to know which
provider is actually being called.
"""
from abc import ABC, abstractmethod


class LLMProvider(ABC):
    name: str = "base"

    @abstractmethod
    async def generate_json(self, system_prompt: str, user_prompt: str) -> str:
        """
        Send the prompts to the provider and return the raw text response.
        Callers expect this text to be a JSON string (possibly needing cleanup),
        and are responsible for parsing/validating it.
        """
        raise NotImplementedError
