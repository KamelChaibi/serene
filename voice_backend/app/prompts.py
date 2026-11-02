"""Load the personality file and build a per-call system prompt."""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Any, Mapping

import yaml

SUPPORTED_LANGUAGES = ("en", "fr", "ar", "tn")


class PromptError(RuntimeError):
    pass


@dataclass(frozen=True)
class LanguageProfile:
    code: str
    name: str
    directive: str
    greeting: str
    greeting_anonymous: str
    safety_line: str


@dataclass(frozen=True)
class Personality:
    identity: str
    rules: list[str]
    languages: dict[str, LanguageProfile]
    styles: dict[str, str]
    lengths: dict[str, str]
    focuses: dict[str, str]

    def language(self, code: str) -> LanguageProfile:
        normalized = normalize_language(code)
        return self.languages.get(normalized) or self.languages["en"]

    def greeting(self, code: str, name: str = "") -> str:
        profile = self.language(code)
        template = profile.greeting if name.strip() else profile.greeting_anonymous
        return template.replace("{name}", name.strip())


def normalize_language(code: str | None) -> str:
    """Map app locales and Whisper hints onto the four supported profiles."""
    if not code:
        return "en"
    value = code.strip().lower().replace("_", "-")
    if value.startswith("ar-tn") or value in {"tn", "aeb", "derja", "tunisian"}:
        return "tn"
    if value.startswith("ar"):
        return "ar"
    if value.startswith("fr"):
        return "fr"
    if value.startswith("en"):
        return "en"
    return "en"


def load_personality(path: Path) -> Personality:
    if not path.exists():
        raise PromptError(f"prompt file not found: {path}")

    try:
        raw = yaml.safe_load(path.read_text(encoding="utf-8"))
    except yaml.YAMLError as exc:  # pragma: no cover - configuration error
        raise PromptError(f"prompt file is not valid YAML: {exc}") from exc

    if not isinstance(raw, Mapping):
        raise PromptError("prompt file must contain a mapping")

    identity = str(raw.get("identity") or "").strip()
    rules = [str(item).strip() for item in raw.get("rules") or [] if str(item).strip()]
    if not identity or not rules:
        raise PromptError("prompt file needs `identity` and `rules`")

    languages: dict[str, LanguageProfile] = {}
    for code, data in (raw.get("languages") or {}).items():
        if not isinstance(data, Mapping):
            continue
        languages[code] = LanguageProfile(
            code=code,
            name=str(data.get("name") or code),
            directive=str(data.get("directive") or "").strip(),
            greeting=str(data.get("greeting") or "").strip(),
            greeting_anonymous=str(data.get("greeting_anonymous") or "").strip(),
            safety_line=str(data.get("safety_line") or "").strip(),
        )

    missing = [code for code in SUPPORTED_LANGUAGES if code not in languages]
    if missing:
        raise PromptError(f"prompt file is missing languages: {', '.join(missing)}")

    profile = raw.get("profile") or {}
    styles = {str(k): str(v) for k, v in (profile.get("styles") or {}).items()}
    lengths = {str(k): str(v) for k, v in (profile.get("lengths") or {}).items()}
    focuses = {str(k): str(v) for k, v in (profile.get("focus") or {}).items()}

    return Personality(
        identity=identity,
        rules=rules,
        languages=languages,
        styles=styles,
        lengths=lengths,
        focuses=focuses,
    )


def _clean(value: Any, limit: int) -> str:
    if not isinstance(value, str):
        return ""
    return " ".join(value.split())[:limit]


def build_instructions(
    personality: Personality,
    *,
    language: str,
    profile: Mapping[str, Any] | None = None,
    memories: list[str] | None = None,
    max_memories: int = 20,
    max_memory_chars: int = 280,
    max_notes_chars: int = 500,
) -> str:
    """Build the per-call system prompt.

    Profile and memories come from the phone and are already user-controlled.
    They are bounded here so a malformed client cannot inflate the prompt.
    """
    profile = profile or {}
    lang = personality.language(language)

    lines: list[str] = [personality.identity, "", "Rules:"]
    lines.extend(f"- {rule}" for rule in personality.rules)
    lines.extend(
        [
            "",
            f"Language: {lang.name}.",
            lang.directive,
            "If the caller switches to another language you understand, follow them "
            "instead of forcing this one.",
        ]
    )

    details: list[str] = []
    name = _clean(profile.get("name"), 60)
    if name:
        details.append(f"- Their preferred name is {name}. Use it rarely.")
    age = profile.get("age")
    if isinstance(age, int) and 13 <= age <= 120:
        details.append(f"- They are {age} years old.")
    style = _clean(profile.get("style"), 20)
    if style and style in personality.styles:
        details.append(f"- {personality.styles[style]}")
    length = _clean(profile.get("length"), 20)
    if length and length in personality.lengths:
        details.append(f"- {personality.lengths[length]}")

    focuses = profile.get("focuses")
    if isinstance(focuses, list):
        notes = [
            personality.focuses[item]
            for item in focuses
            if isinstance(item, str) and item in personality.focuses
        ]
        details.extend(f"- {note}" for note in notes[:8])

    if profile.get("in_therapy") is True:
        details.append(
            "- They already have a therapist or counsellor. Support that work; never replace it."
        )

    notes = _clean(profile.get("notes"), max_notes_chars)
    if notes:
        details.append(f"- They asked you to keep this in mind: {notes}")

    if details:
        lines.extend(["", "About this person:", *details])

    if memories:
        cleaned = [
            _clean(memory, max_memory_chars)
            for memory in memories[:max_memories]
            if isinstance(memory, str) and memory.strip()
        ]
        cleaned = [memory for memory in cleaned if memory]
        if cleaned:
            lines.extend(
                [
                    "",
                    "Things they chose to remember from earlier conversations:",
                    *[f"- {memory}" for memory in cleaned],
                    "Use these only if they are relevant. Do not recite them.",
                ]
            )

    lines.extend(
        [
            "",
            "This is a live voice call. The caller hears you through a speaker.",
            "Start by responding to what they actually said, not with a script.",
            "Do not produce text that only makes sense on a screen.",
        ]
    )

    # Qwen3 honours a soft `/no_think` switch.  Thinking tokens add seconds of
    # latency and are never spoken, so keep them out of the voice path.
    lines.append("/no_think")
    return "\n".join(lines).strip()
