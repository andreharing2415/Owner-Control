import logging
import os
from pathlib import Path

from dotenv import load_dotenv

# Carrega .env do diretório raiz do servidor
load_dotenv(Path(__file__).resolve().parent.parent / ".env")

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import HTMLResponse

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
)

logger = logging.getLogger(__name__)

APP_NAME = "O Mestre da Obra API"

app = FastAPI(title=APP_NAME)

# CORS: com allow_credentials=True o browser não aceita "*"; é preciso origem explícita ou regex.
# Permitir Flutter web em dev (localhost com qualquer porta).
app.add_middleware(
    CORSMiddleware,
    allow_origins=[],
    allow_origin_regex=r"https?://(localhost|127\.0\.0\.1)(:\d+)?$|https://mestreobra-[a-z0-9.-]*\.run\.app$",
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
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
