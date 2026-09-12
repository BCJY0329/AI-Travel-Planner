"""
Returns a canned but valid itinerary JSON, matching the exact schema the real
providers are instructed to produce. Lets us test the whole request/response
pipeline (validation, error handling, endpoint wiring) with zero API keys and
zero network calls — this is what CI or a quick local smoke-test should use.
"""
import json
from .base import LLMProvider


class MockProvider(LLMProvider):
    name = "mock"

    async def generate_json(self, system_prompt: str, user_prompt: str) -> str:
        return json.dumps(
            {
                "summary": "A relaxed mock itinerary generated without calling any real AI provider.",
                "days": [
                    {
                        "day": 1,
                        "date": None,
                        "activities": [
                            {
                                "time": "09:00",
                                "activity": "Explore the city center",
                                "location": "Downtown",
                                "notes": "This is placeholder mock data.",
                            },
                            {
                                "time": "13:00",
                                "activity": "Try local cuisine",
                                "location": "Local restaurant district",
                                "notes": None,
                            },
                        ],
                    }
                ],
            }
        )
