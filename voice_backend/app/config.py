"""Environment configuration shared by the API, the agent and the model servers.

Everything is read once at process start.  No secret is ever written to a log
or returned by an HTTP endpoint.
"""

from __future__ import annotations

import os
from dataclasses import dataclass, field
from pathlib import Path


def _env(name: str, default: str = "") -> str:
    return os.environ.get(name, default).strip()


def _env_int(name: str, default: int) -> int:
    raw = _env(name)
    if not raw:
        return default
    try:
        return int(raw)
    except ValueError:
        return default


def _env_bool(name: str, default: bool) -> bool:
    raw = _env(name).lower()
    if not raw:
        return default
    return raw in {"1", "true", "yes", "on"}


def _env_list(name: str, default: str = "") -> list[str]:
    raw = _env(name, default)
    return [item.strip() for item in raw.split(",") if item.strip()]


@dataclass(frozen=True)
class Settings:
    # --- deployment -----------------------------------------------------
    environment: str = field(default_factory=lambda: _env("SERENE_ENV", "dev"))
    api_host: str = field(default_factory=lambda: _env("SERENE_API_HOST", "0.0.0.0"))
    api_port: int = field(default_factory=lambda: _env_int("SERENE_API_PORT", 8788))
    data_dir: Path = field(
        default_factory=lambda: Path(_env("SERENE_DATA_DIR", "./data")).resolve()
    )
    log_level: str = field(default_factory=lambda: _env("SERENE_LOG_LEVEL", "INFO"))
    allowed_origins: list[str] = field(
        default_factory=lambda: _env_list("SERENE_ALLOWED_ORIGINS", "")
    )

    # --- device enrolment ----------------------------------------------
    enrollment_code: str = field(default_factory=lambda: _env("SERENE_ENROLLMENT_CODE"))
    max_devices: int = field(default_factory=lambda: _env_int("SERENE_MAX_DEVICES", 500))
    enroll_window_seconds: int = field(
        default_factory=lambda: _env_int("SERENE_ENROLL_WINDOW_SECONDS", 600)
    )
    enroll_max_attempts: int = field(
        default_factory=lambda: _env_int("SERENE_ENROLL_MAX_ATTEMPTS", 10)
    )

    # --- LiveKit --------------------------------------------------------
    livekit_url: str = field(
        default_factory=lambda: _env("LIVEKIT_URL", "ws://127.0.0.1:7880")
    )
    livekit_internal_url: str = field(
        default_factory=lambda: _env("LIVEKIT_INTERNAL_URL")
        or _env("LIVEKIT_URL", "ws://127.0.0.1:7880")
    )
    livekit_http_url: str = field(
        default_factory=lambda: _env("LIVEKIT_HTTP_URL", "http://127.0.0.1:7880")
    )
    livekit_api_key: str = field(default_factory=lambda: _env("LIVEKIT_API_KEY", "devkey"))
    livekit_api_secret: str = field(
        default_factory=lambda: _env("LIVEKIT_API_SECRET", "secret")
    )
    agent_name: str = field(
        default_factory=lambda: _env("SERENE_AGENT_NAME", "serene-voice")
    )
    token_ttl_seconds: int = field(
        default_factory=lambda: _env_int("SERENE_TOKEN_TTL_SECONDS", 600)
    )
    room_empty_timeout_seconds: int = field(
        default_factory=lambda: _env_int("SERENE_ROOM_EMPTY_TIMEOUT_SECONDS", 60)
    )

    # --- local model services ------------------------------------------
    ollama_base_url: str = field(
        default_factory=lambda: _env("OLLAMA_BASE_URL", "http://127.0.0.1:11434/v1")
    )
    ollama_model: str = field(default_factory=lambda: _env("OLLAMA_MODEL", "qwen3:4b"))
    ollama_api_key: str = field(default_factory=lambda: _env("OLLAMA_API_KEY", "ollama"))

    stt_base_url: str = field(
        default_factory=lambda: _env("STT_BASE_URL", "http://127.0.0.1:8001/v1")
    )
    stt_model: str = field(default_factory=lambda: _env("STT_MODEL", "whisper-1"))

    tts_base_url: str = field(
        default_factory=lambda: _env("TTS_BASE_URL", "http://127.0.0.1:8002/v1")
    )
    tts_model: str = field(default_factory=lambda: _env("TTS_MODEL", "serene-tts"))

    # --- behaviour ------------------------------------------------------
    prompt_file: Path = field(
        default_factory=lambda: Path(
            _env("SERENE_PROMPT_FILE", "./prompts/serene_friend.yaml")
        ).resolve()
    )
    low_vram: bool = field(default_factory=lambda: _env_bool("SERENE_LOW_VRAM", True))
    max_memories: int = field(default_factory=lambda: _env_int("SERENE_MAX_MEMORIES", 20))
    max_memory_chars: int = field(
        default_factory=lambda: _env_int("SERENE_MAX_MEMORY_CHARS", 280)
    )
    max_notes_chars: int = field(
        default_factory=lambda: _env_int("SERENE_MAX_NOTES_CHARS", 500)
    )

    def ensure_data_dir(self) -> Path:
        self.data_dir.mkdir(parents=True, exist_ok=True)
        return self.data_dir

    def insecure_secret_reason(self) -> str | None:
        """Why ``LIVEKIT_API_SECRET`` must not be used, or ``None`` if it is fine.

        Every value in this list is published in the documentation, so anyone
        who reads the repository could mint a token that LiveKit would accept.
        Refusing to start is the only honest response.
        """
        secret = self.livekit_api_secret.strip()
        if secret.lower() in _PLACEHOLDER_SECRETS:
            return "LIVEKIT_API_SECRET is a placeholder value from the documentation"
        if len(secret) < 32:
            return (
                "LIVEKIT_API_SECRET is shorter than 32 characters, so it is "
                "guessable"
            )
        return None


_PLACEHOLDER_SECRETS = {
    "",
    "secret",
    "devkey",
    "changeme",
    "change-me",
    "change-me-please-use-a-long-random-string",
}


settings = Settings()
