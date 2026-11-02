"""Device enrolment, authentication and rate limiting."""

from pathlib import Path

import pytest

from app.auth import (
    AttemptLimiter,
    AuthError,
    DeviceStore,
    hash_secret,
    public_identity,
    validate_credentials,
)

DEVICE = "device-0123456789abcdef"
SECRET = "s" * 40


@pytest.fixture()
def store(tmp_path: Path) -> DeviceStore:
    return DeviceStore(tmp_path / "devices.sqlite3")


def test_hash_is_stable_and_not_the_secret() -> None:
    assert hash_secret(SECRET) == hash_secret(SECRET)
    assert SECRET not in hash_secret(SECRET)


@pytest.mark.parametrize("device_id", ["", "short", "has spaces in it", "a" * 65])
def test_rejects_bad_device_ids(device_id: str) -> None:
    with pytest.raises(AuthError):
        validate_credentials(device_id, SECRET)


@pytest.mark.parametrize("secret", ["", "short", "x" * 129, "has spaces " * 5])
def test_rejects_bad_secrets(secret: str) -> None:
    with pytest.raises(AuthError):
        validate_credentials(DEVICE, secret)


def test_enroll_then_authenticate(store: DeviceStore) -> None:
    device = store.enroll(DEVICE, SECRET, max_devices=10)
    assert device.device_id == DEVICE
    assert store.count() == 1

    again = store.authenticate(DEVICE, SECRET)
    assert again.device_id == DEVICE


def test_re_enrolling_with_the_same_secret_is_idempotent(store: DeviceStore) -> None:
    store.enroll(DEVICE, SECRET, max_devices=10)
    store.enroll(DEVICE, SECRET, max_devices=10)
    assert store.count() == 1


def test_enrolling_an_existing_id_with_another_secret_fails(store: DeviceStore) -> None:
    store.enroll(DEVICE, SECRET, max_devices=10)
    with pytest.raises(AuthError):
        store.enroll(DEVICE, "d" * 40, max_devices=10)


def test_unknown_device_is_rejected(store: DeviceStore) -> None:
    with pytest.raises(AuthError):
        store.authenticate(DEVICE, SECRET)


def test_device_limit(store: DeviceStore) -> None:
    store.enroll(DEVICE, SECRET, max_devices=1)
    with pytest.raises(AuthError):
        store.enroll("device-fedcba9876543210", SECRET, max_devices=1)


def test_disabled_device_cannot_authenticate(store: DeviceStore) -> None:
    store.enroll(DEVICE, SECRET, max_devices=10)
    import sqlite3

    with sqlite3.connect(store._db_path) as conn:
        conn.execute("UPDATE devices SET disabled = 1 WHERE device_id = ?", (DEVICE,))

    with pytest.raises(AuthError):
        store.authenticate(DEVICE, SECRET)


def test_identity_does_not_leak_the_device_id() -> None:
    identity = public_identity(DEVICE)
    assert DEVICE not in identity
    assert identity.startswith("user-")


def test_limiter_blocks_after_the_budget() -> None:
    limiter = AttemptLimiter(window_seconds=60, max_attempts=2)
    assert limiter.allow("1.2.3.4")
    assert limiter.allow("1.2.3.4")
    assert not limiter.allow("1.2.3.4")
    # A different client is unaffected.
    assert limiter.allow("5.6.7.8")
