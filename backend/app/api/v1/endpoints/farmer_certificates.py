from typing import Any, List
from datetime import datetime, timezone
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.api import deps
from app.core.database import get_db
from app.models.user import User
from app.models.farmer_certificate import FarmerCertificate
from app.models.notification import Notification
from app.schemas.farmer_certificate import (
    FarmerCertificateCreate,
    FarmerCertificateOut,
    FarmerCertificateReview,
)

router = APIRouter()

@router.get("/", response_model=List[FarmerCertificateOut])
def get_certificates(
    db: Session = Depends(get_db),
    skip: int = 0,
    limit: int = 100,
    current_user: User = Depends(deps.get_current_user)
) -> Any:
    """
    Retrieve certificates. Admins see all pending/reviewed certificates; farmers see their own.
    """
    query = db.query(FarmerCertificate)
    # If not admin, restrict to user's certificates
    user_roles = [r.name.upper() for r in current_user.roles] if current_user.roles else []
    if "ADMIN" not in user_roles:
        query = query.filter(FarmerCertificate.user_id == current_user.id)

    certs = query.order_by(FarmerCertificate.created_at.desc()).offset(skip).limit(limit).all()
    results = []
    for c in certs:
        c_dict = FarmerCertificateOut.model_validate(c)
        farmer = db.query(User).filter(User.id == c.user_id).first()
        c_dict.farmer_name = farmer.username if farmer else "Farmer"
        results.append(c_dict)
    return results

@router.post("/", response_model=FarmerCertificateOut, status_code=status.HTTP_201_CREATED)
def submit_certificate(
    *,
    db: Session = Depends(get_db),
    cert_in: FarmerCertificateCreate,
    current_user: User = Depends(deps.get_current_user)
) -> Any:
    """
    Farmer submits agricultural verification certificate.
    """
    cert = FarmerCertificate(
        user_id=current_user.id,
        certificate_type=cert_in.certificate_type,
        issuing_body=cert_in.issuing_body,
        document_url=cert_in.document_url,
        status="pending"
    )
    db.add(cert)
    
    # Notify user
    notif = Notification(
        user_id=current_user.id,
        title="Certificate Submitted",
        message=f"Your {cert_in.certificate_type} certificate was uploaded for MAFF/Admin review."
    )
    db.add(notif)
    db.commit()
    db.refresh(cert)

    res = FarmerCertificateOut.model_validate(cert)
    res.farmer_name = current_user.username
    return res

@router.put("/{cert_id}/review", response_model=FarmerCertificateOut)
def review_certificate(
    cert_id: str,
    review_in: FarmerCertificateReview,
    db: Session = Depends(get_db),
    current_user: User = Depends(deps.get_current_user)
) -> Any:
    """
    Admin reviews and approves or rejects a farmer certificate.
    """
    cert = db.query(FarmerCertificate).filter(FarmerCertificate.id == cert_id).first()
    if not cert:
        raise HTTPException(status_code=404, detail="Farmer certificate not found")

    cert.status = review_in.status.lower()
    cert.admin_feedback = review_in.admin_feedback
    cert.reviewed_at = datetime.now(timezone.utc)

    # Notify farmer
    notif = Notification(
        user_id=cert.user_id,
        title=f"Certificate {cert.status.capitalize()}",
        message=f"Your certificate '{cert.certificate_type}' status was updated to {cert.status}."
    )
    db.add(notif)
    db.commit()
    db.refresh(cert)

    res = FarmerCertificateOut.model_validate(cert)
    farmer = db.query(User).filter(User.id == cert.user_id).first()
    res.farmer_name = farmer.username if farmer else "Farmer"
    return res
