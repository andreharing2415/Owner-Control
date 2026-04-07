"""Checklist Inteligente router — stream, iniciar, status, aplicar, historico, enriquecer."""

import json
import logging
import os
import threading
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone
from typing import List, Generator
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Request
from fastapi.responses import StreamingResponse
from sqlmodel import Session, select

from ..db import get_session
from ..models import (
    User, Obra, Etapa, ChecklistItem, ProjetoDoc, Risco,
    ChecklistGeracaoLog, ChecklistGeracaoItem,
    GeracaoUnificadaLog,
)
from ..schemas import (
    ChecklistItemRead, IniciarChecklistRequest,
    AplicarChecklistRequest, AplicarChecklistResponse,
    ChecklistGeracaoLogRead, ChecklistGeracaoItemRead,
    ChecklistGeracaoStatusRead,
    IniciarGeracaoUnificadaRequest, GeracaoUnificadaLogRead,
)
from ..enums import ChecklistStatus, ChecklistGeracaoStatus, GeracaoUnificadaStatus
from ..auth import get_current_user, require_engineer
from ..subscription import get_plan_config, check_and_increment_usage, require_paid
from ..storage import download_by_url, extract_object_key
from ..checklist_inteligente import gerar_checklist_stream, processar_checklist_background, enriquecer_item_unico
from ..helpers import (
    _verify_obra_ownership, _verify_obra_access,
    _apply_enrichment,
)

logger = logging.getLogger(__name__)

# Pool controlado para background tasks (PERF-02v2)
_background_pool = ThreadPoolExecutor(max_workers=4, thread_name_prefix="checklist_bg")

router = APIRouter(tags=["checklist_inteligente"])


def _build_documento_contexto(obra_id: UUID, session: Session) -> str:
    """Build document context string for AI enrichment (COMPL-06v2: extracted from 3 duplicated blocks)."""
    docs = session.exec(
        select(ProjetoDoc).where(ProjetoDoc.obra_id == obra_id)
    ).all()
    doc_parts: list[str] = []
    for d in docs:
        if d.resumo_geral:
            doc_parts.append(f"[{d.arquivo_nome}] {d.resumo_geral}")
        riscos = session.exec(
            select(Risco).where(Risco.projeto_id == d.id)
        ).all()
        for r in riscos:
            doc_parts.append(f"  Risco ({r.severidade}): {r.descricao}")
    return "\n".join(doc_parts)


@router.get("/api/obras/{obra_id}/checklist-inteligente/stream")
def stream_checklist_inteligente(
    obra_id: UUID,
    session: Session = Depends(get_session),
    current_user: User = Depends(require_engineer),
):
    """
    SSE endpoint que gera checklist inteligente em tempo real.
    Processa pagina por pagina, emitindo eventos de progresso.
    """
    obra = _verify_obra_ownership(obra_id, current_user, session)

    projetos = session.exec(
        select(ProjetoDoc).where(ProjetoDoc.obra_id == obra_id)
    ).all()
    if not projetos:
        raise HTTPException(
            status_code=400,
            detail="Nenhum documento de projeto enviado para esta obra. "
                   "Envie pelo menos um PDF antes de gerar o checklist inteligente.",
        )

    bucket = os.getenv("S3_BUCKET")
    if not bucket:
        raise HTTPException(status_code=500, detail="S3_BUCKET nao configurado")

    pdfs: list[tuple[bytes, str]] = []
    for projeto in projetos:
        object_key = extract_object_key(projeto.arquivo_url, bucket)
        pdf_bytes = download_by_url(projeto.arquivo_url, bucket, object_key)
        pdfs.append((pdf_bytes, projeto.arquivo_nome))

    return StreamingResponse(
        gerar_checklist_stream(pdfs=pdfs, localizacao=obra.localizacao),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "X-Accel-Buffering": "no",
        },
    )


