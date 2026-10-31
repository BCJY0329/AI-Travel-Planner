from typing import List, Literal, Optional
from pydantic import BaseModel, Field


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
            "Which field Lemon is currently asking for: 'destination', 'start_date', "
            "'end_date', 'travelers', 'budget_level', 'interests', 'confirm', or null once "
            "ready/complete. Frontend should key UI (e.g. showing the date picker) off this "
            "instead of sniffing the reply text for keywords."
        ),
    )