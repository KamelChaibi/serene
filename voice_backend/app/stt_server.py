"""OpenAI-compatible speech-to-text server backed by faster-whisper.

The LiveKit agent talks to this service through ``livekit-plugins-openai`` with
``model="whisper-1"``, which makes the plugin request ``verbose_json``.  Only
the fields that contract requires are implemented.

Run::

    uvicorn app.stt_server:app --host 0.0.0.0 --port 8001

Privacy: audio is decoded from the request body, transcribed, and dropped.  No
file is written to disk and no transcript is logged.
"""

from __future__ import annotations

import asyncio
import io
import logging
import os
import time
from contextlib import asynccontextmanager
from dataclasses import dataclass
from typing import Any, AsyncIterator

from fastapi import FastAPI, File, Form, HTTPException, UploadFile
from fastapi.responses import JSONResponse, PlainTextResponse, Response

from .logging_utils import configure_logging, env_flag

logger = logging.getLogger("serene.stt")

MAX_UPLOAD_BYTES = int(os.environ.get("STT_MAX_UPLOAD_MB", "25")) * 1024 * 1024
MAX_AUDIO_SECONDS = float(os.environ.get("STT_MAX_AUDIO_SECONDS", "300"))

# Whisper has no Tunisian Arabic (aeb) language code; the agent sends the
# closest hint and the prompt layer keeps the dialect.
_LANGUAGE_ALIASES = {
    "tn": "ar",
    "aeb": "ar",
    "ar-tn": "ar",
    "ar_tn": "ar",
    "auto": "",
    "": "",
}


@dataclass(frozen=True)
class SttConfig:
    model_name: str = os.environ.get("STT_MODEL_NAME", "medium")
    device: str = os.environ.get("STT_DEVICE", "auto")
    compute_type: str = os.environ.get("STT_COMPUTE_TYPE", "auto")
    beam_size: int = int(os.environ.get("STT_BEAM_SIZE", "1"))
    cpu_threads: int = int(os.environ.get("STT_CPU_THREADS", "0"))
    download_root: str = os.environ.get(
        "STT_DOWNLOAD_ROOT", "/models/faster-whisper"
    )
    preload: bool = env_flag("STT_PRELOAD", True)
    no_speech_threshold: float = float(
        os.environ.get("STT_NO_SPEECH_THRESHOLD", "0.6")
    )
    log_prob_threshold: float = float(
        os.environ.get("STT_LOG_PROB_THRESHOLD", "-1.0")
    )

    def resolved_device(self) -> str:
        if self.device != "auto":
            return self.device
        try:
            import torch

            return "cuda" if torch.cuda.is_available() else "cpu"
        except Exception:
            return "cpu"

    def resolved_compute_type(self, device: str) -> str:
        if self.compute_type != "auto":
            return self.compute_type
        if device == "cuda":
            # int8 weights with fp16 activations: the 8 GB profile.
            return "int8_float16"
        return "int8"


CONFIG = SttConfig()


class WhisperEngine:
    """Single model instance with a lock so one GPU runs one request at a time."""

    def __init__(self, config: SttConfig) -> None:
        self._config = config
        self._model: Any = None
        self._device = config.resolved_device()
        self._compute_type = config.resolved_compute_type(self._device)
        self._lock = asyncio.Lock()
        self._loaded_at: float | None = None

    @property
    def ready(self) -> bool:
        return self._model is not None

    @property
    def info(self) -> dict[str, Any]:
        return {
            "model": self._config.model_name,
            "device": self._device,
            "compute_type": self._compute_type,
            "loaded": self.ready,
            "loaded_at": self._loaded_at,
        }

    def load(self) -> None:
        if self._model is not None:
            return
        from faster_whisper import WhisperModel

        logger.info(
            "loading faster-whisper model=%s device=%s compute_type=%s",
            self._config.model_name,
            self._device,
            self._compute_type,
        )
        os.makedirs(self._config.download_root, exist_ok=True)
        kwargs: dict[str, Any] = {
            "device": self._device,
            "compute_type": self._compute_type,
            "download_root": self._config.download_root,
        }
        if self._config.cpu_threads > 0:
            kwargs["cpu_threads"] = self._config.cpu_threads
        self._model = WhisperModel(self._config.model_name, **kwargs)
        self._loaded_at = time.time()
        logger.info("faster-whisper model ready")

    def _transcribe_sync(
        self,
        audio: io.BytesIO,
        *,
        language: str | None,
        prompt: str | None,
        temperature: float | None,
    ) -> dict[str, Any]:
        if self._model is None:  # pragma: no cover - guarded by the caller
            raise RuntimeError("model is not loaded")

        started = time.perf_counter()
        segments, info = self._model.transcribe(
            audio,
            language=language,
            beam_size=self._config.beam_size,
            temperature=[temperature] if temperature is not None else [0.0, 0.2, 0.4],
            condition_on_previous_text=False,
            initial_prompt=prompt or None,
            vad_filter=False,
            word_timestamps=False,
            no_speech_threshold=self._config.no_speech_threshold,
            log_prob_threshold=self._config.log_prob_threshold,
            compression_ratio_threshold=2.4,
        )

        collected: list[dict[str, Any]] = []
        parts: list[str] = []
        for segment in segments:
            text = (segment.text or "").strip()
            if not text:
                continue
            # Drop classic silence hallucinations: high no-speech probability
            # together with a weak log probability.
            if (
                getattr(segment, "no_speech_prob", 0.0) > 0.85
                and getattr(segment, "avg_logprob", 0.0) < -1.2
            ):
                continue
            parts.append(text)
            collected.append(
                {
                    "id": len(collected),
                    "start": round(float(segment.start), 3),
                    "end": round(float(segment.end), 3),
                    "text": text,
                    "avg_logprob": round(float(getattr(segment, "avg_logprob", 0.0)), 4),
                    "no_speech_prob": round(
                        float(getattr(segment, "no_speech_prob", 0.0)), 4
                    ),
                    "compression_ratio": round(
                        float(getattr(segment, "compression_ratio", 1.0)), 4
                    ),
                }
            )

        duration = float(getattr(info, "duration", 0.0) or 0.0)
        elapsed = time.perf_counter() - started
        # Only non-content metadata is logged.
        logger.info(
            "transcribed duration=%.2fs language=%s segments=%d elapsed=%.2fs",
            duration,
            getattr(info, "language", "unknown"),
            len(collected),
            elapsed,
        )
        return {
            "text": " ".join(parts).strip(),
            "language": str(getattr(info, "language", "") or language or "en"),
            "language_probability": round(
                float(getattr(info, "language_probability", 0.0) or 0.0), 4
            ),
            "duration": round(duration, 3),
            "segments": collected,
            "elapsed": round(elapsed, 3),
        }

    async def transcribe(
        self,
        data: bytes,
        *,
        language: str | None,
        prompt: str | None,
        temperature: float | None,
    ) -> dict[str, Any]:
        async with self._lock:
            await asyncio.to_thread(self.load)
            return await asyncio.to_thread(
                self._transcribe_sync,
                io.BytesIO(data),
                language=language,
                prompt=prompt,
                temperature=temperature,
            )