@router.post(
    "/api/obras/{obra_id}/checklist-inteligente/iniciar",
    response_model=ChecklistGeracaoLogRead,
)
def iniciar_checklist_inteligente(
    obra_id: UUID,
    payload: IniciarChecklistRequest | None = None,
    session: Session = Depends(get_session),
    current_user: User = Depends(require_engineer),
):
    """
    Inicia o processamento do checklist inteligente em background.
    Retorna imediatamente o log_id para acompanhamento.
    """
    obra = _verify_obra_ownership(obra_id, current_user, session)
    config = get_plan_config(current_user)
    check_and_increment_usage(
        session, current_user.id, "checklist_inteligente",
        config["checklist_inteligente_lifetime_limit"],
        period="lifetime",
    )

    existing = session.exec(
        select(ChecklistGeracaoLog)
        .where(ChecklistGeracaoLog.obra_id == obra_id)
        .where(ChecklistGeracaoLog.status == ChecklistGeracaoStatus.PROCESSANDO)
    ).first()
    if existing:
        raise HTTPException(
            status_code=409,
            detail="Ja existe um processamento em andamento para esta obra.",
        )

    projetos = session.exec(
        select(ProjetoDoc).where(ProjetoDoc.obra_id == obra_id)
    ).all()
    if not projetos:
        raise HTTPException(
            status_code=400,
            detail="Nenhum documento de projeto enviado para esta obra. "
                   "Envie pelo menos um PDF antes de gerar o checklist inteligente.",
        )

    selected_ids = payload.projeto_ids if payload else None
    if selected_ids:
        selected_uuids = {UUID(str(pid)) for pid in selected_ids}
        projetos = [p for p in projetos if p.id in selected_uuids]
        if not projetos:
            raise HTTPException(status_code=400, detail="Nenhum documento selecionado encontrado.")

    bucket = os.getenv("S3_BUCKET")
    if not bucket:
        raise HTTPException(status_code=500, detail="S3_BUCKET nao configurado")

    projetos_info = [(p.arquivo_url, p.arquivo_nome, str(p.id)) for p in projetos]

    log = ChecklistGeracaoLog(
        obra_id=obra_id,
        status=ChecklistGeracaoStatus.PROCESSANDO,
        total_docs_analisados=len(projetos),
    )
    session.add(log)
    session.commit()
    session.refresh(log)

    def _run_with_error_handling() -> None:
        try:
            processar_checklist_background(log.id, projetos_info, obra.localizacao, "", bucket)
        except Exception as exc:
            logger.exception("Falha no processamento do checklist log=%s: %s", log.id, exc)
            from ..db import engine
            with Session(engine) as bg_session:
                failed_log = bg_session.get(ChecklistGeracaoLog, log.id)
                if failed_log:
                    failed_log.status = ChecklistGeracaoStatus.ERRO
                    failed_log.erro_detalhe = str(exc)[:500]
                    failed_log.updated_at = datetime.now(timezone.utc)
                    bg_session.add(failed_log)
                    bg_session.commit()

    _background_pool.submit(_run_with_error_handling)

    return log


@router.get(
    "/api/obras/{obra_id}/checklist-inteligente/{log_id}/status",
    response_model=ChecklistGeracaoStatusRead,
)
def status_checklist_inteligente(
    obra_id: UUID,
    log_id: UUID,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
):
    """
    Retorna o status atual do processamento e os itens ja gerados.
    Frontend faz polling neste endpoint.
    """
    _verify_obra_ownership(obra_id, current_user, session)

    log = session.get(ChecklistGeracaoLog, log_id)
    if not log or log.obra_id != obra_id:
        raise HTTPException(status_code=404, detail="Log de geracao nao encontrado")

    itens = session.exec(
        select(ChecklistGeracaoItem)
        .where(ChecklistGeracaoItem.log_id == log_id)
        .order_by(ChecklistGeracaoItem.created_at)
    ).all()

    return ChecklistGeracaoStatusRead(
        log=ChecklistGeracaoLogRead.model_validate(log),
        itens=[ChecklistGeracaoItemRead.model_validate(i) for i in itens],
    )


