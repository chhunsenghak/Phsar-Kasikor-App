import enum
from datetime import datetime, timezone
from typing import List, Optional
from pydantic import BaseModel, ConfigDict, Field, model_validator

class ContractStatus(str, enum.Enum):
    DRAFT = "DRAFT"
    PENDING_DEPOSIT = "PENDING_DEPOSIT"
    ACTIVE = "ACTIVE"
    PENDING_FINAL_PAYMENT = "PENDING_FINAL_PAYMENT"
    IN_FULFILLMENT = "IN_FULFILLMENT"
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
    # Required (0 < pct <= 100) when the seller transitions DRAFT ->
    # PENDING_DEPOSIT — see contract_service.update_contract.
    deposit_percentage: Optional[float] = Field(None, gt=0, le=100)
    # Required when the seller transitions ACTIVE -> PENDING_FINAL_PAYMENT —
    # see contract_service.update_contract. delivery_fee is only required
    # (and only meaningful) when delivery_method == "DELIVERY".
    delivery_method: Optional[str] = None
    delivery_fee: Optional[float] = Field(None, ge=0)

class ContractOut(ContractBase):
    id: str
    buyer_name: Optional[str] = None
    seller_name: Optional[str] = None
    items: List[ContractItemOut]
    deposit_percentage: Optional[float] = None
    deposit_amount: Optional[float] = None
    deposit_status: Optional[str] = None
    deposit_currency: Optional[str] = None
    delivery_method: Optional[str] = None
    delivery_fee: Optional[float] = None
    final_amount: Optional[float] = None
    final_payment_status: Optional[str] = None
    fulfillment_order_id: Optional[str] = None

    model_config = ConfigDict(from_attributes=True)
