"""Data-channel messages sent from the agent to the Flutter app.

Topic: ``serene.voice``.  Payloads are small JSON objects, versioned with
``v`` so the client can ignore future additions without breaking.
"""

from __future__ import annotations

import json
import logging
from typing import Any, Literal

from livekit import rtc

logger = logging.getLogger("serene.events")

TOPIC = "serene.voice"
VERSION = 1

State = Literal["connecting", "listening", "thinking", "speaking", "idle"]


def _payload(kind: str, **fields: Any) -> bytes:
    body = {"v": VERSION, "type": kind, **fields}
    return json.dumps(body, ensure_ascii=False, separators=(",", ":")).encode("utf-8")


async def publish(room: rtc.Room, kind: str, **fields: Any) -> None:
    try:
        await room.local_participant.publish_data(
            _payload(kind, **fields),
            reliable=True,
            topic=TOPIC,
        )
    except Exception:  # pragma: no cover - room may already be closing
        logger.debug("could not publish %s event", kind, exc_info=True)


async def state(room: rtc.Room, value: State) -> None:
    await publish(room, "state", state=value)


async def transcript(
    room: rtc.Room, *, role: Literal["user", "assistant"], text: str, final: bool = True
) -> None:
    text = (text or "").strip()
    if not text:
        return
    await publish(room, "transcript", role=role, text=text, final=final)


async def crisis(room: rtc.Room, language: str) -> None:
    await publish(room, "crisis", language=language)


async def error(room: rtc.Room, code: str, message: str = "") -> None:
    await publish(room, "error", code=code, message=message)


async def ready(room: rtc.Room, language: str) -> None:
    await publish(room, "ready", language=language)
