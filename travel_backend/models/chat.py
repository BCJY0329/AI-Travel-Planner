from typing import List, Optional
from pydantic import BaseModel, Field


class ChatTurn(BaseModel):
    role: str = Field(..., description="'user' or 'assistant'")
    content: str


class LemonChatRequest(BaseModel):
    """Full conversation so far (oldest first) — the backend is stateless,
    so the whole history is sent on every turn."""
    messages: List[ChatTurn]
    provider: str = Field("mock", description="'claude', 'gpt', 'gemini', or 'mock'")


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
            "'end_date', 'travelers', 'budget_level', 'confirm', or null once ready/complete. "
            "Frontend should key UI (e.g. showing the date picker) off this instead of "
            "sniffing the reply text for keywords."
        ),
    )