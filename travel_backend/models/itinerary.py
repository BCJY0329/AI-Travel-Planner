from typing import List, Optional
from pydantic import BaseModel, Field


class TripRequest(BaseModel):
    """The structured WHAT/WHEN/WHERE/HOW form data — no free chat needed for this step."""
    destination: str = Field(..., description="City name, e.g. 'Kyoto'")
    start_date: str = Field(..., description="YYYY-MM-DD")
    end_date: str = Field(..., description="YYYY-MM-DD")
    travelers: int = Field(1, ge=1, le=20)
    budget_level: str = Field("medium", description="'low', 'medium', or 'high'")
    interests: List[str] = Field(default_factory=list, description="e.g. ['food', 'museums', 'nature']")
    provider: str = Field("mock", description="'claude', 'gpt', 'gemini', or 'mock' for testing")


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
