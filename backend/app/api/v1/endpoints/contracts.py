from typing import Any, List
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.api import deps
from app.models.user import User
from app.schemas.contract import ContractCreate, ContractOut, ContractUpdate
from app.schemas.payment import KHQROut, PaymentStatusOut
from app.core import errors
from app.services import contract_service, khqr_service

router = APIRouter()

@router.get("/", response_model=List[ContractOut])
def read_contracts(
    db: Session = Depends(deps.get_db),
    skip: int = 0,
    limit: int = 100,
    current_user: User = Depends(deps.get_current_user)
) -> Any:
    """
    Retrieve all wholesale farming agreements proposed or signed by current user.
    """
    return contract_service.get_contracts_for_user(db, user_id=current_user.id, skip=skip, limit=limit)

@router.post("/", response_model=ContractOut, status_code=status.HTTP_201_CREATED)
def create_contract(
    contract_in: ContractCreate,
    db: Session = Depends(deps.get_db),
    current_user: User = Depends(deps.get_current_user)
) -> Any:
    """
    Propose a new digital contract farming agreement. Must be a transaction actor.
    """
    if contract_in.seller_id != current_user.id and contract_in.buyer_id != current_user.id:
        raise HTTPException(status_code=400, detail="Current user must be one of the contract parties")
    try:
        return contract_service.create_contract(db, contract_in=contract_in, proposer_id=current_user.id)
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@router.get("/admin/pending-deposits", response_model=List[ContractOut])
def read_pending_contract_deposits(
    db: Session = Depends(deps.get_db),
    skip: int = 0,
    limit: int = 100,
    _current_user: User = Depends(deps.get_current_admin_user)
) -> Any:
    """
    Every contract still awaiting deposit confirmation — the admin queue for
    the manual-confirm fallback. Admin-only, and must be declared before
    /{contract_id} so "admin" doesn't get swallowed as a contract_id segment.
    """
    return contract_service.get_pending_contract_deposits(db, skip=skip, limit=limit)

@router.get("/admin/pending-final-payments", response_model=List[ContractOut])
def read_pending_contract_final_payments(
    db: Session = Depends(deps.get_db),
    skip: int = 0,
    limit: int = 100,
    _current_user: User = Depends(deps.get_current_admin_user)
) -> Any:
    """
    Every contract still awaiting final-payment confirmation — the admin
    queue for the manual-confirm fallback. Admin-only, and must be declared
    before /{contract_id} for the same reason as pending-deposits above.
    """
    return contract_service.get_pending_contract_final_payments(db, skip=skip, limit=limit)

@router.get("/admin/all", response_model=List[ContractOut])
def read_all_contracts(
    db: Session = Depends(deps.get_db),
    skip: int = 0,
    limit: int = 100,
    _current_user: User = Depends(deps.get_current_admin_user)
) -> Any:
    """
    Every wholesale agreement platform-wide, regardless of buyer/seller — the
    admin "wholesale history" view. Admin-only, and must be declared before
    /{contract_id} for the same reason as the pending-* routes above.
    """
    return contract_service.get_all_contracts(db, skip=skip, limit=limit)

@router.get("/{contract_id}", response_model=ContractOut)
def read_contract(
    contract_id: str,
    db: Session = Depends(deps.get_db),
    current_user: User = Depends(deps.get_current_user)
) -> Any:
    """
    Retrieve contract details. Only contract parties can view.
    """
    db_contract = contract_service.get_contract(db, contract_id=contract_id)
    if not db_contract:
        raise HTTPException(status_code=404, detail=errors.CONTRACT_NOT_FOUND)
    if db_contract.seller_id != current_user.id and db_contract.buyer_id != current_user.id:
        raise HTTPException(status_code=403, detail=errors.NOT_AUTHORIZED)
    return db_contract

