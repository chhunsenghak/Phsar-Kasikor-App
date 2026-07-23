from typing import Any
from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.orm import Session

from app.core import errors, security
from app.core.database import get_db
from app.schemas.user import Token, UserCreate
from app.services import user_service

router = APIRouter()


@router.post("/login", response_model=Token)
def login(
    db: Session = Depends(get_db),
    form_data: OAuth2PasswordRequestForm = Depends()
) -> Any:
    """
    OAuth2 compatible token login. Returns an access token for subsequent API requests.
    Note: username in form_data corresponds to the user's email.
    """
    user = user_service.authenticate_user(
        db, email=form_data.username, password=form_data.password
    )
    if not user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=errors.INCORRECT_CREDENTIALS,
        )
    elif not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=errors.INACTIVE_USER,
        )
    
    return {
        "access_token": security.create_access_token(user.id),
        "token_type": "bearer",
    }


@router.post("/logout")
def logout() -> Any:
    """
    Log out the current user. Since this application uses stateless JWT authentication,
    this endpoint returns a success message confirming the logout action,
    directing the client application to delete/discard the access token locally.
    """
    return {"message": "Successfully logged out"}


import json
import urllib.request
from pydantic import BaseModel
from jose import jwt

GOOGLE_PUBLIC_KEYS = {}

def verify_firebase_token(id_token: str, project_id: str) -> dict:
    """
    Verify a Firebase ID Token using Google's public certificates.
    Avoids requiring any Google Application Default Credentials or service keys.
    """
    global GOOGLE_PUBLIC_KEYS
    
    # 1. Fetch public keys if not cached
    if not GOOGLE_PUBLIC_KEYS:
        try:
            with urllib.request.urlopen("https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com") as response:
                GOOGLE_PUBLIC_KEYS = json.loads(response.read().decode())
        except Exception as e:
            raise Exception(f"Failed to load Google credentials: {str(e)}")
            
    # 2. Decode header to extract Key ID (kid)
    try:
        headers = jwt.get_unverified_header(id_token)
    except Exception as e:
        raise Exception(f"Malformed token header: {str(e)}")
        
    kid = headers.get("kid")
    if not kid or kid not in GOOGLE_PUBLIC_KEYS:
        # Reload keys
        try:
            with urllib.request.urlopen("https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com") as response:
                GOOGLE_PUBLIC_KEYS = json.loads(response.read().decode())
        except:
            pass
            
    if not kid or kid not in GOOGLE_PUBLIC_KEYS:
        raise Exception("Signing key not found in Google certificates")
        
    # 3. Decode and verify signature, audience, and issuer
    public_key = GOOGLE_PUBLIC_KEYS[kid]
    try:
        decoded = jwt.decode(
            id_token,
            public_key,
            algorithms=["RS256"],
            audience=project_id,
            issuer=f"https://securetoken.google.com/{project_id}"
        )
        return decoded
    except Exception as e:
        raise Exception(f"Signature check failed: {str(e)}")


class GoogleLoginRequest(BaseModel):
    id_token: str

@router.post("/google-login")
def google_login(
    payload: GoogleLoginRequest,
    db: Session = Depends(get_db)
) -> Any:
    """
    Login or register a user using their Google/Firebase ID Token.
    """
    try:
        # 1. Verify the ID Token using Google public keys
        decoded_token = verify_firebase_token(payload.id_token, "phsarkasikorapp")
        
        # 2. Extract user info
        email = decoded_token.get("email")
        firebase_uid = decoded_token.get("sub") # 'sub' claim in JWT holds the Firebase UID
        name = decoded_token.get("name", "Google User")
        phone_number = decoded_token.get("phone_number")
        
        # If phone is not provided by Google, generate a fallback dummy phone number
        if not phone_number:
            phone_number = f"+855_{firebase_uid[:8]}"
            
        # 3. Lookup user
        user = None
        if email:
            user = user_service.get_user_by_email(db, email=email)
        if not user:
            user = user_service.get_user_by_phone(db, phone=phone_number)
            
        # 4. If user doesn't exist, register them
        if not user:
            user_in = UserCreate(
                email=email,
                username=name,
                phoneNumber=phone_number,
                role_id=6, # Default to BUYER role ID
                province=None,
                district=None,
                commune=None,
                password=firebase_uid # Secure seed password
            )
            user = user_service.create_user(db, user_in=user_in)
            
        # 5. Return local JWT token
        return {
            "access_token": security.create_access_token(user.id),
            "token_type": "bearer",
        }
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Google authentication failed: {str(e)}"
        )
