"""STT server helpers that run without loading a model."""

import io
import wave

import pytest

from app.stt_server import _estimate_duration, _normalize_language


@pytest.mark.parametrize(
    ("raw", "expected"),
    [
        (None, None),
        ("", None),
        ("auto", None),
        ("en", "en"),
        ("en-US", "en"),
        ("fr-FR", "fr"),
        ("ar", "ar"),
        ("ar-TN", "ar"),
        ("tn", "ar"),
        ("aeb", "ar"),
    ],
)
def test_language_hints(raw, expected) -> None:
    assert _normalize_language(raw) == expected


def _wav_bytes(seconds: float, rate: int = 16000) -> bytes:
    buffer = io.BytesIO()
    with wave.open(buffer, "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(rate)
        handle.writeframes(b"\x00\x00" * int(seconds * rate))
    return buffer.getvalue()


def test_estimates_wav_duration() -> None:
    assert _estimate_duration(_wav_bytes(1.5)) == pytest.approx(1.5, abs=0.01)


def test_non_wav_data_has_unknown_duration() -> None:
    assert _estimate_duration(b"not a wav file") == 0.0
    assert _estimate_duration(b"") == 0.0
