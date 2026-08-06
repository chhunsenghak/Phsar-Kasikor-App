from typing import Any, Dict, List
from sqlalchemy.orm import Session
from app.models.chat import ChatMessage
from app.models.user import User
from app.schemas.chat import ChatMessageCreate
from app.schemas.notification import NotificationCreate
from app.services import notification_service

def create_message(db: Session, message_in: ChatMessageCreate, sender_id: str) -> ChatMessage:
    db_message = ChatMessage(
        sender_id=sender_id,
        receiver_id=message_in.receiver_id,
        message_text=message_in.message_text
    )
    db.add(db_message)
    db.commit()
    db.refresh(db_message)

    # Trigger system notification to receiver
    try:
        notification_service.create_notification(
            db,
            notification_in=NotificationCreate(
                user_id=message_in.receiver_id,
                title="New Message",
                message=f"New message: {db_message.message_text[:30]}...",
                is_read=False
            )
        )
    except Exception:
        pass

    return db_message

def get_conversation(db: Session, user_a_id: str, user_b_id: str, limit: int = 100) -> List[ChatMessage]:
    # Returns conversation history between user_a and user_b ordered chronologically
    messages = db.query(ChatMessage).filter(
        ((ChatMessage.sender_id == user_a_id) & (ChatMessage.receiver_id == user_b_id)) |
        ((ChatMessage.sender_id == user_b_id) & (ChatMessage.receiver_id == user_a_id))
    ).order_by(ChatMessage.created_at.asc()).limit(limit).all()

    # Opening a thread is treated as reading it — mark anything the other
    # side sent to user_a as read.
    unread_ids = [
        m.id for m in messages
        if m.receiver_id == user_a_id and m.sender_id == user_b_id and not m.is_read
    ]
    if unread_ids:
        db.query(ChatMessage).filter(ChatMessage.id.in_(unread_ids)).update(
            {"is_read": True}, synchronize_session=False
        )
        db.commit()
        for m in messages:
            if m.id in unread_ids:
                m.is_read = True

    return messages


def get_conversations(db: Session, user_id: str) -> List[Dict[str, Any]]:
    """
    One entry per distinct counterparty the user has exchanged messages
    with, newest first, with an unread count of what they sent to us.
    Small message volumes make grouping this in Python simpler and more
    portable than a cross-column SQL group-by.
    """
    messages = db.query(ChatMessage).filter(
        (ChatMessage.sender_id == user_id) | (ChatMessage.receiver_id == user_id)
    ).order_by(ChatMessage.created_at.desc()).all()

    conversations: Dict[str, Dict[str, Any]] = {}
    for m in messages:
        other_id = m.receiver_id if m.sender_id == user_id else m.sender_id
        if other_id not in conversations:
            conversations[other_id] = {
                "other_user_id": other_id,
                "last_message": m.message_text,
                "last_message_at": m.created_at,
                "unread_count": 0,
            }
        if m.receiver_id == user_id and not m.is_read:
            conversations[other_id]["unread_count"] += 1

    results = list(conversations.values())
    results.sort(key=lambda c: c["last_message_at"], reverse=True)

    for c in results:
        other = db.query(User).filter(User.id == c["other_user_id"]).first()
        c["other_user_name"] = other.username if other else "User"

    return results
