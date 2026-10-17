from datetime import date
from typing import Annotated, List, Literal, Optional
from pydantic import BaseModel, Field, StringConstraints, field_validator, model_validator


class TripRequest(BaseModel):
    """The structured WHAT/WHEN/WHERE/HOW form data — no free chat needed for this step."""
    destination: Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=120)] = Field(..., description="City name, e.g. 'Kyoto'")
    start_date: str = Field(..., description="YYYY-MM-DD")
    end_date: str = Field(..., description="YYYY-MM-DD")
    travelers: int = Field(1, ge=1, le=20)
    budget_level: Literal['low', 'medium', 'high'] = 'medium'
    interests: List[Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=120)]] = Field(default_factory=list, max_length=12, description="Selected interests and optional personal preferences")
    provider: str = Field("mock", description="'auto', 'groq', 'gemini', 'openrouter', or 'mock' for testing")

    @field_validator('start_date', 'end_date')
    @classmethod
    def valid_date(cls, value: str) -> str:
        parsed = date.fromisoformat(value)
        if parsed.isoformat() != value:
            raise ValueError('Use YYYY-MM-DD dates')
        return value

    @model_validator(mode='after')
    def valid_range(self):
        days = (date.fromisoformat(self.end_date) - date.fromisoformat(self.start_date)).days
        if not 0 <= days < 30:
            raise ValueError('Choose an ordered date range of 1 to 30 days')
        return self


class ItineraryActivity(BaseModel):
    time: str
    activity: str
    location: Optional[str] = None
    notes: Optional[str] = None


class ItineraryDay(BaseModel):
    day: int
    date: Optional[str] = None
    activities: List[ItineraryActivity]


class ItineraryResponse(BaseModel):
    destination: str
    provider_used: str
    summary: Optional[str] = None
    days: List[ItineraryDay]
