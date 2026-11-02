"""LiveKit Agents worker for Serene.

Pipeline: LiveKit room audio -> Silero VAD -> faster-whisper (OpenAI-compatible
local server) -> Qwen3 via Ollama -> Kokoro/SILMA (OpenAI-compatible local
server) -> LiveKit room audio.

No cloud inference is used.  ``record=False`` is passed explicitly because the
Agents SDK otherwise records audio and transcripts for debugging.
"""

from __future__ import annotations

import asyncio
import json
import logging
import os
from dataclasses import dataclass, field
from typing import Any, Literal

import httpx
import openai
from livekit import rtc
from livekit.agents import (
    Agent,
    AgentSession,
    JobContext,
    RoomOptions,
    StopResponse,
    WorkerOptions,
    cli,
)
from livekit.agents.llm import ChatContext, ChatMessage
from livekit.plugins import openai as lk_openai
from livekit.plugins import silero

from . import events
from .config import settings
from .prompts import Personality, build_instructions, load_personality, normalize_language
from .safety import detect_crisis

logger = logging.getLogger("serene.agent")

CONTROL_TOPIC = "serene.control"

VOICE_BY_LANGUAGE = {
    "en": "af_heart",
    "fr": "ff_siwis",
    "ar": "silma-msa",
    "tn": "silma-derja",
}

STT_LANGUAGE = {
    "en": "en",
    "fr": "fr",
    "ar": "ar",
    "tn": "ar",  # Whisper has no Tunisian Arabic code; ar is the closest hint.
}


@dataclass
class CallContext:
    language: str = "en"
    profile: dict[str, Any] = field(default_factory=dict)
    memories: list[str] = field(default_factory=list)
    session_id: str = ""


def _parse_call_context(raw: str | None) -> CallContext:
    if not raw:
        return CallContext()
    try:
        data = json.loads(raw)
    except (TypeError, ValueError):
        logger.warning("agent metadata was not valid JSON; using defaults")
        return CallContext()
    if not isinstance(data, dict):
        return CallContext()

    profile = data.get("profile") if isinstance(data.get("profile"), dict) else {}
    memories = data.get("memories") if isinstance(data.get("memories"), list) else []
    return CallContext(
        language=normalize_language(str(data.get("language") or "en")),
        profile=profile,
        memories=[str(item) for item in memories if isinstance(item, str)][
            : settings.max_memories
        ],
        session_id=str(data.get("session") or ""),
    )


def _http_timeout(read: float = 90.0) -> httpx.Timeout:
    # The default plugin read timeout is 5 s.  A cold Qwen3 model on an 8 GB
    # card can take longer than that for its first token.
    return httpx.Timeout(connect=10.0, read=read, write=15.0, pool=15.0)


class SereneAgent(Agent):
    """Adds the pre-LLM crisis gate to the standard voice agent."""

    def __init__(
        self,
        *,
        instructions: str,
        room: rtc.Room,
        language: str,
        safety_line: str,
    ) -> None:
        super().__init__(instructions=instructions)
        self._room = room
        self._language = language
        self._safety_line = safety_line
        self._crisis_active = False

    async def on_user_turn_completed(
        self, turn_ctx: ChatContext, new_message: ChatMessage
    ) -> None:
        text = getattr(new_message, "text_content", "") or ""
        verdict = detect_crisis(text)
        if not verdict.is_crisis:
            return

        # Tell the UI to open the hotline sheet, then replace the model's reply
        # with a fixed, reviewed safety line.  `StopResponse` stops the normal
        # LLM turn; the queued `say()` still plays through TTS.
        if not self._crisis_active:
            self._crisis_active = True
            await events.crisis(self._room, self._language)
            await events.transcript(
                self._room, role="assistant", text=self._safety_line, final=True
            )
            self.session.say(self._safety_line, allow_interruptions=True)
        raise StopResponse()


