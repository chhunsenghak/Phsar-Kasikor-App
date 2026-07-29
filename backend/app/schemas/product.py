import enum
from typing import Optional
from datetime import date, datetime
from pydantic import BaseModel, ConfigDict, Field

class ProductUnit(str, enum.Enum):
    KG = "KG"
    TON = "TON"
    SACK = "SACK"
    CRATE = "CRATE"
    BUNCH = "BUNCH"
    BOX = "BOX"
    PIECE = "PIECE"

class ProductBase(BaseModel):
    product_name: str
    category_id: str
    price_per_unit: float = Field(..., gt=0)
    unit_type: ProductUnit
    currency: str = "USD"
    quantity_available: float = Field(..., ge=0)
    harvest_date: Optional[date] = None
    quality_certification_metadata: Optional[str] = None
    status: str = "active"
    image_url: Optional[str] = None

class ProductCreate(ProductBase):
    pass

class ProductUpdate(BaseModel):
    product_name: Optional[str] = None
    category_id: Optional[str] = None
    price_per_unit: Optional[float] = Field(None, gt=0)
    unit_type: Optional[ProductUnit] = None
    currency: Optional[str] = None
    quantity_available: Optional[float] = Field(None, ge=0)
    harvest_date: Optional[date] = None
    quality_certification_metadata: Optional[str] = None
    status: Optional[str] = None
    image_url: Optional[str] = None

class ProductOut(ProductBase):
    id: str
    seller_id: str
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)
