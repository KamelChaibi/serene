"""Logging helpers shared by every Serene voice process.

Privacy rule: conversation content (audio, transcripts, prompts) must never
reach a log file.  The helpers here make that rule the default instead of
something each module has to remember.
"""

from __future__ import annotations

import logging
import os
import sys
from typing import Any, Iterable

# Keys that may carry conversation content.  Anything added under one of these
# names is replaced before formatting.
_SENSITIVE_KEYS = frozenset(
    {
        "text",
        "transcript",
        "transcription",
        "prompt",
        "instructions",
        "input",
        "output",
        "message",
        "messages",
        "content",
        "audio",
        "memory",
        "memories",
        "notes",
        "secret",
        "token",
        "api_key",
        "authorization",
    }
)

_REDACTED = "[redacted]"


class RedactionFilter(logging.Filter):
    """Strip known-sensitive values from ``LogRecord`` attributes."""

    def filter(self, record: logging.LogRecord) -> bool:
        for key in list(record.__dict__):
            if key in _SENSITIVE_KEYS and key not in {
                "message",
                "content",
                "input",
                "output",
            }:
                record.__dict__[key] = _REDACTED
        return True


def configure_logging(level: str = "INFO", *, quiet_livekit: bool = True) -> None:
    handler = logging.StreamHandler(sys.stdout)
    handler.setFormatter(
        logging.Formatter("%(asctime)s %(levelname)s %(name)s %(message)s")
    )
    handler.addFilter(RedactionFilter())

    root = logging.getLogger()
    root.handlers.clear()
    root.addHandler(handler)
    root.setLevel(getattr(logging, level.upper(), logging.INFO))

    if quiet_livekit:
        # The Agents SDK logs full transcripts at DEBUG.  Even at INFO it is
        # chatty, so keep it at WARNING unless explicitly raised.
        logging.getLogger("livekit").setLevel(logging.WARNING)
        logging.getLogger("livekit.agents").setLevel(logging.WARNING)
        logging.getLogger("httpx").setLevel(logging.WARNING)
        logging.getLogger("httpcore").setLevel(logging.WARNING)
        logging.getLogger("openai").setLevel(logging.WARNING)
        logging.getLogger("faster_whisper").setLevel(logging.INFO)


def redact(value: Any) -> str:
    """Safe representation for a value that might be sensitive."""
    if value is None:
        return ""
    return _REDACTED


def scrub(mapping: Iterable[tuple[str, Any]]) -> dict[str, Any]:
    """Copy a mapping, replacing sensitive keys."""
    return {
        key: (_REDACTED if key in _SENSITIVE_KEYS else value)
        for key, value in mapping
    }


def env_flag(name: str, default: bool = False) -> bool:
    raw = os.environ.get(name, "").strip().lower()
    if not raw:
        return default
    return raw in {"1", "true", "yes", "on"}
