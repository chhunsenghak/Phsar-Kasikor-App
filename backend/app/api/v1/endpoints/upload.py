import os
import uuid
from fastapi import APIRouter, Depends, File, UploadFile, HTTPException, status
from sqlalchemy.orm import Session

from app.api import deps
from app.models.user import User

router = APIRouter()

ALLOWED_EXTENSIONS = {".jpg", ".jpeg", ".png", ".gif", ".webp"}
MAX_FILE_SIZE = 5 * 1024 * 1024  # 5 MB

@router.post("/", status_code=status.HTTP_201_CREATED)
async def upload_image(
    file: UploadFile = File(...),
    current_user: User = Depends(deps.get_current_user)
):
    """
    Upload a product image. Restricted to authenticated users.
    Returns the relative URL to access the uploaded file.
    """
    _, ext = os.path.splitext(file.filename)
    ext = ext.lower()
    
    if ext not in ALLOWED_EXTENSIONS:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Unsupported file format. Allowed types: {', '.join(ALLOWED_EXTENSIONS)}"
        )
    
    # Save the file under the uploads directory
    os.makedirs("uploads", exist_ok=True)
    filename = f"{uuid.uuid4()}{ext}"
    filepath = os.path.join("uploads", filename)
    
    try:
        content = await file.read()
        if len(content) > MAX_FILE_SIZE:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="File is too large. Maximum allowed size is 5MB."
            )
            
        with open(filepath, "wb") as f:
            f.write(content)
            
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Could not save file: {str(e)}"
        )
        
    return {
        "url": f"/uploads/{filename}",
        "filename": filename
    }
