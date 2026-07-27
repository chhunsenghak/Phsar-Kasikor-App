from typing import List
from sqlalchemy.orm import Session
from app.models.chat import ChatMessage
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
    return db.query(ChatMessage).filter(
        ((ChatMessage.sender_id == user_a_id) & (ChatMessage.receiver_id == user_b_id)) |
        ((ChatMessage.sender_id == user_b_id) & (ChatMessage.receiver_id == user_a_id))
    ).order_by(ChatMessage.created_at.asc()).limit(limit).all()
