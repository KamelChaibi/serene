"""Token minting: the app must get a room token and nothing more."""

import json

import jwt
import pytest

from app.config import Settings
from app.tokens import mint_participant_token

SETTINGS = Settings(
    livekit_url="wss://voice.example.test",
    livekit_api_key="test-key",
    livekit_api_secret="test-secret-that-is-long-enough-1234",
    livekit_http_url="http://livekit:7880",
    agent_name="serene-voice",
    token_ttl_seconds=600,
    room_empty_timeout_seconds=45,
)


def _mint(**overrides):
    metadata = overrides.pop("agent_metadata", {"language": "fr", "session": "abc"})
    return mint_participant_token(
        SETTINGS,
        room=overrides.pop("room", "serene-testroom"),
        identity=overrides.pop("identity", "user-deadbeef"),
        agent_metadata=metadata,
    )


def test_token_grants_room_join_and_publish() -> None:
    issued = _mint()
    claims = jwt.decode(
        issued.token, SETTINGS.livekit_api_secret, algorithms=["HS256"]
    )

    assert claims["sub"] == "user-deadbeef"
    assert claims["video"]["room"] == "serene-testroom"
    assert claims["video"]["roomJoin"] is True
    assert claims["video"]["canPublish"] is True
    assert claims["video"]["canSubscribe"] is True
    assert claims["video"]["canPublishData"] is True


def test_token_dispatches_the_agent_with_metadata() -> None:
    issued = _mint(agent_metadata={"language": "tn", "memories": ["a"]})
    claims = jwt.decode(
        issued.token, SETTINGS.livekit_api_secret, algorithms=["HS256"]
    )

    agents = claims["roomConfig"]["agents"]
    assert agents[0]["agentName"] == "serene-voice"
    assert json.loads(agents[0]["metadata"]) == {
        "language": "tn",
        "memories": ["a"],
    }
    assert claims["roomConfig"]["emptyTimeout"] == 45


def test_token_is_short_lived() -> None:
    issued = _mint()
    claims = jwt.decode(
        issued.token, SETTINGS.livekit_api_secret, algorithms=["HS256"]
    )
    ttl = int(claims["exp"]) - int(claims["nbf"])
    assert ttl == 600


def test_api_secret_is_not_in_the_token() -> None:
    issued = _mint()
    assert SETTINGS.livekit_api_secret not in issued.token
    assert issued.token.count(".") == 2


def test_returned_url_is_the_public_one() -> None:
    issued = _mint()
    assert issued.url == "wss://voice.example.test"


def test_metadata_survives_unicode() -> None:
    issued = _mint(agent_metadata={"language": "ar", "profile": {"name": "سيرين"}})
    claims = jwt.decode(
        issued.token, SETTINGS.livekit_api_secret, algorithms=["HS256"]
    )
    metadata = json.loads(claims["roomConfig"]["agents"][0]["metadata"])
    assert metadata["profile"]["name"] == "سيرين"
