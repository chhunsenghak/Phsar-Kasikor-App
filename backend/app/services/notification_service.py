from typing import List, Optional
from sqlalchemy.orm import Session
from app.models.notification import Notification
from app.schemas.notification import NotificationCreate
from app.services import push_service

from datetime import datetime, timezone

def get_notifications_for_user(db: Session, user_id: str, skip: int = 0, limit: int = 100) -> List[Notification]:
    return db.query(Notification).filter(
        (Notification.user_id == user_id) & (Notification.deleted_at == None)
    ).order_by(Notification.sent_at.desc()).offset(skip).limit(limit).all()

def create_notification(db: Session, notification_in: NotificationCreate) -> Notification:
    db_notification = Notification(
        user_id=notification_in.user_id,
        title=notification_in.title,
        message=notification_in.message,
        is_read=notification_in.is_read
    )
    db.add(db_notification)
    db.commit()
    db.refresh(db_notification)

    # Push is best-effort — every existing call site gets it for free, but a
    # failure here must never take down notification creation itself.
    try:
        push_service.send_push(
            db,
            user_id=notification_in.user_id,
            title=notification_in.title,
            body=notification_in.message,
        )
    except Exception:
        pass

    return db_notification

def mark_notification_as_read(db: Session, notification_id: str, user_id: str) -> Optional[Notification]:
    db_notification = db.query(Notification).filter(
        (Notification.id == notification_id) & (Notification.user_id == user_id)
    ).first()
    if db_notification:
        db_notification.is_read = True
        db.commit()
        db.refresh(db_notification)
    return db_notification

def delete_notification_soft(db: Session, notification_id: str, user_id: str) -> Optional[Notification]:
    db_notification = db.query(Notification).filter(
        (Notification.id == notification_id) & (Notification.user_id == user_id)
    ).first()
    if db_notification:
        db_notification.deleted_at = datetime.now(timezone.utc)
        db.commit()
        db.refresh(db_notification)
    return db_notification
