"""Public Serene voice API: device enrolment, short-lived tokens, health.

This is the only voice service exposed to the internet.  It never imports
torch, never sees audio, and never stores transcripts.  The Flutter app calls:

    POST /v1/device/enroll   once per install
    POST /v1/voice/token     at the start of every call

Run::

    uvicorn app.api:app --host 0.0.0.0 --port 8788
"""

from __future__ import annotations

import asyncio
import hmac
import json
import logging
import os
from contextlib import asynccontextmanager
from dataclasses import dataclass
from typing import Any, AsyncIterator

import httpx
from fastapi import FastAPI, Header, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, ConfigDict, Field

from . import __version__
from .auth import (
    AttemptLimiter,
    AuthError,
    DeviceStore,
    new_room_name,
    public_identity,
)
from .config import settings
from .logging_utils import configure_logging
from .prompts import SUPPORTED_LANGUAGES, normalize_language
from .tokens import mint_participant_token

logger = logging.getLogger("serene.api")

# LiveKit embeds room metadata in the participant JWT.  Browsers and the
# Flutter SDK handle a few KB comfortably; keep a hard ceiling so a malicious
# client cannot mint an oversized token.
MAX_METADATA_BYTES = 3000


@dataclass
class ApiState:
    store: DeviceStore
    enroll_limiter: AttemptLimiter
    token_limiter: AttemptLimiter


state: ApiState | None = None


class EnrollRequest(BaseModel):
    model_config = ConfigDict(extra="ignore")

    device_id: str = Field(min_length=16, max_length=64)
    secret: str = Field(min_length=32, max_length=128)
    enrollment_code: str = ""


class ProfilePayload(BaseModel):
    model_config = ConfigDict(extra="ignore")

    name: str = ""
    age: int | None = None
    style: str = ""
    length: str = ""
    focuses: list[str] = Field(default_factory=list)
    in_therapy: bool = False
    notes: str = ""


class TokenRequest(BaseModel):
    model_config = ConfigDict(extra="ignore")

    language: str = "en"
    profile: ProfilePayload | None = None
    memories: list[str] = Field(default_factory=list)
    session: str = ""


def _client_ip(request: Request) -> str:
    if os.environ.get("SERENE_TRUST_PROXY", "").strip().lower() in {
        "1",
        "true",
        "yes",
    }:
        forwarded = request.headers.get("x-forwarded-for", "")
        if forwarded:
            return forwarded.split(",", 1)[0].strip()
    return request.client.host if request.client else "unknown"


def _require_state() -> ApiState:
    if state is None:  # pragma: no cover - lifespan always runs in production
        raise HTTPException(status_code=503, detail="service is starting")
    return state


def _credentials(
    x_device_id: str | None, x_device_secret: str | None
) -> tuple[str, str]:
    if not x_device_id or not x_device_secret:
        raise HTTPException(status_code=401, detail="missing device credentials")
    return x_device_id.strip(), x_device_secret.strip()


def _bounded_profile(profile: ProfilePayload | None) -> dict[str, Any]:
    if profile is None:
        return {}

    age = profile.age if isinstance(profile.age, int) and 13 <= profile.age <= 120 else None
    return {
        "name": profile.name.strip()[:60],
        "age": age,
        "style": profile.style.strip()[:20],
        "length": profile.length.strip()[:20],
        "focuses": [
            item.strip()[:40]
            for item in profile.focuses[:8]
            if isinstance(item, str) and item.strip()
        ],
        "in_therapy": bool(profile.in_therapy),
        "notes": profile.notes.strip()[: settings.max_notes_chars],
    }


def _bounded_memories(memories: list[str]) -> list[str]:
    cleaned = [
        item.strip()[: settings.max_memory_chars]
        for item in memories[: settings.max_memories]
        if isinstance(item, str) and item.strip()
    ]
    return [item for item in cleaned if item]


def _shrink(metadata: dict[str, Any]) -> dict[str, Any]:
    """Drop the least important fields until the metadata fits the ceiling."""
    encoded = json.dumps(metadata, ensure_ascii=False, separators=(",", ":"))
    if len(encoded.encode("utf-8")) <= MAX_METADATA_BYTES:
        return metadata

    metadata = dict(metadata)
    memories = list(metadata.get("memories") or [])
    while memories:
        memories.pop()
        metadata["memories"] = memories
        encoded = json.dumps(metadata, ensure_ascii=False, separators=(",", ":"))
        if len(encoded.encode("utf-8")) <= MAX_METADATA_BYTES:
            return metadata

    profile = dict(metadata.get("profile") or {})
    if profile.get("notes"):
        profile["notes"] = ""
        metadata["profile"] = profile
        encoded = json.dumps(metadata, ensure_ascii=False, separators=(",", ":"))
        if len(encoded.encode("utf-8")) <= MAX_METADATA_BYTES:
            return metadata

    # Last resort: keep only the language.  The call still works.
    return {"language": metadata.get("language", "en"), "session": metadata.get("session", "")}


