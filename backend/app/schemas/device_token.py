from typing import Optional
from pydantic import BaseModel

class DeviceTokenRegister(BaseModel):
    fcm_token: str
    platform: Optional[str] = None
