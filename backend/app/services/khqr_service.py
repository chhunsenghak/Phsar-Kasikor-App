import logging
import time
from typing import Optional

import requests
from bakong_khqr import KHQR

from app.core.config import settings

logger = logging.getLogger("khqr_service")

# Bakong's check_transaction_by_md5 is capped at a small number of calls per
# day, account-wide (observed in production: 100/day total, shared across
# every order the whole app checks) — polling every few seconds from the
# checkout screen, the tracking screen, and the opportunistic re-check on
# every order read would burn through that in minutes, after which every
# further check would misreport as "unpaid" instead of "couldn't tell" (see
# the errorCode handling below). This throttles real upstream calls per QR
# to at most once every COOLDOWN_SECONDS; callers within the window get the
# last known result instead of spending another call. In-memory only — fine
# for this app's single-worker deployment; a multi-worker deployment would
# need a shared store instead.
COOLDOWN_SECONDS = 20
_last_check: dict[str, tuple[float, Optional[bool]]] = {}


def _client() -> KHQR:
    # create_qr/generate_md5/qr_image never touch the token or the network —
    # only check_payment (and the deeplink/webcheckout methods, unused here)
    # do. Passing an empty string when no token is configured is safe.
    return KHQR(settings.BAKONG_BEARER_TOKEN or "")


def generate_khqr(amount: float, currency: str, bill_number: str, store_label: str = "PhsarKasikor") -> dict:
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


def render_qr_image(qr_string: str) -> str:
    """
    Re-renders the scannable image for an already-generated QR string. Pure
    local drawing, same as the image step inside generate_khqr — no Bakong
    call, so it's safe to call repeatedly for the same qr_string without
    ever changing its md5.
    """
    return _client().qr_image(qr_string, format="base64")


def check_payment_status(md5_hash: str) -> Optional[bool]:
    """
    Best-effort payment check against the real Bakong API. Returns True/False
    if a bearer token is configured and the call succeeds, or None if
    verification isn't available right now (no token, an expired token, a
    network failure, or the daily call cap) — callers should treat None as
    "couldn't tell," never as "not paid."
    """
    if not settings.BAKONG_BEARER_TOKEN:
        return None

    now = time.monotonic()
    cached = _last_check.get(md5_hash)
    if cached is not None and now - cached[0] < COOLDOWN_SECONDS:
        return cached[1]

    result = _check_once(md5_hash)
    _last_check[md5_hash] = (now, result)
    return result


def _check_once(md5_hash: str) -> Optional[bool]:
    # Deliberately not using the library's own check_payment() here — it
    # collapses every non-zero responseCode to the literal string "UNPAID",
    # with no way to tell a genuine "not paid yet" apart from a request that
    # never really checked at all (rate limit, bad token, transient error).
    # Reporting the latter as "unpaid" would tell a buyer who already paid
    # that they hadn't, so this inspects the raw response itself instead.
    try:
        response = requests.post(
            f"{settings.BAKONG_API_BASE_URL}/v1/check_transaction_by_md5",
            json={"md5": md5_hash},
            headers={
                "Authorization": f"Bearer {settings.BAKONG_BEARER_TOKEN}",
                "Content-Type": "application/json",
            },
            timeout=10,
        )
        data = response.json()
    except Exception as e:
        logger.warning(f"Bakong payment check failed for {md5_hash}: {e}")
        return None

    if data.get("responseCode") == 0:
        return True
    # errorCode 1 is Bakong's documented "transaction not found" — a real,
    # checked "not paid yet". Any other code (17 = daily request limit
    # exceeded, auth failures, etc.) means the check itself didn't actually
    # happen, and must not be reported as unpaid.
    if data.get("errorCode") == 1:
        return False
    logger.warning(f"Bakong check_transaction_by_md5 returned an error for {md5_hash}: {data}")
    return None