@router.post(
    "/api/obras/{obra_id}/checklist-inteligente/aplicar",
    response_model=AplicarChecklistResponse,
)
def aplicar_checklist_inteligente(
    obra_id: UUID,
    payload: AplicarChecklistRequest,
    session: Session = Depends(get_session),
    current_user: User = Depends(require_engineer),
) -> AplicarChecklistResponse:
    """
    Aplica os itens selecionados pelo usuario ao checklist real.
    Etapa 2 do fluxo: gerar -> revisar -> aplicar.
    """
    obra = _verify_obra_ownership(obra_id, current_user, session)

    log = None
    if payload.log_id:
        log = session.get(ChecklistGeracaoLog, payload.log_id)
        if not log or log.obra_id != obra_id:
            raise HTTPException(status_code=404, detail="Log de geracao nao encontrado")

    etapas = session.exec(
        select(Etapa).where(Etapa.obra_id == obra_id)
    ).all()
    etapa_map: dict[str, UUID] = {e.nome: e.id for e in etapas}

    itens_criados: list[ChecklistItem] = []
    for item_data in payload.itens:
        etapa_id = etapa_map.get(item_data.etapa_nome)
        if not etapa_id:
            continue

        grupo = getattr(item_data, "grupo", "Geral") or "Geral"
        grupo = grupo.replace("_", " ").title()

        novo_item = ChecklistItem(
            etapa_id=etapa_id,
            titulo=item_data.titulo,
            descricao=item_data.descricao,
            critico=item_data.critico,
            norma_referencia=item_data.norma_referencia,
            origem="ia",
            status=ChecklistStatus.PENDENTE.value,
            grupo=grupo,
            ordem=getattr(item_data, "ordem", 0),
            severidade=getattr(item_data, "severidade", None),
            traducao_leigo=getattr(item_data, "traducao_leigo", None),
            dado_projeto=getattr(item_data, "dado_projeto", None),
            verificacoes=getattr(item_data, "verificacoes", None),
            pergunta_engenheiro=getattr(item_data, "pergunta_engenheiro", None),
            documentos_a_exigir=getattr(item_data, "documentos_a_exigir", None),
            confianca=getattr(item_data, "confianca", None),
            requer_validacao_profissional=getattr(item_data, "requer_validacao_profissional", False),
            como_verificar=getattr(item_data, "como_verificar", None),
            medidas_minimas=getattr(item_data, "medidas_minimas", None),
            explicacao_leigo=getattr(item_data, "explicacao_leigo", None),
            projeto_doc_id=getattr(item_data, "projeto_doc_id", None),
            projeto_doc_nome=getattr(item_data, "projeto_doc_nome", None),
        )
        session.add(novo_item)
        itens_criados.append(novo_item)

    if log:
        log.total_itens_aplicados = len(itens_criados)
        log.updated_at = datetime.now(timezone.utc)
        session.add(log)

    session.commit()
    for item in itens_criados:
        session.refresh(item)

    return AplicarChecklistResponse(
        total_aplicados=len(itens_criados),
        itens_criados=[ChecklistItemRead.model_validate(i) for i in itens_criados],
    )


@router.get(
    "/api/obras/{obra_id}/checklist-inteligente/historico",
    response_model=List[ChecklistGeracaoLogRead],
)
def historico_checklist_inteligente(
    obra_id: UUID,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
) -> list[ChecklistGeracaoLog]:
    """Lista o historico de geracoes de checklist inteligente para a obra."""
    obra = _verify_obra_ownership(obra_id, current_user, session)
    return session.exec(
        select(ChecklistGeracaoLog)
        .where(ChecklistGeracaoLog.obra_id == obra_id)
        .order_by(ChecklistGeracaoLog.created_at.desc())
    ).all()


