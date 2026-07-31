import json
import os
from fastapi import APIRouter
from typing import Any, Dict

router = APIRouter()

# Resolve dynamic paths for static assets in backend/app/static
APP_DIR = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(__file__))))
STATIC_DIR = os.path.join(APP_DIR, "static")
GAZETTEER_PATH = os.path.join(STATIC_DIR, "cambodia_gazetteer.json")

# Fallback basic locations dataset in case the file reading encounters any runtime issues
FALLBACK_LOCATIONS: Dict[str, Any] = {
    "provinces": [
        {
            "id": "phnom_penh",
            "name": {"en": "Phnom Penh", "kh": "ភ្នំពេញ"},
            "districts": [
                {
                    "id": "chamkar_mon",
                    "name": {"en": "Chamkar Mon", "kh": "ចំការមន"},
                    "communes": [
                        {
                            "id": "tonle_bassac",
                            "name": {"en": "Tonle Bassac", "kh": "ទន្លេបាសាក់"},
                            "villages": [
                                {"id": "v3", "name": {"en": "Village 3", "kh": "ភូមិ ៣"}},
                                {"id": "v4", "name": {"en": "Village 4", "kh": "ភូមិ ៤"}}
                            ]
                        }
                    ]
                }
            ]
        },
        {
            "id": "battambang",
            "name": {"en": "Battambang", "kh": "បាត់ដំបង"},
            "districts": [
                {
                    "id": "sangkae",
                    "name": {"en": "Sangkae", "kh": "សង្កែ"},
                    "communes": [
                        {
                            "id": "wat_ta_mim",
                            "name": {"en": "Wat Ta Mim", "kh": "វត្តតាមិម"},
                            "villages": [
                                {"id": "o_sralau", "name": {"en": "O Sralau", "kh": "អូរស្រឡៅ"}},
                                {"id": "anlong_vil", "name": {"en": "Anlong Vil", "kh": "អន្លង់វិល"}}
                            ]
                        }
                    ]
                }
            ]
        }
    ]
}

def load_all_locations() -> Dict[str, Any]:
    if not os.path.exists(GAZETTEER_PATH):
        return FALLBACK_LOCATIONS
    try:
        with open(GAZETTEER_PATH, "r", encoding="utf-8") as f:
            raw_data = json.load(f)
            
        provinces_output = []
        for p in raw_data:
            p_latin = p.get("latin") or "Province"
            p_khmer = p.get("khmer") or ""
            p_id = p.get("code") or p_latin.lower().replace(" ", "_")
            p_name = {"en": p_latin, "kh": p_khmer}
            
            districts_output = []
            for d in p.get("districts", []):
                d_latin = d.get("latin") or "District"
                d_khmer = d.get("khmer") or ""
                d_id = d.get("code") or d_latin.lower().replace(" ", "_")
                d_name = {"en": d_latin, "kh": d_khmer}
                
                communes_output = []
                for c in d.get("communes", []):
                    c_latin = c.get("latin") or "Commune"
                    c_khmer = c.get("khmer") or ""
                    c_id = c.get("code") or c_latin.lower().replace(" ", "_")
                    c_name = {"en": c_latin, "kh": c_khmer}
                    
                    villages_output = []
                    for v in c.get("villages", []):
                        v_latin = v.get("latin") or "Village"
                        v_khmer = v.get("khmer") or ""
                        v_id = v.get("code") or v_latin.lower().replace(" ", "_")
                        v_name = {"en": v_latin, "kh": v_khmer}
                        
                        villages_output.append({
                            "id": v_id,
                            "name": v_name
                        })
                        
                    communes_output.append({
                        "id": c_id,
                        "name": c_name,
                        "villages": villages_output
                    })
                    
                districts_output.append({
                    "id": d_id,
                    "name": d_name,
                    "communes": communes_output
                })
                
            provinces_output.append({
                "id": p_id,
                "name": p_name,
                "districts": districts_output
            })
            
        return {"provinces": provinces_output}
    except Exception:
        return FALLBACK_LOCATIONS

@router.get("/")
def get_locations() -> Dict[str, Any]:
    """
    Get the complete nested bilingual hierarchy of Cambodia subdivisions (Province -> District -> Commune -> Villages)
    """
    return load_all_locations()