async def _entrypoint(ctx: JobContext) -> None:
    call = _parse_call_context(ctx.job.metadata)
    personality: Personality = load_personality(settings.prompt_file)

    instructions = build_instructions(
        personality,
        language=call.language,
        profile=call.profile,
        memories=call.memories,
        max_memories=settings.max_memories,
        max_memory_chars=settings.max_memory_chars,
        max_notes_chars=settings.max_notes_chars,
    )

    stt_client = openai.AsyncClient(
        base_url=settings.stt_base_url,
        api_key="local-stt",
        max_retries=0,
        timeout=_http_timeout(60.0),
    )
    tts_client = openai.AsyncClient(
        base_url=settings.tts_base_url,
        api_key="local-tts",
        max_retries=0,
        timeout=_http_timeout(90.0),
    )
    llm_client = openai.AsyncClient(
        base_url=settings.ollama_base_url,
        api_key=settings.ollama_api_key,
        max_retries=0,
        timeout=_http_timeout(90.0),
    )

    async def _close_clients() -> None:
        for client in (stt_client, tts_client, llm_client):
            try:
                await client.close()
            except Exception:
                pass

    ctx.add_shutdown_callback(_close_clients)

    stt = lk_openai.STT(
        model=settings.stt_model,
        language=STT_LANGUAGE.get(call.language, "en"),
        use_realtime=False,
        client=stt_client,
    )
    tts = lk_openai.TTS(
        model=settings.tts_model,
        voice=VOICE_BY_LANGUAGE.get(call.language, "af_heart"),
        response_format="pcm",
        sample_rate=24000,
        client=tts_client,
    )
    llm = lk_openai.LLM(
        model=settings.ollama_model,
        client=llm_client,
        temperature=0.8,
    )
    vad = silero.VAD.load(
        min_speech_duration=0.15,
        min_silence_duration=0.45,
        prefix_padding_duration=0.35,
        activation_threshold=0.5,
    )

    session = AgentSession(
        stt=stt,
        llm=llm,
        tts=tts,
        vad=vad,
        turn_handling={
            "turn_detection": "vad",
            "endpointing": {"mode": "fixed", "min_delay": 0.35, "max_delay": 4.0},
            "interruption": {
                "enabled": True,
                "mode": "vad",
                "min_duration": 0.35,
                "resume_false_interruption": True,
            },
        },
        user_away_timeout=None,
    )

    @session.on("agent_state_changed")
    def _on_agent_state(ev: Any) -> None:
        mapping: dict[str, events.State] = {
            "initializing": "connecting",
            "idle": "listening",
            "listening": "listening",
            "thinking": "thinking",
            "speaking": "speaking",
        }
        value = mapping.get(str(getattr(ev, "new_state", "")), "listening")
        asyncio.create_task(events.state(ctx.room, value))

    @session.on("user_input_transcribed")
    def _on_user_transcript(ev: Any) -> None:
        text = str(getattr(ev, "transcript", "") or "")
        final = bool(getattr(ev, "is_final", False))
        if text.strip():
            asyncio.create_task(
                events.transcript(ctx.room, role="user", text=text, final=final)
            )

    @session.on("conversation_item_added")
    def _on_item(ev: Any) -> None:
        item = getattr(ev, "item", None)
        if item is None or getattr(item, "role", "") != "assistant":
            return
        text = getattr(item, "text_content", "") or ""
        if text.strip():
            asyncio.create_task(
                events.transcript(ctx.room, role="assistant", text=text, final=True)
            )

    @session.on("error")
    def _on_error(ev: Any) -> None:
        logger.error("agent session error: %s", type(getattr(ev, "error", ev)).__name__)
        asyncio.create_task(
            events.error(ctx.room, "agent_error", "The voice agent hit an error.")
        )

    @ctx.room.on("data_received")
    def _on_data(packet: rtc.DataPacket) -> None:
        if packet.topic != CONTROL_TOPIC:
            return
        try:
            message = json.loads(packet.data.decode("utf-8"))
        except (UnicodeDecodeError, ValueError):
            return
        if message.get("action") == "interrupt":
            asyncio.create_task(_interrupt(session))

    async def _interrupt(target: AgentSession) -> None:
        try:
            await target.interrupt(force=True)
        except RuntimeError:
            pass

    agent = SereneAgent(
        instructions=instructions,
        room=ctx.room,
        language=call.language,
        safety_line=personality.language(call.language).safety_line,
    )

    await ctx.connect()
    await session.start(
        agent,
        room=ctx.room,
        room_options=RoomOptions(
            close_on_disconnect=True,
            delete_room_on_close=True,
        ),
        record=False,
    )

    await events.ready(ctx.room, call.language)
    await events.state(ctx.room, "listening")

    name = str(call.profile.get("name") or "")
    greeting = personality.greeting(call.language, name)
    await events.transcript(ctx.room, role="assistant", text=greeting, final=True)
    session.say(greeting, allow_interruptions=True)


def main() -> None:
    logging.basicConfig(
        level=getattr(logging, settings.log_level.upper(), logging.INFO),
        format="%(asctime)s %(levelname)s %(name)s %(message)s",
    )
    # The Agents SDK logs transcripts at DEBUG. Keep production logs free of
    # conversation content.
    if settings.environment == "prod":
        logging.getLogger("livekit.agents").setLevel(logging.INFO)

    problem = settings.insecure_secret_reason()
    if problem:
        raise SystemExit(
            f"{problem}. Refusing to serve calls with a published credential."
        )

    os.environ.setdefault("LIVEKIT_URL", settings.livekit_internal_url)
    os.environ.setdefault("LIVEKIT_API_KEY", settings.livekit_api_key)
    os.environ.setdefault("LIVEKIT_API_SECRET", settings.livekit_api_secret)

    cli.run_app(
        WorkerOptions(
            entrypoint_fnc=_entrypoint,
            agent_name=settings.agent_name,
        )
    )


if __name__ == "__main__":
    main()