@router.post("/api/admin/migrar-riscos-para-checklist")
def migrar_riscos_para_checklist(
    session: Session = Depends(get_session),
    current_user: User = Depends(require_engineer),
):
    """One-time migration: converts Risco records into ChecklistItems."""

    riscos = session.exec(select(Risco)).all()
    migrados = 0

    for risco in riscos:
        projeto = session.get(ProjetoDoc, risco.projeto_id)
        if not projeto:
            continue

        etapas = session.exec(
            select(Etapa).where(Etapa.obra_id == projeto.obra_id)
        ).all()
        etapa_alvo = None
        for e in etapas:
            if e.nome == "Fundacoes e Estrutura":
                etapa_alvo = e
                break
        if not etapa_alvo and etapas:
            etapa_alvo = etapas[0]
        if not etapa_alvo:
            continue

        novo = ChecklistItem(
            etapa_id=etapa_alvo.id,
            titulo=risco.descricao[:120] if risco.descricao else "Risco importado",
            descricao=risco.descricao,
            critico=risco.severidade == "alto",
            norma_referencia=risco.norma_referencia,
            origem="ia",
            severidade=risco.severidade,
            traducao_leigo=risco.traducao_leigo,
            dado_projeto=risco.dado_projeto,
            verificacoes=risco.verificacoes,
            pergunta_engenheiro=risco.pergunta_engenheiro,
            documentos_a_exigir=risco.documentos_a_exigir,
            registro_proprietario=risco.registro_proprietario,
            resultado_cruzamento=risco.resultado_cruzamento,
            status_verificacao=risco.status_verificacao,
            confianca=risco.confianca,
            requer_validacao_profissional=risco.requer_validacao_profissional,
        )
        session.add(novo)
        migrados += 1

    session.commit()
    return {"migrados": migrados, "total_riscos": len(riscos)}


# ─── Enriquecimento IA ──────────────────────────────────────────────────────


def _enriquecer_items_background(
    item_data: list[dict],
    contexto: str,
) -> None:
    """Executa enriquecimento IA em background thread com session própria."""
    from ..db import engine

    with Session(engine) as bg_session:
        count = 0
        for data in item_data:
            try:
                enrichment = enriquecer_item_unico(
                    titulo=data["titulo"],
                    descricao=data["descricao"],
                    etapa_nome=data["etapa_nome"],
                    contexto_docs=contexto,
                )
                item = bg_session.get(ChecklistItem, data["item_id"])
                if item:
                    _apply_enrichment(item, enrichment)
                    bg_session.add(item)
                    count += 1
            except Exception as e:
                logger.warning(f"Falha ao enriquecer item {data['item_id']}: {e}")
        bg_session.commit()
        logger.info(f"Enriquecimento background concluído: {count}/{len(item_data)} itens")


@router.post("/api/checklist-items/{item_id}/enriquecer", response_model=ChecklistItemRead)
def enriquecer_item(
    item_id: UUID,
    session: Session = Depends(get_session),
    current_user: User = Depends(require_paid),
):
    """Enriquece um item de checklist padrão com análise IA (3 blocos)."""
    item = session.get(ChecklistItem, item_id)
    if not item:
        raise HTTPException(status_code=404, detail="Item nao encontrado")

    etapa = session.get(Etapa, item.etapa_id)
    if not etapa:
        raise HTTPException(status_code=404, detail="Etapa nao encontrada")

    _verify_obra_access(etapa.obra_id, current_user, session)

    contexto = _build_documento_contexto(etapa.obra_id, session)

    enrichment = enriquecer_item_unico(
        titulo=item.titulo,
        descricao=item.descricao or "",
        etapa_nome=etapa.nome,
        contexto_docs=contexto,
    )

    _apply_enrichment(item, enrichment)
    session.add(item)
    session.commit()
    session.refresh(item)
    return item