@router.put("/{contract_id}", response_model=ContractOut)
def update_contract(
    contract_id: str,
    contract_update: ContractUpdate,
    db: Session = Depends(deps.get_db),
    current_user: User = Depends(deps.get_current_user)
) -> Any:
    """
    Modify or sign proposed contract farming terms. Only contract parties can update.
    """
    db_contract = contract_service.get_contract(db, contract_id=contract_id)
    if not db_contract:
        raise HTTPException(status_code=404, detail=errors.CONTRACT_NOT_FOUND)
    if db_contract.seller_id != current_user.id and db_contract.buyer_id != current_user.id:
        raise HTTPException(status_code=403, detail=errors.NOT_AUTHORIZED)
    try:
        return contract_service.update_contract(db, db_contract=db_contract, contract_update=contract_update, updater_id=current_user.id)
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@router.post("/{contract_id}/deposit/khqr", response_model=KHQROut)
def generate_contract_deposit_khqr(
    contract_id: str,
    db: Session = Depends(deps.get_db),
    current_user: User = Depends(deps.get_current_user)
) -> Any:
    """
    Generate the buyer's booking-deposit KHQR for an accepted contract.
    Buyer-only — it's their deposit. Reuses khqr_service exactly as
    payments.py does, including idempotent re-generation: re-calling this
    while still pending returns the same md5/qr_string rather than minting
    a fresh one (which would silently orphan a QR the buyer already paid).
    """
    db_contract = contract_service.get_contract(db, contract_id=contract_id)
    if not db_contract:
        raise HTTPException(status_code=404, detail=errors.CONTRACT_NOT_FOUND)
    if db_contract.buyer_id != current_user.id:
        raise HTTPException(status_code=403, detail=errors.NOT_AUTHORIZED)
    if db_contract.contract_status != "PENDING_DEPOSIT" or not db_contract.deposit_amount:
        raise HTTPException(status_code=400, detail=errors.CONTRACT_DEPOSIT_NOT_SET)

    if db_contract.deposit_khqr_md5 and db_contract.deposit_khqr_qr_string:
        return KHQROut(
            qr_string=db_contract.deposit_khqr_qr_string,
            md5=db_contract.deposit_khqr_md5,
            qr_image_base64=khqr_service.render_qr_image(db_contract.deposit_khqr_qr_string),
        )

    result = khqr_service.generate_khqr(
        amount=float(db_contract.deposit_amount),
        currency=db_contract.deposit_currency,
        bill_number=f"DEP{db_contract.id[:5].upper()}",
    )
    db_contract.deposit_khqr_md5 = result["md5"]
    db_contract.deposit_khqr_qr_string = result["qr_string"]
    db.commit()

    return KHQROut(**result)

@router.post("/{contract_id}/deposit/khqr/{md5_hash}/confirm", response_model=PaymentStatusOut)
def confirm_contract_deposit_khqr(
    contract_id: str,
    md5_hash: str,
    db: Session = Depends(deps.get_db),
    current_user: User = Depends(deps.get_current_user)
) -> Any:
    """
    Re-verifies the deposit KHQR against Bakong and, only on a confirmed
    "paid", activates the contract. Buyer-only. This is also called
    automatically every time the contract is read (see
    contract_service.get_contract), so tracking works even if the buyer
    never taps anything here themselves.
    """
    db_contract = contract_service.get_contract(db, contract_id=contract_id)
    if not db_contract:
        raise HTTPException(status_code=404, detail=errors.CONTRACT_NOT_FOUND)
    if db_contract.buyer_id != current_user.id:
        raise HTTPException(status_code=403, detail=errors.NOT_AUTHORIZED)
    if db_contract.deposit_khqr_md5 != md5_hash:
        raise HTTPException(status_code=404, detail=errors.CONTRACT_NOT_FOUND)

    status_str, _ = contract_service.verify_and_settle_contract_deposit(db, md5_hash)
    return PaymentStatusOut(status=status_str)

