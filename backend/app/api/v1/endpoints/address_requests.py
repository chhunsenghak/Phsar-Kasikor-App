from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import Any, Dict
from datetime import datetime, timezone
from app.api import deps
from app.models.user import User
from app.models.address_change_request import AddressChangeRequest
from app.models.notification import Notification
from app.core.database import get_db
from app.core import errors

router = APIRouter()

@router.get("/")
def get_address_requests(
    db: Session = Depends(get_db),
    current_user: User = Depends(deps.get_current_user)
) -> Any:
    """
    List all address change requests.
    """
    result = db.query(AddressChangeRequest).order_by(AddressChangeRequest.created_at.desc()).all()
    requests = []
    for r in result:
        # Load associated user info dynamically
        user = db.query(User).filter(User.id == r.user_id).first()
        username = user.username if user else "Unknown User"
        role_name = user.roles[0].name.lower() if (user and user.roles) else "farmer"

        requests.append({
            # Core Metadata
            "id": r.id,
            "username": username,
            "role": role_name,
            "user_id": r.user_id,
            "status": r.status,

            # Proposed Address Info
            "newAddress": {
                "province": r.province,
                "district": r.district,
                "commune": r.commune,
                "village": r.village,
                "street_address": r.street_address,
                "latitude": r.latitude,
                "longitude": r.longitude,
                "proof_document_url": r.proof_document_url,
            },

            # Current Address Info (from user table)
            "oldAddress": {
                "province": user.province if user else "",
                "district": user.district if user else "",
                "commune": user.commune if user else "",
                "village": user.village if user else "",
                "street_address": user.street_address if user else "",
            },

            # Admin Review
            "admin_feedback": r.admin_feedback,
            "reviewed_at": r.reviewed_at.isoformat() if r.reviewed_at else None,
            "created_at": r.created_at.isoformat() if r.created_at else None,
            "timestamp": r.created_at.isoformat() if r.created_at else None,
        })
    return requests

@router.post("/")
def create_address_request(
    *,
    db: Session = Depends(get_db),
    request_in: Dict[str, Any],
    current_user: User = Depends(deps.get_current_user)
) -> Any:
    """
    Create a new address change request for review.
    """
    existing = db.query(AddressChangeRequest).filter(
        AddressChangeRequest.user_id == current_user.id,
        AddressChangeRequest.status == "PENDING"
    ).first()
    if existing:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=errors.ADDRESS_CHANGE_REQUEST_ALREADY_PENDING
        )

    new_req = AddressChangeRequest(
        user_id=current_user.id,
        status="PENDING",
        province=request_in.get("province"),
        district=request_in.get("district"),
        commune=request_in.get("commune"),
        village=request_in.get("village"),
        street_address=request_in.get("street_address"),
        latitude=request_in.get("latitude"),
        longitude=request_in.get("longitude"),
        proof_document_url=request_in.get("proof_document_url"),
        admin_feedback=request_in.get("admin_feedback")
    )
    db.add(new_req)
    
    # Add a database notification alert for the user
    notif = Notification(
        user_id=current_user.id,
        title="addr_update_pending_title",
        message="addr_update_pending_desc"
    )
    db.add(notif)

    db.commit()
    db.refresh(new_req)
    return {"status": "success", "id": new_req.id}

@router.put("/{request_id}/approve")
def approve_address_request(
    request_id: str,
    payload: Dict[str, Any] = None,
    db: Session = Depends(get_db),
    current_user: User = Depends(deps.get_current_user)
) -> Any:
    """
    Approve the address change request and apply updates to the user profile.
    """
    req = db.query(AddressChangeRequest).filter(AddressChangeRequest.id == request_id).first()
    if not req:
        raise HTTPException(status_code=404, detail=errors.ADDRESS_CHANGE_REQUEST_NOT_FOUND)

    if req.status != 'PENDING':
        raise HTTPException(status_code=400, detail=errors.ADDRESS_CHANGE_REQUEST_ALREADY_RESOLVED)

    # Mark as approved
    req.status = 'APPROVED'
    req.reviewed_at = datetime.now(timezone.utc)
    if payload and "admin_feedback" in payload:
        req.admin_feedback = payload["admin_feedback"]

    # Apply change to the user by pointing active address_id to the approved request
    user = db.query(User).filter(User.id == req.user_id).first()
    if user:
        user.address_id = req.id

    # Create notification record
    notif = Notification(
        user_id=req.user_id,
        title="addr_update_approved_title",
        message="addr_update_approved_desc"
    )
    db.add(notif)

    db.commit()
    return {"status": "approved"}

@router.put("/{request_id}/reject")
def reject_address_request(
    request_id: str,
    payload: Dict[str, Any] = None,
    db: Session = Depends(get_db),
    current_user: User = Depends(deps.get_current_user)
) -> Any:
    """
    Reject the address change request.
    """
    req = db.query(AddressChangeRequest).filter(AddressChangeRequest.id == request_id).first()
    if not req:
        raise HTTPException(status_code=404, detail=errors.ADDRESS_CHANGE_REQUEST_NOT_FOUND)

    if req.status != 'PENDING':
        raise HTTPException(status_code=400, detail=errors.ADDRESS_CHANGE_REQUEST_ALREADY_RESOLVED)

    req.status = 'REJECTED'
    req.reviewed_at = datetime.now(timezone.utc)
    if payload and "admin_feedback" in payload:
        req.admin_feedback = payload["admin_feedback"]

    # Create notification record
    notif = Notification(
        user_id=req.user_id,
        title="addr_update_rejected_title",
        message="addr_update_rejected_desc"
    )
    db.add(notif)

    db.commit()
    return {"status": "rejected"}
