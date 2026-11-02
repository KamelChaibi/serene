"""OpenAI-compatible text-to-speech server for Serene.

Engines
-------
``kokoro``      English and French, 24 kHz, ~80 MB, very low latency.
``silma-msa``   Modern Standard Arabic (SILMA TTS v1, Apache-2.0).
``silma-derja`` Tunisian Derja fine-tune (CC-BY-NC-4.0), MSA fallback.

The LiveKit agent requests ``response_format="pcm"`` at 24 kHz mono, so raw
little-endian int16 is the primary output.  WAV is supported for debugging.

Run::

    uvicorn app.tts_server:app --host 0.0.0.0 --port 8002

Privacy: the input text is synthesised and dropped.  It is never logged and
never written to disk.
"""

from __future__ import annotations

import asyncio
import contextlib
import io
import logging
import os
import re
import threading
import time
import uuid
import wave
from abc import ABC, abstractmethod
from contextlib import asynccontextmanager
from dataclasses import dataclass, field
from importlib.resources import files
from typing import Any, AsyncIterator

import numpy as np
from fastapi import FastAPI, HTTPException
from fastapi.responses import JSONResponse, Response
from pydantic import BaseModel, ConfigDict, Field

from .logging_utils import configure_logging, env_flag

logger = logging.getLogger("serene.tts")

SAMPLE_RATE = 24000
MAX_INPUT_CHARS = int(os.environ.get("TTS_MAX_INPUT_CHARS", "2000"))

# Spoken text should not contain markup.  The agent prompt already forbids it,
# but a stray asterisk is read aloud as "asterisk" by some front ends.
_MARKUP_RE = re.compile(r"[*_`#>\[\]{}|~]+")
_WHITESPACE_RE = re.compile(r"\s+")


def _clean_text(text: str) -> str:
    text = _MARKUP_RE.sub(" ", text or "")
    return _WHITESPACE_RE.sub(" ", text).strip()


def to_pcm16(samples: np.ndarray) -> bytes:
    """Convert float samples in [-1, 1] to little-endian int16 PCM."""
    data = np.asarray(samples, dtype=np.float32).reshape(-1)
    if data.size == 0:
        return b""
    data = np.clip(data, -1.0, 1.0)
    return (data * 32767.0).astype("<i2").tobytes()


