"""Documentos router — projetos CRUD, analisar, riscos, aplicar-riscos, detalhamento."""

import asyncio
import json
import logging
import os
from datetime import datetime, timezone
from typing import List
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Request, UploadFile, File
from fastapi.responses import Response
from sqlmodel import Session, select

from ..db import get_session
from ..models import (
    User, Obra, Etapa, ChecklistItem, ProjetoDoc, Risco, ObraDetalhamento,
)
from ..schemas import (
    ProjetoDocRead, RiscoRead, AplicarRiscosRequest,
)
from ..enums import ChecklistStatus, ProjetoDocStatus
from ..auth import get_current_user, require_engineer
from ..subscription import get_plan_config, require_paid
from ..storage import upload_file, download_by_url, extract_object_key
from ..rate_limit import limiter
from ..helpers import _sanitize_filename, _verify_obra_ownership, _verify_obra_access
from ..services.documento_service import (
    analisar_documento_e_persistir,
    aplicar_riscos_como_itens,
    extrair_detalhamento_obra,
    _normalize_comodos,
)

logger = logging.getLogger(__name__)

router = APIRouter(tags=["documentos"])


@router.post("/api/obras/{obra_id}/projetos", response_model=ProjetoDocRead)
def upload_projeto(
    obra_id: UUID,
    file: UploadFile = File(...),
    session: Session = Depends(get_session),
    current_user: User = Depends(require_engineer),
) -> ProjetoDoc:
    """Faz upload de um PDF de projeto e cria o registro para análise."""
    obra = _verify_obra_ownership(obra_id, current_user, session)
    config = get_plan_config(current_user)
    # Gate: limite de uploads
    if config["max_doc_uploads"] is not None:
        doc_count = len(session.exec(
            select(ProjetoDoc).where(ProjetoDoc.obra_id == obra_id)
        ).all())
        if doc_count >= config["max_doc_uploads"]:
            raise HTTPException(status_code=403, detail="Limite de documentos atingido para seu plano")
    # Gate: limite de tamanho
    if config["max_doc_size_mb"] is not None:
        file.file.seek(0, os.SEEK_END)
        size_mb = file.file.tell() / (1024 * 1024)
        file.file.seek(0)
        if size_mb > config["max_doc_size_mb"]:
            raise HTTPException(
                status_code=403,
                detail=f"Arquivo excede o limite de {config['max_doc_size_mb']}MB para seu plano",
            )
    if not file.filename:
        raise HTTPException(status_code=400, detail="Nome do arquivo ausente")
    # Gate: arquivo vazio
    file.file.seek(0, os.SEEK_END)
    file_size = file.file.tell()
    file.file.seek(0)
    if file_size == 0:
        raise HTTPException(status_code=400, detail="Arquivo vazio (0 bytes). Selecione um PDF válido.")
    # Gate: validar MIME real via magic bytes (SEC-05)
    ALLOWED_MIMES = {"application/pdf", "image/jpeg", "image/png"}
    header_bytes = file.file.read(8192)
    file.file.seek(0)
    try:
        import magic
        detected_mime = magic.from_buffer(header_bytes, mime=True)
    except ImportError:
        # Fallback: verificar magic bytes manualmente
        detected_mime = None
        if header_bytes[:4] == b'%PDF':
            detected_mime = "application/pdf"
        elif header_bytes[:3] == b'\xff\xd8\xff':
            detected_mime = "image/jpeg"
        elif header_bytes[:8] == b'\x89PNG\r\n\x1a\n':
            detected_mime = "image/png"
    if detected_mime not in ALLOWED_MIMES:
        raise HTTPException(
            status_code=400,
            detail=f"Tipo de arquivo nao permitido. Aceitos: PDF, JPEG, PNG.",
        )
    # Gate: duplicata — mesmo nome na mesma obra
    existing = session.exec(
        select(ProjetoDoc)
        .where(ProjetoDoc.obra_id == obra_id)
        .where(ProjetoDoc.arquivo_nome == file.filename)
    ).first()
    if existing:
        raise HTTPException(status_code=409, detail="Documento com este nome já foi enviado para esta obra")
    bucket = os.getenv("S3_BUCKET")
    if not bucket:
        raise HTTPException(status_code=500, detail="S3_BUCKET nao configurado")
    object_key = f"projetos/{obra_id}/{_sanitize_filename(file.filename)}"
    file.file.seek(0)
    file_url = upload_file(bucket, object_key, file.file, file.content_type)
    projeto = ProjetoDoc(
        obra_id=obra_id,
        arquivo_url=file_url,
        arquivo_nome=file.filename,
        status=ProjetoDocStatus.PENDENTE,
    )
    session.add(projeto)
    session.commit()
    session.refresh(projeto)
    return projeto


