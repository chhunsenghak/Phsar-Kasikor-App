from datetime import datetime, timezone
from typing import List, Optional, Tuple
from sqlalchemy.orm import Session
from app.models.contract import Contract, ContractItem
from app.models.product import Product
from app.schemas.contract import ContractCreate, ContractUpdate
from app.core import errors
from app.schemas.notification import NotificationCreate
from app.services import khqr_service, notification_service, order_service

def _round_for_currency(amount: float, currency: str) -> float:
    # Riel has no practical fractional denomination in daily use, unlike USD
    # cents — mirrors order_service._delivery_fee_for's same rule.
    return round(amount / 100) * 100 if currency == "KHR" else round(amount, 2)

def verify_and_settle_contract_deposit(db: Session, md5_hash: str) -> Tuple[str, Optional[Contract]]:
    """
    Re-checks the given KHQR against Bakong and, only on a confirmed "paid",
    flips the matching still-PENDING_DEPOSIT contract to ACTIVE. This is the
    single place contract_status ever becomes ACTIVE — mirrors
    order_service.verify_and_settle_khqr exactly, including reusing
    khqr_service.check_payment_status unchanged (same True/False/None
    handling, same daily-call-limit-safe cooldown).
    Returns ("paid", contract) / ("unpaid", None) / ("unavailable", None).
    """
    db_contract = db.query(Contract).filter(
        Contract.deposit_khqr_md5 == md5_hash,
        Contract.contract_status == "PENDING_DEPOSIT",
    ).first()
    if not db_contract:
        return ("unpaid", None)

    paid = khqr_service.check_payment_status(md5_hash)
    if paid is None:
        return ("unavailable", None)
    if paid is False:
        return ("unpaid", None)

    db_contract.deposit_status = "PAID"
    db_contract.contract_status = "ACTIVE"
    db.commit()
    db.refresh(db_contract)

    for user_id in (db_contract.buyer_id, db_contract.seller_id):
        try:
            notification_service.create_notification(
                db,
                notification_in=NotificationCreate(
                    user_id=user_id,
                    title="Contract Activated",
                    message="The deposit has been received — the contract agreement is now ACTIVE.",
                    is_read=False
                )
            )
        except Exception:
            pass

    return ("paid", db_contract)

def _settle_final_payment(db: Session, db_contract: Contract) -> Contract:
    """
    The single place a contract ever moves off PENDING_FINAL_PAYMENT — called
    once the final payment is confirmed paid (via Bakong, an admin override,
    or immediately if the deposit already covered everything and there's
    nothing left to collect). Hands fulfillment off to a real Order (see
    order_service.create_order_from_contract) so delivery tracking
    (Confirm/Ship/Deliver, the live-map tracking screen) reuses the order
    system entirely instead of a second parallel implementation — the
    contract only reaches COMPLETED once that order is actually DELIVERED
    (see complete_contract_from_fulfillment).
    """
    db_contract.final_payment_status = "PAID"
    db_order = order_service.create_order_from_contract(db, db_contract)
    db_contract.fulfillment_order_id = db_order.id
    db_contract.contract_status = "IN_FULFILLMENT"
    db.commit()
    db.refresh(db_contract)

    for user_id in (db_contract.buyer_id, db_contract.seller_id):
        try:
            notification_service.create_notification(
                db,
                notification_in=NotificationCreate(
                    user_id=user_id,
                    title="Final Payment Received",
                    message="The final payment has cleared — track your delivery from the Contracts tab.",
                    is_read=False
                )
            )
        except Exception:
            pass

    return db_contract

def verify_and_settle_contract_final_payment(db: Session, md5_hash: str) -> Tuple[str, Optional[Contract]]:
    """
    Re-checks the given KHQR against Bakong and, only on a confirmed "paid",
    hands the matching still-PENDING_FINAL_PAYMENT contract off to
    fulfillment (see _settle_final_payment) — mirrors
    verify_and_settle_contract_deposit exactly up to that point.
    Returns ("paid", contract) / ("unpaid", None) / ("unavailable", None).
    """
    db_contract = db.query(Contract).filter(
        Contract.final_khqr_md5 == md5_hash,
        Contract.contract_status == "PENDING_FINAL_PAYMENT",
    ).first()
    if not db_contract:
        return ("unpaid", None)

    paid = khqr_service.check_payment_status(md5_hash)
    if paid is None:
        return ("unavailable", None)
    if paid is False:
        return ("unpaid", None)

    _settle_final_payment(db, db_contract)
    return ("paid", db_contract)

