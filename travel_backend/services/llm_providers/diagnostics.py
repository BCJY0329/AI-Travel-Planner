"""Allowlisted diagnostics: never emit exception messages or response inputs."""
import json
import re
from pydantic import ValidationError

_LABEL_RE = re.compile(r"[a-z][a-z0-9_.\-]{0,63}")

_FIELDS = set("reply destination start_date end_date travelers budget_level interests ready next_field summary days day date activities time activity location notes".split())
_REASONS = {400: "invalid_request", 401: "authentication", 403: "permission", 404: "not_found", 429: "rate_limit", 500: "server_error", 503: "unavailable"}


def http_status(exc):
    """HTTP status from OpenAI-style (status_code) or google-genai-style (code) errors."""
    status = getattr(exc, "status_code", None)
    if not isinstance(status, int):
        status = getattr(exc, "code", None)
    return status if isinstance(status, int) and 100 <= status <= 599 else None


def _label(value):
    """A provider's machine error label (e.g. 'rate_limit_exceeded'), or None.

    Only short identifier-like strings pass, so a free-text message can never
    reach the log through these fields.
    """
    return value if isinstance(value, str) and _LABEL_RE.fullmatch(value) else None


def error_details(exc):
    details = {"error_type": type(exc).__name__}
    status = http_status(exc)
    if status is not None:
        details.update(status=status, reason=_REASONS.get(status, "http_error"))
    # OpenAI-compatible errors sent inside a stream carry no HTTP status, only
    # these labels (openai SDK APIError.code / .type); they name the cause.
    for field in ("code", "type"):
        label = _label(getattr(exc, field, None))
        if label is not None:
            details[f"provider_{field}"] = label
    if isinstance(exc, ValidationError):
        details["validation"] = [
            {"field": ".".join(str(part) if isinstance(part, int) or part in _FIELDS else "<field>"
                               for part in error["loc"]), "type": error["type"]}
            for error in exc.errors(include_url=False, include_context=False, include_input=False)
        ]
    elif isinstance(exc, json.JSONDecodeError):
        details["reason"] = "invalid_json"
    return details