@router.get("/api/obras/{obra_id}/projetos", response_model=List[ProjetoDocRead])
def listar_projetos(
    obra_id: UUID,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
) -> list[ProjetoDoc]:
    """Lista todos os projetos PDF enviados para a obra."""
    obra = _verify_obra_ownership(obra_id, current_user, session)
    return session.exec(
        select(ProjetoDoc)
        .where(ProjetoDoc.obra_id == obra_id)
        .order_by(ProjetoDoc.created_at.desc())
    ).all()


@router.get("/api/projetos/{projeto_id}", response_model=ProjetoDocRead)
def obter_projeto(
    projeto_id: UUID,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
) -> ProjetoDoc:
    """Retorna os detalhes de um projeto PDF."""
    projeto = session.get(ProjetoDoc, projeto_id)
    if not projeto:
        raise HTTPException(status_code=404, detail="Projeto nao encontrado")
    obra = session.get(Obra, projeto.obra_id)
    if not obra or obra.user_id != current_user.id:
        raise HTTPException(status_code=404, detail="Projeto nao encontrado")
    return projeto


@router.get("/api/projetos/{projeto_id}/pdf")
def download_projeto_pdf(
    projeto_id: UUID,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
):
    """Serve o PDF do projeto via proxy (resolve CORS com storage)."""
    projeto = session.get(ProjetoDoc, projeto_id)
    if not projeto:
        raise HTTPException(status_code=404, detail="Projeto nao encontrado")
    obra = session.get(Obra, projeto.obra_id)
    if not obra or obra.user_id != current_user.id:
        raise HTTPException(status_code=404, detail="Projeto nao encontrado")
    bucket = os.getenv("S3_BUCKET")
    if not bucket:
        raise HTTPException(status_code=500, detail="S3_BUCKET nao configurado")
    object_key = extract_object_key(projeto.arquivo_url, bucket)
    pdf_bytes = download_by_url(projeto.arquivo_url, bucket, object_key)
    return Response(
        content=pdf_bytes,
        media_type="application/pdf",
        headers={"Content-Disposition": f'inline; filename="{projeto.arquivo_nome}"'},
    )


@router.delete("/api/projetos/{projeto_id}")
def deletar_projeto(
    projeto_id: UUID,
    session: Session = Depends(get_session),
    current_user: User = Depends(require_engineer),
):
    """Remove um projeto PDF e seus riscos associados."""
    projeto = session.get(ProjetoDoc, projeto_id)
    if not projeto:
        raise HTTPException(status_code=404, detail="Projeto nao encontrado")
    obra = session.get(Obra, projeto.obra_id)
    if not obra or obra.user_id != current_user.id:
        raise HTTPException(status_code=404, detail="Projeto nao encontrado")
    try:
        riscos = session.exec(select(Risco).where(Risco.projeto_id == projeto_id)).all()
        for r in riscos:
            session.delete(r)
        session.flush()
        session.delete(projeto)
        session.commit()
    except Exception as exc:
        session.rollback()
        logger.error("Erro ao deletar projeto %s do banco: %s", projeto_id, exc)
        raise HTTPException(status_code=500, detail="Erro ao remover projeto do banco")

    bucket = os.getenv("S3_BUCKET")
    if bucket and projeto.arquivo_url:
        try:
            object_key = extract_object_key(projeto.arquivo_url, bucket)
            from ..storage import delete_file
            delete_file(bucket, object_key)
        except Exception as exc:
            logger.warning("Falha ao remover arquivo do storage para projeto %s: %s", projeto_id, exc)

    return {"ok": True}


