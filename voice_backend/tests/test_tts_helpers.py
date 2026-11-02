"""TTS server helpers: text cleanup and PCM encoding."""

import io
import wave

import numpy as np

from app.tts_server import _clean_text, to_pcm16, to_wav


def test_clean_text_removes_markup() -> None:
    assert _clean_text("**hi** _there_ `now`") == "hi there now"
    assert _clean_text("# Heading\n\nBody") == "Heading Body"


def test_clean_text_collapses_whitespace() -> None:
    assert _clean_text("  a \n\t b  ") == "a b"
    assert _clean_text("") == ""


def test_pcm_is_little_endian_int16() -> None:
    samples = np.array([0.0, 0.5, -0.5, 1.0, -1.0], dtype=np.float32)
    data = to_pcm16(samples)
    assert len(data) == 10
    values = np.frombuffer(data, dtype="<i2")
    assert values[0] == 0
    assert values[1] == 16383
    assert values[2] == -16383
    assert values[3] == 32767
    assert values[4] == -32767


def test_pcm_clips_out_of_range_samples() -> None:
    data = to_pcm16(np.array([4.0, -4.0], dtype=np.float32))
    values = np.frombuffer(data, dtype="<i2")
    assert values[0] == 32767
    assert values[1] == -32767


def test_empty_audio_is_empty_bytes() -> None:
    assert to_pcm16(np.zeros(0, dtype=np.float32)) == b""


def test_wav_round_trip() -> None:
    samples = np.zeros(2400, dtype=np.float32)
    data = to_wav(samples, 24000)
    with wave.open(io.BytesIO(data), "rb") as handle:
        assert handle.getnchannels() == 1
        assert handle.getsampwidth() == 2
        assert handle.getframerate() == 24000
        assert handle.getnframes() == 2400
