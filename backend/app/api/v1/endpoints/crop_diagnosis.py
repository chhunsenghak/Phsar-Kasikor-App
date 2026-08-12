from typing import Any, List
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.api import deps
from app.schemas.crop_diagnosis import (
    CropDiagnosisCreate, CropDiagnosisOut, CropDiagnosisUpdate, CropDiagnosisMatchResult
)
from app.services import crop_diagnosis_service

router = APIRouter()

@router.get("/", response_model=List[CropDiagnosisOut])
def read_crop_diagnoses(
    db: Session = Depends(deps.get_db),
    skip: int = 0,
    limit: int = 100,
) -> Any:
    """
    The Crop Advisor's "common issues" reference list — public, like
    market prices, since it's read-only agronomy reference data.
    """
    return crop_diagnosis_service.get_crop_diagnoses(db, skip=skip, limit=limit)

@router.get("/match", response_model=CropDiagnosisMatchResult)
def match_crop_symptoms(
    symptoms: str,
    db: Session = Depends(deps.get_db),
) -> Any:
    """
    Scores the given free-text symptom description against every reference
    row's keywords (see crop_diagnosis_service.match_symptoms) and returns
    the best match if it clears the confidence bar, or an honest "no
    confident match" result with whatever partially matched.
    """
    if not symptoms or not symptoms.strip():
        raise HTTPException(status_code=400, detail="SYMPTOMS_REQUIRED")
    return crop_diagnosis_service.match_symptoms(db, symptoms)

@router.post("/", response_model=CropDiagnosisOut, status_code=status.HTTP_201_CREATED)
def create_crop_diagnosis(
    diagnosis_in: CropDiagnosisCreate,
    db: Session = Depends(deps.get_db),
    _current_user: Any = Depends(deps.get_current_admin_user)
) -> Any:
    """
    Admin-only — adds a new reference entry (seeded data covers the common
    cases; this exists for extending the knowledge base later).
    """
    return crop_diagnosis_service.create_crop_diagnosis(db, diagnosis_in=diagnosis_in)

@router.put("/{diagnosis_id}", response_model=CropDiagnosisOut)
def update_crop_diagnosis(
    diagnosis_id: str,
    diagnosis_update: CropDiagnosisUpdate,
    db: Session = Depends(deps.get_db),
    _current_user: Any = Depends(deps.get_current_admin_user)
) -> Any:
    db_diagnosis = crop_diagnosis_service.get_crop_diagnosis(db, diagnosis_id=diagnosis_id)
    if not db_diagnosis:
        raise HTTPException(status_code=404, detail="CROP_DIAGNOSIS_NOT_FOUND")
    return crop_diagnosis_service.update_crop_diagnosis(db, db_diagnosis=db_diagnosis, diagnosis_update=diagnosis_update)

@router.delete("/{diagnosis_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_crop_diagnosis(
    diagnosis_id: str,
    db: Session = Depends(deps.get_db),
    _current_user: Any = Depends(deps.get_current_admin_user)
) -> None:
    deleted = crop_diagnosis_service.delete_crop_diagnosis(db, diagnosis_id=diagnosis_id)
    if not deleted:
        raise HTTPException(status_code=404, detail="CROP_DIAGNOSIS_NOT_FOUND")