async def _run_analysis_background(projeto_id: UUID) -> None:
    """Executa a análise de IA em background, com sua própria sessão de BD."""
    from ..db import engine
    with Session(engine) as session:
        await asyncio.to_thread(analisar_documento_e_persistir, session, projeto_id)


@router.post("/api/projetos/{projeto_id}/analisar", status_code=200)
@limiter.limit("10/day")
async def analisar_projeto(
    request: Request,
    projeto_id: UUID,
    session: Session = Depends(get_session),
    current_user: User = Depends(require_engineer),
):
    """
    Executa a análise de IA sobre o PDF do projeto.
    Roda sincronamente dentro do request para evitar que Cloud Run mate a task.
    Timeout do Cloud Run: 300s.
    """
    projeto = session.get(ProjetoDoc, projeto_id)
    if not projeto:
        raise HTTPException(status_code=404, detail="Projeto nao encontrado")
    obra = session.get(Obra, projeto.obra_id)
    if not obra or obra.user_id != current_user.id:
        raise HTTPException(status_code=404, detail="Projeto nao encontrado")
    if projeto.status == ProjetoDocStatus.PROCESSANDO:
        raise HTTPException(status_code=409, detail="Analise ja em andamento")

    bucket = os.getenv("S3_BUCKET")
    if not bucket:
        raise HTTPException(status_code=500, detail="S3_BUCKET nao configurado")

    projeto.status = ProjetoDocStatus.PROCESSANDO
    projeto.updated_at = datetime.now(timezone.utc)
    session.add(projeto)
    session.commit()
    session.refresh(projeto)

    # Executa a análise dentro do request (síncrono para Cloud Run não matar)
    await _run_analysis_background(projeto_id)

    projeto = session.get(ProjetoDoc, projeto_id)
    return {"id": str(projeto.id), "status": projeto.status}


@router.get("/api/projetos/{projeto_id}/analise")
def obter_analise(
    projeto_id: UUID,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
):
    """Retorna o projeto com seus riscos (análise completa)."""
    projeto = session.get(ProjetoDoc, projeto_id)
    if not projeto:
        raise HTTPException(status_code=404, detail="Projeto nao encontrado")
    obra = session.get(Obra, projeto.obra_id)
    if not obra or obra.user_id != current_user.id:
        raise HTTPException(status_code=404, detail="Projeto nao encontrado")
    if projeto.status != ProjetoDocStatus.CONCLUIDO:
        raise HTTPException(status_code=400, detail="Analise ainda nao concluida")
    riscos = session.exec(
        select(Risco).where(Risco.projeto_id == projeto_id)
    ).all()
    return {
        "projeto": ProjetoDocRead.model_validate(projeto).model_dump(mode="json"),
        "riscos": [RiscoRead.model_validate(r).model_dump(mode="json") for r in riscos],
    }


