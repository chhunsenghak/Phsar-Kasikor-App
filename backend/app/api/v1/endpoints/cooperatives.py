from typing import Any, List
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy import func

from app.api import deps
from app.core import errors
from app.core.database import get_db
from app.models.user import User
from app.models.product import Product
from app.models.cooperative import Cooperative, CooperativeMember
from app.schemas.cooperative import (
    CooperativeMemberOut,
    CooperativeOut,
    CooperativeMemberInvite,
    CooperativeMemberStatusUpdate,
    StockSummaryItem,
)
from app.services import user_service

router = APIRouter()


def _get_or_create_own_cooperative(db: Session, leader: User) -> Cooperative:
    coop = db.query(Cooperative).filter(Cooperative.leader_id == leader.id).first()
    if not coop:
        coop = Cooperative(
            leader_id=leader.id,
            name=f"{leader.province or 'Local'} Agricultural Cooperative",
            province=leader.province,
        )
        db.add(coop)
        db.commit()
        db.refresh(coop)
    return coop


def _member_out(db: Session, member: CooperativeMember, coop: Cooperative | None = None) -> CooperativeMemberOut:
    m_out = CooperativeMemberOut.model_validate(member)
    farmer = db.query(User).filter(User.id == member.farmer_id).first()
    m_out.farmer_name = farmer.username if farmer else "Farmer"
    m_out.location = farmer.province if farmer else None
    m_out.products_count = db.query(func.count(Product.id)).filter(
        Product.seller_id == member.farmer_id
    ).scalar() or 0
    coop = coop or db.query(Cooperative).filter(Cooperative.id == member.cooperative_id).first()
    m_out.cooperative_name = coop.name if coop else None
    return m_out


@router.get("/mine", response_model=CooperativeOut)
def get_my_cooperative(
    db: Session = Depends(get_db),
    current_user: User = Depends(deps.get_current_user)
) -> Any:
    """
    Get (or lazily create) the cooperative led by the current user.
    """
    coop = _get_or_create_own_cooperative(db, current_user)
    out = CooperativeOut.model_validate(coop)
    out.members_count = db.query(func.count(CooperativeMember.id)).filter(
        CooperativeMember.cooperative_id == coop.id,
        CooperativeMember.status == "active"
    ).scalar() or 0
    return out


@router.get("/members", response_model=List[CooperativeMemberOut])
def list_cooperative_members(
    db: Session = Depends(get_db),
    current_user: User = Depends(deps.get_current_user)
) -> Any:
    """
    Get the member directory (active, pending, and rejected) for the
    cooperative led by the current user.
    """
    coop = _get_or_create_own_cooperative(db, current_user)
    members = db.query(CooperativeMember).filter(CooperativeMember.cooperative_id == coop.id).all()
    return [_member_out(db, m, coop) for m in members]


@router.post("/members/invite", response_model=CooperativeMemberOut, status_code=status.HTTP_201_CREATED)
def invite_member(
    invite_in: CooperativeMemberInvite,
    db: Session = Depends(get_db),
    current_user: User = Depends(deps.get_current_user)
) -> Any:
    """
    Invite a farmer to the current user's cooperative by phone number or
    email. The invite sits as 'pending' until the invited farmer accepts or
    declines it via /members/{id}/respond — a leader cannot unilaterally
    enroll someone, since that would expose the farmer's listings in the
    cooperative directory without their consent.
    """
    coop = _get_or_create_own_cooperative(db, current_user)

    identifier = invite_in.identifier.strip()
    target = user_service.get_user_by_email(db, email=identifier) or user_service.get_user_by_phone(db, phone=identifier)
    if not target:
        raise HTTPException(status_code=404, detail=errors.USER_NOT_FOUND)
    if target.id == current_user.id:
        raise HTTPException(status_code=400, detail=errors.CANNOT_INVITE_SELF)

    existing = db.query(CooperativeMember).filter(
        CooperativeMember.cooperative_id == coop.id,
        CooperativeMember.farmer_id == target.id
    ).first()
    if existing:
        raise HTTPException(status_code=400, detail=errors.COOPERATIVE_MEMBER_ALREADY_EXISTS)

    member = CooperativeMember(cooperative_id=coop.id, farmer_id=target.id, status="pending")
    db.add(member)
    db.commit()
    db.refresh(member)
    return _member_out(db, member, coop)


