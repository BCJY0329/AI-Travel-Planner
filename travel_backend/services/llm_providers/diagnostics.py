"""Allowlisted diagnostics: never emit exception messages or response inputs."""
import json
from pydantic import ValidationError

_FIELDS = set("reply destination start_date end_date travelers budget_level interests ready next_field summary days day date activities time activity location notes".split())
_REASONS = {400: "invalid_request", 401: "authentication", 403: "permission", 404: "not_found", 429: "rate_limit", 500: "server_error", 503: "unavailable"}


def error_details(exc):
    details = {"error_type": type(exc).__name__}
    status = getattr(exc, "status_code", None)
    if not isinstance(status, int):
        status = getattr(exc, "code", None)
    if isinstance(status, int) and 100 <= status <= 599:
        details.update(status=status, reason=_REASONS.get(status, "http_error"))
    if isinstance(exc, ValidationError):
        details["validation"] = [
            {"field": ".".join(str(part) if isinstance(part, int) or part in _FIELDS else "<field>"
                               for part in error["loc"]), "type": error["type"]}
            for error in exc.errors(include_url=False, include_context=False, include_input=False)
        ]
    elif isinstance(exc, json.JSONDecodeError):
        details["reason"] = "invalid_json"
    return details