@router.post("/api/etapas/{etapa_id}/enriquecer-checklist")
def enriquecer_checklist_etapa(
    etapa_id: UUID,
    session: Session = Depends(get_session),
    current_user: User = Depends(require_paid),
):
    """Enriquece em batch todos os itens padrão de uma etapa com IA (background)."""
    etapa = session.get(Etapa, etapa_id)
    if not etapa:
        raise HTTPException(status_code=404, detail="Etapa nao encontrada")

    _verify_obra_access(etapa.obra_id, current_user, session)

    items = session.exec(
        select(ChecklistItem)
        .where(ChecklistItem.etapa_id == etapa_id)
        .where(ChecklistItem.origem == "padrao")
        .where(ChecklistItem.dado_projeto.is_(None))
    ).all()

    if not items:
        return {"enriquecidos": 0, "total": 0, "mensagem": "Todos os itens ja foram enriquecidos."}

    contexto = _build_documento_contexto(etapa.obra_id, session)

    item_data = [
        {"item_id": item.id, "titulo": item.titulo, "descricao": item.descricao or "", "etapa_nome": etapa.nome}
        for item in items
    ]

    _background_pool.submit(_enriquecer_items_background, item_data, contexto)

    return {"enriquecidos": 0, "total": len(items), "mensagem": f"Enriquecimento de {len(items)} itens iniciado em background."}


@router.post("/api/obras/{obra_id}/enriquecer-todos")
def enriquecer_todos_checklist(
    obra_id: UUID,
    session: Session = Depends(get_session),
    current_user: User = Depends(require_paid),
):
    """Enriquece em batch todos os itens padrão de TODAS as etapas da obra (background)."""
    obra = _verify_obra_ownership(obra_id, current_user, session)

    etapas = session.exec(
        select(Etapa).where(Etapa.obra_id == obra_id)
    ).all()

    contexto = _build_documento_contexto(obra_id, session)

    item_data = []
    for etapa in etapas:
        items = session.exec(
            select(ChecklistItem)
            .where(ChecklistItem.etapa_id == etapa.id)
            .where(ChecklistItem.origem == "padrao")
            .where(ChecklistItem.dado_projeto.is_(None))
        ).all()
        for item in items:
            item_data.append({
                "item_id": item.id,
                "titulo": item.titulo,
                "descricao": item.descricao or "",
                "etapa_nome": etapa.nome,
            })

    if not item_data:
        return {"enriquecidos": 0, "total": 0, "etapas": len(etapas), "mensagem": "Todos os itens ja foram enriquecidos."}

    _background_pool.submit(_enriquecer_items_background, item_data, contexto)

    return {"enriquecidos": 0, "total": len(item_data), "etapas": len(etapas), "mensagem": f"Enriquecimento de {len(item_data)} itens iniciado em background."}


# ─── Geração Unificada — state machine (AI-06/AI-07) ─────────────────────────


def _atualizar_status_log(log_id: UUID, status: str, etapa_atual: str | None = None, **kwargs: object) -> None:
    """Atualiza status do GeracaoUnificadaLog em sessão própria."""
    from ..db import engine

    with Session(engine) as s:
        log = s.get(GeracaoUnificadaLog, log_id)
        if not log:
            return
        log.status = status
        log.updated_at = datetime.now(timezone.utc)
        if etapa_atual is not None:
            log.etapa_atual = etapa_atual
        for field, value in kwargs.items():
            setattr(log, field, value)
        s.add(log)
        s.commit()


