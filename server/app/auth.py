"""Autenticação JWT — hashing de senha, criação/verificação de tokens, dependency FastAPI."""

import os
from datetime import datetime, timedelta, timezone
from typing import Optional
from uuid import UUID

import bcrypt
import jwt
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlmodel import Session

from .db import get_session
from .models import User

# ─── Role constants ───────────────────────────────────────────────────────────

# Papéis com permissão plena de escrita (engenheiro/gestor da obra)
ENGINEER_ROLES = {"owner", "admin"}

# Papel do dono de obra — acesso somente leitura à obra convidada
DONO_DA_OBRA_ROLE = "dono_da_obra"

# ─── Config ──────────────────────────────────────────────────────────────────

SECRET_KEY = os.getenv("JWT_SECRET_KEY")
if not SECRET_KEY:
    raise RuntimeError("JWT_SECRET_KEY environment variable not set")
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 60
REFRESH_TOKEN_EXPIRE_DAYS = 7
TOKEN_ISSUER = "obramaster-api"
TOKEN_AUDIENCE = "obramaster-app"

# ─── Password hashing ────────────────────────────────────────────────────────


def hash_password(password: str) -> str:
    return bcrypt.hashpw(password.encode(), bcrypt.gensalt()).decode()


def verify_password(plain: str, hashed: str) -> bool:
    return bcrypt.checkpw(plain.encode(), hashed.encode())


# ─── JWT ─────────────────────────────────────────────────────────────────────

def create_access_token(user_id: str) -> str:
    expire = datetime.now(timezone.utc) + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    return jwt.encode(
        {"sub": user_id, "exp": expire, "type": "access", "iss": TOKEN_ISSUER, "aud": TOKEN_AUDIENCE},
        SECRET_KEY, algorithm=ALGORITHM,
    )


def create_refresh_token(user_id: str) -> str:
    expire = datetime.now(timezone.utc) + timedelta(days=REFRESH_TOKEN_EXPIRE_DAYS)
    return jwt.encode(
        {"sub": user_id, "exp": expire, "type": "refresh", "iss": TOKEN_ISSUER, "aud": TOKEN_AUDIENCE},
        SECRET_KEY, algorithm=ALGORITHM,
    )


def decode_token(token: str) -> dict:
    try:
        return jwt.decode(
            token, SECRET_KEY, algorithms=[ALGORITHM],
            issuer=TOKEN_ISSUER, audience=TOKEN_AUDIENCE,
        )
    except jwt.PyJWTError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token invalido ou expirado",
        )


# ─── FastAPI dependencies ────────────────────────────────────────────────────

security = HTTPBearer(auto_error=False)


def get_current_user(
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(security),
    session: Session = Depends(get_session),
) -> User:
    """Dependency que exige token Bearer válido e retorna o User."""
    if not credentials:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token nao fornecido",
        )
    payload = decode_token(credentials.credentials)
    if payload.get("type") != "access":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Tipo de token invalido",
        )
    user_id = payload.get("sub")
    if not user_id:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token invalido",
        )
    user = session.get(User, UUID(user_id))
    if not user or not user.ativo:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Usuario nao encontrado",
        )
    return user


# ─── Role enforcement ────────────────────────────────────────────────────────


def require_role(allowed_roles: set[str] | list[str] | None = None) -> None:
    """Verifica que o usuário possui papel autorizado para operações de escrita.

    Por padrão (allowed_roles=None) exige papel de engenheiro (owner ou admin).
    Dono de obra ('dono_da_obra') nunca tem acesso a operações de escrita.

    Uso:
        require_role(current_user)  # usa ENGINEER_ROLES padrão
        require_role(current_user, {"owner"})

    Args:
        allowed_roles: conjunto de roles permitidos. Se None, usa ENGINEER_ROLES.
    """
    # Retorna uma closure para uso como dependência ou chamada direta
    roles = set(allowed_roles) if allowed_roles is not None else ENGINEER_ROLES

    def _check(user: User) -> None:
        if user.role not in roles:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Operacao nao permitida para seu perfil de acesso",
            )

    return _check


def require_engineer(current_user: User = Depends(get_current_user)) -> User:
    """FastAPI dependency — exige papel de engenheiro (owner ou admin).

    Bloqueia 'dono_da_obra' e 'convidado' de operações de escrita.
    Retorna o User autenticado para uso no endpoint.
    """
    if current_user.role not in ENGINEER_ROLES:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Operacao nao permitida para seu perfil de acesso",
        )
    return current_user
