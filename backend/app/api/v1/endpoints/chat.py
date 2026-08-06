from typing import Any, List
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.api import deps
from app.models.user import User
from app.schemas.chat import ChatMessageCreate, ChatMessageOut, ChatConversationOut
from app.services import chat_service
from app.core import errors

router = APIRouter()

@router.post("/", response_model=ChatMessageOut, status_code=status.HTTP_201_CREATED)
def send_message(
    message_in: ChatMessageCreate,
    db: Session = Depends(deps.get_db),
    current_user: User = Depends(deps.get_current_user)
) -> Any:
    """
    Send a chat message to another user.
    """
    if message_in.receiver_id == current_user.id:
        raise HTTPException(status_code=400, detail=errors.CHAT_SENDER_CANNOT_BE_RECEIVER)
    return chat_service.create_message(db, message_in=message_in, sender_id=current_user.id)

@router.get("/conversations", response_model=List[ChatConversationOut])
def get_conversations(
    db: Session = Depends(deps.get_db),
    current_user: User = Depends(deps.get_current_user)
) -> Any:
    """
    List the current user's conversations, one per counterparty, newest
    first — the chat inbox. Must be declared before /{user_id} so it isn't
    swallowed by that path parameter.
    """
    return chat_service.get_conversations(db, user_id=current_user.id)

@router.get("/{user_id}", response_model=List[ChatMessageOut])
def get_chat_history(
    user_id: str,
    db: Session = Depends(deps.get_db),
    current_user: User = Depends(deps.get_current_user)
) -> Any:
    """
    Get conversation history between current user and the specified user.
    """
    return chat_service.get_conversation(db, user_a_id=current_user.id, user_b_id=user_id)
