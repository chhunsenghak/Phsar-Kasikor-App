from datetime import datetime
from pydantic import BaseModel, ConfigDict

class ChatMessageCreate(BaseModel):
    receiver_id: str
    message_text: str

class ChatMessageOut(BaseModel):
    id: str
    sender_id: str
    receiver_id: str
    message_text: str
    is_read: bool
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)
