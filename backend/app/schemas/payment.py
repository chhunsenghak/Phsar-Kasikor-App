from typing import List
from pydantic import BaseModel

class KHQRGenerateRequest(BaseModel):
    order_ids: List[str]

class KHQROut(BaseModel):
    qr_string: str
    md5: str
    qr_image_base64: str

class PaymentStatusOut(BaseModel):
    status: str  # paid, unpaid, unavailable