def _executar_geracao_unificada(
    log_id: UUID,
    obra_id: UUID,
    tipos_projeto: list[str],
    cancelado: threading.Event,
) -> None:
    """Worker background: executa cronograma + checklist em sequência, atualizando o log.

    Para imediatamente se `cancelado` for sinalizado (cliente desconectou SSE).
    """
    from ..db import engine
    from ..cronograma_ai import gerar_cronograma
    from ..models import (
        AtividadeCronograma, ServicoNecessario, ChecklistItem,
    )
    from ..enums import AtividadeStatus

    def _parse_date_str(value: str) -> object:
        from datetime import date as _date
        if not value:
            return None
        try:
            return _date.fromisoformat(value)
        except (ValueError, TypeError):
            return None

    try:
        # ── ANALISANDO ─────────────────────────────────────────────────────────
        if cancelado.is_set():
            _atualizar_status_log(log_id, GeracaoUnificadaStatus.CANCELADO, etapa_atual="Cancelado pelo cliente")
            return
        _atualizar_status_log(log_id, GeracaoUnificadaStatus.ANALISANDO, etapa_atual="Buscando documentos da obra")

        with Session(engine) as s:
            obra = s.get(Obra, obra_id)
            if not obra:
                _atualizar_status_log(log_id, GeracaoUnificadaStatus.ERRO, erro_detalhe="Obra nao encontrada")
                return
            obra_info = {
                "nome": obra.nome,
                "localizacao": obra.localizacao or "",
                "orcamento": obra.orcamento or 0,
                "data_inicio": str(obra.data_inicio) if obra.data_inicio else "",
                "data_fim": str(obra.data_fim) if obra.data_fim else "",
            }

        # ── GERANDO ────────────────────────────────────────────────────────────
        if cancelado.is_set():
            _atualizar_status_log(log_id, GeracaoUnificadaStatus.CANCELADO, etapa_atual="Cancelado pelo cliente")
            return
        _atualizar_status_log(log_id, GeracaoUnificadaStatus.GERANDO, etapa_atual="Gerando cronograma e checklist com IA")

        resultado = gerar_cronograma(obra_info, tipos_projeto)
        atividades_ai = resultado.get("atividades", [])

        if not atividades_ai:
            _atualizar_status_log(log_id, GeracaoUnificadaStatus.ERRO, erro_detalhe="IA nao retornou atividades")
            return

        if cancelado.is_set():
            _atualizar_status_log(log_id, GeracaoUnificadaStatus.CANCELADO, etapa_atual="Cancelado pelo cliente")
            return

        # ── Persiste no DB ──────────────────────────────────────────────────────
        _atualizar_status_log(
            log_id,
            GeracaoUnificadaStatus.GERANDO,
            etapa_atual="Salvando atividades",
            total_atividades=len(atividades_ai),
        )

        with Session(engine) as s:
            # Remove atividades nao-locked anteriores
            atividades_existentes = s.exec(
                select(AtividadeCronograma).where(AtividadeCronograma.obra_id == obra_id)
            ).all()
            ids_para_deletar = [a.id for a in atividades_existentes if not a.locked]

            if ids_para_deletar:
                servicos_antigos = s.exec(
                    select(ServicoNecessario).where(
                        ServicoNecessario.atividade_id.in_(ids_para_deletar)  # type: ignore[attr-defined]
                    )
                ).all()
                for sv in servicos_antigos:
                    s.delete(sv)

                checklist_antigos = s.exec(
                    select(ChecklistItem).where(
                        ChecklistItem.atividade_id.in_(ids_para_deletar),  # type: ignore[attr-defined]
                        ChecklistItem.origem == "ia",
                    )
                ).all()
                for ci in checklist_antigos:
                    s.delete(ci)

            for a in atividades_existentes:
                if not a.locked:
                    s.delete(a)
            s.flush()

            total_checklist = 0
            geradas = 0

            for ativ_data in atividades_ai:
                if cancelado.is_set():
                    s.rollback()
                    _atualizar_status_log(log_id, GeracaoUnificadaStatus.CANCELADO, etapa_atual="Cancelado pelo cliente")
                    return

                l1 = AtividadeCronograma(
                    obra_id=obra_id,
                    nome=ativ_data["nome"],
                    descricao=ativ_data.get("descricao"),
                    ordem=ativ_data.get("ordem", 0),
                    nivel=1,
                    status=AtividadeStatus.PENDENTE,
                    tipo_projeto=ativ_data.get("tipo_projeto"),
                    valor_previsto=float(ativ_data.get("valor_previsto", 0)),
                    data_inicio_prevista=_parse_date_str(ativ_data.get("data_inicio_prevista", "")),
                    data_fim_prevista=_parse_date_str(ativ_data.get("data_fim_prevista", "")),
                )
                s.add(l1)
                s.flush()

                for svc_data in ativ_data.get("servicos", []):
                    s.add(ServicoNecessario(
                        atividade_id=l1.id,
                        descricao=svc_data["descricao"],
                        categoria=svc_data.get("categoria", "outro"),
                    ))

                for sub_data in ativ_data.get("sub_atividades", []):
                    l2 = AtividadeCronograma(
                        obra_id=obra_id,
                        parent_id=l1.id,
                        nome=sub_data["nome"],
                        descricao=sub_data.get("descricao"),
                        ordem=sub_data.get("ordem", 0),
                        nivel=2,
                        status=AtividadeStatus.PENDENTE,
                        tipo_projeto=sub_data.get("tipo_projeto"),
                        valor_previsto=float(sub_data.get("valor_previsto", 0)),
                        data_inicio_prevista=_parse_date_str(sub_data.get("data_inicio_prevista", "")),
                        data_fim_prevista=_parse_date_str(sub_data.get("data_fim_prevista", "")),
                    )
                    s.add(l2)
                    s.flush()

                    descricao_item = sub_data.get("descricao") or sub_data["nome"]
                    s.add(ChecklistItem(
                        atividade_id=l2.id,
                        titulo=f"Verificar: {sub_data['nome']}",
                        descricao=descricao_item[:500] if descricao_item else None,
                        origem="ia",
                        grupo=ativ_data["nome"],
                        ordem=sub_data.get("ordem", 0),
                    ))
                    total_checklist += 1

                    for svc_data in sub_data.get("servicos", []):
                        s.add(ServicoNecessario(
                            atividade_id=l2.id,
                            descricao=svc_data["descricao"],
                            categoria=svc_data.get("categoria", "outro"),
                        ))

                geradas += 1
                _atualizar_status_log(
                    log_id,
                    GeracaoUnificadaStatus.GERANDO,
                    etapa_atual=f"Salvando: {ativ_data['nome']}",
                    atividades_geradas=geradas,
                    total_itens_checklist=total_checklist,
                )

            s.commit()

        _atualizar_status_log(
            log_id,
            GeracaoUnificadaStatus.CONCLUIDO,
            etapa_atual="Concluido",
            atividades_geradas=geradas,
            total_itens_checklist=total_checklist,
        )
        logger.info("GeracaoUnificada log=%s concluido: %s atividades, %s checklist", log_id, geradas, total_checklist)

    except Exception as exc:
        logger.exception("Falha na geracao unificada log=%s: %s", log_id, exc)
        _atualizar_status_log(
            log_id,
            GeracaoUnificadaStatus.ERRO,
            etapa_atual="Erro",
            erro_detalhe=str(exc)[:500],
        )


