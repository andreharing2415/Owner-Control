import logging
import os
from pathlib import Path

from dotenv import load_dotenv

# Carrega .env do diretório raiz do servidor
load_dotenv(Path(__file__).resolve().parent.parent / ".env")

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import HTMLResponse, JSONResponse
from slowapi import _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded

from .rate_limit import limiter
from .db import init_db
from .storage import ensure_bucket
from .helpers import _read_template

from .routers import (
    auth,
    obras,
    etapas,
    checklist,
    normas,
    financeiro,
    documentos,
    visual_ai,
    prestadores,
    checklist_inteligente,
    subscription,
    convites,
    cronograma,
    rdo,
)

logger = logging.getLogger(__name__)

APP_NAME = "O Mestre da Obra API"

# ─── Rate Limiter (SEC-01) ────────────────────────────────────────────────────
app = FastAPI(title=APP_NAME)
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

# ─── Security Headers Middleware (SEC-02) ─────────────────────────────────────
@app.middleware("http")
async def add_security_headers(request: Request, call_next):
    response = await call_next(request)
    response.headers["X-Frame-Options"] = "DENY"
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains"
    response.headers["X-XSS-Protection"] = "1; mode=block"
    response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"
    return response

# ─── Global Exception Handler (SEC-06) ───────────────────────────────────────
@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    logger.error("Unhandled exception: %s", exc, exc_info=True)
    return JSONResponse(status_code=500, content={"detail": "Erro interno do servidor"})

# CORS: com allow_credentials=True o browser não aceita "*"; é preciso origem explícita ou regex.
# Permitir Flutter web em dev (localhost com qualquer porta).
app.add_middleware(
    CORSMiddleware,
    allow_origins=[],
    allow_origin_regex=r"https?://(localhost|127\.0\.0\.1)(:\d+)?$|https://mestreobra-backend-530484413221\.us-central1\.run\.app$",
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["Content-Type", "Authorization", "X-Requested-With"],
)


@app.on_event("startup")
def on_startup() -> None:
    try:
        init_db()
    except Exception as exc:
        print(f"[startup] DB init deferred (will retry on first request): {exc}")
    bucket = os.getenv("S3_BUCKET")
    if bucket:
        try:
            ensure_bucket(bucket)
        except Exception as exc:
            print(f"[startup] S3 bucket setup skipped: {exc}")


@app.get("/health")
def health() -> dict:
    return {"status": "ok"}


@app.get("/privacy", response_class=HTMLResponse)
def privacy_policy():
    return _read_template("privacy.html")


# ─── Include all routers ─────────────────────────────────────────────────────

app.include_router(auth.router)
app.include_router(obras.router)
app.include_router(etapas.router)
app.include_router(checklist.router)
app.include_router(normas.router)
app.include_router(financeiro.router)
app.include_router(documentos.router)
app.include_router(visual_ai.router)
app.include_router(prestadores.router)
app.include_router(checklist_inteligente.router)
app.include_router(subscription.router)
app.include_router(convites.router)
app.include_router(cronograma.router)
app.include_router(rdo.router)
