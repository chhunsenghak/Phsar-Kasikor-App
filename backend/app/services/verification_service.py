import hashlib
import secrets
from datetime import datetime, timedelta, timezone
from typing import Optional

from sqlalchemy.orm import Session

from app.models.verification_code import VerificationCode

PASSWORD_RESET = "password_reset"
EMAIL_VERIFICATION = "email_verification"

_CODE_TTL_MINUTES = 15


def _hash_code(code: str) -> str:
    return hashlib.sha256(code.encode("utf-8")).hexdigest()


def create_code(db: Session, user_id: str, purpose: str) -> str:
    """
    Generates a 6-digit numeric code, stores only its hash, and returns the
    plaintext for the caller to email. Invalidates any prior outstanding
    code of the same purpose for this user, so only the most recent one
    a user requested can ever be redeemed.
    """
    db.query(VerificationCode).filter(
        VerificationCode.user_id == user_id,
        VerificationCode.purpose == purpose,
        VerificationCode.used_at.is_(None),
    ).update({"used_at": datetime.now(timezone.utc)}, synchronize_session=False)

    code = f"{secrets.randbelow(1_000_000):06d}"
    record = VerificationCode(
        user_id=user_id,
        code_hash=_hash_code(code),
        purpose=purpose,
        expires_at=datetime.now(timezone.utc) + timedelta(minutes=_CODE_TTL_MINUTES),
    )
    db.add(record)
    db.commit()
    return code


def verify_and_consume_code(db: Session, user_id: str, purpose: str, code: str) -> bool:
    """
    Checks a submitted code against the most recent unused, unexpired code
    of this purpose for the user, and marks it used on success so it can't
    be replayed. Returns False for any mismatch, expiry, or reuse attempt —
    deliberately without distinguishing which, to avoid leaking state to a
    guesser.
    """
    record = (
        db.query(VerificationCode)
        .filter(
            VerificationCode.user_id == user_id,
            VerificationCode.purpose == purpose,
            VerificationCode.used_at.is_(None),
        )
        .order_by(VerificationCode.created_at.desc())
        .first()
    )
    if not record:
        return False
    # expires_at is stored naive-UTC, matching every other timestamp column
    # in this codebase (created_at, sent_at, etc.) — compare against a naive
    # UTC "now" rather than an aware one.
    if record.expires_at < datetime.now(timezone.utc).replace(tzinfo=None):
        return False
    if record.code_hash != _hash_code(code):
        return False

    record.used_at = datetime.now(timezone.utc)
    db.commit()
    return True
