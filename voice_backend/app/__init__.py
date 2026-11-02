"""Serene self-hosted voice backend.

The package is split so the public API container never imports torch or the
model runtimes:

* ``app.api``          – FastAPI auth / token / health service (light).
* ``app.agent``        – LiveKit Agents worker (needs livekit-agents).
* ``app.stt_server``   – faster-whisper OpenAI-compatible STT (needs torch).
* ``app.tts_server``   – Kokoro + SILMA OpenAI-compatible TTS (needs torch).
"""

__version__ = "1.0.0"
