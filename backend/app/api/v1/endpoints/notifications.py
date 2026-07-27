from typing import Any, List
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.api import deps
from app.models.user import User
from app.schemas.notification import NotificationCreate, NotificationOut
from app.services import notification_service

router = APIRouter()

@router.get("/", response_model=List[NotificationOut])
def read_notifications(
    db: Session = Depends(deps.get_db),
    skip: int = 0,
    limit: int = 100,
    current_user: User = Depends(deps.get_current_user)
) -> Any:
    """
    Retrieve current logged-in user notifications history.
    """
    return notification_service.get_notifications_for_user(db, user_id=current_user.id, skip=skip, limit=limit)

@router.post("/", response_model=NotificationOut, status_code=status.HTTP_201_CREATED)
def create_notification(
    notification_in: NotificationCreate,
    db: Session = Depends(deps.get_db),
    _current_user: Any = Depends(deps.get_current_user)
) -> Any:
    """
    Trigger a new push/system notification alert for a user.
    """
    return notification_service.create_notification(db, notification_in=notification_in)

@router.put("/{notification_id}/read", response_model=NotificationOut)
def mark_notification_as_read(
    notification_id: str,
    db: Session = Depends(deps.get_db),
    current_user: User = Depends(deps.get_current_user)
) -> Any:
    """
    Mark an alert notification as read.
    """
    db_notification = notification_service.mark_notification_as_read(
        db, notification_id=notification_id, user_id=current_user.id
    )
    if not db_notification:
        raise HTTPException(status_code=404, detail="Notification not found")
    return db_notification
