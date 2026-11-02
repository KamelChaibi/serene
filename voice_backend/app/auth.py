"""Per-install device enrolment.

The Flutter app has no user accounts.  On first use it generates a random
device id and a 32-byte secret, keeps both in Android Keystore-backed secure
storage, and enrols once.  The server stores only ``sha256(secret)``.

This is deliberately *device* authentication, not a user identity: anyone with
physical access to an unlocked phone can start a call.  It exists to stop
anonymous internet clients from minting LiveKit tokens, not to identify people.
"""

from __future__ import annotations

import hashlib
import hmac
import re
import secrets
import sqlite3
import threading
import time
from dataclasses import dataclass
from pathlib import Path

_DEVICE_ID_RE = re.compile(r"^[A-Za-z0-9_-]{16,64}$")
_SECRET_RE = re.compile(r"^[A-Za-z0-9_\-]{32,128}$")

_SCHEMA = """
CREATE TABLE IF NOT EXISTS devices (
    device_id    TEXT PRIMARY KEY,
    secret_hash  TEXT NOT NULL,
    created_at   INTEGER NOT NULL,
    last_seen_at INTEGER NOT NULL,
    disabled     INTEGER NOT NULL DEFAULT 0
);
CREATE INDEX IF NOT EXISTS idx_devices_seen ON devices(last_seen_at);
"""


class AuthError(Exception):
    """Raised for any authentication failure.  The message is safe to return."""

    def __init__(self, message: str, status_code: int = 401) -> None:
        super().__init__(message)
        self.message = message
        self.status_code = status_code


def hash_secret(secret: str) -> str:
    return hashlib.sha256(secret.encode("utf-8")).hexdigest()


def validate_credentials(device_id: str, secret: str) -> None:
    if not _DEVICE_ID_RE.match(device_id or ""):
        raise AuthError("invalid device id", 400)
    if not _SECRET_RE.match(secret or ""):
        raise AuthError("invalid device secret", 400)


@dataclass(frozen=True)
class Device:
    device_id: str
    created_at: int
    last_seen_at: int


class DeviceStore:
    """Small SQLite store with one connection per operation.

    SQLite is enough for a self-hosted companion app.  If you run more than one
    API replica, put the database on shared storage or replace this class with
    Postgres; the rest of the service only calls the methods below.
    """

    def __init__(self, db_path: Path) -> None:
        self._db_path = db_path
        # Re-entrant: enroll() reads the device count while holding the lock.
        self._lock = threading.RLock()
        self._db_path.parent.mkdir(parents=True, exist_ok=True)
        with self._connect() as conn:
            conn.executescript(_SCHEMA)

    def _connect(self) -> sqlite3.Connection:
        conn = sqlite3.connect(self._db_path, timeout=10)
        conn.row_factory = sqlite3.Row
        conn.execute("PRAGMA journal_mode=WAL")
        conn.execute("PRAGMA foreign_keys=ON")
        return conn

    def count(self) -> int:
        with self._lock, self._connect() as conn:
            row = conn.execute("SELECT COUNT(*) AS n FROM devices").fetchone()
            return int(row["n"])

    def enroll(self, device_id: str, secret: str, max_devices: int) -> Device:
        validate_credentials(device_id, secret)
        digest = hash_secret(secret)
        now = int(time.time())

        with self._lock, self._connect() as conn:
            row = conn.execute(
                "SELECT secret_hash, created_at, last_seen_at, disabled FROM devices WHERE device_id = ?",
                (device_id,),
            ).fetchone()

            if row is not None:
                if row["disabled"]:
                    raise AuthError("device disabled", 403)
                if not hmac.compare_digest(row["secret_hash"], digest):
                    raise AuthError("device secret does not match", 401)
                conn.execute(
                    "UPDATE devices SET last_seen_at = ? WHERE device_id = ?",
                    (now, device_id),
                )
                return Device(device_id, int(row["created_at"]), now)

            total = conn.execute("SELECT COUNT(*) AS n FROM devices").fetchone()
            if int(total["n"]) >= max_devices:
                raise AuthError("device limit reached", 403)
            conn.execute(
                "INSERT INTO devices (device_id, secret_hash, created_at, last_seen_at) "
                "VALUES (?, ?, ?, ?)",
                (device_id, digest, now, now),
            )
            return Device(device_id, now, now)

    def authenticate(self, device_id: str, secret: str) -> Device:
        validate_credentials(device_id, secret)
        digest = hash_secret(secret)

        with self._lock, self._connect() as conn:
            row = conn.execute(
                "SELECT secret_hash, created_at, last_seen_at, disabled FROM devices WHERE device_id = ?",
                (device_id,),
            ).fetchone()
            if row is None:
                raise AuthError("unknown device", 401)
            if row["disabled"]:
                raise AuthError("device disabled", 403)
            if not hmac.compare_digest(row["secret_hash"], digest):
                raise AuthError("device secret does not match", 401)

            now = int(time.time())
            conn.execute(
                "UPDATE devices SET last_seen_at = ? WHERE device_id = ?",
                (now, device_id),
            )
            return Device(device_id, int(row["created_at"]), now)


class AttemptLimiter:
    """In-memory sliding-window limiter for enrolment attempts.

    A single API process is the normal deployment.  With several replicas this
    becomes per-replica, which is still useful as a brute-force speed bump.
    """

    def __init__(self, window_seconds: int, max_attempts: int) -> None:
        self._window = window_seconds
        self._max = max_attempts
        self._hits: dict[str, list[float]] = {}
        self._lock = threading.Lock()

    def allow(self, key: str) -> bool:
        now = time.monotonic()
        with self._lock:
            bucket = [t for t in self._hits.get(key, []) if now - t < self._window]
            if len(bucket) >= self._max:
                self._hits[key] = bucket
                return False
            bucket.append(now)
            self._hits[key] = bucket
            return True


def new_room_name() -> str:
    return f"serene-{secrets.token_hex(8)}"


def public_identity(device_id: str) -> str:
    """Do not expose the raw device id in LiveKit analytics."""
    return "user-" + hashlib.sha256(device_id.encode("utf-8")).hexdigest()[:16]
