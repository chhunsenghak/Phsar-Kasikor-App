import enum
from datetime import datetime, timezone
from typing import List, Optional
from pydantic import BaseModel, ConfigDict, Field, model_validator

class ContractStatus(str, enum.Enum):
    DRAFT = "DRAFT"
    ACTIVE = "ACTIVE"
    COMPLETED = "COMPLETED"
    TERMINATED = "TERMINATED"

class ContractItemBase(BaseModel):
    product_id: str
    agreed_price: float = Field(..., gt=0)
    agreed_quantity: float = Field(..., gt=0)
    unit_type: str

class ContractItemCreate(ContractItemBase):
    pass

class ContractItemOut(ContractItemBase):
    id: str
    contract_id: str

    model_config = ConfigDict(from_attributes=True)

class ContractBase(BaseModel):
    seller_id: str # Producer
    buyer_id: str # Buyer
    terms_description: Optional[str] = None
    start_date: datetime
    end_date: datetime
    contract_status: ContractStatus = ContractStatus.DRAFT

class ContractCreate(ContractBase):
    items: List[ContractItemCreate]

    @model_validator(mode="after")
    def validate_dates(self) -> "ContractCreate":
        now_utc = datetime.now(timezone.utc)
        if self.start_date <= now_utc:
            raise ValueError("START_DATE_MUST_BE_IN_FUTURE")
        if self.end_date <= self.start_date:
            raise ValueError("END_DATE_MUST_BE_AFTER_START_DATE")
        return self

class ContractUpdate(BaseModel):
    terms_description: Optional[str] = None
    start_date: Optional[datetime] = None
    end_date: Optional[datetime] = None
    contract_status: Optional[ContractStatus] = None
    items: Optional[List[ContractItemCreate]] = None

class ContractOut(ContractBase):
    id: str
    items: List[ContractItemOut]

    model_config = ConfigDict(from_attributes=True)