@router.get("/api/obras/{obra_id}/riscos-pendentes")
def listar_riscos_pendentes(
    obra_id: UUID,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
):
    """Retorna riscos de documentos analisados que ainda nao viraram checklist items."""
    docs = session.exec(
        select(ProjetoDoc)
        .where(ProjetoDoc.obra_id == obra_id)
        .where(ProjetoDoc.status == ProjetoDocStatus.CONCLUIDO)
    ).all()

    titulos_existentes: set[str] = set()
    etapas = session.exec(select(Etapa).where(Etapa.obra_id == obra_id)).all()
    etapa_ids = [e.id for e in etapas]
    if etapa_ids:
        items_existentes = session.exec(
            select(ChecklistItem.titulo).where(ChecklistItem.etapa_id.in_(etapa_ids))  # type: ignore[attr-defined]
        ).all()
        titulos_existentes = {t for t in items_existentes}

    riscos_pendentes = []
    for doc in docs:
        riscos = session.exec(
            select(Risco).where(Risco.projeto_id == doc.id)
        ).all()
        for risco in riscos:
            if risco.descricao in titulos_existentes:
                continue
            riscos_pendentes.append({
                "id": str(risco.id),
                "projeto_id": str(risco.projeto_id),
                "descricao": risco.descricao,
                "severidade": risco.severidade,
                "disciplina": risco.disciplina,
                "norma_referencia": risco.norma_referencia,
                "traducao_leigo": risco.traducao_leigo,
                "requer_validacao_profissional": risco.requer_validacao_profissional,
                "confianca": risco.confianca,
                "documento_nome": doc.arquivo_nome,
            })

    return {"riscos": riscos_pendentes, "total": len(riscos_pendentes)}


@router.post("/api/obras/{obra_id}/aplicar-riscos")
def aplicar_riscos(
    obra_id: UUID,
    body: AplicarRiscosRequest,
    session: Session = Depends(get_session),
    current_user: User = Depends(require_engineer),
):
    """Converte riscos selecionados em ChecklistItems nas etapas adequadas."""
    _verify_obra_ownership(obra_id, current_user, session)
    criados = aplicar_riscos_como_itens(session, obra_id, body.risco_ids)
    return {"criados": criados}


# ─── Detalhamento da Obra (cômodos + m²) ────────────────────────────────────




@router.get("/api/obras/{obra_id}/detalhamento")
def get_detalhamento(
    obra_id: UUID,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
):
    """Retorna o detalhamento da obra (cômodos e metragens extraídas)."""
    _verify_obra_access(obra_id, current_user, session)
    det = session.exec(
        select(ObraDetalhamento)
        .where(ObraDetalhamento.obra_id == obra_id)
        .order_by(ObraDetalhamento.updated_at.desc())
    ).first()
    if not det:
        return {"comodos": [], "area_total_m2": None, "fonte_doc_nome": None, "totais_estimados": None}
    comodos = json.loads(det.comodos) if det.comodos else []
    # Normalize legacy field names and compute derived fields on the fly
    _normalize_comodos(comodos)
    # Compute totals from stored comodos
    total_pisos = sum(c.get("estimativa_piso_com_sobra_m2") or 0 for c in comodos)
    total_azulejos = sum(c.get("estimativa_azulejo_parede_com_sobra_m2") or 0 for c in comodos)
    return {
        "id": str(det.id),
        "comodos": comodos,
        "area_total_m2": det.area_total_m2,
        "fonte_doc_id": str(det.fonte_doc_id) if det.fonte_doc_id else None,
        "fonte_doc_nome": det.fonte_doc_nome,
        "totais_estimados": {
            "total_pisos_m2": round(total_pisos, 2) if total_pisos else 0,
            "total_azulejos_m2": round(total_azulejos, 2) if total_azulejos else 0,
        },
    }


@router.post("/api/obras/{obra_id}/extrair-detalhamento")
@limiter.limit("10/day")
def extrair_detalhamento(
    request: Request,
    obra_id: UUID,
    pe_direito: float = 2.70,
    session: Session = Depends(get_session),
    current_user: User = Depends(require_paid),
):
    """Extrai cômodos, metragens e quantitativos dos documentos da obra usando IA vision."""
    obra = _verify_obra_ownership(obra_id, current_user, session)
    try:
        return extrair_detalhamento_obra(session, obra, pe_direito=pe_direito)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc))
