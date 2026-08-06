from datetime import datetime, timezone
from typing import List, Optional
from sqlalchemy.orm import Session
from app.models.contract import Contract, ContractItem
from app.models.product import Product
from app.schemas.contract import ContractCreate, ContractUpdate
from app.core import errors
from app.schemas.notification import NotificationCreate
from app.services import notification_service

def get_contract(db: Session, contract_id: str) -> Optional[Contract]:
    return db.query(Contract).filter(Contract.id == contract_id).first()

def get_contracts_for_user(db: Session, user_id: str, skip: int = 0, limit: int = 100) -> List[Contract]:
    return db.query(Contract).filter(
        (Contract.seller_id == user_id) | (Contract.buyer_id == user_id)
    ).offset(skip).limit(limit).all()

def create_contract(db: Session, contract_in: ContractCreate, proposer_id: str) -> Contract:
    # First validate all products ownership
    for item in contract_in.items:
        product = db.query(Product).filter(Product.id == item.product_id).first()
        if not product:
            raise Exception(errors.PRODUCT_NOT_FOUND)
        if product.seller_id != contract_in.seller_id:
            raise Exception(errors.CONTRACT_PRODUCT_OWNER_MISMATCH)

    db_contract = Contract(
        seller_id=contract_in.seller_id,
        buyer_id=contract_in.buyer_id,
        terms_description=contract_in.terms_description,
        start_date=contract_in.start_date,
        end_date=contract_in.end_date,
        contract_status=contract_in.contract_status
    )
    db.add(db_contract)
    db.flush() # Generate ID

    for item in contract_in.items:
        db_item = ContractItem(
            contract_id=db_contract.id,
            product_id=item.product_id,
            agreed_price=item.agreed_price,
            agreed_quantity=item.agreed_quantity,
            unit_type=item.unit_type
        )
        db.add(db_item)

    db.commit()
    db.refresh(db_contract)

    # Trigger notification to the other party
    try:
        notify_user_id = contract_in.buyer_id if proposer_id == contract_in.seller_id else contract_in.seller_id
        notification_service.create_notification(
            db,
            notification_in=NotificationCreate(
                user_id=notify_user_id,
                title="New Contract Proposed",
                message="A new contract agreement has been proposed to you.",
                is_read=False
            )
        )
    except Exception:
        pass

    return db_contract

def update_contract(db: Session, db_contract: Contract, contract_update: ContractUpdate, updater_id: str) -> Contract:
    old_status = db_contract.contract_status
    update_data = contract_update.model_dump(exclude_unset=True)

    if old_status in ("TERMINATED", "COMPLETED") and update_data:
        raise Exception(errors.CONTRACT_ALREADY_RESOLVED)

    # Only the seller can activate a contract — that's the real acceptance
    # of the deal. Without this, the buyer could unilaterally flip their own
    # proposal to ACTIVE with no actual confirmation from the farmer.
    if update_data.get("contract_status") == "ACTIVE" and updater_id != db_contract.seller_id:
        raise Exception(errors.ONLY_SELLER_CAN_ACTIVATE_CONTRACT)

    new_start_date = update_data.get("start_date")
    new_end_date = update_data.get("end_date")
    
    if new_start_date is not None or new_end_date is not None:
        start_date = new_start_date if new_start_date is not None else db_contract.start_date
        end_date = new_end_date if new_end_date is not None else db_contract.end_date
        
        if start_date.tzinfo is None:
            start_date = start_date.replace(tzinfo=timezone.utc)
        if end_date.tzinfo is None:
            end_date = end_date.replace(tzinfo=timezone.utc)
            
        now_utc = datetime.now(timezone.utc)
        if start_date <= now_utc:
            raise Exception(errors.START_DATE_MUST_BE_IN_FUTURE)
        if end_date <= start_date:
            raise Exception(errors.END_DATE_MUST_BE_AFTER_START_DATE)
            
    # Process items update first
    if "items" in update_data:
        new_items = update_data.pop("items")
        # Check if contract is currently in DRAFT status
        if db_contract.contract_status != "DRAFT":
            raise Exception(errors.CANNOT_MODIFY_ITEMS_AFTER_DRAFT)
        
        # Validate all products ownership
        for item_data in new_items:
            product = db.query(Product).filter(Product.id == item_data["product_id"]).first()
            if not product:
                raise Exception(errors.PRODUCT_NOT_FOUND)
            if product.seller_id != db_contract.seller_id:
                raise Exception(errors.CONTRACT_PRODUCT_OWNER_MISMATCH)
        
        # Clear existing items (delete-orphan cascade deletes from DB)
        db_contract.items.clear()
        
        # Create and link new items
        for item_data in new_items:
            db_item = ContractItem(
                contract_id=db_contract.id,
                product_id=item_data["product_id"],
                agreed_price=item_data["agreed_price"],
                agreed_quantity=item_data["agreed_quantity"],
                unit_type=item_data["unit_type"]
            )
            db_contract.items.append(db_item)

    # Process remaining fields
    for field, value in update_data.items():
        setattr(db_contract, field, value)
        
    db.commit()
    db.refresh(db_contract)

    # Trigger notification if status transitions to ACTIVE
    if contract_update.contract_status == "ACTIVE" and old_status != "ACTIVE":
        try:
            notify_user_id = db_contract.buyer_id if updater_id == db_contract.seller_id else db_contract.seller_id
            notification_service.create_notification(
                db,
                notification_in=NotificationCreate(
                    user_id=notify_user_id,
                    title="Contract Activated",
                    message="The contract agreement is now ACTIVE.",
                    is_read=False
                )
            )
        except Exception:
            pass

    return db_contract


