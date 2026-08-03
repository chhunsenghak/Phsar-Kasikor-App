from typing import Any, List
from datetime import datetime, timezone
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.api import deps
from app.core.database import get_db
from app.models.user import User
from app.models.product import Product
from app.models.forum import ForumPost
from app.models.content_report import ContentReport
from app.schemas.content_report import ContentReportCreate, ContentReportOut, ContentReportResolve

router = APIRouter()

@router.post("/products/{product_id}/report", response_model=ContentReportOut, status_code=status.HTTP_201_CREATED)
def report_product(
    product_id: str,
    report_in: ContentReportCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(deps.get_current_user)
) -> Any:
    """
    User reports a product listing for policy violations or prohibited content.
    """
    product = db.query(Product).filter(Product.id == product_id).first()
    if not product:
        raise HTTPException(status_code=404, detail="Product not found")

    report = ContentReport(
        reporter_id=current_user.id,
        product_id=product_id,
        reason=report_in.reason,
        status="pending"
    )
    db.add(report)
    db.commit()
    db.refresh(report)

    r_out = ContentReportOut.model_validate(report)
    r_out.reporter_name = current_user.username
    r_out.product_name = product.product_name
    return r_out

@router.get("/admin/reports", response_model=List[ContentReportOut])
def get_content_reports(
    db: Session = Depends(get_db),
    skip: int = 0,
    limit: int = 100,
    current_user: User = Depends(deps.get_current_user)
) -> Any:
    """
    List all content moderation reports for Admin audit queue.
    """
    reports = db.query(ContentReport).order_by(ContentReport.created_at.desc()).offset(skip).limit(limit).all()
    results = []
    for r in reports:
        r_out = ContentReportOut.model_validate(r)
        reporter = db.query(User).filter(User.id == r.reporter_id).first()
        r_out.reporter_name = reporter.username if reporter else "User"

        if r.product_id:
            prod = db.query(Product).filter(Product.id == r.product_id).first()
            r_out.product_name = prod.product_name if prod else "Product Listing"

        if r.post_id:
            post = db.query(ForumPost).filter(ForumPost.id == r.post_id).first()
            r_out.post_title = post.title if post else "Forum Thread"

        results.append(r_out)
    return results

@router.put("/admin/reports/{report_id}/resolve", response_model=ContentReportOut)
def resolve_content_report(
    report_id: str,
    resolve_in: ContentReportResolve,
    db: Session = Depends(get_db),
    current_user: User = Depends(deps.get_current_user)
) -> Any:
    """
    Admin resolves or dismisses a reported content flag.
    """
    report = db.query(ContentReport).filter(ContentReport.id == report_id).first()
    if not report:
        raise HTTPException(status_code=404, detail="Content report not found")

    report.status = resolve_in.status.lower()
    report.admin_feedback = resolve_in.admin_feedback
    report.reviewed_at = datetime.now(timezone.utc)

    # If action was resolved and product reported, mark product inactive
    if resolve_in.status.lower() == "resolved" and report.product_id:
        prod = db.query(Product).filter(Product.id == report.product_id).first()
        if prod:
            prod.status = "inactive"

    db.commit()
    db.refresh(report)

    r_out = ContentReportOut.model_validate(report)
    reporter = db.query(User).filter(User.id == report.reporter_id).first()
    r_out.reporter_name = reporter.username if reporter else "User"
    return r_out