engine = WhisperEngine(CONFIG)


def _normalize_language(raw: str | None) -> str | None:
    value = (raw or "").strip().lower().replace("_", "-")
    if not value:
        return None
    if value in _LANGUAGE_ALIASES:
        mapped = _LANGUAGE_ALIASES[value]
        return mapped or None
    # Accept "ar-TN", "fr-FR", "en-US" by keeping the primary subtag.
    primary = value.split("-", 1)[0]
    return _LANGUAGE_ALIASES.get(primary, primary) or None


def _estimate_duration(data: bytes) -> float:
    """Rough WAV duration, used only to reject absurd uploads early."""
    if len(data) < 44 or data[:4] != b"RIFF":
        return 0.0
    try:
        import wave

        with wave.open(io.BytesIO(data), "rb") as handle:
            rate = handle.getframerate() or 1
            return handle.getnframes() / float(rate)
    except Exception:
        return 0.0


@asynccontextmanager
async def lifespan(_: FastAPI) -> AsyncIterator[None]:
    configure_logging(os.environ.get("SERENE_LOG_LEVEL", "INFO"))
    if CONFIG.preload:
        # Loading on the event loop is fine here: nothing else is serving yet.
        await asyncio.to_thread(engine.load)
    yield
    logger.info("stt server shutting down")


app = FastAPI(
    title="Serene STT",
    version="1.0.0",
    description="Local faster-whisper transcription with an OpenAI-compatible API.",
    lifespan=lifespan,
)


@app.get("/healthz")
async def healthz() -> dict[str, Any]:
    return {"status": "ok", "service": "stt", **engine.info}


@app.get("/v1/models")
async def models() -> dict[str, Any]:
    return {
        "object": "list",
        "data": [
            {
                "id": "whisper-1",
                "object": "model",
                "owned_by": "local",
                "created": int(engine._loaded_at or 0),
            }
        ],
    }


@app.post("/v1/audio/transcriptions")
async def transcriptions(
    file: UploadFile = File(...),
    model: str = Form("whisper-1"),
    language: str | None = Form(None),
    prompt: str | None = Form(None),
    response_format: str = Form("json"),
    temperature: float | None = Form(None),
) -> Response:
    del model  # the local model is fixed by configuration

    data = await file.read()
    if not data:
        raise HTTPException(status_code=400, detail="empty audio upload")
    if len(data) > MAX_UPLOAD_BYTES:
        raise HTTPException(status_code=413, detail="audio upload too large")

    duration = _estimate_duration(data)
    if duration > MAX_AUDIO_SECONDS:
        raise HTTPException(status_code=413, detail="audio is too long")

    result = await engine.transcribe(
        data,
        language=_normalize_language(language),
        prompt=(prompt or "").strip()[:400] or None,
        temperature=temperature,
    )

    if response_format == "text":
        return PlainTextResponse(result["text"])

    if response_format == "verbose_json":
        return JSONResponse(
            {
                "task": "transcribe",
                "language": result["language"],
                "duration": result["duration"],
                "text": result["text"],
                "segments": result["segments"],
            }
        )

    if response_format in {"json", ""}:
        return JSONResponse({"text": result["text"]})

    raise HTTPException(
        status_code=400, detail=f"unsupported response_format: {response_format}"
    )
