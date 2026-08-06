from typing import Any, List
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.api import deps
from app.core import errors
from app.core.database import get_db
from app.models.user import User
from app.schemas.dispute import DisputeCreate, DisputeOut, DisputeResolve
from app.services import dispute_service

router = APIRouter()

_ERROR_STATUS = {
    "ORDER_NOT_FOUND": 404,
    "NOT_AUTHORIZED": 403,
    "DISPUTE_ALREADY_OPEN": 400,
    "DISPUTE_ALREADY_RESOLVED": 400,
    "INVALID_DISPUTE_STATUS": 400,
}

def _to_out(dispute) -> DisputeOut:
    out = DisputeOut.model_validate(dispute)
    out.raiser_name = dispute.raiser.username if dispute.raiser else None
    return out

@router.post("/", response_model=DisputeOut, status_code=201)
def create_dispute(
    dispute_in: DisputeCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(deps.get_current_user)
) -> Any:
    """
    Flag a problem with an order. Only the buyer or seller of that order can
    raise one, and only one open dispute per order at a time.
    """
    try:
        dispute = dispute_service.create_dispute(db, dispute_in=dispute_in, raised_by=current_user.id)
    except Exception as e:
        code = str(e)
        raise HTTPException(status_code=_ERROR_STATUS.get(code, 400), detail=code)
    return _to_out(dispute)

@router.get("/", response_model=List[DisputeOut])
def list_my_disputes(
    skip: int = 0,
    limit: int = 100,
    db: Session = Depends(get_db),
    current_user: User = Depends(deps.get_current_user)
) -> Any:
    """
    The current user's own raised disputes.
    """
    disputes = dispute_service.get_disputes_for_user(db, user_id=current_user.id, skip=skip, limit=limit)
    return [_to_out(d) for d in disputes]

@router.get("/admin/all", response_model=List[DisputeOut])
def list_all_disputes(
    skip: int = 0,
    limit: int = 100,
    db: Session = Depends(get_db),
    _current_user: User = Depends(deps.get_current_admin_user)
) -> Any:
    """
    Every dispute in the system — the admin resolution queue.
    """
    disputes = dispute_service.get_all_disputes(db, skip=skip, limit=limit)
    return [_to_out(d) for d in disputes]

@router.put("/{dispute_id}/resolve", response_model=DisputeOut)
def resolve_dispute(
    dispute_id: str,
    resolve_in: DisputeResolve,
    db: Session = Depends(get_db),
    _current_user: User = Depends(deps.get_current_admin_user)
) -> Any:
    """
    Admin resolves a dispute — either issuing a refund (flips the order's
    payment_status to REFUNDED) or rejecting it with a note.
    """
    dispute = dispute_service.get_dispute(db, dispute_id=dispute_id)
    if not dispute:
        raise HTTPException(status_code=404, detail=errors.DISPUTE_NOT_FOUND)
    try:
        dispute = dispute_service.resolve_dispute(db, dispute=dispute, resolve_in=resolve_in)
    except Exception as e:
        code = str(e)
        raise HTTPException(status_code=_ERROR_STATUS.get(code, 400), detail=code)
    return _to_out(dispute)
