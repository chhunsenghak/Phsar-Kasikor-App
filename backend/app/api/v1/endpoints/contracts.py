from typing import Any, List
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.api import deps
from app.models.user import User
from app.schemas.contract import ContractCreate, ContractOut, ContractUpdate
from app.core import errors
from app.services import contract_service

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


