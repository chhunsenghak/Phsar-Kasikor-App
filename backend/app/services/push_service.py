import logging
from typing import Optional
from sqlalchemy.orm import Session

from app.core.config import settings
from app.models.device_token import DeviceToken

logger = logging.getLogger("push_service")

_firebase_app = None
_init_attempted = False


def _get_firebase_app():
    """
    Lazily initializes the Firebase Admin SDK from the configured service
    account file. Returns None (and logs once) if no path is configured or
    initialization fails, so callers can no-op instead of crashing — a push
    failure must never break notification creation.
    """
    global _firebase_app, _init_attempted
    if _firebase_app is not None or _init_attempted:
        return _firebase_app
    _init_attempted = True

    if not settings.FIREBASE_SERVICE_ACCOUNT_PATH:
        logger.info("FIREBASE_SERVICE_ACCOUNT_PATH not set — push notifications disabled.")
        return None

    try:
        import firebase_admin
        from firebase_admin import credentials

        cred = credentials.Certificate(settings.FIREBASE_SERVICE_ACCOUNT_PATH)
        _firebase_app = firebase_admin.initialize_app(cred)
    except Exception as e:
        logger.warning(f"Failed to initialize Firebase Admin SDK: {e}")
        _firebase_app = None

    return _firebase_app


def register_device(db: Session, user_id: str, fcm_token: str, platform: Optional[str] = None) -> DeviceToken:
    """
    A token can migrate to a different account (device changes hands, app
    reinstalled under another login) — re-point it rather than erroring on
    the unique constraint.
    """
    existing = db.query(DeviceToken).filter(DeviceToken.fcm_token == fcm_token).first()
    if existing:
        existing.user_id = user_id
        existing.platform = platform or existing.platform
        db.commit()
        db.refresh(existing)
        return existing

    token = DeviceToken(user_id=user_id, fcm_token=fcm_token, platform=platform)
    db.add(token)
    db.commit()
    db.refresh(token)
    return token


def send_push(db: Session, user_id: str, title: str, body: str) -> None:
    """
    Best-effort push to every device registered for user_id. No-ops
    entirely if Firebase isn't configured.
    """
    app = _get_firebase_app()
    if app is None:
        return

    tokens = db.query(DeviceToken).filter(DeviceToken.user_id == user_id).all()
    if not tokens:
        return

    from firebase_admin import messaging

    stale_token_ids = []
    for t in tokens:
        try:
            message = messaging.Message(
                notification=messaging.Notification(title=title, body=body),
                token=t.fcm_token,
            )
            messaging.send(message, app=app)
        except messaging.UnregisteredError:
            # The device uninstalled the app or the token otherwise expired.
            stale_token_ids.append(t.id)
        except Exception as e:
            logger.warning(f"Push send failed for token {t.id}: {e}")

    if stale_token_ids:
        db.query(DeviceToken).filter(DeviceToken.id.in_(stale_token_ids)).delete(synchronize_session=False)
        db.commit()
