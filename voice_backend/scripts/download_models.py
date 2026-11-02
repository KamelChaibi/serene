"""Download every local model Serene needs into ./models.

    python scripts/download_models.py --profile low_vram

Nothing here is a paid service.  The script only pulls open weights from
Hugging Face.  Ollama models are pulled by Ollama itself (see the printed
commands at the end).

Profiles
--------
``low_vram``  Qwen3 4B + faster-whisper medium + Kokoro + SILMA MSA/Derja.
``quality``   Qwen3 8B + faster-whisper large-v3 + the same speech models.

The TTS and STT containers read from ``/models``; this script writes to
``./models`` on the host, which compose bind-mounts to the same path.
"""

from __future__ import annotations

import argparse
import shutil
import sys
from pathlib import Path

PROFILES = {
    "low_vram": {
        "whisper_repo": "Systran/faster-whisper-medium",
        "whisper_dir": "faster-whisper/medium",
        "ollama_model": "qwen3:4b",
    },
    "quality": {
        "whisper_repo": "Systran/faster-whisper-large-v3",
        "whisper_dir": "faster-whisper/large-v3",
        "ollama_model": "qwen3:8b",
    },
}

SILMA_MODELS = {
    "silma-msa": ("silma-ai/silma-tts", ["config.yaml", "vocab.txt", "model.pt"]),
    "silma-derja": (
        "Ghazouaniwala/silma-tts-derja",
        ["config.yaml", "vocab.txt", "model.pt"],
    ),
}


def _human(size: int) -> str:
    value = float(size)
    for unit in ("B", "KB", "MB", "GB"):
        if value < 1024 or unit == "GB":
            return f"{value:.1f} {unit}"
        value /= 1024
    return f"{value:.1f} GB"


def _require_huggingface() -> None:
    try:
        import huggingface_hub  # noqa: F401
    except Exception:
        print(
            "huggingface_hub is missing.  Install it with:\n"
            "    pip install huggingface_hub",
            file=sys.stderr,
        )
        raise SystemExit(2)


def download_silma(models_dir: Path, name: str, repo: str, files: list[str]) -> None:
    from huggingface_hub import hf_hub_download

    target = models_dir / name
    target.mkdir(parents=True, exist_ok=True)
    print(f"\n== {name} ({repo}) ==")
    for filename in files:
        destination = target / filename
        if destination.exists() and destination.stat().st_size > 0:
            print(f"   {filename}: already present ({_human(destination.stat().st_size)})")
            continue
        print(f"   {filename}: downloading…")
        cached = hf_hub_download(repo_id=repo, filename=filename)
        shutil.copy2(cached, destination)
        print(f"   {filename}: {_human(destination.stat().st_size)}")


def download_kokoro(models_dir: Path) -> None:
    from huggingface_hub import snapshot_download

    target = models_dir / "kokoro"
    target.mkdir(parents=True, exist_ok=True)
    print("\n== kokoro (hexgrad/Kokoro-82M) ==")
    snapshot_download(
        repo_id="hexgrad/Kokoro-82M",
        local_dir=str(target),
        allow_patterns=["*.json", "*.pth", "*.pt", "voices/*.pt", "voices/*.bin"],
    )
    total = sum(p.stat().st_size for p in target.rglob("*") if p.is_file())
    print(f"   {_human(total)} in {target}")


def download_whisper(models_dir: Path, repo: str, subdir: str) -> Path:
    from huggingface_hub import snapshot_download

    target = models_dir / subdir
    target.mkdir(parents=True, exist_ok=True)
    print(f"\n== faster-whisper ({repo}) ==")
    snapshot_download(
        repo_id=repo,
        local_dir=str(target),
        allow_patterns=["*.bin", "*.json", "*.txt", "*.md"],
    )
    total = sum(p.stat().st_size for p in target.rglob("*") if p.is_file())
    print(f"   {_human(total)} in {target}")
    return target


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--profile",
        choices=sorted(PROFILES),
        default="low_vram",
        help="model size profile (default: low_vram)",
    )
    parser.add_argument(
        "--models-dir",
        default="models",
        help="destination directory (default: ./models)",
    )
    parser.add_argument("--skip-silma", action="store_true", help="skip Arabic TTS")
    parser.add_argument("--skip-kokoro", action="store_true", help="skip en/fr TTS")
    parser.add_argument("--skip-whisper", action="store_true", help="skip STT")
    args = parser.parse_args()

    _require_huggingface()
    models_dir = Path(args.models_dir).expanduser().resolve()
    models_dir.mkdir(parents=True, exist_ok=True)
    profile = PROFILES[args.profile]

    print(f"models directory: {models_dir}")
    print(f"profile: {args.profile}")

    if not args.skip_whisper:
        download_whisper(
            models_dir, profile["whisper_repo"], profile["whisper_dir"]
        )

    if not args.skip_kokoro:
        download_kokoro(models_dir)

    if not args.skip_silma:
        for name, (repo, files) in SILMA_MODELS.items():
            download_silma(models_dir, name, repo, files)

    print("\n== Ollama model ==")
    print("   Run this once, on the host or in the container:")
    print(f"       docker compose exec ollama ollama pull {profile['ollama_model']}")
    print("\nPoint the backend at the downloaded files:")
    print(f"   STT_MODEL_NAME=/models/{profile['whisper_dir']}")
    print(f"   OLLAMA_MODEL={profile['ollama_model']}")
    print("\nDone.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
