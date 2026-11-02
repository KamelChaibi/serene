"""Short-lived LiveKit access tokens.

The Flutter app receives only:

* the public LiveKit WebSocket URL,
* a participant JWT (10 minutes by default),
* the room name.

It never receives the API secret.  The token also carries an *agent dispatch*
room configuration, so the self-hosted LiveKit server starts the Python agent
for this room automatically.  That keeps the API stateless and avoids a second
round trip.
"""

from __future__ import annotations

import json
import time
from dataclasses import dataclass
from datetime import timedelta
from typing import Any

from livekit.api import (
    AccessToken,
    RoomAgentDispatch,
    RoomConfiguration,
    VideoGrants,
)

from .config import Settings


@dataclass(frozen=True)
class IssuedToken:
    url: str
    token: str
    room: str
    identity: str
    expires_at: int


def mint_participant_token(
    settings: Settings,
    *,
    room: str,
    identity: str,
    agent_metadata: dict[str, Any],
) -> IssuedToken:
    """Mint a room-join token that also dispatches the Serene agent."""

    now = int(time.time())
    expires_at = now + max(60, settings.token_ttl_seconds)

    grants = VideoGrants(
        room_join=True,
        room=room,
        can_publish=True,
        can_subscribe=True,
        can_publish_data=True,
        can_update_own_metadata=False,
    )

    metadata = json.dumps(agent_metadata, ensure_ascii=False, separators=(",", ":"))
    room_config = RoomConfiguration(
        agents=[
            RoomAgentDispatch(
                agent_name=settings.agent_name,
                metadata=metadata,
            )
        ],
        empty_timeout=settings.room_empty_timeout_seconds,
    )

    token = (
        AccessToken(settings.livekit_api_key, settings.livekit_api_secret)
        .with_identity(identity)
        .with_name("Serene caller")
        .with_grants(grants)
        .with_ttl(timedelta(seconds=max(60, settings.token_ttl_seconds)))
        .with_room_config(room_config)
        .to_jwt()
    )

    return IssuedToken(
        url=settings.livekit_url,
        token=token,
        room=room,
        identity=identity,
        expires_at=expires_at,
    )
