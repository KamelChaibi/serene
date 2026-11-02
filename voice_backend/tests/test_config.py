"""Configuration guards: the API must refuse to start with a public secret."""

from app.config import Settings

GOOD = "zJ3n0rB0XQ7pWc1lT9vYhKf4sAd8mEu2Rg6iOq5NtPk"


def _settings(**overrides) -> Settings:
    return Settings(**overrides)


def test_a_strong_secret_is_accepted() -> None:
    assert _settings(livekit_api_secret=GOOD).insecure_secret_reason() is None


def test_the_documented_placeholder_is_rejected() -> None:
    reason = _settings(
        livekit_api_secret="change-me-please-use-a-long-random-string"
    ).insecure_secret_reason()
    assert reason is not None
    assert "placeholder" in reason


def test_short_and_empty_secrets_are_rejected() -> None:
    for secret in ("", "secret", "devkey", "short-secret"):
        reason = _settings(livekit_api_secret=secret).insecure_secret_reason()
        assert reason is not None, secret


def test_placeholder_matching_ignores_case_and_padding() -> None:
    assert _settings(livekit_api_secret="  SECRET  ").insecure_secret_reason()


def test_just_under_the_length_floor_is_rejected() -> None:
    assert _settings(livekit_api_secret="a" * 31).insecure_secret_reason()
    assert _settings(livekit_api_secret="a" * 32).insecure_secret_reason() is None