def complete_contract_from_fulfillment(db: Session, order_id: str) -> Optional[Contract]:
    """
    Called from the order endpoint once an order reaches DELIVERED (see
    endpoints/orders.py's update_order) — if that order was created from a
    contract, this is the only place contract_status ever becomes
    COMPLETED. Returns None if the order wasn't contract-derived (the
    common case for ordinary orders) or the contract already resolved.
    """
    db_contract = db.query(Contract).filter(
        Contract.fulfillment_order_id == order_id,
        Contract.contract_status == "IN_FULFILLMENT",
    ).first()
    if not db_contract:
        return None

    db_contract.contract_status = "COMPLETED"
    db.commit()
    db.refresh(db_contract)

    for user_id in (db_contract.buyer_id, db_contract.seller_id):
        try:
            notification_service.create_notification(
                db,
                notification_in=NotificationCreate(
                    user_id=user_id,
                    title="Contract Completed",
                    message="Delivery is complete — the contract has been fulfilled.",
                    is_read=False
                )
            )
        except Exception:
            pass

    return db_contract

def get_pending_contract_deposits(db: Session, skip: int = 0, limit: int = 100) -> List[Contract]:
    """
    Every contract still awaiting deposit confirmation — the admin queue for
    the manual-confirm fallback, used when automatic Bakong verification
    can't run (mirrors order_service.get_pending_khqr_payments).
    """
    return db.query(Contract).filter(
        Contract.contract_status == "PENDING_DEPOSIT",
    ).order_by(Contract.start_date.desc()).offset(skip).limit(limit).all()

def confirm_contract_deposit_by_admin(db: Session, db_contract: Contract) -> Contract:
    """
    Support-only escape hatch mirroring order_service.confirm_payment_by_admin
    — for a contract deposit stuck PENDING_DEPOSIT despite really being paid.
    Admin-only: the deposit pays into the platform's own merchant account,
    not the seller's, so only admin has any firsthand basis to override it.
    """
    if db_contract.contract_status != "PENDING_DEPOSIT":
        raise Exception(errors.CONTRACT_DEPOSIT_ALREADY_PAID)

    db_contract.deposit_status = "PAID"
    db_contract.contract_status = "ACTIVE"
    db.commit()
    db.refresh(db_contract)

    for user_id in (db_contract.buyer_id, db_contract.seller_id):
        try:
            notification_service.create_notification(
                db,
                notification_in=NotificationCreate(
                    user_id=user_id,
                    title="Contract Activated",
                    message="The deposit has been confirmed — the contract agreement is now ACTIVE.",
                    is_read=False
                )
            )
        except Exception:
            pass

    return db_contract

def get_pending_contract_final_payments(db: Session, skip: int = 0, limit: int = 100) -> List[Contract]:
    """
    Every contract still awaiting final-payment confirmation — the admin
    queue for the manual-confirm fallback, mirrors
    get_pending_contract_deposits above.
    """
    return db.query(Contract).filter(
        Contract.contract_status == "PENDING_FINAL_PAYMENT",
    ).order_by(Contract.start_date.desc()).offset(skip).limit(limit).all()

def confirm_contract_final_payment_by_admin(db: Session, db_contract: Contract) -> Contract:
    """
    Support-only escape hatch mirroring confirm_contract_deposit_by_admin —
    for a contract final payment stuck PENDING_FINAL_PAYMENT despite really
    being paid.
    """
    if db_contract.contract_status != "PENDING_FINAL_PAYMENT":
        raise Exception(errors.CONTRACT_FINAL_PAYMENT_ALREADY_PAID)

    return _settle_final_payment(db, db_contract)

def get_contract(db: Session, contract_id: str) -> Optional[Contract]:
    db_contract = db.query(Contract).filter(Contract.id == contract_id).first()

    # Piggyback a re-check onto every read of a contract still waiting on its
    # deposit or final payment — same automatic-tracking pattern as
    # order_service.get_order, so the buyer/seller never need a manual
    # confirm step.
    if (
        db_contract
        and db_contract.contract_status == "PENDING_DEPOSIT"
        and db_contract.deposit_khqr_md5
    ):
        verify_and_settle_contract_deposit(db, db_contract.deposit_khqr_md5)
        db.refresh(db_contract)
    elif (
        db_contract
        and db_contract.contract_status == "PENDING_FINAL_PAYMENT"
        and db_contract.final_khqr_md5
    ):
        verify_and_settle_contract_final_payment(db, db_contract.final_khqr_md5)
        db.refresh(db_contract)

    return db_contract