@router.post("/{contract_id}/deposit/confirm-payment", response_model=ContractOut)
def confirm_contract_deposit_by_admin(
    contract_id: str,
    db: Session = Depends(deps.get_db),
    _current_user: User = Depends(deps.get_current_admin_user)
) -> Any:
    """
    Support-only escape hatch for a contract deposit stuck PENDING_DEPOSIT
    despite really being paid — mirrors orders.py's confirm_order_payment.
    Admin-only: the deposit pays into the platform's own merchant account,
    not the seller's, so only admin has any firsthand basis to override it.
    """
    db_contract = contract_service.get_contract(db, contract_id=contract_id)
    if not db_contract:
        raise HTTPException(status_code=404, detail=errors.CONTRACT_NOT_FOUND)
    try:
        return contract_service.confirm_contract_deposit_by_admin(db, db_contract=db_contract)
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@router.post("/{contract_id}/final-payment/khqr", response_model=KHQROut)
def generate_contract_final_payment_khqr(
    contract_id: str,
    db: Session = Depends(deps.get_db),
    current_user: User = Depends(deps.get_current_user)
) -> Any:
    """
    Generate the buyer's final-balance KHQR once the seller has requested
    it. Buyer-only. Same idempotent-reuse behavior as the deposit KHQR
    above — re-calling this while still pending returns the same
    md5/qr_string rather than minting a fresh one.
    """
    db_contract = contract_service.get_contract(db, contract_id=contract_id)
    if not db_contract:
        raise HTTPException(status_code=404, detail=errors.CONTRACT_NOT_FOUND)
    if db_contract.buyer_id != current_user.id:
        raise HTTPException(status_code=403, detail=errors.NOT_AUTHORIZED)
    if db_contract.contract_status != "PENDING_FINAL_PAYMENT" or not db_contract.final_amount:
        raise HTTPException(status_code=400, detail=errors.CONTRACT_FINAL_PAYMENT_NOT_SET)

    if db_contract.final_khqr_md5 and db_contract.final_khqr_qr_string:
        return KHQROut(
            qr_string=db_contract.final_khqr_qr_string,
            md5=db_contract.final_khqr_md5,
            qr_image_base64=khqr_service.render_qr_image(db_contract.final_khqr_qr_string),
        )

    result = khqr_service.generate_khqr(
        amount=float(db_contract.final_amount),
        currency=db_contract.deposit_currency,
        bill_number=f"FIN{db_contract.id[:5].upper()}",
    )
    db_contract.final_khqr_md5 = result["md5"]
    db_contract.final_khqr_qr_string = result["qr_string"]
    db.commit()

    return KHQROut(**result)

@router.post("/{contract_id}/final-payment/khqr/{md5_hash}/confirm", response_model=PaymentStatusOut)
def confirm_contract_final_payment_khqr(
    contract_id: str,
    md5_hash: str,
    db: Session = Depends(deps.get_db),
    current_user: User = Depends(deps.get_current_user)
) -> Any:
    """
    Re-verifies the final-payment KHQR against Bakong and, only on a
    confirmed "paid", completes the contract. Buyer-only. Also called
    automatically every time the contract is read (see
    contract_service.get_contract).
    """
    db_contract = contract_service.get_contract(db, contract_id=contract_id)
    if not db_contract:
        raise HTTPException(status_code=404, detail=errors.CONTRACT_NOT_FOUND)
    if db_contract.buyer_id != current_user.id:
        raise HTTPException(status_code=403, detail=errors.NOT_AUTHORIZED)
    if db_contract.final_khqr_md5 != md5_hash:
        raise HTTPException(status_code=404, detail=errors.CONTRACT_NOT_FOUND)

    status_str, _ = contract_service.verify_and_settle_contract_final_payment(db, md5_hash)
    return PaymentStatusOut(status=status_str)

@router.post("/{contract_id}/final-payment/confirm-payment", response_model=ContractOut)
def confirm_contract_final_payment_by_admin(
    contract_id: str,
    db: Session = Depends(deps.get_db),
    _current_user: User = Depends(deps.get_current_admin_user)
) -> Any:
    """
    Support-only escape hatch for a contract final payment stuck
    PENDING_FINAL_PAYMENT despite really being paid — mirrors the deposit
    admin override above.
    """
    db_contract = contract_service.get_contract(db, contract_id=contract_id)
    if not db_contract:
        raise HTTPException(status_code=404, detail=errors.CONTRACT_NOT_FOUND)
    try:
        return contract_service.confirm_contract_final_payment_by_admin(db, db_contract=db_contract)
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))
