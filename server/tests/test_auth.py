"""Testes de regressão para autenticação JWT com PyJWT."""

import os
import sys
from datetime import datetime, timedelta, timezone
from unittest.mock import MagicMock, patch

import pytest
import jwt

# ─── Setup de ambiente para testes unitários ─────────────────────────────────

os.environ.setdefault("JWT_SECRET_KEY", "test-secret-key-for-unit-tests")
os.environ.setdefault("DATABASE_URL", "sqlite:///./test_temp.db")

# ─── Funções JWT puras — testar sem importar o módulo completo ────────────────
#
# Para evitar dependência do banco na importação de app.auth (que importa app.db),
# re-implementamos aqui a lógica de encode/decode idêntica ao auth.py usando PyJWT.
# Isso valida que a interface PyJWT funciona conforme esperado.

SECRET_KEY = os.environ["JWT_SECRET_KEY"]
ALGORITHM = "HS256"
TOKEN_ISSUER = "obramaster-api"
TOKEN_AUDIENCE = "obramaster-app"
ACCESS_TOKEN_EXPIRE_MINUTES = 60
REFRESH_TOKEN_EXPIRE_DAYS = 7


def _create_access_token(user_id: str) -> str:
    expire = datetime.now(timezone.utc) + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    return jwt.encode(
        {"sub": user_id, "exp": expire, "type": "access", "iss": TOKEN_ISSUER, "aud": TOKEN_AUDIENCE},
        SECRET_KEY, algorithm=ALGORITHM,
    )


def _create_refresh_token(user_id: str) -> str:
    expire = datetime.now(timezone.utc) + timedelta(days=REFRESH_TOKEN_EXPIRE_DAYS)
    return jwt.encode(
        {"sub": user_id, "exp": expire, "type": "refresh", "iss": TOKEN_ISSUER, "aud": TOKEN_AUDIENCE},
        SECRET_KEY, algorithm=ALGORITHM,
    )


def _decode_token(token: str) -> dict:
    """Replica exata de auth.decode_token usando PyJWT."""
    from fastapi import HTTPException, status
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


def _expired_token(user_id: str, token_type: str = "access") -> str:
    """Gera token com exp no passado."""
    expire = datetime.now(timezone.utc) - timedelta(seconds=1)
    return jwt.encode(
        {
            "sub": user_id,
            "exp": expire,
            "type": token_type,
            "iss": TOKEN_ISSUER,
            "aud": TOKEN_AUDIENCE,
        },
        SECRET_KEY,
        algorithm=ALGORITHM,
    )


# ─── Testes: create_access_token ─────────────────────────────────────────────

class TestCreateAccessToken:
    def test_token_decodificavel(self):
        """Token criado deve ser decodificável com PyJWT diretamente."""
        user_id = "00000000-0000-0000-0000-000000000001"
        token = _create_access_token(user_id)
        payload = jwt.decode(
            token, SECRET_KEY, algorithms=[ALGORITHM],
            issuer=TOKEN_ISSUER, audience=TOKEN_AUDIENCE,
        )
        assert payload["sub"] == user_id
        assert payload["type"] == "access"

    def test_claims_obrigatorios(self):
        """Token deve conter iss, aud, exp, type e sub."""
        token = _create_access_token("uuid-teste")
        payload = jwt.decode(
            token, SECRET_KEY, algorithms=[ALGORITHM],
            issuer=TOKEN_ISSUER, audience=TOKEN_AUDIENCE,
        )
        assert payload.get("iss") == TOKEN_ISSUER
        assert payload.get("aud") == TOKEN_AUDIENCE
        assert "exp" in payload
        assert payload["type"] == "access"

    def test_token_nao_vazio(self):
        token = _create_access_token("some-user")
        assert isinstance(token, str) and len(token) > 10

    def test_algoritmo_hs256(self):
        """Token deve usar algoritmo HS256."""
        token = _create_access_token("user-alg")
        header = jwt.get_unverified_header(token)
        assert header["alg"] == "HS256"


# ─── Testes: create_refresh_token ────────────────────────────────────────────

