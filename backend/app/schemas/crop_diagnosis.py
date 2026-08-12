from typing import List, Optional
from pydantic import BaseModel, ConfigDict

class CropDiagnosisBase(BaseModel):
    disease_name: str
    disease_name_kh: Optional[str] = None
    crop_type: str
    keywords: str
    symptoms_description: str
    symptoms_description_kh: Optional[str] = None
    treatment_advice: str
    treatment_advice_kh: Optional[str] = None

class CropDiagnosisCreate(CropDiagnosisBase):
    pass

class CropDiagnosisUpdate(BaseModel):
    disease_name: Optional[str] = None
    disease_name_kh: Optional[str] = None
    crop_type: Optional[str] = None
    keywords: Optional[str] = None
    symptoms_description: Optional[str] = None
    symptoms_description_kh: Optional[str] = None
    treatment_advice: Optional[str] = None
    treatment_advice_kh: Optional[str] = None

class CropDiagnosisOut(CropDiagnosisBase):
    id: str

    model_config = ConfigDict(from_attributes=True)

class CropDiagnosisMatch(BaseModel):
    """One scored candidate — confidence is matched_keywords / total_keywords
    for that reference entry, a real (if simple) overlap score, never a
    fabricated number."""
    diagnosis: CropDiagnosisOut
    confidence: float
    matched_keywords: List[str]

class CropDiagnosisMatchResult(BaseModel):
    # True only when the top match cleared the minimum-confidence bar in
    # crop_diagnosis_service.match_symptoms — the honest "we're not sure"
    # signal the old hardcoded catch-all never gave.
    matched: bool
    best_match: Optional[CropDiagnosisMatch] = None
    possible_matches: List[CropDiagnosisMatch] = []
