import enum
from typing import Optional
from datetime import date, datetime
from pydantic import BaseModel, ConfigDict, Field


class CategoryBase(BaseModel):
  name: str
  description: str

class CategoryCreate(CategoryBase):
  pass

class CategoryUpdate(BaseModel):
  name: Optional[str] = None
  description: Optional[str] = None

class CategoryOut(CategoryBase):
  id: str
  created_at: datetime

  model_config = ConfigDict(from_attributes=True)
