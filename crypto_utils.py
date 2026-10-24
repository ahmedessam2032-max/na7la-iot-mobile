"""
Na7la IoT Cryptographic Core & Zero-Knowledge Security Utilities
- AES-256-GCM authenticated encryption at rest (SQLAlchemy TypeDecorator)
- HMAC-SHA256 domain-separated blind indexing (MAC, Email, Invite, Webhook)
- Irreversible HMAC-SHA256 OTP hashing
- Privacy log masking (MAC / IP / Email)
- Thread-safe sliding-window Brute-Force RateLimiter
"""
import base64
import hashlib
import hmac
import json
import os
import re
import secrets
import threading
import time
from pathlib import Path
from typing import Optional

from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from fastapi import HTTPException
from sqlalchemy.types import TypeDecorator, Text

LEGACY_DEFAULT_SECRET = "na7la_iot_super_secret_master_key_2026"
CIPHERTEXT_PREFIX = "enc:v1:"
AAD_CONTEXT = b"na7la-iot-aes256gcm-v1"


def _resolve_key_store_path() -> Path:
    data_dir = Path("/app/data")
    if data_dir.exists() and data_dir.is_dir():
        return data_dir / ".encryption_keys.json"
    return Path(__file__).parent / ".encryption_keys.json"


def load_or_create_master_keys() -> dict[str, str]:
    """
    تحميل مفاتيح التشفير الإنتاجية (256-bit) من متغيرات البيئة أو توليدها وحفظها بأمان خارج الكود.
    لا يتم أبداً استخدام مفتاح افتراضي مكشوف في الكود المصدري.
    """
    env_secret = os.getenv("SECRET_KEY", "").strip()
    env_enc = os.getenv("DATA_ENCRYPTION_KEY", "").strip()
    env_blind = os.getenv("BLIND_INDEX_KEY", "").strip()

    if env_secret == LEGACY_DEFAULT_SECRET:
        env_secret = ""

    key_file = _resolve_key_store_path()
    stored: dict[str, str] = {}
    if key_file.exists():
        try:
            stored = json.loads(key_file.read_text(encoding="utf-8"))
        except Exception:
            stored = {}

    changed = False
    secret_key = env_secret or stored.get("secret_key") or ""
    if not secret_key:
        secret_key = secrets.token_hex(32)
        stored["secret_key"] = secret_key
        changed = True

    data_enc_key = env_enc or stored.get("data_encryption_key") or ""
    if not data_enc_key:
        data_enc_key = secrets.token_hex(32)
        stored["data_encryption_key"] = data_enc_key
        changed = True

    blind_idx_key = env_blind or stored.get("blind_index_key") or ""
    if not blind_idx_key:
        blind_idx_key = secrets.token_hex(32)
        stored["blind_index_key"] = blind_idx_key
        changed = True

    if changed:
        try:
            key_file.parent.mkdir(parents=True, exist_ok=True)
            key_file.write_text(json.dumps(stored, indent=2), encoding="utf-8")
            try:
                os.chmod(key_file, 0o600)
            except OSError:
                pass
        except Exception:
            pass

    return {
        "secret_key": secret_key,
        "data_encryption_key": data_enc_key,
        "blind_index_key": blind_idx_key,
    }


_KEYS = load_or_create_master_keys()
MASTER_SECRET_KEY: str = _KEYS["secret_key"]
_AES_KEY_BYTES: bytes = hashlib.sha256(
    f"aes256gcm:{_KEYS['data_encryption_key']}".encode("utf-8")
).digest()
_BLIND_KEY_BYTES: bytes = hashlib.sha256(
    f"blindidx:{_KEYS['blind_index_key']}".encode("utf-8")
).digest()
_AESGCM = AESGCM(_AES_KEY_BYTES)


def encrypt_str(plaintext: Optional[str]) -> Optional[str]:
    """تشفير النص باستخدام AES-256-GCM مع Nonce عشوائي فريد لكل عملية كتابة"""
    if plaintext is None:
        return None
    val = str(plaintext)
    if val == "":
        return ""
    if val.startswith(CIPHERTEXT_PREFIX):
        return val
    nonce = os.urandom(12)
    ct = _AESGCM.encrypt(nonce, val.encode("utf-8"), AAD_CONTEXT)
    blob = base64.urlsafe_b64encode(nonce + ct).decode("ascii")
    return f"{CIPHERTEXT_PREFIX}{blob}"


def decrypt_str(ciphertext: Optional[str]) -> Optional[str]:
    """فك تشفير النص المشفر بـ AES-256-GCM في الذاكرة (مع دعم الترقية التلقائية للنصوص القديمة)"""
    if ciphertext is None:
        return None
    val = str(ciphertext)
    if val == "" or not val.startswith(CIPHERTEXT_PREFIX):
        return val
    raw = base64.urlsafe_b64decode(val[len(CIPHERTEXT_PREFIX):].encode("ascii"))
    nonce, ct = raw[:12], raw[12:]
    return _AESGCM.decrypt(nonce, ct, AAD_CONTEXT).decode("utf-8")


