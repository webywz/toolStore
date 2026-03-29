from __future__ import annotations

from datetime import datetime, timedelta, timezone
import hashlib

import jwt

from app.config import settings
from app.core.exceptions import BusinessError


TOKEN_EXPIRE_DAYS = 30
PASSWORD_SALT = b"tool-store-password-salt-v1"
LEGACY_PASSWORD_SALTS = [b"ywzstore"]


def _hash_with_salt(password: str, salt: bytes) -> str:
    digest = hashlib.pbkdf2_hmac("sha256", password.encode("utf-8"), salt, 390000)
    return digest.hex()


def hash_password(password: str) -> str:
    return _hash_with_salt(password, PASSWORD_SALT)


def verify_password(password: str, password_hash: str) -> bool:
    if hash_password(password) == password_hash:
        return True
    salts_to_try = LEGACY_PASSWORD_SALTS + [settings.secret_key.encode("utf-8")]
    for salt in salts_to_try:
        if _hash_with_salt(password, salt) == password_hash:
            return True
    return False


def create_access_token(user_id: int) -> str:
    now = datetime.now(timezone.utc)
    payload = {
        "sub": str(user_id),
        "iat": int(now.timestamp()),
        "exp": int((now + timedelta(days=TOKEN_EXPIRE_DAYS)).timestamp()),
    }
    return jwt.encode(payload, settings.secret_key, algorithm="HS256")


def decode_access_token(token: str) -> int:
    try:
        payload = jwt.decode(token, settings.secret_key, algorithms=["HS256"])
    except jwt.PyJWTError as exc:
        raise BusinessError(status_code=401, code=401, message="未授权") from exc
    user_id = payload.get("sub")
    if not user_id:
        raise BusinessError(status_code=401, code=401, message="未授权")
    try:
        return int(user_id)
    except ValueError as exc:
        raise BusinessError(status_code=401, code=401, message="未授权") from exc
