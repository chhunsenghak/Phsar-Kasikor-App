from typing import List, Optional
from sqlalchemy.orm import Session
from app.models.crop_diagnosis import CropDiagnosis
from app.schemas.crop_diagnosis import (
    CropDiagnosisCreate, CropDiagnosisUpdate, CropDiagnosisMatch, CropDiagnosisMatchResult
)

# A single keyword hit is enough to surface something as a "possible" match,
# but the *best* match must clear this bar to be reported as confident —
# tuned low since real symptom descriptions are short free text and won't
# naturally contain every keyword on a reference row.
MIN_CONFIDENCE = 0.34


def get_crop_diagnosis(db: Session, diagnosis_id: str) -> Optional[CropDiagnosis]:
    return db.query(CropDiagnosis).filter(CropDiagnosis.id == diagnosis_id).first()


def get_crop_diagnoses(db: Session, skip: int = 0, limit: int = 100) -> List[CropDiagnosis]:
    return (
        db.query(CropDiagnosis)
        .order_by(CropDiagnosis.crop_type, CropDiagnosis.disease_name)
        .offset(skip)
        .limit(limit)
        .all()
    )


def create_crop_diagnosis(db: Session, diagnosis_in: CropDiagnosisCreate) -> CropDiagnosis:
    db_diagnosis = CropDiagnosis(**diagnosis_in.model_dump())
    db.add(db_diagnosis)
    db.commit()
    db.refresh(db_diagnosis)
    return db_diagnosis


def update_crop_diagnosis(db: Session, db_diagnosis: CropDiagnosis, diagnosis_update: CropDiagnosisUpdate) -> CropDiagnosis:
    update_data = diagnosis_update.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(db_diagnosis, field, value)
    db.commit()
    db.refresh(db_diagnosis)
    return db_diagnosis


def delete_crop_diagnosis(db: Session, diagnosis_id: str) -> bool:
    db_diagnosis = get_crop_diagnosis(db, diagnosis_id)
    if not db_diagnosis:
        return False
    db.delete(db_diagnosis)
    db.commit()
    return True


def match_symptoms(db: Session, symptom_text: str) -> CropDiagnosisMatchResult:
    """
    Real word-overlap scoring against every reference row's keyword list —
    no AI/LLM call is configured anywhere in this stack, but this is a
    genuine computed match, not the old hardcoded 3-way contains() branch
    that always claimed one of two specific diseases (or a vague catch-all)
    regardless of what was actually typed.

    confidence = (row keywords found in the text) / (total keywords on that
    row) — simple, but real: a row only surfaces at all if at least one of
    its keywords genuinely appears in the input.
    """
    lowered = symptom_text.lower()
    candidates: List[CropDiagnosisMatch] = []

    for row in db.query(CropDiagnosis).all():
        row_keywords = [k.strip().lower() for k in row.keywords.split(",") if k.strip()]
        if not row_keywords:
            continue
        matched = [k for k in row_keywords if k in lowered]
        if not matched:
            continue
        confidence = len(matched) / len(row_keywords)
        candidates.append(CropDiagnosisMatch(
            diagnosis=row,
            confidence=round(confidence, 2),
            matched_keywords=matched,
        ))

    candidates.sort(key=lambda c: c.confidence, reverse=True)

    if candidates and candidates[0].confidence >= MIN_CONFIDENCE:
        return CropDiagnosisMatchResult(
            matched=True,
            best_match=candidates[0],
            possible_matches=candidates[1:3],
        )

    # Nothing scored high enough to call it a diagnosis — say so honestly,
    # surfacing whatever weakly matched (if anything) as "possible" only.
    return CropDiagnosisMatchResult(
        matched=False,
        best_match=None,
        possible_matches=candidates[:3],
    )
