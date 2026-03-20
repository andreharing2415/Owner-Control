"""Shared helper functions used across routers.

ARQ-04: Constants moved to constants.py, notifications to notifications.py.
Re-exports kept for backward compatibility.
"""

import json
import logging
import re
import unicodedata
from pathlib import Path
from uuid import UUID

from fastapi import HTTPException
from sqlmodel import Session, select

from .models import Obra, Etapa, ObraConvite, ChecklistItem
from .enums import ConviteStatus

# ─── Re-exports for backward compatibility ────────────────────────────────────
from .constants import ETAPAS_PADRAO, RISCO_ETAPA_KEYWORDS as _RISCO_ETAPA_KEYWORDS  # noqa: F401
from .notifications import (  # noqa: F401
    notificar_dono_atualizacao as _notificar_dono_atualizacao,
    verificar_e_notificar_alerta as _verificar_e_notificar_alerta,
)

logger = logging.getLogger(__name__)

_TEMPLATES_DIR = Path(__file__).parent / "templates"


# ─── Helper Functions ─────────────────────────────────────────────────────────


def _sanitize_filename(name: str) -> str:
    """Remove accents, replace spaces and unsafe chars for S3-compatible keys."""
    name = unicodedata.normalize("NFKD", name).encode("ascii", "ignore").decode("ascii")
    name = name.replace(" ", "_")
    name = re.sub(r"[^\w.\-]", "", name)
    return name or "file"


def _read_template(name: str) -> str:
    return (_TEMPLATES_DIR / name).read_text(encoding="utf-8")


def _verify_obra_ownership(obra_id: UUID, user, session: Session) -> Obra:
    """Verifica que a obra existe e pertence ao usuário. Retorna a Obra."""
    obra = session.get(Obra, obra_id)
    if not obra or obra.user_id != user.id:
        raise HTTPException(status_code=404, detail="Obra nao encontrada")
    return obra


def _verify_obra_access(obra_id: UUID, user, session: Session) -> tuple[Obra, str]:
    """Verifica acesso à obra (dono ou convidado). Retorna (Obra, role)."""
    obra = session.get(Obra, obra_id)
    if not obra:
        raise HTTPException(status_code=404, detail="Obra nao encontrada")
    if obra.user_id == user.id:
        return obra, "dono"
    convite = session.exec(
        select(ObraConvite).where(
            ObraConvite.obra_id == obra_id,
            ObraConvite.convidado_id == user.id,
            ObraConvite.status == ConviteStatus.ACEITO,
        )
    ).first()
    if convite:
        return obra, "convidado"
    raise HTTPException(status_code=404, detail="Obra nao encontrada")


def _verify_etapa_ownership(etapa_id: UUID, user, session: Session) -> Etapa:
    """Verifica que a etapa existe e sua obra pertence ao usuário."""
    etapa = session.get(Etapa, etapa_id)
    if not etapa:
        raise HTTPException(status_code=404, detail="Etapa nao encontrada")
    _verify_obra_ownership(etapa.obra_id, user, session)
    return etapa


def _verify_etapa_access(etapa_id: UUID, user, session: Session) -> tuple[Etapa, str]:
    """Verifica acesso à etapa (dono ou convidado). Retorna (Etapa, role)."""
    etapa = session.get(Etapa, etapa_id)
    if not etapa:
        raise HTTPException(status_code=404, detail="Etapa nao encontrada")
    _, role = _verify_obra_access(etapa.obra_id, user, session)
    return etapa, role


def _apply_enrichment(item: ChecklistItem, enrichment: dict) -> None:
    """Aplica dados de enriquecimento IA a um ChecklistItem."""
    if enrichment.get("severidade"):
        item.severidade = enrichment["severidade"]
    if enrichment.get("traducao_leigo"):
        item.traducao_leigo = enrichment["traducao_leigo"]
    if enrichment.get("norma_referencia"):
        item.norma_referencia = enrichment["norma_referencia"]
    if enrichment.get("confianca") is not None:
        item.confianca = int(enrichment["confianca"])
    if enrichment.get("dado_projeto"):
        item.dado_projeto = json.dumps(enrichment["dado_projeto"], ensure_ascii=False)
    if enrichment.get("verificacoes"):
        item.verificacoes = json.dumps(enrichment["verificacoes"], ensure_ascii=False)
    if enrichment.get("pergunta_engenheiro"):
        item.pergunta_engenheiro = json.dumps(enrichment["pergunta_engenheiro"], ensure_ascii=False)
    if enrichment.get("documentos_a_exigir"):
        item.documentos_a_exigir = json.dumps(enrichment["documentos_a_exigir"], ensure_ascii=False)
    if enrichment.get("como_verificar"):
        item.como_verificar = enrichment["como_verificar"]
    if enrichment.get("medidas_minimas"):
        item.medidas_minimas = enrichment["medidas_minimas"]
    if enrichment.get("explicacao_leigo"):
        item.explicacao_leigo = enrichment["explicacao_leigo"]
    item.origem = "ia"