@asynccontextmanager
async def lifespan(_: FastAPI) -> AsyncIterator[None]:
    global state

    configure_logging(settings.log_level)
    problem = settings.insecure_secret_reason()
    if problem:
        raise RuntimeError(
            f"{problem}. Generate one with: "
            'python -c "import secrets; print(secrets.token_urlsafe(48))"'
        )
    settings.ensure_data_dir()
    store = DeviceStore(settings.data_dir / "devices.sqlite3")
    state = ApiState(
        store=store,
        enroll_limiter=AttemptLimiter(
            settings.enroll_window_seconds, settings.enroll_max_attempts
        ),
        token_limiter=AttemptLimiter(60, 60),
    )
    logger.info(
        "voice api ready env=%s devices=%d enrolment_code=%s",
        settings.environment,
        store.count(),
        "set" if settings.enrollment_code else "open",
    )
    yield
    state = None


app = FastAPI(
    title="Serene Voice API",
    version=__version__,
    description="Device enrolment and short-lived LiveKit tokens for Serene voice calls.",
    lifespan=lifespan,
)

if settings.allowed_origins:
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.allowed_origins,
        allow_methods=["POST", "GET"],
        allow_headers=["content-type", "x-device-id", "x-device-secret"],
        max_age=600,
    )


@app.get("/healthz")
async def healthz() -> dict[str, Any]:
    return {
        "status": "ok",
        "service": "api",
        "version": __version__,
        "environment": settings.environment,
        "languages": list(SUPPORTED_LANGUAGES),
    }


@app.get("/readyz")
async def readyz() -> dict[str, Any]:
    """Check the dependencies a call actually needs.

    Returns 200 only when LiveKit and Ollama answer.  STT and TTS are checked
    lazily because loading whisper/torch is expensive.
    """

    async with httpx.AsyncClient(timeout=2.5) as client:

        async def probe(url: str) -> bool:
            try:
                response = await client.get(url)
                return response.status_code < 500
            except Exception:
                return False

        livekit_ok, ollama_ok = await asyncio.gather(
            probe(settings.livekit_http_url.rstrip("/") + "/"),
            probe(settings.ollama_base_url.rstrip("/") + "/models"),
        )

    ok = livekit_ok and ollama_ok
    payload = {
        "status": "ok" if ok else "degraded",
        "livekit": livekit_ok,
        "ollama": ollama_ok,
        "agent": settings.agent_name,
        "model": settings.ollama_model,
    }
    if not ok:
        raise HTTPException(status_code=503, detail=payload)
    return payload


@app.post("/v1/device/enroll")
async def enroll(payload: EnrollRequest, request: Request) -> dict[str, Any]:
    current = _require_state()
    ip = _client_ip(request)

    if not current.enroll_limiter.allow(ip):
        raise HTTPException(status_code=429, detail="too many enrolment attempts")

    if settings.enrollment_code:
        provided = payload.enrollment_code.strip()
        if not hmac.compare_digest(provided, settings.enrollment_code):
            raise HTTPException(status_code=403, detail="invalid enrolment code")

    try:
        device = await asyncio.to_thread(
            current.store.enroll,
            payload.device_id,
            payload.secret,
            settings.max_devices,
        )
    except AuthError as exc:
        raise HTTPException(status_code=exc.status_code, detail=exc.message) from exc

    logger.info("device enrolled total=%d", current.store.count())
    return {
        "enrolled": True,
        "device_id": device.device_id,
        "server_time": device.last_seen_at,
    }


@app.post("/v1/voice/token")
async def voice_token(
    payload: TokenRequest,
    request: Request,
    x_device_id: str | None = Header(default=None),
    x_device_secret: str | None = Header(default=None),
) -> dict[str, Any]:
    current = _require_state()
    device_id, secret = _credentials(x_device_id, x_device_secret)

    try:
        device = await asyncio.to_thread(current.store.authenticate, device_id, secret)
    except AuthError as exc:
        raise HTTPException(status_code=exc.status_code, detail=exc.message) from exc

    if not current.token_limiter.allow(device.device_id):
        raise HTTPException(status_code=429, detail="too many call attempts")

    language = normalize_language(payload.language)
    metadata = _shrink(
        {
            "language": language,
            "session": (payload.session or "").strip()[:64],
            "profile": _bounded_profile(payload.profile),
            "memories": _bounded_memories(payload.memories),
        }
    )

    issued = mint_participant_token(
        settings,
        room=new_room_name(),
        identity=public_identity(device.device_id),
        agent_metadata=metadata,
    )

    logger.info(
        "issued token language=%s room=%s metadata_bytes=%d",
        language,
        issued.room,
        len(json.dumps(metadata, ensure_ascii=False).encode("utf-8")),
    )

    return {
        "url": issued.url,
        "token": issued.token,
        "room": issued.room,
        "identity": issued.identity,
        "expires_at": issued.expires_at,
        "language": language,
    }


@app.get("/v1/voice/config")
async def voice_config() -> dict[str, Any]:
    """Non-secret hints the app can use to render its settings screen."""
    return {
        "agent": settings.agent_name,
        "languages": list(SUPPORTED_LANGUAGES),
        "token_ttl_seconds": settings.token_ttl_seconds,
        "enrollment_required": bool(settings.enrollment_code),
    }