class EncryptedText(TypeDecorator):
    """نوع عمود SQLAlchemy يقوم بتشفير البيانات تلقائياً قبل كتابتها في SQLite وفكها عند القراءة"""
    impl = Text
    cache_ok = True

    def process_bind_param(self, value, dialect):
        if value is None:
            return None
        return encrypt_str(str(value))

    def process_result_value(self, value, dialect):
        if value is None:
            return None
        try:
            return decrypt_str(str(value))
        except Exception:
            return value


def normalize_mac(mac: Optional[str]) -> str:
    if not mac:
        return ""
    return re.sub(r"[^A-Fa-f0-9]", "", str(mac)).upper()


def compute_blind_index(domain: str, value: Optional[str]) -> Optional[str]:
    """حساب بصمة عمياء ذات اتجاه واحد (HMAC-SHA256) للبحث المفهرس دون كشف البيانات الأصلية"""
    if value is None:
        return None
    raw = str(value).strip()
    if not raw:
        return None
    if domain == "mac":
        norm = normalize_mac(raw)
    elif domain == "email":
        norm = raw.lower()
    elif domain == "invite":
        norm = raw.upper()
    else:
        norm = raw
    if not norm:
        return None
    msg = f"na7la:blind:{domain}:{norm}".encode("utf-8")
    return hmac.new(_BLIND_KEY_BYTES, msg, hashlib.sha256).hexdigest()


def hash_otp(email: str, otp_code: str) -> str:
    """تشفير كود التحقق السحابي OTP باتجاه واحد غير قابل للعكس باستخدام HMAC-SHA256"""
    norm_email = (email or "").strip().lower()
    norm_otp = (otp_code or "").strip()
    msg = f"na7la:otp:v1:{norm_email}:{norm_otp}".encode("utf-8")
    return hmac.new(_BLIND_KEY_BYTES, msg, hashlib.sha256).hexdigest()


def verify_otp_hash(email: str, otp_code: str, stored_hash: str) -> bool:
    if not stored_hash:
        return False
    expected = hash_otp(email, otp_code)
    return hmac.compare_digest(expected, stored_hash)


def mask_mac(mac: Optional[str]) -> str:
    """تقنيع عنوان الـ MAC لمنع تسريبه في السجلات أو لوحة الأدمن"""
    clean = normalize_mac(mac)
    if len(clean) < 4:
        return "••••••••••••"
    return f"••••••••{clean[-4:]}"


def mask_ip(ip: Optional[str]) -> str:
    """تقنيع عنوان الـ IP المنزلي للمستخدم في السجلات"""
    if not ip:
        return "•••.•••.•••.•••"
    s = str(ip).strip()
    if "." in s:
        parts = s.split(".")
        return f"{parts[0]}.•••.•••.•••"
    if ":" in s:
        parts = s.split(":")
        return f"{parts[0]}:••••:••••"
    return "•••.•••.•••.•••"


def mask_email(email: Optional[str]) -> str:
    if not email or "@" not in email:
        return "•••@•••"
    local, dom = email.strip().split("@", 1)
    prefix = local[:2] if len(local) >= 2 else local[:1]
    return f"{prefix}•••@{dom}"


class SlidingWindowRateLimiter:
    """حماية ضد هجمات التخمين المتكرر (Brute-Force Protection) للـ Login والـ OTP والـ PIN والـ MAC"""

    def __init__(self) -> None:
        self._lock = threading.Lock()
        self._buckets: dict[str, list[float]] = {}

    def _prune(self, bucket_key: str, now: float, window_sec: int) -> list[float]:
        entries = self._buckets.get(bucket_key, [])
        cutoff = now - window_sec
        fresh = [t for t in entries if t >= cutoff]
        if fresh:
            self._buckets[bucket_key] = fresh
        else:
            self._buckets.pop(bucket_key, None)
        return fresh

    def check_or_raise(
        self,
        scope: str,
        identifier: str,
        max_attempts: int = 5,
        window_sec: int = 600,
        detail: str = "تم تجاوز الحد المسموح للمحاولات الخاطئة. يرجى الانتظار 10 دقائق ثم المحاولة مجدداً.",
    ) -> None:
        now = time.monotonic()
        bkey = f"{scope}:{identifier}"
        with self._lock:
            fresh = self._prune(bkey, now, window_sec)
            if len(fresh) >= max_attempts:
                raise HTTPException(status_code=429, detail=detail)

    def record_attempt(self, scope: str, identifier: str, window_sec: int = 600) -> int:
        now = time.monotonic()
        bkey = f"{scope}:{identifier}"
        with self._lock:
            fresh = self._prune(bkey, now, window_sec)
            fresh.append(now)
            self._buckets[bkey] = fresh
            return len(fresh)

    def reset(self, scope: str, identifier: str) -> None:
        bkey = f"{scope}:{identifier}"
        with self._lock:
            self._buckets.pop(bkey, None)


rate_limiter = SlidingWindowRateLimiter()
