"""Shared helper functions and constants used across routers."""

import json
import logging
import os
import re
import unicodedata
from datetime import datetime, timezone
from pathlib import Path
from uuid import UUID

from fastapi import HTTPException
from sqlmodel import Session, select

from .models import (
    Obra, Etapa, ObraConvite, ChecklistItem,
    OrcamentoEtapa, Despesa, AlertaConfig, DeviceToken,
)
from .push import enviar_push_multiplos

logger = logging.getLogger(__name__)


# ─── Constants ────────────────────────────────────────────────────────────────

ETAPAS_PADRAO = [
    "Planejamento e Projeto",
    "Preparacao do Terreno",
    "Fundacoes e Estrutura",
    "Alvenaria e Cobertura",
    "Instalacoes e Acabamentos",
    "Entrega e Pos-obra",
]

_RISCO_ETAPA_KEYWORDS: dict[str, list[str]] = {
    "fundação": ["Fundacoes e Estrutura"],
    "fundacao": ["Fundacoes e Estrutura"],
    "estrutura": ["Fundacoes e Estrutura"],
    "concreto": ["Fundacoes e Estrutura"],
    "ferragem": ["Fundacoes e Estrutura"],
    "armadura": ["Fundacoes e Estrutura"],
    "estaca": ["Fundacoes e Estrutura"],
    "sapata": ["Fundacoes e Estrutura"],
    "terreno": ["Preparacao do Terreno"],
    "terraplanagem": ["Preparacao do Terreno"],
    "topografia": ["Preparacao do Terreno"],
    "sondagem": ["Preparacao do Terreno"],
    "demolição": ["Preparacao do Terreno"],
    "demolicao": ["Preparacao do Terreno"],
    "alvenaria": ["Alvenaria e Cobertura"],
    "cobertura": ["Alvenaria e Cobertura"],
    "telhado": ["Alvenaria e Cobertura"],
    "laje": ["Alvenaria e Cobertura"],
    "impermeabilização": ["Alvenaria e Cobertura"],
    "impermeabilizacao": ["Alvenaria e Cobertura"],
    "elétric": ["Instalacoes e Acabamentos"],
    "eletric": ["Instalacoes e Acabamentos"],
    "hidráulic": ["Instalacoes e Acabamentos"],
    "hidraulic": ["Instalacoes e Acabamentos"],
    "acabamento": ["Instalacoes e Acabamentos"],
    "revestimento": ["Instalacoes e Acabamentos"],
    "pintura": ["Instalacoes e Acabamentos"],
    "piso": ["Instalacoes e Acabamentos"],
    "entrega": ["Entrega e Pos-obra"],
    "habite-se": ["Entrega e Pos-obra"],
    "vistoria": ["Entrega e Pos-obra"],
    "garantia": ["Entrega e Pos-obra"],
    "projeto": ["Planejamento e Projeto"],
    "licença": ["Planejamento e Projeto"],
    "licenca": ["Planejamento e Projeto"],
    "alvará": ["Planejamento e Projeto"],
    "alvara": ["Planejamento e Projeto"],
}

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
            ObraConvite.status == "aceito",
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


def _notificar_dono_atualizacao(session: Session, obra_id: UUID, nome_convidado: str) -> None:
    """Envia push notification ao dono da obra quando convidado faz atualização."""
    try:
        obra = session.get(Obra, obra_id)
        if not obra or not obra.user_id:
            return
        tokens = session.exec(
            select(DeviceToken).where(DeviceToken.obra_id == obra_id)
        ).all()
        if tokens:
            enviar_push_multiplos(
                tokens=[t.token for t in tokens],
                titulo="Obra atualizada",
                corpo=f"O andamento da sua obra foi atualizado por {nome_convidado}",
            )
    except Exception as exc:
        logger.warning("Falha ao enviar push de atualização: %s", exc)


def _verificar_e_notificar_alerta(obra_id: UUID, obra: Obra, session: Session) -> None:
    """
    Após um lançamento de despesa, recalcula o desvio total da obra.
    Se o desvio superar o threshold configurado e notificacao_ativa=True,
    envia push para todos os dispositivos registrados na obra.
    Execução best-effort: falhas não propagam exceção.
    """
    try:
        alerta_config = session.exec(
            select(AlertaConfig).where(AlertaConfig.obra_id == obra_id)
        ).first()
        if not alerta_config or not alerta_config.notificacao_ativa:
            return

        orcamentos = session.exec(
            select(OrcamentoEtapa).where(OrcamentoEtapa.obra_id == obra_id)
        ).all()
        despesas = session.exec(
            select(Despesa).where(Despesa.obra_id == obra_id)
        ).all()

        total_previsto = sum(o.valor_previsto for o in orcamentos)
        total_gasto = sum(d.valor for d in despesas)

        if total_previsto <= 0:
            return

        desvio_pct = ((total_gasto - total_previsto) / total_previsto) * 100
        if desvio_pct <= alerta_config.percentual_desvio_threshold:
            return

        tokens = session.exec(
            select(DeviceToken).where(DeviceToken.obra_id == obra_id)
        ).all()
        if not tokens:
            return

        token_list = [dt.token for dt in tokens]
        titulo = "⚠️ Alerta Orçamentário"
        corpo = (
            f"{obra.nome}: desvio de {desvio_pct:.1f}% "
            f"(limite: {alerta_config.percentual_desvio_threshold:.0f}%)"
        )
        enviar_push_multiplos(
            token_list,
            titulo,
            corpo,
            data={"obra_id": str(obra_id), "tipo": "alerta_orcamentario"},
        )
    except Exception as exc:
        logger.error("Erro ao verificar alerta push: %s", exc)


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
