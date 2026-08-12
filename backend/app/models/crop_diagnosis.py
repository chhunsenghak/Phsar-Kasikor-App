import uuid
from sqlalchemy import Column, String, Text

from app.models.base import Base

class CropDiagnosis(Base):
    """
    A reference disease/pest entry, matched against a farmer's free-text
    symptom description (see crop_diagnosis_service.match_symptoms) and
    also listed as-is as the Crop Advisor's "common issues" reference
    section — one real, seeded table backing both, replacing what used to
    be two separately hardcoded lists in the Flutter screen.
    """
    __tablename__ = "crop_diagnoses"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    disease_name = Column(String, nullable=False)
    disease_name_kh = Column(String, nullable=True)
    crop_type = Column(String, nullable=False)  # e.g. "Rice", "Citrus", "General"
    # Comma-separated symptom words matched (case-insensitively, whole-word)
    # against a farmer's submitted text — see crop_diagnosis_service.
    keywords = Column(String, nullable=False)
    symptoms_description = Column(Text, nullable=False)
    symptoms_description_kh = Column(Text, nullable=True)
    treatment_advice = Column(Text, nullable=False)
    treatment_advice_kh = Column(Text, nullable=True)
