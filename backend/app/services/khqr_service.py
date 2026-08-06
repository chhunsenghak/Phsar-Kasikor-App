import logging
from typing import Optional

from bakong_khqr import KHQR

from app.core.config import settings

logger = logging.getLogger("khqr_service")


def _client() -> KHQR:
    # create_qr/generate_md5/qr_image never touch the token or the network —
    # only check_payment (and the deeplink/webcheckout methods, unused here)
    # do. Passing an empty string when no token is configured is safe.
    return KHQR(settings.BAKONG_BEARER_TOKEN or "")


def generate_khqr(amount: float, currency: str, bill_number: str, store_label: str = "AgriMarket") -> dict:
    """
    Builds a real, scannable dynamic KHQR code for the given amount. This is
    pure local string construction per the KHQR/EMVCo spec — no Bakong API
    call, no token required, so it works even with BAKONG_BEARER_TOKEN unset.
    """
    client = _client()
    qr_string = client.create_qr(
        account_id=settings.BAKONG_MERCHANT_ACCOUNT_ID,
        merchant_name=settings.BAKONG_MERCHANT_NAME,
        merchant_city=settings.BAKONG_MERCHANT_CITY,
        amount=amount,
        currency=currency,
        store_label=store_label,
        bill_number=bill_number,
        static=False,
    )
    md5_hash = client.generate_md5(qr_string)
    qr_image_base64 = client.qr_image(qr_string, format="base64")

    return {
        "qr_string": qr_string,
        "md5": md5_hash,
        "qr_image_base64": qr_image_base64,
    }


def check_payment_status(md5_hash: str) -> Optional[bool]:
    """
    Best-effort payment check against the real Bakong API. Returns True/False
    if a bearer token is configured and the call succeeds, or None if
    verification isn't available right now (no token, an expired token, or a
    network failure) — callers should treat None as "ask the user to confirm
    manually," never as "not paid."
    """
    if not settings.BAKONG_BEARER_TOKEN:
        return None
    try:
        client = _client()
        return bool(client.check_payment(md5_hash))
    except Exception as e:
        logger.warning(f"Bakong payment check failed for {md5_hash}: {e}")
        return None
