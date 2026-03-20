"""Visual AI router — analisar, listar, obter."""

import os
from datetime import datetime, timezone
from io import BytesIO
from typing import List
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Form
from sqlmodel import Session, select

from ..db import get_session
from ..models import User, Obra, Etapa, AnaliseVisual, Achado
from ..schemas import (
    AnaliseVisualRead, AchadoRead, AnaliseVisualComAchadosRead,
)
from ..auth import get_current_user
from ..enums import AnaliseVisualStatus
from ..subscription import get_plan_config, check_and_increment_usage
from ..storage import upload_file
from ..visual_ai import analisar_imagem
from ..helpers import _sanitize_filename, _verify_etapa_ownership

router = APIRouter(tags=["visual_ai"])


@router.post("/api/etapas/{etapa_id}/analise-visual", response_model=AnaliseVisualComAchadosRead)
async def analisar_visual(
    etapa_id: UUID,
    file: UploadFile = File(...),
    grupo: str | None = Form(None),
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
) -> AnaliseVisualComAchadosRead:
    """
    Faz upload de uma foto e dispara análise visual por IA.
    Armazena no S3, envia ao Claude Vision e persiste os achados.
    """
    import asyncio

    etapa = _verify_etapa_ownership(etapa_id, current_user, session)
    config = get_plan_config(current_user)
    check_and_increment_usage(
        session, current_user.id, "ai_visual", config["ai_visual_monthly_limit"]
    )

    bucket = os.getenv("S3_BUCKET")
    if not bucket:
        raise HTTPException(status_code=500, detail="S3_BUCKET nao configurado")

    if not file.filename:
        raise HTTPException(status_code=400, detail="Nome do arquivo ausente")

    file.file.seek(0)
    imagem_bytes = file.file.read()

    object_key = f"analises-visuais/{etapa_id}/{_sanitize_filename(file.filename)}"
    imagem_url = upload_file(bucket, object_key, BytesIO(imagem_bytes), file.content_type)

    analise = AnaliseVisual(
        etapa_id=etapa_id,
        imagem_url=imagem_url,
        imagem_nome=file.filename,
        status=AnaliseVisualStatus.PROCESSANDO,
    )
    session.add(analise)
    session.commit()
    session.refresh(analise)

    try:
        resultado = await asyncio.to_thread(analisar_imagem, imagem_bytes, file.filename, etapa.nome, grupo)

        achados_db: list[Achado] = []
        for achado_data in resultado.get("achados", []):
            achado = Achado(
                analise_id=analise.id,
                descricao=achado_data.get("descricao", ""),
                severidade=achado_data.get("severidade", "baixo"),
                acao_recomendada=achado_data.get("acao_recomendada", ""),
                requer_evidencia_adicional=bool(achado_data.get("requer_evidencia_adicional", False)),
                requer_validacao_profissional=bool(achado_data.get("requer_validacao_profissional", False)),
                confianca=int(achado_data.get("confianca", 50)),
            )
            session.add(achado)
            achados_db.append(achado)

        analise.etapa_inferida = resultado.get("etapa_inferida")
        analise.confianca = int(resultado.get("confianca_etapa", 0))
        analise.resumo_geral = resultado.get("resumo_geral")
        analise.aviso_legal = resultado.get(
            "aviso_legal",
            "Esta análise é informativa e NÃO substitui vistoria técnica de engenheiro ou arquiteto habilitado.",
        )
        analise.status = AnaliseVisualStatus.CONCLUIDA
        analise.updated_at = datetime.now(timezone.utc)
        session.add(analise)
        session.commit()
        session.refresh(analise)
        for a in achados_db:
            session.refresh(a)

        return AnaliseVisualComAchadosRead(
            analise=AnaliseVisualRead.model_validate(analise),
            achados=[AchadoRead.model_validate(a) for a in achados_db],
        )

    except Exception as exc:
        import traceback
        traceback.print_exc()
        analise.status = AnaliseVisualStatus.ERRO
        analise.updated_at = datetime.now(timezone.utc)
        session.add(analise)
        session.commit()
        raise HTTPException(status_code=502, detail=f"Erro na analise visual: {exc}")


@router.get("/api/etapas/{etapa_id}/analises-visuais", response_model=List[AnaliseVisualRead])
def listar_analises_visuais(
    etapa_id: UUID,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
) -> list[AnaliseVisual]:
    """Lista todas as análises visuais de uma etapa."""
    etapa = _verify_etapa_ownership(etapa_id, current_user, session)
    return session.exec(
        select(AnaliseVisual)
        .where(AnaliseVisual.etapa_id == etapa_id)
        .order_by(AnaliseVisual.created_at.desc())
    ).all()


@router.get("/api/analises-visuais/{analise_id}", response_model=AnaliseVisualComAchadosRead)
def obter_analise_visual(
    analise_id: UUID,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
) -> AnaliseVisualComAchadosRead:
    """Retorna uma análise visual com todos os achados."""
    analise = session.get(AnaliseVisual, analise_id)
    if not analise:
        raise HTTPException(status_code=404, detail="Analise nao encontrada")
    etapa = session.get(Etapa, analise.etapa_id)
    if not etapa:
        raise HTTPException(status_code=404, detail="Analise nao encontrada")
    obra = session.get(Obra, etapa.obra_id)
    if not obra or obra.user_id != current_user.id:
        raise HTTPException(status_code=404, detail="Analise nao encontrada")
    achados = session.exec(
        select(Achado)
        .where(Achado.analise_id == analise_id)
        .order_by(Achado.severidade)
    ).all()
    return AnaliseVisualComAchadosRead(
        analise=AnaliseVisualRead.model_validate(analise),
        achados=[AchadoRead.model_validate(a) for a in achados],
    )
