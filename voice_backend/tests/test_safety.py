"""Crisis detector tests.

The detector is a transparent safety net, not a classifier.  These tests pin
the phrases it must catch and a few it must not, in all four languages.
"""

import pytest

from app.safety import detect_crisis


@pytest.mark.parametrize(
    "text",
    [
        "I want to kill myself",
        "I'm going to end my life tonight",
        "I've been cutting myself again",
        "honestly I'd be better off dead",
        "there is no reason to live anymore",
        "je veux mourir",
        "j'ai envie d'en finir avec la vie",
        "je me suis fait du mal, automutilation",
        "أريد أن أموت",
        "أفكر في الانتحار",
        "أؤذي نفسي كل ليلة",
        "نحب نموت، ما فماش سبب نعيش",
        "بش نقتل روحي",
        "n7eb nmout",
        "bech n9tel rouhi",
    ],
)
def test_detects_crisis_phrases(text: str) -> None:
    assert detect_crisis(text).is_crisis


@pytest.mark.parametrize(
    "text",
    [
        "",
        "I watched a film about suicide prevention last night",
        "my back hurts and I want to sleep",
        "je suis fatigué mais ça va",
        "أنا تعبان شوية، نروح نرقد",
        "hello, how are you?",
    ],
)
def test_ignores_ordinary_speech(text: str) -> None:
    assert not detect_crisis(text).is_crisis


def test_strips_arabic_diacritics() -> None:
    # Vowelized spelling must still match the undiacritized pattern.
    assert detect_crisis("أُرِيدُ أَنْ أَمُوت").is_crisis


def test_reports_the_matched_phrase() -> None:
    verdict = detect_crisis("I want to kill myself")
    assert verdict.is_crisis
    assert "kill myself" in verdict.matched
