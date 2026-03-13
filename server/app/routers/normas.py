"""Normas router — buscar, historico, etapas-suportadas."""

from datetime import datetime, timezone
from typing import List
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException
from sqlmodel import Session, select

from ..db import get_session
from ..models import User, NormaLog, NormaResultado
from ..schemas import (
    NormaBuscarRequest, NormaBuscarResponse, NormaResultadoRead, NormaLogRead,
)
from ..auth import get_current_user
from ..subscription import get_plan_config, check_and_increment_usage
from ..normas import buscar_normas

router = APIRouter(prefix="/api/normas", tags=["normas"])


@router.post("/buscar", response_model=NormaBuscarResponse)
def buscar_normas_endpoint(
    payload: NormaBuscarRequest,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
) -> NormaBuscarResponse:
    """
    Pesquisa normas técnicas brasileiras aplicáveis à etapa informada.
    Usa GPT-4o com web search. Registra a consulta de forma auditável.
    """
    config = get_plan_config(current_user)
    check_and_increment_usage(
        session, current_user.id, "normas_buscar", config.get("normas_monthly_limit")
    )

    try:
        resultado = buscar_normas(
            etapa_nome=payload.etapa_nome,
            disciplina=payload.disciplina,
            localizacao=payload.localizacao,
            obra_tipo=payload.obra_tipo,
        )
    except ValueError as exc:
        raise HTTPException(status_code=503, detail=str(exc))
    except Exception as exc:
        raise HTTPException(status_code=502, detail=f"Erro na pesquisa de normas: {exc}")

    # Persiste o log da consulta
    norma_log = NormaLog(
        user_id=current_user.id,
        etapa_nome=payload.etapa_nome,
        disciplina=payload.disciplina,
        localizacao=payload.localizacao,
        query_texto=resultado.get("query_texto", ""),
        data_consulta=datetime.now(timezone.utc),
    )
    session.add(norma_log)
    session.commit()
    session.refresh(norma_log)

    # Persiste cada norma retornada
    normas_db: list[NormaResultado] = []
    for norma in resultado.get("normas", []):
        nr = NormaResultado(
            norma_log_id=norma_log.id,
            titulo=norma.get("titulo", ""),
            fonte_nome=norma.get("fonte_nome", ""),
            fonte_url=norma.get("fonte_url"),
            fonte_tipo=norma.get("fonte_tipo", "secundaria"),
            versao=norma.get("versao"),
            data_norma=norma.get("data_norma"),
            trecho_relevante=norma.get("trecho_relevante"),
            traducao_leigo=norma.get("traducao_leigo", ""),
            nivel_confianca=int(norma.get("nivel_confianca", 50)),
            risco_nivel=norma.get("risco_nivel"),
            requer_validacao_profissional=bool(norma.get("requer_validacao_profissional", False)),
        )
        session.add(nr)
        normas_db.append(nr)

    session.commit()
    for nr in normas_db:
        session.refresh(nr)

    # Truncar resultados para plano gratuito
    normas_read = [NormaResultadoRead.model_validate(nr) for nr in normas_db]
    config = get_plan_config(current_user)
    normas_limit = config.get("normas_results_limit")
    total_normas = len(normas_read)
    if normas_limit is not None:
        normas_read = normas_read[:normas_limit]

    return NormaBuscarResponse(
        log_id=norma_log.id,
        etapa_nome=payload.etapa_nome,
        resumo_geral=resultado.get("resumo_geral", ""),
        aviso_legal=resultado.get(
            "aviso_legal",
            "Este resultado é informativo e NÃO substitui parecer técnico de profissional habilitado.",
        ),
        data_consulta=resultado.get("data_consulta", datetime.now(timezone.utc).isoformat()),
        normas=normas_read,
        checklist_dinamico=resultado.get("checklist_dinamico", []),
        total_normas=total_normas,
    )


@router.get("/historico", response_model=List[NormaLogRead])
def listar_historico_normas(
    limit: int = 20,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
) -> list[NormaLog]:
    """Lista as últimas consultas normativas realizadas pelo usuário."""
    logs = session.exec(
        select(NormaLog)
        .where(NormaLog.user_id == current_user.id)
        .order_by(NormaLog.data_consulta.desc())
        .limit(limit)
    ).all()
    result = []
    for log in logs:
        resultados = session.exec(
            select(NormaResultado).where(NormaResultado.norma_log_id == log.id)
        ).all()
        log_read = NormaLogRead.model_validate(log)
        log_read.resultados = [NormaResultadoRead.model_validate(r) for r in resultados]
        result.append(log_read)
    return result


@router.get("/historico/{log_id}", response_model=NormaLogRead)
def obter_consulta_norma(
    log_id: UUID,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
) -> NormaLogRead:
    """Retorna uma consulta normativa específica com todos os resultados."""
    log = session.get(NormaLog, log_id)
    if not log:
        raise HTTPException(status_code=404, detail="Consulta nao encontrada")
    resultados = session.exec(
        select(NormaResultado).where(NormaResultado.norma_log_id == log_id)
    ).all()
    log_read = NormaLogRead.model_validate(log)
    log_read.resultados = [NormaResultadoRead.model_validate(r) for r in resultados]
    return log_read


@router.get("/etapas")
def listar_etapas_suportadas() -> dict:
    """Lista as etapas com suporte a busca normativa e suas palavras-chave."""
    from ..normas import KEYWORDS_POR_ETAPA
    return {
        "etapas": [
            {"nome": etapa, "keywords": kws}
            for etapa, kws in KEYWORDS_POR_ETAPA.items()
        ]
    }
