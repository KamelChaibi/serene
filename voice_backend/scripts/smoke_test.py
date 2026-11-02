"""End-to-end smoke test for a running Serene voice backend.

Checks, in order:

1. ``/healthz`` on the API, STT and TTS services.
2. Device enrolment and a short-lived LiveKit token.
3. The token's JWT claims (room grant + agent dispatch).
4. One TTS request per configured voice, with timing.
5. Optional STT transcription of a local audio file.

Audio is written only when ``--out-dir`` is given, and only to that directory.

    python scripts/smoke_test.py --api http://127.0.0.1:8788 \
        --tts http://127.0.0.1:8002 --stt http://127.0.0.1:8001

    python scripts/smoke_test.py --audio sample.wav --language fr
"""

from __future__ import annotations

import argparse
import base64
import json
import secrets
import sys
import time
from pathlib import Path
from typing import Any

import httpx

TTS_SAMPLES = {
    "af_heart": "Hey, I'm really glad you called. How are you doing?",
    "ff_siwis": "Coucou, je suis vraiment contente que tu appelles.",
    "silma-msa": "أهلاً، أنا سيرين. يسعدني جداً أنك اتصلت. كيف حالك الآن؟",
    "silma-derja": "أهلا، أنا سيرين. فرحانة برشة إنك عيّتت. كيفاش حالك توّا؟",
}

RESULTS: list[tuple[str, bool, str]] = []


def record(name: str, ok: bool, detail: str = "") -> None:
    RESULTS.append((name, ok, detail))
    mark = "PASS" if ok else "FAIL"
    print(f"[{mark}] {name}" + (f" — {detail}" if detail else ""))


def decode_jwt_payload(token: str) -> dict[str, Any]:
    parts = token.split(".")
    if len(parts) != 3:
        raise ValueError("token is not a JWT")
    payload = parts[1] + "=" * (-len(parts[1]) % 4)
    return json.loads(base64.urlsafe_b64decode(payload))


def check_health(client: httpx.Client, name: str, base: str) -> None:
    try:
        response = client.get(f"{base.rstrip('/')}/healthz")
        ok = response.status_code == 200
        detail = response.json().get("status", "") if ok else f"HTTP {response.status_code}"
    except Exception as exc:
        ok, detail = False, type(exc).__name__
    record(f"{name} healthz", ok, detail)


def check_token(
    client: httpx.Client, api: str, enrollment_code: str
) -> tuple[str, str] | None:
    device_id = "smoke-" + secrets.token_hex(12)
    secret = secrets.token_urlsafe(32).replace("-", "A").replace("_", "B")

    try:
        response = client.post(
            f"{api.rstrip('/')}/v1/device/enroll",
            json={
                "device_id": device_id,
                "secret": secret,
                "enrollment_code": enrollment_code,
            },
        )
        record(
            "device enrolment",
            response.status_code == 200,
            f"HTTP {response.status_code}",
        )
    except Exception as exc:
        record("device enrolment", False, type(exc).__name__)
        return None

    try:
        response = client.post(
            f"{api.rstrip('/')}/v1/voice/token",
            headers={"x-device-id": device_id, "x-device-secret": secret},
            json={
                "language": "en",
                "session": "smoke-test",
                "profile": {"name": "Smoke", "style": "friend", "length": "short"},
                "memories": ["smoke test memory"],
            },
        )
        if response.status_code != 200:
            record("token issuance", False, f"HTTP {response.status_code}")
            return None
        data = response.json()
        record("token issuance", True, f"room={data['room']}")
    except Exception as exc:
        record("token issuance", False, type(exc).__name__)
        return None

    try:
        claims = decode_jwt_payload(data["token"])
        video = claims.get("video", {})
        room_config = claims.get("roomConfig") or {}
        agents = room_config.get("agents") or []
        room_ok = video.get("room") == data["room"] and bool(video.get("roomJoin"))
        dispatch_ok = bool(agents and agents[0].get("agentName"))
        record("token room grant", room_ok)
        record("token agent dispatch", dispatch_ok)
        ttl = int(claims.get("exp", 0)) - int(claims.get("iat", 0))
        record("token is short-lived", 0 < ttl <= 900, f"ttl={ttl}s")
    except Exception as exc:
        record("token claims", False, type(exc).__name__)

    return device_id, secret


def check_tts(
    client: httpx.Client, tts: str, out_dir: Path | None, voices: list[str]
) -> None:
    for voice in voices:
        text = TTS_SAMPLES.get(voice, "Hello from Serene.")
        started = time.perf_counter()
        try:
            response = client.post(
                f"{tts.rstrip('/')}/v1/audio/speech",
                json={
                    "model": "serene-tts",
                    "input": text,
                    "voice": voice,
                    "response_format": "wav",
                    "speed": 1.0,
                },
                timeout=180.0,
            )
            elapsed = time.perf_counter() - started
            ok = response.status_code == 200 and len(response.content) > 1000
            detail = (
                f"{len(response.content) / 1024:.0f} KB in {elapsed:.2f}s"
                if ok
                else f"HTTP {response.status_code}"
            )
            record(f"tts {voice}", ok, detail)
            if ok and out_dir is not None:
                out_dir.mkdir(parents=True, exist_ok=True)
                (out_dir / f"{voice}.wav").write_bytes(response.content)
        except Exception as exc:
            record(f"tts {voice}", False, type(exc).__name__)


def check_stt(
    client: httpx.Client, stt: str, audio: Path, language: str
) -> None:
    try:
        with audio.open("rb") as handle:
            response = client.post(
                f"{stt.rstrip('/')}/v1/audio/transcriptions",
                files={"file": (audio.name, handle, "audio/wav")},
                data={"model": "whisper-1", "language": language},
                timeout=180.0,
            )
        ok = response.status_code == 200
        text = response.json().get("text", "") if ok else ""
        record("stt transcription", ok and bool(text), f"{len(text)} chars")
        if ok and text:
            # Only printed because this is a manual diagnostic run.
            print(f"       transcript: {text}")
    except Exception as exc:
        record("stt transcription", False, type(exc).__name__)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--api", default="http://127.0.0.1:8788")
    parser.add_argument("--stt", default="http://127.0.0.1:8001")
    parser.add_argument("--tts", default="http://127.0.0.1:8002")
    parser.add_argument("--enrollment-code", default="")
    parser.add_argument(
        "--voices",
        default="af_heart,ff_siwis,silma-msa,silma-derja",
        help="comma separated voice ids",
    )
    parser.add_argument("--audio", type=Path, help="local wav file for an STT check")
    parser.add_argument("--language", default="en", help="STT language hint")
    parser.add_argument(
        "--out-dir",
        type=Path,
        help="write synthesised wav files here for manual listening",
    )
    parser.add_argument("--skip-tts", action="store_true")
    args = parser.parse_args()

    voices = [voice.strip() for voice in args.voices.split(",") if voice.strip()]

    with httpx.Client(timeout=10.0) as client:
        check_health(client, "api", args.api)
        check_health(client, "stt", args.stt)
        check_health(client, "tts", args.tts)
        check_token(client, args.api, args.enrollment_code)
        if not args.skip_tts:
            check_tts(client, args.tts, args.out_dir, voices)
        if args.audio:
            check_stt(client, args.stt, args.audio, args.language)

    failed = [name for name, ok, _ in RESULTS if not ok]
    print(f"\n{len(RESULTS) - len(failed)}/{len(RESULTS)} checks passed")
    if failed:
        print("failed: " + ", ".join(failed))
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
