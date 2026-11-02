"""Personality file and prompt-builder tests."""

from pathlib import Path

import pytest

from app.prompts import (
    PromptError,
    build_instructions,
    load_personality,
    normalize_language,
)

PROMPT_FILE = Path(__file__).resolve().parents[1] / "prompts" / "serene_friend.yaml"


@pytest.fixture(scope="module")
def personality():
    return load_personality(PROMPT_FILE)


def test_all_languages_present(personality) -> None:
    assert set(personality.languages) == {"en", "fr", "ar", "tn"}
    for profile in personality.languages.values():
        assert profile.directive
        assert profile.greeting
        assert profile.greeting_anonymous
        assert profile.safety_line


def test_greeting_uses_name_when_given(personality) -> None:
    assert "Sami" in personality.greeting("en", "Sami")
    assert "Sami" not in personality.greeting("en", "")


@pytest.mark.parametrize(
    ("raw", "expected"),
    [
        ("en", "en"),
        ("en-US", "en"),
        ("fr", "fr"),
        ("fr-FR", "fr"),
        ("ar", "ar"),
        ("ar-TN", "tn"),
        ("tn", "tn"),
        ("aeb", "tn"),
        ("AR_tn", "tn"),
        ("de", "en"),
        ("", "en"),
        (None, "en"),
    ],
)
def test_normalize_language(raw, expected) -> None:
    assert normalize_language(raw) == expected


def test_instructions_include_profile_and_memories(personality) -> None:
    prompt = build_instructions(
        personality,
        language="fr",
        profile={
            "name": "Ines",
            "age": 29,
            "style": "warm",
            "length": "short",
            "focuses": ["anxiety", "sleep"],
            "in_therapy": True,
            "notes": "Exams next week",
        },
        memories=["Plays the oud", "Has a cat called Minou"],
    )
    assert "Ines" in prompt
    assert "29" in prompt
    assert "Exams next week" in prompt
    assert "Plays the oud" in prompt
    assert "therapist" in prompt
    assert "Language: French" in prompt
    assert "/no_think" in prompt


def test_instructions_bound_hostile_input(personality) -> None:
    prompt = build_instructions(
        personality,
        language="en",
        profile={"name": "x" * 5000, "notes": "y" * 5000, "age": 900},
        memories=["z" * 5000] * 100,
        max_memories=3,
        max_memory_chars=50,
        max_notes_chars=80,
    )
    assert "x" * 200 not in prompt
    assert "y" * 200 not in prompt
    assert prompt.count("z" * 50) <= 3
    assert "900 years old" not in prompt


def test_instructions_ignore_unknown_profile_values(personality) -> None:
    prompt = build_instructions(
        personality,
        language="en",
        profile={"style": "manipulative", "length": "endless", "focuses": ["nonsense"]},
    )
    assert "manipulative" not in prompt
    assert "endless" not in prompt


def test_missing_file_is_a_clear_error(tmp_path: Path) -> None:
    with pytest.raises(PromptError):
        load_personality(tmp_path / "nope.yaml")


def test_bad_yaml_is_a_clear_error(tmp_path: Path) -> None:
    path = tmp_path / "bad.yaml"
    path.write_text("identity: [unclosed", encoding="utf-8")
    with pytest.raises(PromptError):
        load_personality(path)
