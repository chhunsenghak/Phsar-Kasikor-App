from typing import Any, List
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy import func

from app.api import deps
from app.core.database import get_db
from app.models.user import User
from app.models.product import Product
from app.models.cooperative import Cooperative, CooperativeMember
from app.schemas.cooperative import CooperativeMemberOut, CooperativeOut

router = APIRouter()

@router.get("/members", response_model=List[CooperativeMemberOut])
def list_cooperative_members(
    db: Session = Depends(get_db),
    current_user: User = Depends(deps.get_current_user)
) -> Any:
    """
    Get cooperative member directory for current user's cooperative or default local cooperative.
    """
    # Find cooperative where current user is leader or member
    coop = db.query(Cooperative).filter(Cooperative.leader_id == current_user.id).first()
    if not coop:
        # Create default cooperative if none exists for leader
        coop = Cooperative(
            leader_id=current_user.id,
            name="Battambang Agricultural Cooperative",
            province=current_user.province or "Battambang",
            description="B2B Farmers Alliance"
        )
        db.add(coop)
        db.commit()
        db.refresh(coop)

    members = db.query(CooperativeMember).filter(CooperativeMember.cooperative_id == coop.id).all()
    
    # Seed default members if coop has no members yet
    if not members:
        all_farmers = db.query(User).limit(5).all()
        for f in all_farmers:
            if f.id != current_user.id:
                m = CooperativeMember(
                    cooperative_id=coop.id,
                    farmer_id=f.id,
                    status="active"
                )
                db.add(m)
        db.commit()
        members = db.query(CooperativeMember).filter(CooperativeMember.cooperative_id == coop.id).all()

    results = []
    for m in members:
        m_out = CooperativeMemberOut.model_validate(m)
        farmer = db.query(User).filter(User.id == m.farmer_id).first()
        m_out.farmer_name = farmer.username if farmer else "Sok Farmer"
        m_out.location = f"{farmer.district or 'Sangkae'}, {farmer.province or 'Battambang'}" if farmer else "Battambang"
        m_out.products_count = db.query(func.count(Product.id)).filter(Product.seller_id == m.farmer_id).scalar() or 0
        results.append(m_out)

    return results
