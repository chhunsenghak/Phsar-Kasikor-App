from datetime import datetime, timezone
from typing import List, Optional
from sqlalchemy.orm import Session

from app.models.dispute import Dispute
from app.models.order import Order
from app.models.user import User
from app.models.role import Role
from app.schemas.dispute import DisputeCreate, DisputeResolve
from app.schemas.notification import NotificationCreate
from app.services import notification_service


def create_dispute(db: Session, dispute_in: DisputeCreate, raised_by: str) -> Dispute:
    order = db.query(Order).filter(Order.id == dispute_in.order_id).first()
    if not order:
        raise Exception("ORDER_NOT_FOUND")
    if order.buyer_id != raised_by and order.seller_id != raised_by:
        raise Exception("NOT_AUTHORIZED")

    existing_open = (
        db.query(Dispute)
        .filter(Dispute.order_id == order.id, Dispute.status == "OPEN")
        .first()
    )
    if existing_open:
        raise Exception("DISPUTE_ALREADY_OPEN")

    dispute = Dispute(
        order_id=order.id,
        raised_by=raised_by,
        reason=dispute_in.reason,
        status="OPEN",
    )
    db.add(dispute)
    db.commit()
    db.refresh(dispute)

    # Notify every admin — a dispute otherwise has no signal telling anyone
    # to look at the resolution queue.
    try:
        admin_ids = [
            u.id for u in db.query(User).join(User.roles).filter(Role.name == "ADMIN").all()
        ]
        for admin_id in admin_ids:
            notification_service.create_notification(
                db,
                notification_in=NotificationCreate(
                    user_id=admin_id,
                    title="New Dispute Raised",
                    message=f"A dispute was raised on order #{order.id[:8].upper()}.",
                    is_read=False
                )
            )
    except Exception:
        pass

    return dispute


def get_disputes_for_user(db: Session, user_id: str, skip: int = 0, limit: int = 100) -> List[Dispute]:
    return (
        db.query(Dispute)
        .filter(Dispute.raised_by == user_id)
        .order_by(Dispute.created_at.desc())
        .offset(skip)
        .limit(limit)
        .all()
    )


def get_all_disputes(db: Session, skip: int = 0, limit: int = 100) -> List[Dispute]:
    return (
        db.query(Dispute)
        .order_by(Dispute.created_at.desc())
        .offset(skip)
        .limit(limit)
        .all()
    )


def get_dispute(db: Session, dispute_id: str) -> Optional[Dispute]:
    return db.query(Dispute).filter(Dispute.id == dispute_id).first()


def resolve_dispute(db: Session, dispute: Dispute, resolve_in: DisputeResolve) -> Dispute:
    if dispute.status != "OPEN":
        raise Exception("DISPUTE_ALREADY_RESOLVED")
    if resolve_in.status not in ("RESOLVED_REFUND", "RESOLVED_REJECTED"):
        raise Exception("INVALID_DISPUTE_STATUS")

    dispute.status = resolve_in.status
    dispute.resolution_note = resolve_in.resolution_note
    dispute.resolved_at = datetime.now(timezone.utc)

    if resolve_in.status == "RESOLVED_REFUND":
        order = db.query(Order).filter(Order.id == dispute.order_id).first()
        if order:
            order.payment_status = "REFUNDED"
            dispute.refund_amount = (
                resolve_in.refund_amount
                if resolve_in.refund_amount is not None
                else float(order.total_amount)
            )

    db.commit()
    db.refresh(dispute)

    try:
        notification_service.create_notification(
            db,
            notification_in=NotificationCreate(
                user_id=dispute.raised_by,
                title="Dispute Resolved",
                message=f"Your dispute has been {'refunded' if resolve_in.status == 'RESOLVED_REFUND' else 'reviewed and closed'}.",
                is_read=False
            )
        )
    except Exception:
        pass

    return dispute
