"""Auth router — register, login, refresh, me, google login, profile update."""

import logging
import os
from datetime import datetime, timezone
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException
from sqlmodel import Session, select

from ..db import get_session
from ..models import User
from ..schemas import (
    UserRegister, UserLogin, UserRead, TokenResponse,
    TokenRefreshRequest, GoogleLoginRequest, GoogleTokenResponse,
    UpdateProfileRequest,
)
from ..auth import (
    hash_password, verify_password, create_access_token,
    create_refresh_token, decode_token, get_current_user,
)
from google.oauth2 import id_token as google_id_token
from google.auth.transport import requests as google_requests

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/auth", tags=["auth"])


@router.post("/register", response_model=TokenResponse)
def registrar_usuario(payload: UserRegister, session: Session = Depends(get_session)):
    existing = session.exec(select(User).where(User.email == payload.email.lower().strip())).first()
    if existing:
        raise HTTPException(status_code=409, detail="Email ja cadastrado")
    user = User(
        email=payload.email.lower().strip(),
        password_hash=hash_password(payload.password),
        nome=payload.nome,
        telefone=payload.telefone,
    )
    session.add(user)
    session.commit()
    session.refresh(user)
    return TokenResponse(
        access_token=create_access_token(str(user.id)),
        refresh_token=create_refresh_token(str(user.id)),
        user=UserRead.from_user(user),
    )


@router.post("/login", response_model=TokenResponse)
def login(payload: UserLogin, session: Session = Depends(get_session)):
    user = session.exec(select(User).where(User.email == payload.email.lower().strip())).first()
    if not user or not user.password_hash:
        raise HTTPException(status_code=401, detail="Email ou senha incorretos")
    if not verify_password(payload.password, user.password_hash):
        raise HTTPException(status_code=401, detail="Email ou senha incorretos")
    if not user.ativo:
        raise HTTPException(status_code=403, detail="Conta desativada")
    return TokenResponse(
        access_token=create_access_token(str(user.id)),
        refresh_token=create_refresh_token(str(user.id)),
        user=UserRead.from_user(user),
    )


@router.post("/refresh", response_model=TokenResponse)
def refresh_token(payload: TokenRefreshRequest, session: Session = Depends(get_session)):
    data = decode_token(payload.refresh_token)
    if data.get("type") != "refresh":
        raise HTTPException(status_code=401, detail="Token de refresh invalido")
    user = session.get(User, UUID(data["sub"]))
    if not user or not user.ativo:
        raise HTTPException(status_code=401, detail="Usuario nao encontrado")
    return TokenResponse(
        access_token=create_access_token(str(user.id)),
        refresh_token=create_refresh_token(str(user.id)),
        user=UserRead.from_user(user),
    )


@router.get("/me", response_model=UserRead)
def me(current_user: User = Depends(get_current_user)):
    return UserRead.from_user(current_user)


@router.post("/google", response_model=GoogleTokenResponse)
def login_google(payload: GoogleLoginRequest, session: Session = Depends(get_session)):
    """Verifica um Google ID Token e retorna JWT próprio."""
    google_client_id = os.getenv("GOOGLE_CLIENT_ID")
    if not google_client_id:
        raise HTTPException(status_code=500, detail="Google login nao configurado")
    try:
        info = google_id_token.verify_oauth2_token(
            payload.id_token,
            google_requests.Request(),
            google_client_id,
        )
    except Exception as e:
        logger.warning(f"Google token verification failed: {e}")
        raise HTTPException(status_code=401, detail="Token Google invalido")

    google_sub = info["sub"]
    email = info.get("email", "").lower().strip()
    nome_google = info.get("name", "")

    user = session.exec(select(User).where(User.google_id == google_sub)).first()
    is_new_user = False

    if not user and email:
        user = session.exec(select(User).where(User.email == email)).first()
        if user:
            user.google_id = google_sub
            session.add(user)
            session.commit()
            session.refresh(user)

    if not user:
        is_new_user = True
        user = User(
            email=email,
            password_hash=None,
            google_id=google_sub,
            nome=nome_google or email.split("@")[0],
        )
        session.add(user)
        session.commit()
        session.refresh(user)

    if not user.ativo:
        raise HTTPException(status_code=403, detail="Conta desativada")

    return GoogleTokenResponse(
        access_token=create_access_token(str(user.id)),
        refresh_token=create_refresh_token(str(user.id)),
        user=UserRead.from_user(user),
        is_new_user=is_new_user,
    )


@router.patch("/me", response_model=UserRead)
def atualizar_perfil(
    payload: UpdateProfileRequest,
    current_user: User = Depends(get_current_user),
    session: Session = Depends(get_session),
):
    """Atualiza nome e/ou telefone do usuário autenticado."""
    if payload.nome is not None:
        current_user.nome = payload.nome.strip()
    if payload.telefone is not None:
        current_user.telefone = payload.telefone.strip() or None
    current_user.updated_at = datetime.now(timezone.utc)
    session.add(current_user)
    session.commit()
    session.refresh(current_user)
    return UserRead.from_user(current_user)