def get_contracts_for_user(db: Session, user_id: str, skip: int = 0, limit: int = 100) -> List[Contract]:
    return db.query(Contract).filter(
        (Contract.seller_id == user_id) | (Contract.buyer_id == user_id)
    ).offset(skip).limit(limit).all()

def create_contract(db: Session, contract_in: ContractCreate, proposer_id: str) -> Contract:
    if not contract_in.items:
        raise Exception(errors.NO_ITEMS_IN_CONTRACT)

    # First validate all products ownership, and that a single KHQR deposit
    # can even be generated for this contract later — a QR encodes exactly
    # one amount in one currency, same constraint Order enforces.
    currencies = set()
    for item in contract_in.items:
        product = db.query(Product).filter(Product.id == item.product_id).first()
        if not product:
            raise Exception(errors.PRODUCT_NOT_FOUND)
        if product.seller_id != contract_in.seller_id:
            raise Exception(errors.CONTRACT_PRODUCT_OWNER_MISMATCH)
        currencies.add(product.currency)
    if len(currencies) != 1:
        raise Exception(errors.MULTIPLE_CURRENCIES_IN_CONTRACT)

    # A buyer/seller pair can have any number of contracts open at once —
    # e.g. separate contracts for different crops or delivery windows — so
    # there is deliberately no "already have an open contract" check here.

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

    # IN_FULFILLMENT is included here too — once the final payment has
    # settled, terms/dates/items are no more editable than after COMPLETED;
    # fulfillment now proceeds entirely through the linked order instead.
    if old_status in ("TERMINATED", "COMPLETED", "IN_FULFILLMENT") and update_data:
        raise Exception(errors.CONTRACT_ALREADY_RESOLVED)

    requested_status = update_data.get("contract_status")

    # ACTIVE is never settable directly through this endpoint — it's only
    # ever reached once the buyer's deposit is verified paid (see
    # verify_and_settle_contract_deposit). Allowing a direct PUT here would
    # let either party skip the deposit entirely, defeating its whole point
    # as a trust signal.
    if requested_status == "ACTIVE":
        raise Exception(errors.CONTRACT_ACTIVATION_REQUIRES_DEPOSIT)

    # Same reasoning as the ACTIVE guard above — COMPLETED is only ever
    # reached once the buyer's final payment is verified paid (see
    # verify_and_settle_contract_final_payment). Previously nothing blocked
    # this, so either party could have marked a contract COMPLETED with a
    # raw PUT, skipping the final payment entirely.
    if requested_status == "COMPLETED":
        raise Exception(errors.CONTRACT_COMPLETION_REQUIRES_FINAL_PAYMENT)

    # Same reasoning again — IN_FULFILLMENT is only ever reached
    # automatically once the final payment settles (see
    # _settle_final_payment), never through a direct PUT.
    if requested_status == "IN_FULFILLMENT":
        raise Exception(errors.CONTRACT_FULFILLMENT_NOT_MANUAL)

    deposit_percentage = update_data.pop("deposit_percentage", None)
    delivery_method = update_data.pop("delivery_method", None)
    delivery_fee = update_data.pop("delivery_fee", None)

    # Accepting a proposal now means the seller sets a deposit percentage
    # and the contract moves to PENDING_DEPOSIT (not straight to ACTIVE) —
    # the buyer still has to actually pay that deposit. Only the seller can
    # do this, same reasoning as the old ACTIVE-only check: without it, the
    # buyer could unilaterally advance their own proposal.
    if requested_status == "PENDING_DEPOSIT":
        if old_status != "DRAFT":
            raise Exception(errors.INVALID_CONTRACT_STATUS_TRANSITION)
        if updater_id != db_contract.seller_id:
            raise Exception(errors.ONLY_SELLER_CAN_ACTIVATE_CONTRACT)
        if deposit_percentage is None:
            raise Exception(errors.DEPOSIT_PERCENTAGE_REQUIRED)

        currencies = {item.product.currency for item in db_contract.items}
        if len(currencies) != 1:
            raise Exception(errors.MULTIPLE_CURRENCIES_IN_CONTRACT)
        currency = currencies.pop()
        total_value = sum(float(item.agreed_price) * float(item.agreed_quantity) for item in db_contract.items)

        db_contract.deposit_percentage = deposit_percentage
        db_contract.deposit_amount = _round_for_currency(total_value * deposit_percentage / 100, currency)
        db_contract.deposit_currency = currency
        db_contract.deposit_status = "PENDING"

    # Requesting the final payment means the seller sets the delivery
    # method/fee (a plain seller-entered amount — never auto-calculated the
    # way order_service computes one from distance/weight, since a wholesale
    # contract's real transport cost usually isn't known until the seller
    # actually arranges it) and the contract moves to PENDING_FINAL_PAYMENT.
    # Only the seller can do this, same reasoning as the deposit step above.
    settle_immediately = False
    if requested_status == "PENDING_FINAL_PAYMENT":
        if old_status != "ACTIVE":
            raise Exception(errors.INVALID_CONTRACT_STATUS_TRANSITION)
        if updater_id != db_contract.seller_id:
            raise Exception(errors.ONLY_SELLER_CAN_REQUEST_FINAL_PAYMENT)
        if delivery_method not in ("DELIVERY", "PICKUP"):
            raise Exception(errors.DELIVERY_METHOD_REQUIRED)
        if delivery_method == "DELIVERY" and delivery_fee is None:
            raise Exception(errors.DELIVERY_FEE_REQUIRED)
        # PICKUP always skips a delivery charge, regardless of what (if
        # anything) was sent — mirrors order_service's PICKUP-skips-fee rule.
        resolved_delivery_fee = float(delivery_fee) if delivery_method == "DELIVERY" else 0.0

        currency = db_contract.deposit_currency
        total_value = sum(float(item.agreed_price) * float(item.agreed_quantity) for item in db_contract.items)
        deposit_paid = float(db_contract.deposit_amount or 0)
        remaining = max(total_value - deposit_paid, 0)
        final_amount = _round_for_currency(remaining + resolved_delivery_fee, currency)

        db_contract.delivery_method = delivery_method
        db_contract.delivery_fee = _round_for_currency(resolved_delivery_fee, currency)
        db_contract.final_amount = final_amount

        if final_amount <= 0:
            # Deposit already covered everything and there's no delivery
            # charge — nothing left to collect, so skip straight to
            # fulfillment (via _settle_final_payment, after this function's
            # own commit below) instead of generating a pointless $0 QR.
            # The goods still need to be delivered/picked up, so this must
            # NOT jump straight to COMPLETED.
            update_data.pop("contract_status", None)
            settle_immediately = True
        else:
            db_contract.final_payment_status = "PENDING"

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
        if not new_items:
            raise Exception(errors.NO_ITEMS_IN_CONTRACT)
        # Check if contract is currently in DRAFT status
        if db_contract.contract_status != "DRAFT":
            raise Exception(errors.CANNOT_MODIFY_ITEMS_AFTER_DRAFT)

        # Validate all products ownership, and that a single KHQR deposit can
        # still be generated later (one currency per contract).
        currencies = set()
        for item_data in new_items:
            product = db.query(Product).filter(Product.id == item_data["product_id"]).first()
            if not product:
                raise Exception(errors.PRODUCT_NOT_FOUND)
            if product.seller_id != db_contract.seller_id:
                raise Exception(errors.CONTRACT_PRODUCT_OWNER_MISMATCH)
            currencies.add(product.currency)
        if len(currencies) != 1:
            raise Exception(errors.MULTIPLE_CURRENCIES_IN_CONTRACT)

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

    # Notify the buyer once the seller has accepted and set a deposit — this
    # is the seller's "yes", even though the contract isn't ACTIVE until the
    # deposit actually clears.
    if requested_status == "PENDING_DEPOSIT" and old_status != "PENDING_DEPOSIT":
        try:
            notification_service.create_notification(
                db,
                notification_in=NotificationCreate(
                    user_id=db_contract.buyer_id,
                    title="Contract Accepted — Deposit Required",
                    message=f"The seller accepted your contract and requires a {db_contract.deposit_percentage:g}% deposit before it becomes active.",
                    is_read=False
                )
            )
        except Exception:
            pass

    # Once the seller requests the final payment — either the buyer still
    # owes something (PENDING_FINAL_PAYMENT, notify them) or the deposit
    # already covered everything (settle straight to fulfillment).
    if requested_status == "PENDING_FINAL_PAYMENT" and old_status != "PENDING_FINAL_PAYMENT":
        if settle_immediately:
            _settle_final_payment(db, db_contract)
        else:
            try:
                notification_service.create_notification(
                    db,
                    notification_in=NotificationCreate(
                        user_id=db_contract.buyer_id,
                        title="Final Payment Requested",
                        message=f"The seller is ready to deliver and requests the remaining {db_contract.final_amount:g} {db_contract.deposit_currency}.",
                        is_read=False
                    )
                )
            except Exception:
                pass

    return db_contract


