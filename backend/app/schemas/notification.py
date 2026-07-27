from datetime import datetime
from pydantic import BaseModel, ConfigDict

class NotificationBase(BaseModel):
    user_id: str
    title: str
    message: str
    is_read: bool = False

class NotificationCreate(NotificationBase):
    pass

class NotificationOut(NotificationBase):
    id: str
    sent_at: datetime

    model_config = ConfigDict(from_attributes=True)