def to_wav(samples: np.ndarray, sample_rate: int = SAMPLE_RATE) -> bytes:
    buffer = io.BytesIO()
    with wave.open(buffer, "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(sample_rate)
        handle.writeframes(to_pcm16(samples))
    return buffer.getvalue()


class EngineError(RuntimeError):
    """Engine could not load or synthesise."""


class Engine(ABC):
    name: str
    sample_rate: int = SAMPLE_RATE

    @abstractmethod
    def load(self) -> None: ...

    @property
    @abstractmethod
    def ready(self) -> bool: ...

    @abstractmethod
    def _synthesise_sync(self, text: str, voice: str, speed: float) -> np.ndarray: ...

    def synthesise(self, text: str, voice: str, speed: float) -> np.ndarray:
        self.load()
        return self._synthesise_sync(text, voice, speed)

    def status(self) -> dict[str, Any]:
        return {"engine": self.name, "ready": self.ready, "sample_rate": self.sample_rate}


# ---------------------------------------------------------------------------
# Kokoro
# ---------------------------------------------------------------------------


class KokoroEngine(Engine):
    """Kokoro-82M for English and French."""

    name = "kokoro"

    # Kokoro language packs: 'a' American English, 'b' British English,
    # 'f' French.  The first letter of a voice id selects the pack.
    _PACKS = {"a": "a", "b": "b", "f": "f"}

    def __init__(self, device: str = "auto", voices: list[str] | None = None) -> None:
        self._device = device
        self._voices = set(voices or [])
        self._pipelines: dict[str, Any] = {}
        self._lock = threading.Lock()
        self._loaded = False

    @property
    def ready(self) -> bool:
        return self._loaded

    def _resolve_device(self) -> str:
        if self._device != "auto":
            return self._device
        try:
            import torch

            return "cuda" if torch.cuda.is_available() else "cpu"
        except Exception:
            return "cpu"

    def load(self) -> None:
        if self._loaded:
            return
        with self._lock:
            if self._loaded:
                return
            try:
                from kokoro import KPipeline  # noqa: F401
            except Exception as exc:  # pragma: no cover - install problem
                raise EngineError(
                    "kokoro is not installed; install the `tts` extras"
                ) from exc
            self._loaded = True
            logger.info("kokoro available on device=%s", self._resolve_device())

    def _pipeline(self, lang_code: str) -> Any:
        pipeline = self._pipelines.get(lang_code)
        if pipeline is not None:
            return pipeline

        from kokoro import KPipeline

        logger.info("loading kokoro language pack %s", lang_code)
        pipeline = KPipeline(
            lang_code=lang_code,
            repo_id=os.environ.get("TTS_KOKORO_REPO", "hexgrad/Kokoro-82M"),
            device=self._resolve_device(),
        )
        self._pipelines[lang_code] = pipeline
        return pipeline

    def _check_voice(self, voice: str) -> str:
        pack = self._PACKS.get(voice[:1].lower())
        if pack is None:
            raise EngineError(f"unknown Kokoro voice: {voice}")
        if self._voices and voice not in self._voices:
            raise EngineError(f"voice is not enabled: {voice}")
        return pack

    def _synthesise_sync(self, text: str, voice: str, speed: float) -> np.ndarray:
        pack = self._check_voice(voice)
        pipeline = self._pipeline(pack)
        chunks: list[np.ndarray] = []
        with self._lock:
            for result in pipeline(text, voice=voice, speed=max(0.5, min(2.0, speed))):
                audio = getattr(result, "audio", None)
                if audio is None:
                    continue
                if hasattr(audio, "detach"):
                    audio = audio.detach().cpu().numpy()
                chunks.append(np.asarray(audio, dtype=np.float32).reshape(-1))
        if not chunks:
            return np.zeros(0, dtype=np.float32)
        return np.concatenate(chunks)


# ---------------------------------------------------------------------------
# SILMA (F5-TTS architecture)
# ---------------------------------------------------------------------------

# Reference clip and transcript shipped with the SILMA package.  F5-TTS is a
# voice-cloning architecture: output timbre and prosody follow this clip.
MSA_REF_TEXT = (
    "ويدقق النظر في القرآن الكريم وسائر الكتب السماوية ويتبع مسالك الرسل "
    "العظام عليهم الصلاة والسلام."
)


def _silma_ref_audio() -> str:
    return str(files("silma_tts").joinpath("infer/ref_audio_samples/ar.ref.24k.wav"))


@contextlib.contextmanager
def _quiet_stdout() -> Any:
    """SILMA prints each text chunk to stdout.  That is a transcript leak.

    The TTS process is single-purpose and inference is serialised, so swapping
    the process-wide stdout for the duration of one synthesis is acceptable.
    Losing a concurrent log line is better than writing caller speech to disk.
    """

    with open(os.devnull, "w", encoding="utf-8") as sink:
        with contextlib.redirect_stdout(sink):
            yield


class SilmaEngine(Engine):
    """SILMA TTS with a configurable checkpoint.

    ``SilmaTTS`` from the upstream package ignores its ``ckpt_file`` argument
    and always downloads the MSA weights.  This class mirrors the documented
    internals (``load_model`` / ``load_vocoder`` / ``infer_process``) so the
    Derja fine-tune can be loaded from disk.
    """

    def __init__(
        self,
        *,
        name: str,
        checkpoint: str,
        vocab: str,
        config: str = "",
        ref_audio: str = "",
        ref_text: str = "",
        device: str = "auto",
        nfe_step: int = 16,
        cfg_strength: float = 2.0,
        use_ema: bool = False,
        normalize: bool = False,
        tashkeel: bool = False,
    ) -> None:
        self.name = name
        self._checkpoint = checkpoint
        self._vocab = vocab
        self._config = config
        self._ref_audio = ref_audio or ""
        self._ref_text = ref_text or MSA_REF_TEXT
        self._device = device
        self._nfe_step = nfe_step
        self._cfg_strength = cfg_strength
        self._use_ema = use_ema
        self._normalize = normalize
        self._tashkeel = tashkeel
        self._model: Any = None
        self._vocoder: Any = None
        self._mel_spec_type = "vocos"
        self._lock = threading.Lock()

    @property
    def ready(self) -> bool:
        return self._model is not None

    def _resolve_device(self) -> str:
        if self._device != "auto":
            return self._device
        try:
            import torch

            if torch.cuda.is_available():
                return "cuda"
            if getattr(torch.backends, "mps", None) and torch.backends.mps.is_available():
                return "mps"
        except Exception:
            pass
        return "cpu"

    def _resolve_ref_audio(self) -> str:
        if self._ref_audio and os.path.exists(self._ref_audio):
            return self._ref_audio
        if self._ref_audio:
            logger.warning(
                "configured reference clip is missing; using the packaged Arabic clip"
            )
        return _silma_ref_audio()

    def load(self) -> None:
        if self._model is not None:
            return
        with self._lock:
            if self._model is not None:
                return
            if not os.path.exists(self._checkpoint):
                raise EngineError(f"checkpoint not found: {self._checkpoint}")
            if not os.path.exists(self._vocab):
                raise EngineError(f"vocab not found: {self._vocab}")

            try:
                from hydra.utils import get_class
                from omegaconf import OmegaConf
                from silma_tts.infer.utils_infer import load_model, load_vocoder
            except Exception as exc:  # pragma: no cover - install problem
                raise EngineError("silma-tts is not installed") from exc

            device = self._resolve_device()
            config_path = (
                self._config
                if self._config and os.path.exists(self._config)
                else str(files("silma_tts").joinpath("config.yaml"))
            )
            cfg = OmegaConf.load(config_path)
            model_cls = get_class(f"silma_tts.model.{cfg.model.backbone}")
            self._mel_spec_type = str(cfg.model.mel_spec.mel_spec_type)
            self.sample_rate = int(cfg.model.mel_spec.target_sample_rate)

            if self._normalize or self._tashkeel:
                from silma_tts.infer.utils_infer import (
                    load_nemo_text_normalizer,
                    load_tashkeel_model,
                )

                if self._normalize:
                    load_nemo_text_normalizer("english")
                    load_nemo_text_normalizer("عربي")
                if self._tashkeel:
                    load_tashkeel_model()

            logger.info("loading %s on %s", self.name, device)
            self._vocoder = load_vocoder(
                self._mel_spec_type, False, "", device, os.environ.get("HF_HOME")
            )
            self._model = load_model(
                model_cls,
                cfg.model.arch,
                self._checkpoint,
                self._mel_spec_type,
                self._vocab,
                "euler",
                self._use_ema,
                device,
            )
            logger.info("%s ready", self.name)

    def _synthesise_sync(self, text: str, voice: str, speed: float) -> np.ndarray:
        del voice  # a SILMA checkpoint has a single voice
        from silma_tts.infer.utils_infer import (
            infer_process,
            normalize_text,
            preprocess_ref_audio_text,
        )

        device = self._resolve_device()
        gen_text = text
        if self._normalize:
            with _quiet_stdout():
                gen_text = normalize_text(gen_text)

        def _noop(*_: Any, **__: Any) -> None:
            return None

        with self._lock, _quiet_stdout():
            ref_audio, ref_text = preprocess_ref_audio_text(
                self._resolve_ref_audio(), self._ref_text, show_info=_noop
            )
            wav, _sr, _spec = infer_process(
                ref_audio,
                ref_text,
                gen_text,
                self._model,
                self._vocoder,
                self._mel_spec_type,
                show_info=_noop,
                progress=None,
                nfe_step=self._nfe_step,
                cfg_strength=self._cfg_strength,
                speed=max(0.5, min(2.0, speed)),
                device=device,
                force_tashkeel=self._tashkeel,
            )
        return np.asarray(wav, dtype=np.float32).reshape(-1)


# ---------------------------------------------------------------------------
# Registry
# ---------------------------------------------------------------------------


@dataclass
class VoiceRegistry:
    engines: dict[str, Engine] = field(default_factory=dict)
    aliases: dict[str, str] = field(default_factory=dict)
    fallbacks: dict[str, str] = field(default_factory=dict)

    def resolve(self, voice: str) -> Engine:
        key = self.aliases.get(voice, voice)
        engine = self.engines.get(key)
        if engine is None:
            raise EngineError(f"unknown voice: {voice}")
        return engine

    def status(self) -> list[dict[str, Any]]:
        seen: set[int] = set()
        result: list[dict[str, Any]] = []
        for engine in self.engines.values():
            if id(engine) in seen:
                continue
            seen.add(id(engine))
            result.append(engine.status())
        return result


def _build_registry() -> VoiceRegistry:
    registry = VoiceRegistry()

    kokoro_voices = [
        voice.strip()
        for voice in os.environ.get(
            "TTS_KOKORO_VOICES",
            "af_heart,af_bella,af_nicole,af_sarah,am_michael,am_adam,"
            "bf_emma,bm_george,ff_siwis",
        ).split(",")
        if voice.strip()
    ]
    kokoro = KokoroEngine(
        device=os.environ.get("TTS_DEVICE", "auto"), voices=kokoro_voices
    )
    for voice in kokoro_voices:
        registry.engines[voice] = kokoro

    model_dir = os.environ.get("SERENE_MODELS_DIR", "/models")

    msa_dir = os.environ.get("SILMA_MSA_DIR", os.path.join(model_dir, "silma-msa"))
    msa = SilmaEngine(
        name="silma-msa",
        checkpoint=os.environ.get("SILMA_MSA_CKPT", os.path.join(msa_dir, "model.pt")),
        vocab=os.environ.get("SILMA_MSA_VOCAB", os.path.join(msa_dir, "vocab.txt")),
        config=os.environ.get("SILMA_MSA_CONFIG", os.path.join(msa_dir, "config.yaml")),
        ref_audio=os.environ.get("SILMA_MSA_REF_AUDIO", ""),
        ref_text=os.environ.get("SILMA_MSA_REF_TEXT", MSA_REF_TEXT),
        device=os.environ.get("TTS_DEVICE", "auto"),
        nfe_step=int(os.environ.get("SILMA_NFE_STEP", "16")),
        cfg_strength=float(os.environ.get("SILMA_CFG_STRENGTH", "2.0")),
        use_ema=env_flag("SILMA_USE_EMA", False),
        normalize=env_flag("SILMA_NORMALIZE", False),
        tashkeel=env_flag("SILMA_TASHKEEL", False),
    )
    registry.engines["silma-msa"] = msa

    derja_dir = os.environ.get(
        "SILMA_DERJA_DIR", os.path.join(model_dir, "silma-derja")
    )
    derja = SilmaEngine(
        name="silma-derja",
        checkpoint=os.environ.get(
            "SILMA_DERJA_CKPT", os.path.join(derja_dir, "model.pt")
        ),
        vocab=os.environ.get(
            "SILMA_DERJA_VOCAB", os.path.join(derja_dir, "vocab.txt")
        ),
        config=os.environ.get(
            "SILMA_DERJA_CONFIG", os.path.join(derja_dir, "config.yaml")
        ),
        ref_audio=os.environ.get("SILMA_DERJA_REF_AUDIO", ""),
        ref_text=os.environ.get("SILMA_DERJA_REF_TEXT", MSA_REF_TEXT),
        device=os.environ.get("TTS_DEVICE", "auto"),
        nfe_step=int(os.environ.get("SILMA_NFE_STEP", "16")),
        cfg_strength=float(os.environ.get("SILMA_CFG_STRENGTH", "2.0")),
        use_ema=env_flag("SILMA_USE_EMA", False),
        normalize=env_flag("SILMA_NORMALIZE", False),
        tashkeel=env_flag("SILMA_TASHKEEL", False),
    )
    registry.engines["silma-derja"] = derja
    # If the fine-tune is missing, the agent still gets Arabic audio rather
    # than silence.  The server reports the degradation in /healthz.
    registry.fallbacks["silma-derja"] = "silma-msa"

    return registry


REGISTRY = _build_registry()


def _engine_for(voice: str) -> Engine:
    engine = REGISTRY.resolve(voice)
    if engine.ready:
        return engine
    try:
        engine.load()
        return engine
    except EngineError:
        fallback_key = REGISTRY.fallbacks.get(engine.name)
        if not fallback_key:
            raise
        fallback = REGISTRY.engines[fallback_key]
        logger.warning("%s unavailable; falling back to %s", engine.name, fallback.name)
        fallback.load()
        return fallback


class SpeechRequest(BaseModel):
    model_config = ConfigDict(extra="ignore")

    model: str = "serene-tts"
    input: str = Field(min_length=1)
    voice: str = "af_heart"
    response_format: str = "pcm"
    speed: float = 1.0
    instructions: str | None = None
    stream_format: str | None = None


@asynccontextmanager
async def lifespan(_: FastAPI) -> AsyncIterator[None]:
    configure_logging(os.environ.get("SERENE_LOG_LEVEL", "INFO"))
    if env_flag("TTS_PRELOAD", True):
        kokoro = REGISTRY.engines.get("af_heart")
        if kokoro is not None:
            try:
                await asyncio.to_thread(kokoro.load)
            except EngineError as exc:
                logger.warning("kokoro preload failed: %s", exc)
    if env_flag("TTS_PRELOAD_SILMA", False):
        for key in ("silma-msa", "silma-derja"):
            engine = REGISTRY.engines.get(key)
            if engine is None:
                continue
            try:
                await asyncio.to_thread(engine.load)
            except EngineError as exc:
                logger.warning("%s preload failed: %s", key, exc)
    yield
    logger.info("tts server shutting down")


app = FastAPI(
    title="Serene TTS",
    version="1.0.0",
    description="Local Kokoro and SILMA speech synthesis with an OpenAI-compatible API.",
    lifespan=lifespan,
)


@app.get("/healthz")
async def healthz() -> dict[str, Any]:
    engines = REGISTRY.status()
    return {
        "status": "ok",
        "service": "tts",
        "sample_rate": SAMPLE_RATE,
        "engines": engines,
        "fallbacks": REGISTRY.fallbacks,
    }


@app.get("/v1/models")
async def models() -> dict[str, Any]:
    return {
        "object": "list",
        "data": [
            {"id": "serene-tts", "object": "model", "owned_by": "local"},
            {"id": "tts-1", "object": "model", "owned_by": "local"},
        ],
    }


@app.get("/v1/voices")
async def voices() -> dict[str, Any]:
    return {
        "voices": [
            {"id": voice, "engine": engine.name, "ready": engine.ready}
            for voice, engine in REGISTRY.engines.items()
        ]
    }


@app.post("/v1/audio/speech")
async def speech(payload: SpeechRequest) -> Response:
    text = _clean_text(payload.input)
    if not text:
        raise HTTPException(status_code=400, detail="input text is empty")
    if len(text) > MAX_INPUT_CHARS:
        raise HTTPException(status_code=413, detail="input text is too long")

    fmt = (payload.response_format or "pcm").lower()
    if fmt not in {"pcm", "wav"}:
        raise HTTPException(
            status_code=400,
            detail="supported response_format values are pcm and wav",
        )

    started = time.perf_counter()
    try:
        engine = await asyncio.to_thread(_engine_for, payload.voice)
        samples = await asyncio.to_thread(
            engine.synthesise, text, payload.voice, payload.speed
        )
    except EngineError as exc:
        logger.warning("tts engine error: %s", exc)
        raise HTTPException(status_code=503, detail=str(exc)) from exc

    elapsed = time.perf_counter() - started
    audio_seconds = samples.size / float(engine.sample_rate or SAMPLE_RATE)
    # Character count and timing only; never the text itself.
    logger.info(
        "synthesised engine=%s chars=%d audio=%.2fs elapsed=%.2fs rtf=%.2f",
        engine.name,
        len(text),
        audio_seconds,
        elapsed,
        (elapsed / audio_seconds) if audio_seconds > 0 else 0.0,
    )

    if fmt == "wav":
        body = to_wav(samples, engine.sample_rate or SAMPLE_RATE)
        media_type = "audio/wav"
    else:
        body = to_pcm16(samples)
        media_type = "audio/pcm"

    if not body:
        raise HTTPException(status_code=503, detail="engine produced no audio")

    return Response(
        content=body,
        media_type=media_type,
        headers={
            "x-request-id": uuid.uuid4().hex,
            "cache-control": "no-store",
        },
    )
