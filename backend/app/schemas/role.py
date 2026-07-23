from datetime import datetime
from typing import Optional
from pydantic import BaseModel, ConfigDict, Field

class RoleBase(BaseModel):
    name: str = Field(..., min_length=2, max_length=50, description="The name of the role (e.g. FARMER, BUYER, MERCHANT, ADMIN)")
    description: Optional[str] = Field(None, max_length=255, description="A brief description of what the role entails")

class RoleCreate(RoleBase):
    pass

class RoleUpdate(BaseModel):
    name: Optional[str] = Field(None, min_length=2, max_length=50)
    description: Optional[str] = Field(None, max_length=255)

class RoleOut(RoleBase):
    id: int
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)

class RoleAssignment(BaseModel):
    user_id: str = Field(..., description="The unique ID of the target user")
    role_id: int = Field(..., description="The unique ID of the role to assign")
