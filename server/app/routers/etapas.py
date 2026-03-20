"""Etapas router — score, status/prazo update, checklist-normas, sugerir-grupo, evidence upload."""

import os
from datetime import datetime, timezone
from typing import List
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, UploadFile, File
from sqlmodel import Session, select

from ..db import get_session
from ..models import User, Obra, Etapa, ChecklistItem, Evidencia
from ..schemas import (
    EtapaRead, EtapaStatusUpdate, EtapaPrazoUpdate,
    EtapaNormasChecklistRead, SugerirGrupoRequest, SugerirGrupoResponse,
    EvidenciaRead,
)
from ..enums import ChecklistStatus
from ..auth import get_current_user
from ..subscription import get_plan_config
from ..storage import upload_file
from ..helpers import (
    _sanitize_filename, _verify_obra_ownership,
    _verify_etapa_ownership, _verify_etapa_access,
    _notificar_dono_atualizacao,
)

router = APIRouter(tags=["etapas"])


@router.get("/api/etapas/{etapa_id}/score")
def score_etapa(
    etapa_id: UUID,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
) -> dict:
    itens = session.exec(select(ChecklistItem).where(ChecklistItem.etapa_id == etapa_id)).all()
    total = len(itens)
    if total == 0:
        score = 0.0
    else:
        ok_count = len([item for item in itens if item.status == ChecklistStatus.OK.value])
        score = (ok_count / total) * 100
    etapa = session.get(Etapa, etapa_id)
    if etapa:
        etapa.score = score
        etapa.updated_at = datetime.now(timezone.utc)
        session.add(etapa)
        session.commit()
    return {"etapa_id": etapa_id, "score": score}


@router.patch("/api/etapas/{etapa_id}/status", response_model=EtapaRead)
def atualizar_status_etapa(
    etapa_id: UUID,
    payload: EtapaStatusUpdate,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
) -> Etapa:
    etapa = _verify_etapa_ownership(etapa_id, current_user, session)
    etapa.status = payload.status.value
    etapa.updated_at = datetime.now(timezone.utc)
    session.add(etapa)
    session.commit()
    session.refresh(etapa)
    return etapa


@router.patch("/api/etapas/{etapa_id}/prazo", response_model=EtapaRead)
def atualizar_prazo_etapa(
    etapa_id: UUID,
    payload: EtapaPrazoUpdate,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
) -> EtapaRead:
    etapa = session.get(Etapa, etapa_id)
    if not etapa:
        raise HTTPException(status_code=404, detail="Etapa nao encontrada")
    obra = session.get(Obra, etapa.obra_id)
    if not obra or obra.user_id != current_user.id:
        raise HTTPException(status_code=403, detail="Acesso negado")
    if payload.prazo_previsto is not None:
        etapa.prazo_previsto = payload.prazo_previsto
    if payload.prazo_executado is not None:
        etapa.prazo_executado = payload.prazo_executado
    etapa.updated_at = datetime.now(timezone.utc)
    session.add(etapa)
    session.commit()
    session.refresh(etapa)
    return EtapaRead.model_validate(etapa)


@router.get("/api/etapas/{etapa_id}/checklist-normas", response_model=EtapaNormasChecklistRead)
def listar_normas_checklist_etapa(
    etapa_id: UUID,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
) -> EtapaNormasChecklistRead:
    etapa = session.get(Etapa, etapa_id)
    if not etapa:
        raise HTTPException(status_code=404, detail="Etapa nao encontrada")
    obra = session.get(Obra, etapa.obra_id)
    if not obra or obra.user_id != current_user.id:
        raise HTTPException(status_code=403, detail="Acesso negado")
    itens = session.exec(
        select(ChecklistItem).where(
            ChecklistItem.etapa_id == etapa_id,
            ChecklistItem.norma_referencia != None,
        )
    ).all()
    normas = sorted({i.norma_referencia for i in itens if i.norma_referencia})
    return EtapaNormasChecklistRead(etapa_id=etapa_id, normas=list(normas))


@router.post("/api/etapas/{etapa_id}/checklist-items/sugerir-grupo", response_model=SugerirGrupoResponse)
def sugerir_grupo_item(
    etapa_id: UUID,
    payload: SugerirGrupoRequest,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
) -> SugerirGrupoResponse:
    etapa = session.get(Etapa, etapa_id)
    if not etapa:
        raise HTTPException(status_code=404, detail="Etapa nao encontrada")
    obra = session.get(Obra, etapa.obra_id)
    if not obra or obra.user_id != current_user.id:
        raise HTTPException(status_code=403, detail="Acesso negado")
    itens = session.exec(
        select(ChecklistItem).where(ChecklistItem.etapa_id == etapa_id)
    ).all()
    grupos_ordens: dict[str, int] = {}
    for item in itens:
        grupos_ordens[item.grupo] = max(grupos_ordens.get(item.grupo, 0), item.ordem)
    titulo_lower = payload.titulo.lower()
    for grupo in grupos_ordens:
        if grupo.lower() != "geral" and grupo.lower() in titulo_lower:
            return SugerirGrupoResponse(
                grupo=grupo,
                ordem=grupos_ordens[grupo] + 1,
            )
    return SugerirGrupoResponse(
        grupo="Geral",
        ordem=grupos_ordens.get("Geral", 0) + 1,
    )


@router.post("/api/checklist-items/{item_id}/evidencias", response_model=EvidenciaRead)
def upload_evidencia(
    item_id: UUID,
    file: UploadFile = File(...),
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
) -> Evidencia:
    item = session.get(ChecklistItem, item_id)
    if not item:
        raise HTTPException(status_code=404, detail="Item nao encontrado")
    etapa, role = _verify_etapa_access(item.etapa_id, current_user, session)
    if not file.filename:
        raise HTTPException(status_code=400, detail="Nome do arquivo ausente")
    bucket = os.getenv("S3_BUCKET")
    if not bucket:
        raise HTTPException(status_code=500, detail="S3_BUCKET nao configurado")
    object_key = f"evidencias/{item_id}/{_sanitize_filename(file.filename)}"
    file.file.seek(0, os.SEEK_END)
    tamanho_bytes = file.file.tell()
    file.file.seek(0)
    file_url = upload_file(bucket, object_key, file.file, file.content_type)
    evidencia = Evidencia(
        checklist_item_id=item_id,
        arquivo_url=file_url,
        arquivo_nome=file.filename,
        mime_type=file.content_type,
        tamanho_bytes=tamanho_bytes,
    )
    session.add(evidencia)
    session.commit()
    session.refresh(evidencia)
    if role == "convidado":
        _notificar_dono_atualizacao(session, etapa.obra_id, current_user.nome)
    return evidencia