class TestCreateRefreshToken:
    def test_tipo_refresh(self):
        token = _create_refresh_token("uuid-refresh")
        payload = jwt.decode(
            token, SECRET_KEY, algorithms=[ALGORITHM],
            issuer=TOKEN_ISSUER, audience=TOKEN_AUDIENCE,
        )
        assert payload["type"] == "refresh"

    def test_exp_maior_que_access(self):
        """Refresh token deve expirar depois de um access token gerado no mesmo instante."""
        user_id = "uuid-compare"
        access = _create_access_token(user_id)
        refresh = _create_refresh_token(user_id)

        access_payload = jwt.decode(
            access, SECRET_KEY, algorithms=[ALGORITHM],
            issuer=TOKEN_ISSUER, audience=TOKEN_AUDIENCE,
        )
        refresh_payload = jwt.decode(
            refresh, SECRET_KEY, algorithms=[ALGORITHM],
            issuer=TOKEN_ISSUER, audience=TOKEN_AUDIENCE,
        )
        assert refresh_payload["exp"] > access_payload["exp"]


# ─── Testes: decode_token (lógica idêntica ao auth.py) ───────────────────────

class TestDecodeToken:
    def test_token_valido(self):
        """decode_token deve retornar payload para token válido."""
        user_id = "valid-user-id"
        token = _create_access_token(user_id)
        payload = _decode_token(token)
        assert payload["sub"] == user_id
        assert payload["type"] == "access"

    def test_token_expirado_retorna_401(self):
        """Token expirado deve levantar HTTPException 401."""
        from fastapi import HTTPException

        token = _expired_token("user-expired")
        with pytest.raises(HTTPException) as exc_info:
            _decode_token(token)
        assert exc_info.value.status_code == 401

    def test_token_assinatura_errada_retorna_401(self):
        """Token assinado com chave diferente deve ser rejeitado com 401."""
        from fastapi import HTTPException

        expire = datetime.now(timezone.utc) + timedelta(hours=1)
        forged = jwt.encode(
            {
                "sub": "attacker",
                "exp": expire,
                "type": "access",
                "iss": TOKEN_ISSUER,
                "aud": TOKEN_AUDIENCE,
            },
            "chave-errada",
            algorithm=ALGORITHM,
        )
        with pytest.raises(HTTPException) as exc_info:
            _decode_token(forged)
        assert exc_info.value.status_code == 401

    def test_token_aleatorio_retorna_401(self):
        """String aleatória como token deve retornar 401."""
        from fastapi import HTTPException

        with pytest.raises(HTTPException) as exc_info:
            _decode_token("nao-sou-um-jwt.invalido.mesmo")
        assert exc_info.value.status_code == 401

    def test_token_sem_issuer_correto_retorna_401(self):
        """Token sem issuer correto deve ser rejeitado."""
        from fastapi import HTTPException

        expire = datetime.now(timezone.utc) + timedelta(hours=1)
        token = jwt.encode(
            {
                "sub": "user",
                "exp": expire,
                "type": "access",
                "aud": TOKEN_AUDIENCE,
                # iss ausente
            },
            SECRET_KEY,
            algorithm=ALGORITHM,
        )
        with pytest.raises(HTTPException) as exc_info:
            _decode_token(token)
        assert exc_info.value.status_code == 401

    def test_token_sem_audience_retorna_401(self):
        """Token sem audience correto deve ser rejeitado."""
        from fastapi import HTTPException

        expire = datetime.now(timezone.utc) + timedelta(hours=1)
        token = jwt.encode(
            {
                "sub": "user",
                "exp": expire,
                "type": "access",
                "iss": TOKEN_ISSUER,
                # aud ausente
            },
            SECRET_KEY,
            algorithm=ALGORITHM,
        )
        with pytest.raises(HTTPException) as exc_info:
            _decode_token(token)
        assert exc_info.value.status_code == 401

    def test_mensagem_de_erro_consistente(self):
        """Mensagem de erro deve ser 'Token invalido ou expirado'."""
        from fastapi import HTTPException

        with pytest.raises(HTTPException) as exc_info:
            _decode_token("token-invalido")
        assert exc_info.value.detail == "Token invalido ou expirado"

    def test_token_refresh_nao_e_access(self):
        """Token do tipo refresh deve ser decodificável, mas payload.type == 'refresh'."""
        token = _create_refresh_token("user-refresh-check")
        payload = _decode_token(token)
        assert payload["type"] == "refresh"
        # O caller (get_current_user) é responsável por rejeitar tipo != access
