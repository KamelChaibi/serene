#!/usr/bin/env python3
"""Fail when source files contain something that looks like a leaked credential.

Usage:
    python scripts/check_secrets.py

The scan covers text files in the working tree. It deliberately skips local
``.env`` files (they are expected to hold real values and must stay untracked),
build output, model weights, and other binary assets. It does not scan Git
history: a key that was committed once survives a working-tree cleanup.

Exit status is 1 when a finding is reported, 0 when the tree is clean.
"""

from __future__ import annotations

import os
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SKIP_DIR_NAMES = {
    ".git",
    ".dart_tool",
    ".gradle",
    ".idea",
    ".pub-cache",
    ".pytest_cache",
    ".vscode",
    "__pycache__",
    "build",
    "coverage",
    "node_modules",
}
SKIP_DIR_PATHS = {
    ".venv",
    "venv",
    "voice_backend/.venv",
    "voice_backend/data",
    "voice_backend/models",
    "voice_backend/smoke-audio",
}
SKIP_SUFFIXES = {
    ".7z",
    ".aab",
    ".apk",
    ".bin",
    ".db",
    ".dill",
    ".dll",
    ".exe",
    ".gif",
    ".gz",
    ".ico",
    ".ipa",
    ".jpeg",
    ".jpg",
    ".m4a",
    ".mp3",
    ".ogg",
    ".onnx",
    ".otf",
    ".pdf",
    ".png",
    ".pt",
    ".safetensors",
    ".snapshot",
    ".so",
    ".sqlite",
    ".tar",
    ".ttf",
    ".wav",
    ".webp",
    ".woff",
    ".woff2",
    ".zip",
}
SKIP_FILES = {
    Path(__file__).resolve(),
    (ROOT / ".gitignore").resolve(),
}
MAX_BYTES = 2 * 1024 * 1024

# Values used in examples and tests are not credentials.
ALLOWED_FRAGMENTS = (
    "...",
    "change-me",
    "changeme",
    "devkey",
    "dummy",
    "example",
    "fake",
    "local-stt",
    "local-tts",
    "not-a-real",
    "ollama",
    "placeholder",
    "test-secret",
    "your-key-here",
    "your_key_here",
)

# (label, compiled pattern, group that holds the candidate value)
RULES = (
    (
        "OpenRouter key",
        re.compile(r"sk-or-v1-[A-Za-z0-9]{20,}"),
        0,
    ),
    (
        "Anthropic key",
        re.compile(r"sk-ant-[A-Za-z0-9_-]{20,}"),
        0,
    ),
    (
        "OpenAI project key",
        re.compile(r"sk-proj-[A-Za-z0-9_-]{20,}"),
        0,
    ),
    (
        "Google API key",
        re.compile(r"AIza[0-9A-Za-z_-]{35}"),
        0,
    ),
    (
        "AWS access key",
        re.compile(r"AKIA[0-9A-Z]{16}"),
        0,
    ),
    (
        "GitHub token",
        re.compile(r"gh[pousr]_[A-Za-z0-9]{36,}"),
        0,
    ),
    (
        "Slack token",
        re.compile(r"xox[baprs]-[A-Za-z0-9-]{10,}"),
        0,
    ),
    (
        "Stripe live key",
        re.compile(r"[rs]k_live_[0-9A-Za-z]{24,}"),
        0,
    ),
    (
        "JWT",
        re.compile(r"eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}"),
        0,
    ),
    (
        "private key",
        re.compile(r"-----BEGIN (?:RSA |EC |OPENSSH |DSA |PGP )?PRIVATE KEY-----"),
        0,
    ),
    (
        "hardcoded credential",
        re.compile(
            r"(?ix)\b(?:api[_-]?key|apikey|client[_-]?secret|secret|"
            r"access[_-]?token|auth[_-]?token|password|passwd)\b"
            r"\s*[:=]\s*['\"]([^'\"\n]{16,})['\"]"
        ),
        1,
    ),
    (
        "environment assignment",
        re.compile(
            r"(?im)^\s*(?:OPENROUTER_API_KEY|OPENAI_API_KEY|ANTHROPIC_API_KEY|"
            r"LIVEKIT_API_SECRET|SERENE_ENROLLMENT_CODE|AWS_SECRET_ACCESS_KEY)"
            r"\s*=\s*([^\s#]{12,})\s*$"
        ),
        1,
    ),
)


def _is_allowed(value: str) -> bool:
    lowered = value.lower()
    if any(fragment in lowered for fragment in ALLOWED_FRAGMENTS):
        return True
    if value.startswith(("<", "$", "{")):
        return True
    if len(set(value)) < 6:
        return True
    return False


def _iter_files():
    for dirpath, dirnames, filenames in os.walk(ROOT):
        rel_dir = Path(dirpath).relative_to(ROOT).as_posix()
        kept = []
        for name in dirnames:
            rel = name if rel_dir == "." else f"{rel_dir}/{name}"
            if name in SKIP_DIR_NAMES or rel in SKIP_DIR_PATHS:
                continue
            kept.append(name)
        dirnames[:] = kept

        for name in filenames:
            if name == ".env" or (name.startswith(".env.") and name != ".env.example"):
                continue
            path = Path(dirpath) / name
            if path.resolve() in SKIP_FILES or path.suffix.lower() in SKIP_SUFFIXES:
                continue
            try:
                if path.stat().st_size > MAX_BYTES:
                    continue
                data = path.read_bytes()
            except OSError:
                continue
            if b"\0" in data[:8192]:
                continue
            yield path, data.decode("utf-8", errors="replace")


def scan_working_tree() -> int:
    findings = 0
    for path, text in _iter_files():
        rel = path.relative_to(ROOT).as_posix()
        for lineno, line in enumerate(text.splitlines(), 1):
            for label, pattern, group in RULES:
                match = pattern.search(line)
                if not match:
                    continue
                value = match.group(group)
                if _is_allowed(value):
                    continue
                print(f"{rel}:{lineno}: {label} -> <redacted>")
                findings += 1
    return findings


def main() -> int:
    findings = scan_working_tree()
    if findings:
        print(
            f"\n{findings} potential secret(s) found. Remove them, rotate the "
            "credential, and keep the real value in an untracked .env file.",
            file=sys.stderr,
        )
        return 1
    print("No credential-looking strings found in tracked source files.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
