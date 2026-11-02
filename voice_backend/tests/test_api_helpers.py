"""API request bounding: untrusted profile data must stay small and safe."""

import json

from app.api import (
    MAX_METADATA_BYTES,
    ProfilePayload,
    _bounded_memories,
    _bounded_profile,
    _shrink,
)


def test_profile_is_truncated() -> None:
    profile = _bounded_profile(
        ProfilePayload(
            name="n" * 500,
            age=900,
            style="s" * 100,
            length="l" * 100,
            focuses=[f"focus-{i}" for i in range(50)],
            notes="o" * 5000,
        )
    )
    assert len(profile["name"]) == 60
    assert profile["age"] is None
    assert len(profile["style"]) == 20
    assert len(profile["length"]) == 20
    assert len(profile["focuses"]) == 8
    assert len(profile["notes"]) <= 500


def test_age_outside_the_supported_range_is_dropped() -> None:
    assert _bounded_profile(ProfilePayload(age=7))["age"] is None
    assert _bounded_profile(ProfilePayload(age=29))["age"] == 29


def test_memories_are_bounded() -> None:
    memories = _bounded_memories([f"{i}-" + "m" * 1000 for i in range(100)])
    assert len(memories) <= 20
    assert all(len(memory) <= 280 for memory in memories)


def test_memories_drop_blank_entries() -> None:
    assert _bounded_memories(["", "   ", "kept"]) == ["kept"]


def test_shrink_keeps_small_metadata_untouched() -> None:
    metadata = {"language": "en", "session": "s", "memories": ["a"]}
    assert _shrink(metadata) == metadata


def test_shrink_fits_the_metadata_ceiling() -> None:
    metadata = {
        "language": "ar",
        "session": "s" * 64,
        "profile": {"name": "ن" * 60, "notes": "ن" * 500},
        "memories": ["ذ" * 280 for _ in range(20)],
    }
    shrunk = _shrink(metadata)
    encoded = json.dumps(shrunk, ensure_ascii=False, separators=(",", ":"))
    assert len(encoded.encode("utf-8")) <= MAX_METADATA_BYTES
    assert shrunk["language"] == "ar"


def test_shrink_never_returns_an_empty_payload() -> None:
    metadata = {"language": "tn", "session": "x", "memories": ["m" * 280] * 20}
    shrunk = _shrink(metadata)
    assert shrunk["language"] == "tn"
