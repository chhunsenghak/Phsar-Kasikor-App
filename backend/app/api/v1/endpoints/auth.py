from typing import Any
from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.orm import Session

from app.api import deps
from app.core import errors, security, success
from app.core.database import get_db
from app.core.security import get_password_hash
from app.models.user import User
from app.schemas.user import (
    Token, UserCreate, ForgotPasswordRequest, ResetPasswordRequest, VerifyEmailRequest
)
from app.schemas.base import SuccessResponse
from app.services import user_service, verification_service, email_service

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
    user, auth_error = user_service.authenticate_user(
        db, email=form_data.username, password=form_data.password
    )
    if not user:
        raise HTTPException(
            status_code=status.HTTP_423_LOCKED if auth_error == "ACCOUNT_LOCKED" else status.HTTP_400_BAD_REQUEST,
            detail=auth_error or errors.INCORRECT_CREDENTIALS,
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


@router.post("/logout", response_model=SuccessResponse)
def logout() -> Any:
    """
    Log out the current user by returning a standard success response.
    """
    return success.make_success_response(success.LOGOUT_SUCCESS)


@router.post("/forgot-password", response_model=SuccessResponse)
def forgot_password(
    request: ForgotPasswordRequest,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db)
) -> Any:
    """
    Requests a password-reset code by email. Always returns the same
    generic response regardless of whether the email is registered, so this
    endpoint can't be used to enumerate accounts.
    """
    user = user_service.get_user_by_email(db, email=request.email)
    if user:
        code = verification_service.create_code(
            db, user_id=user.id, purpose=verification_service.PASSWORD_RESET
        )
        background_tasks.add_task(
            email_service.send_email,
            user.email,
            "Phsar Kasikor - Password Reset Code",
            f"Your password reset code is: {code}\n\n"
            "This code expires in 15 minutes. If you didn't request this, "
            "you can safely ignore this email.",
        )
    return success.make_success_response(success.PASSWORD_RESET_CODE_SENT)


@router.post("/reset-password", response_model=SuccessResponse)
def reset_password(
    request: ResetPasswordRequest,
    db: Session = Depends(get_db)
) -> Any:
    """
    Completes a password reset using the code emailed to the user.
    """
    user = user_service.get_user_by_email(db, email=request.email)
    if not user:
        raise HTTPException(status_code=400, detail=errors.INVALID_OR_EXPIRED_CODE)

    valid = verification_service.verify_and_consume_code(
        db, user_id=user.id, purpose=verification_service.PASSWORD_RESET, code=request.code
    )
    if not valid:
        raise HTTPException(status_code=400, detail=errors.INVALID_OR_EXPIRED_CODE)

    user.password = get_password_hash(request.new_password)
    db.commit()
    return success.make_success_response(success.PASSWORD_RESET_SUCCESS)


@router.post("/send-verification-email", response_model=SuccessResponse)
def send_verification_email(
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db),
    current_user: User = Depends(deps.get_current_user)
) -> Any:
    """
    Sends (or resends) an email-verification code to the current user.
    """
    if current_user.is_verified:
        return success.make_success_response(success.ALREADY_VERIFIED)
    if not current_user.email:
        raise HTTPException(status_code=400, detail=errors.NO_EMAIL_ON_ACCOUNT)

    code = verification_service.create_code(
        db, user_id=current_user.id, purpose=verification_service.EMAIL_VERIFICATION
    )
    background_tasks.add_task(
        email_service.send_email,
        current_user.email,
        "Phsar Kasikor - Verify Your Email",
        f"Your verification code is: {code}\n\nThis code expires in 15 minutes.",
    )
    return success.make_success_response(success.VERIFICATION_CODE_SENT)


@router.post("/verify-email", response_model=SuccessResponse)
def verify_email(
    request: VerifyEmailRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(deps.get_current_user)
) -> Any:
    """
    Confirms the current user's email using the code they were sent.
    """
    valid = verification_service.verify_and_consume_code(
        db, user_id=current_user.id, purpose=verification_service.EMAIL_VERIFICATION, code=request.code
    )
    if not valid:
        raise HTTPException(status_code=400, detail=errors.INVALID_OR_EXPIRED_CODE)

    current_user.is_verified = True
    db.commit()
    return success.make_success_response(success.EMAIL_VERIFIED)


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