# Mapa de eventos de cancelamento por log_id (AI-07)
_cancelamento_events: dict[UUID, threading.Event] = {}
_cancelamento_lock = threading.Lock()


def _get_or_create_cancelamento_event(log_id: UUID) -> threading.Event:
    """Retorna o Event de cancelamento associado ao log_id, criando se necessário."""
    with _cancelamento_lock:
        if log_id not in _cancelamento_events:
            _cancelamento_events[log_id] = threading.Event()
        return _cancelamento_events[log_id]


def _remove_cancelamento_event(log_id: UUID) -> None:
    """Remove o Event de cancelamento (cleanup pós-conclusão)."""
    with _cancelamento_lock:
        _cancelamento_events.pop(log_id, None)


@router.post(
    "/api/obras/{obra_id}/geracao-unificada/iniciar",
    response_model=GeracaoUnificadaLogRead,
)
def iniciar_geracao_unificada(
    obra_id: UUID,
    payload: IniciarGeracaoUnificadaRequest,
    session: Session = Depends(get_session),
    current_user: User = Depends(require_engineer),
) -> GeracaoUnificadaLogRead:
    """Inicia geração unificada (cronograma + checklist) em background.

    Retorna imediatamente com log_id para polling via GET /status.
    O cliente pode abrir GET /sse para detectar disconnect e cancelar o processamento.
    """
    obra = _verify_obra_ownership(obra_id, current_user, session)

    if not payload.tipos_projeto:
        raise HTTPException(status_code=400, detail="Nenhum tipo de projeto informado")

    # Verifica se ja existe processamento ativo
    existente = session.exec(
        select(GeracaoUnificadaLog)
        .where(GeracaoUnificadaLog.obra_id == obra_id)
        .where(GeracaoUnificadaLog.status.in_([  # type: ignore[attr-defined]
            GeracaoUnificadaStatus.PENDENTE,
            GeracaoUnificadaStatus.ANALISANDO,
            GeracaoUnificadaStatus.GERANDO,
        ]))
    ).first()
    if existente:
        raise HTTPException(status_code=409, detail="Ja existe uma geracao em andamento para esta obra.")

    log = GeracaoUnificadaLog(
        obra_id=obra_id,
        status=GeracaoUnificadaStatus.PENDENTE,
        etapa_atual="Aguardando inicio",
    )
    session.add(log)
    session.commit()
    session.refresh(log)

    cancelado = _get_or_create_cancelamento_event(log.id)

    tipos = list(payload.tipos_projeto)
    log_id = log.id

    def _run() -> None:
        try:
            _executar_geracao_unificada(log_id, obra_id, tipos, cancelado)
        finally:
            _remove_cancelamento_event(log_id)

    _background_pool.submit(_run)

    return GeracaoUnificadaLogRead.model_validate(log)


