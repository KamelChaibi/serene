"""First-line crisis detection.

This is intentionally a transparent, local, rule-based detector.  It runs on
the final transcript before the LLM answers, so a distressed caller gets a
human-help message and the hotline sheet instead of an improvised reply.

It is *not* a clinical classifier and it will miss indirect signals.  The app
keeps its own on-device detector and the UI always offers an emergency button.
"""

from __future__ import annotations

import re
import unicodedata
from dataclasses import dataclass

# Patterns are intentionally phrase-level to reduce false positives on words
# like "suicide" used in a film review.  Both Arabic script and Arabizi
# (Latin-script Tunisian) are covered.
_PATTERNS: tuple[re.Pattern[str], ...] = tuple(
    re.compile(pattern, re.IGNORECASE | re.UNICODE)
    for pattern in (
        # English
        r"\b(?:i(?:'m| am)? (?:going to|gonna|want to|wanna) )?(?:kill|hurt) myself\b",
        r"\bi (?:want|wanna|need) to die\b",
        r"\bi(?:'m| am) (?:suicidal|going to end (?:my life|it all))\b",
        r"\bend (?:my life|it all)\b",
        r"\b(?:commit|committing) suicide\b",
        r"\bkill myself\b",
        r"\b(?:cut|cutting|harm|harming|hurt|hurting|burn|burning) myself\b",
        r"\bself[- ]harm\b",
        r"\b(?:take|took) (?:an|a) overdose\b",
        r"\bno (?:reason|point) (?:to|in) (?:live|living|life)\b",
        r"\bbetter off (?:dead|without me)\b",
        # French
        r"\b(?:me|m') ?(?:suicider|tuer)\b",
        r"\bje (?:veux|voudrais) (?:mourir|en finir)\b",
        r"\ben finir avec (?:la vie|moi)\b",
        r"\bmettre fin à (?:mes jours|ma vie)\b",
        r"\b(?:me faire|me couper|me brûler|me blesser)\b",
        r"\bautomutilation\b",
        r"\bplus envie de vivre\b",
        r"\b(?:je serais|je suis) mieux mort\b",
        # Arabic (MSA and dialect spellings)
        r"انتحر|الانتحار|أنتحر",
        r"أنهي حياتي|انهي حياتي|أقتل نفسي|اقتل نفسي",
        r"أريد أن أموت|اريد ان اموت|أريد الموت|بدي موت",
        r"أؤذي نفسي|اؤذي نفسي|أجرح نفسي|اجرح نفسي|أضر نفسي",
        r"لا أريد العيش|ما عنديش سبب نعيش|ما فماش سبب نعيش",
        r"خير لي نموت|خيرلي نموت|نحب نموت|بش نقتل روحي",
        r"نأذي روحي|نجرح روحي|نقطع روحي",
        # Arabizi / French-influenced Derja
        r"\bn7eb nmout\b",
        r"\b(?:bech|bch) (?:n9tel|ne9tel) rouhi\b",
        r"\b(?:n9atel|n9tel) rouhi\b",
        r"\bje veux mourir\b",
    )
)


@dataclass(frozen=True)
class CrisisVerdict:
    is_crisis: bool
    matched: str = ""


def _normalize(text: str) -> str:
    text = unicodedata.normalize("NFKC", text or "")
    # Strip Arabic diacritics and tatweel so vowelized text still matches.
    text = re.sub(r"[\u064B-\u0652\u0670\u0640]", "", text)
    text = re.sub(r"\s+", " ", text)
    return text.strip()


def detect_crisis(text: str) -> CrisisVerdict:
    normalized = _normalize(text)
    if not normalized:
        return CrisisVerdict(False)
    for pattern in _PATTERNS:
        match = pattern.search(normalized)
        if match:
            return CrisisVerdict(True, match.group(0))
    return CrisisVerdict(False)
