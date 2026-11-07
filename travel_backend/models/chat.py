from typing import List, Literal, Optional
from pydantic import BaseModel, Field, field_validator


class ChatTurn(BaseModel):
    role: Literal['user', 'assistant'] = Field(..., description="'user' or 'assistant'")
    # The app's composer allows 600 characters; assistant turns are Lemon's own replies.
    content: str = Field(..., max_length=2000)


class LemonChatRequest(BaseModel):
    """Full conversation so far (oldest first) — the backend is stateless,
    so the whole history is sent on every turn. Bounded so one request cannot
    push an oversized prompt to the providers."""
    messages: List[ChatTurn] = Field(..., max_length=100)
    provider: str = Field("mock", max_length=20, description="'auto', 'groq', 'gemini', 'openrouter', or 'mock'")
    # Once a plan exists (DECISIONS 069): a short text summary of it, so Lemon
    # can tell an edit request ("swap the museum on day 3") from trip details.
    plan_summary: Optional[str] = Field(None, max_length=8000)
    plan_days: Optional[int] = Field(None, ge=1, le=30, description="Number of days in the current plan")


# What kind of message the traveller's latest turn was (DECISIONS 059).
INTENTS = ('trip', 'small_talk', 'off_topic', 'gibberish', 'unsafe',
           'unhappy', 'switch_to_guided', 'switch_to_free',
           # DECISIONS 069: a change to the existing plan, or a question about
           # the trip (answered with "coming soon" for now).
           'edit_plan', 'plan_question')
PACES = ('relaxed', 'balanced', 'packed')
EDIT_ACTIONS = ('regenerate_day', 'swap_activity', 'adjust_day')
# Fields the reader can fill in by inference rather than plain statement.
INFERABLE_FIELDS = ('travelers', 'budget_level', 'interests', 'end_date', 'pace')


class MustVisitPlace(BaseModel):
    """A place the traveller named in chat, checked against Geoapify near the
    destination (DECISIONS 069)."""
    name: str
    status: Literal['verified', 'unverified', 'not_found'] = 'unverified'
    place_id: Optional[str] = None
    lat: Optional[float] = None
    lon: Optional[float] = None
    # The map's own name for the place found (DECISIONS 071).
    matched_name: Optional[str] = None


class PlanEdit(BaseModel):
    """What the traveller asked to change in the existing plan."""
    action: Literal['regenerate_day', 'swap_activity', 'adjust_day']
    day: int = Field(..., ge=1, le=30)
    stop: Optional[int] = Field(None, ge=1, le=20)
    instruction: Optional[str] = Field(None, max_length=300)


class LemonChatResponse(BaseModel):
    reply: str
    destination: Optional[str] = None
    start_date: Optional[str] = None
    end_date: Optional[str] = None
    travelers: Optional[int] = None
    budget_level: Optional[str] = None
    interests: List[str] = Field(default_factory=list)
    ready: bool = False
    next_field: Optional[str] = Field(
        None,
        description=(
            "Which required detail Lemon still needs: 'destination', 'start_date', "
            "'end_date', or 'confirm' once those are known (travelers, budget and "
            "interests are optional; the app shows defaults for them). Null when ready."
        ),
    )
    intent: str = Field('trip', description="One of: " + ", ".join(INTENTS))
    inferred: List[str] = Field(
        default_factory=list,
        description="Fields guessed from indirect wording ('me and my wife' -> travelers), "
                    "so the app can show them as editable assumptions.")
    destination_status: Optional[Literal['verified', 'unverified', 'not_found', 'ambiguous']] = Field(
        None,
        description="Result of checking the destination with the geocoder. 'unverified' means "
                    "the check was skipped (mock) or unavailable; the plan step geocodes again.")
    destination_options: List[str] = Field(
        default_factory=list,
        description="When destination_status is 'ambiguous': labels such as 'Paris, France' to choose from.")
    destination_label: Optional[str] = Field(
        None,
        description="When destination_status is 'verified': the exact place, e.g. 'Paris, France', "
                    "for the brief and the plan request (DECISIONS 068).")
    destination_alternatives: List[str] = Field(
        default_factory=list,
        description="When Lemon picked the famous one of several same-name places: the others, "
                    "for the app's 'Not this one?' choice. Empty otherwise.")
    fallback_used: bool = Field(
        False, description="True when the local parser answered instead of an AI provider.")
    pace: Optional[str] = Field(None, description="'relaxed', 'balanced' or 'packed' when the traveller said so")
    must_visit: List[MustVisitPlace] = Field(
        default_factory=list,
        description="Places the traveller named as must-visits, each checked near the destination.")
    spots_to_lemon: bool = Field(
        False, description="True when the latest message leaves the choice of spots to Lemon ('surprise me').")
    edit: Optional[PlanEdit] = Field(None, description="When intent is 'edit_plan': the change to make.")

    @field_validator('intent', mode='before')
    @classmethod
    def known_intent(cls, value):
        # A model inventing a new label must not fail the whole turn.
        value = str(value or 'trip').strip().lower()
        return value if value in INTENTS else 'trip'

    @field_validator('pace', mode='before')
    @classmethod
    def known_pace(cls, value):
        value = str(value or '').strip().lower()
        return value if value in PACES else None

    @field_validator('must_visit', mode='before')
    @classmethod
    def place_names(cls, value):
        # Models return plain names; the server checks them and fills the rest.
        if not isinstance(value, list):
            return []
        items = []
        for item in value[:10]:
            if isinstance(item, str):
                item = {'name': item}
            if isinstance(item, dict) and str(item.get('name') or '').strip():
                items.append(item)
        return items

    @field_validator('edit', mode='before')
    @classmethod
    def usable_edit(cls, value):
        # A half-filled edit (no day, unknown action) is dropped; the server
        # then asks which day instead of failing the turn.
        if not isinstance(value, dict):
            return None
        try:
            return PlanEdit.model_validate(value)
        except Exception:
            return None

    @field_validator('inferred', mode='before')
    @classmethod
    def known_inferred(cls, value):
        if not isinstance(value, list):
            return []
        return [v for v in dict.fromkeys(str(x) for x in value) if v in INFERABLE_FIELDS]