@router.get(
    "/api/obras/{obra_id}/geracao-unificada/{log_id}/status",
    response_model=GeracaoUnificadaLogRead,
)
def status_geracao_unificada(
    obra_id: UUID,
    log_id: UUID,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
) -> GeracaoUnificadaLogRead:
    """Retorna estado atual do log de geração unificada — endpoint de polling.

    Frontend chama periodicamente (ex: a cada 2s) para acompanhar o progresso.
    Quando status for CONCLUIDO ou ERRO, o polling pode parar.
    """
    _verify_obra_ownership(obra_id, current_user, session)

    log = session.get(GeracaoUnificadaLog, log_id)
    if not log or log.obra_id != obra_id:
        raise HTTPException(status_code=404, detail="Log de geracao nao encontrado")

    return GeracaoUnificadaLogRead.model_validate(log)


@router.get("/api/obras/{obra_id}/geracao-unificada/{log_id}/sse")
def sse_geracao_unificada(
    obra_id: UUID,
    log_id: UUID,
    request: Request,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
) -> StreamingResponse:
    """SSE stream para detectar disconnect do cliente (AI-07).

    O cliente conecta neste endpoint e mantém a conexão aberta enquanto aguarda.
    Quando o cliente desconecta (navega para outra tela), o servidor detecta via
    `request.is_disconnected()` e sinaliza o evento de cancelamento, interrompendo
    o processamento background e evitando consumo ocioso de tokens de IA.
    """
    _verify_obra_ownership(obra_id, current_user, session)

    log = session.get(GeracaoUnificadaLog, log_id)
    if not log or log.obra_id != obra_id:
        raise HTTPException(status_code=404, detail="Log de geracao nao encontrado")

    cancelado = _get_or_create_cancelamento_event(log_id)

    async def _sse_generator() -> Generator:
        """Mantém conexão SSE aberta; cancela background ao detectar disconnect."""
        yield "data: {\"connected\": true}\n\n"
        try:
            while True:
                if await request.is_disconnected():
                    logger.info("SSE disconnect detectado para log=%s — sinalizando cancelamento", log_id)
                    cancelado.set()
                    break
                yield ": keepalive\n\n"
                import asyncio
                await asyncio.sleep(5)
        except Exception:
            cancelado.set()

    return StreamingResponse(
        _sse_generator(),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "X-Accel-Buffering": "no",
        },
    )
