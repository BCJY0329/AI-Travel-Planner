from datetime import date
from typing import Annotated, List, Literal, Optional
from pydantic import BaseModel, Field, StringConstraints, field_validator, model_validator

PlaceName = Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=120)]
# How full each day is (DECISIONS 069). Changes the number of activities,
# never how detailed each one is (DECISIONS 042).
Pace = Literal['relaxed', 'balanced', 'packed']
MAX_MUST_VISIT = 10


class MustVisit(BaseModel):
    """A place the traveller wants in the plan: tapped from Lemon's popular
    spots, typed in chat, or picked by Lemon on "surprise me" (DECISIONS 069).
    Coordinates and place_id come from Geoapify when the place was checked."""
    name: PlaceName
    place_id: Optional[str] = Field(None, max_length=300)
    lat: Optional[float] = Field(None, ge=-90, le=90)
    lon: Optional[float] = Field(None, ge=-180, le=180)
    # The map's own name for the place, when it differs (DECISIONS 071).
    matched_name: Optional[str] = Field(None, max_length=200)


class TripRequest(BaseModel):
    """The structured WHAT/WHEN/WHERE/HOW form data — no free chat needed for this step."""
    destination: Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=120)] = Field(..., description="City name, e.g. 'Kyoto'")
    start_date: str = Field(..., description="YYYY-MM-DD")
    end_date: str = Field(..., description="YYYY-MM-DD")
    travelers: int = Field(1, ge=1, le=20)
    budget_level: Literal['low', 'medium', 'high'] = 'medium'
    interests: List[Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=120)]] = Field(default_factory=list, max_length=12, description="Selected interests and optional personal preferences")
    pace: Pace = Field('balanced', description="'relaxed' (2-3 activities a day), 'balanced' (3-5) or 'packed' (5-7)")
    must_visit: List[MustVisit] = Field(default_factory=list, max_length=MAX_MUST_VISIT,
                                        description="Places the plan must include; the validator checks each one is in it")
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
    # Grounding (DECISIONS 069): set by the server, never trusted from a model.
    # 'verified': matched to a real place (place_id and coordinates set).
    # 'unverified': names a place that could not be matched. None: no specific
    # place (a meal, free time), or the check did not run.
    place_id: Optional[str] = None
    lat: Optional[float] = None
    lon: Optional[float] = None
    place_status: Optional[Literal['verified', 'unverified']] = None
    # The map's name for the place a verified stop was matched to, so the app
    # can show it when it differs from `location` (DECISIONS 071).
    place_name: Optional[str] = None
    # The model's pointer into the prompt's "Known places"; internal only.
    place_ref: Optional[str] = Field(None, exclude=True)

    @field_validator('place_status', mode='before')
    @classmethod
    def known_status(cls, value):
        return value if value in ('verified', 'unverified') else None


class ItineraryDay(BaseModel):
    day: int
    date: Optional[str] = None
    activities: List[ItineraryActivity]


class ItineraryResponse(BaseModel):
    destination: str
    provider_used: str
    summary: Optional[str] = None
    days: List[ItineraryDay]
    # Must-visits no provider fitted into the plan (DECISIONS 070). The app asks
    # before showing a plan that has none of them.
    missing_must_visits: List[str] = Field(default_factory=list)


EditAction = Literal['regenerate_day', 'swap_activity', 'adjust_day']


class PlanEditRequest(BaseModel):
    """Change one day of an existing plan (DECISIONS 069). The client sends the
    trip and the whole current plan (the backend is stateless) and gets back
    only the new day, which it previews before replacing the old one."""
    trip: TripRequest
    days: List[ItineraryDay] = Field(..., min_length=1, max_length=30)
    action: EditAction
    day: int = Field(..., ge=1, le=30, description="Absolute day number to change")
    stop: Optional[int] = Field(None, ge=1, le=20, description="swap_activity: 1-based stop on that day")
    instruction: Optional[str] = Field(None, max_length=300, description="adjust_day: what to change, in the traveller's words")

    @model_validator(mode='after')
    def consistent(self):
        target = next((d for d in self.days if d.day == self.day), None)
        if target is None:
            raise ValueError('That day is not in the plan')
        if self.action == 'swap_activity' and (self.stop is None or self.stop > len(target.activities)):
            raise ValueError('Choose a stop on that day to swap')
        if self.action == 'adjust_day' and not (self.instruction or '').strip():
            raise ValueError('Say what to change on that day')
        return self


class PlanEditResponse(BaseModel):
    day: ItineraryDay
    provider_used: str
    # Must-visits the new day no longer has (DECISIONS 070); the preview says so.
    missing_must_visits: List[str] = Field(default_factory=list)