@router.get("/my-invitations", response_model=List[CooperativeMemberOut])
def list_my_invitations(
    db: Session = Depends(get_db),
    current_user: User = Depends(deps.get_current_user)
) -> Any:
    """
    Pending cooperative invitations addressed to the current user.
    """
    members = db.query(CooperativeMember).filter(
        CooperativeMember.farmer_id == current_user.id,
        CooperativeMember.status == "pending"
    ).all()
    return [_member_out(db, m) for m in members]


@router.put("/members/{member_id}/respond", response_model=CooperativeMemberOut)
def respond_to_invitation(
    member_id: str,
    status_in: CooperativeMemberStatusUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(deps.get_current_user)
) -> Any:
    """
    The invited farmer accepts ('active') or declines ('rejected') a pending
    cooperative invitation. Only the invitee may respond to their own invite.
    """
    member = db.query(CooperativeMember).filter(CooperativeMember.id == member_id).first()
    if not member:
        raise HTTPException(status_code=404, detail=errors.COOPERATIVE_MEMBER_NOT_FOUND)
    if member.farmer_id != current_user.id:
        raise HTTPException(status_code=403, detail=errors.NOT_AUTHORIZED)

    new_status = status_in.status.lower()
    if new_status not in ("active", "rejected"):
        raise HTTPException(status_code=400, detail=errors.VALIDATION_ERROR)

    member.status = new_status
    db.commit()
    db.refresh(member)
    return _member_out(db, member)


@router.delete("/members/{member_id}", status_code=status.HTTP_204_NO_CONTENT, response_model=None)
def remove_member(
    member_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(deps.get_current_user)
) -> None:
    """
    Remove a member (or withdraw a pending invite) from the cooperative.
    Only the cooperative's leader may act.
    """
    member = db.query(CooperativeMember).filter(CooperativeMember.id == member_id).first()
    if not member:
        raise HTTPException(status_code=404, detail=errors.COOPERATIVE_MEMBER_NOT_FOUND)
    coop = db.query(Cooperative).filter(Cooperative.id == member.cooperative_id).first()
    if not coop or coop.leader_id != current_user.id:
        raise HTTPException(status_code=403, detail=errors.NOT_AUTHORIZED)

    db.delete(member)
    db.commit()


@router.get("/stock-summary", response_model=List[StockSummaryItem])
def get_stock_summary(
    db: Session = Depends(get_db),
    current_user: User = Depends(deps.get_current_user)
) -> Any:
    """
    Aggregated available stock across the cooperative's active members
    (plus the leader's own listings), grouped by crop name + unit.
    """
    coop = _get_or_create_own_cooperative(db, current_user)
    active_farmer_ids = [
        m.farmer_id for m in db.query(CooperativeMember).filter(
            CooperativeMember.cooperative_id == coop.id,
            CooperativeMember.status == "active"
        ).all()
    ]
    farmer_ids = list(set(active_farmer_ids + [current_user.id]))

    rows = db.query(
        Product.product_name,
        Product.unit_type,
        func.sum(Product.quantity_available),
        func.count(func.distinct(Product.seller_id)),
    ).filter(
        Product.seller_id.in_(farmer_ids),
        Product.status == "active"
    ).group_by(Product.product_name, Product.unit_type).all()

    return [
        StockSummaryItem(
            crop_name=name,
            unit=unit,
            total_quantity=float(qty or 0),
            farms_count=farms
        )
        for name, unit, qty, farms in rows
    ]
