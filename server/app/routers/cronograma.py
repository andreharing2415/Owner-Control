"""Cronograma router — identificar projetos, gerar cronograma, atividades, servicos, checklist, despesas."""

from datetime import date, datetime, timezone
from typing import List, Optional
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlmodel import Session, select

from ..db import get_session
from ..models import (
    User, Obra, ProjetoDoc, AtividadeCronograma, ServicoNecessario,
    ChecklistItem, Despesa, Prestador,
)
from ..schemas import (
    IdentificarProjetosResponse,
    ServicoNecessarioRead, AtividadeCronogramaRead,
    CronogramaResponse, AtividadeUpdate,
    VincularPrestadorRequest, DespesaAtividadeCreate,
    ChecklistItemCreate, ChecklistItemRead,
    DespesaRead,
)
from ..enums import ProjetoDocStatus, AtividadeStatus
from ..auth import get_current_user
from ..helpers import _verify_obra_ownership
from ..cronograma_ai import identificar_tipos_projeto, gerar_cronograma

router = APIRouter(tags=["cronograma"])


# ─── Helpers ─────────────────────────────────────────────────────────────────


def _parse_date_str(value: str) -> Optional[date]:
    """Parse a date string (YYYY-MM-DD) or return None."""
    if not value:
        return None
    try:
        return date.fromisoformat(value)
    except (ValueError, TypeError):
        return None


def _build_atividade_read(
    atividade: AtividadeCronograma,
    sub_atividades: List[AtividadeCronogramaRead],
    servicos: List[ServicoNecessarioRead],
) -> AtividadeCronogramaRead:
    """Build an AtividadeCronogramaRead from a model instance."""
    return AtividadeCronogramaRead(
        id=atividade.id,
        obra_id=atividade.obra_id,
        parent_id=atividade.parent_id,
        nome=atividade.nome,
        descricao=atividade.descricao,
        ordem=atividade.ordem,
        nivel=atividade.nivel,
        status=atividade.status,
        data_inicio_prevista=atividade.data_inicio_prevista,
        data_fim_prevista=atividade.data_fim_prevista,
        data_inicio_real=atividade.data_inicio_real,
        data_fim_real=atividade.data_fim_real,
        valor_previsto=atividade.valor_previsto,
        valor_gasto=atividade.valor_gasto,
        tipo_projeto=atividade.tipo_projeto,
        sub_atividades=sub_atividades,
        servicos=servicos,
        created_at=atividade.created_at,
        updated_at=atividade.updated_at,
    )


def _get_servicos_read(atividade_id: UUID, session: Session) -> List[ServicoNecessarioRead]:
    """Fetch ServicoNecessario records for an activity and return as read models."""
    servicos = session.exec(
        select(ServicoNecessario).where(ServicoNecessario.atividade_id == atividade_id)
    ).all()
    return [
        ServicoNecessarioRead(
            id=s.id,
            atividade_id=s.atividade_id,
            descricao=s.descricao,
            categoria=s.categoria,
            prestador_id=s.prestador_id,
            created_at=s.created_at,
        )
        for s in servicos
    ]


def _build_cronograma_response(obra_id: UUID, session: Session) -> CronogramaResponse:
    """Build a full CronogramaResponse with nested L1 -> L2 activities and services."""
    l1_atividades = session.exec(
        select(AtividadeCronograma)
        .where(AtividadeCronograma.obra_id == obra_id)
        .where(AtividadeCronograma.nivel == 1)
        .order_by(AtividadeCronograma.ordem)
    ).all()

    atividades_read: List[AtividadeCronogramaRead] = []
    total_previsto = 0.0
    total_gasto = 0.0

    for l1 in l1_atividades:
        # Fetch L2 sub-activities
        l2_atividades = session.exec(
            select(AtividadeCronograma)
            .where(AtividadeCronograma.parent_id == l1.id)
            .where(AtividadeCronograma.nivel == 2)
            .order_by(AtividadeCronograma.ordem)
        ).all()

        sub_reads: List[AtividadeCronogramaRead] = []
        for l2 in l2_atividades:
            l2_servicos = _get_servicos_read(l2.id, session)
            sub_reads.append(_build_atividade_read(l2, [], l2_servicos))
            total_previsto += l2.valor_previsto
            total_gasto += l2.valor_gasto

        l1_servicos = _get_servicos_read(l1.id, session)
        atividades_read.append(_build_atividade_read(l1, sub_reads, l1_servicos))
        total_previsto += l1.valor_previsto
        total_gasto += l1.valor_gasto

    desvio = ((total_gasto - total_previsto) / total_previsto * 100) if total_previsto > 0 else 0.0

    return CronogramaResponse(
        obra_id=obra_id,
        total_previsto=round(total_previsto, 2),
        total_gasto=round(total_gasto, 2),
        desvio_percentual=round(desvio, 2),
        atividades=atividades_read,
    )


# ─── Request body models ────────────────────────────────────────────────────


class GerarCronogramaRequest(BaseModel):
    tipos_projeto: List[str]


# ─── 1. Identificar projetos ────────────────────────────────────────────────


@router.post("/api/obras/{obra_id}/identificar-projetos", response_model=IdentificarProjetosResponse)
def identificar_projetos(
    obra_id: UUID,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
) -> IdentificarProjetosResponse:
    """Analisa documentos concluidos da obra e identifica tipos de projeto."""
    _verify_obra_ownership(obra_id, current_user, session)

    docs = session.exec(
        select(ProjetoDoc)
        .where(ProjetoDoc.obra_id == obra_id)
        .where(ProjetoDoc.status == ProjetoDocStatus.CONCLUIDO)
    ).all()

    if not docs:
        raise HTTPException(status_code=400, detail="Nenhum documento concluido encontrado para esta obra")

    docs_info = [
        {
            "id": str(d.id),
            "arquivo_nome": d.arquivo_nome,
            "resumo_geral": d.resumo_geral,
        }
        for d in docs
    ]

    resultado = identificar_tipos_projeto(docs_info)

    return IdentificarProjetosResponse(
        tipos=resultado.get("tipos", []),
        resumo=resultado.get("resumo", ""),
        aviso_legal=resultado.get("aviso_legal", ""),
    )


# ─── 2. Gerar cronograma ────────────────────────────────────────────────────


@router.post("/api/obras/{obra_id}/cronograma/gerar", response_model=CronogramaResponse)
def gerar_cronograma_endpoint(
    obra_id: UUID,
    payload: GerarCronogramaRequest,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
) -> CronogramaResponse:
    """Gera cronograma hierarquico a partir dos tipos de projeto confirmados."""
    obra = _verify_obra_ownership(obra_id, current_user, session)

    if not payload.tipos_projeto:
        raise HTTPException(status_code=400, detail="Nenhum tipo de projeto informado")

    obra_info = {
        "nome": obra.nome,
        "localizacao": obra.localizacao or "",
        "orcamento": obra.orcamento or 0,
        "data_inicio": str(obra.data_inicio) if obra.data_inicio else "",
        "data_fim": str(obra.data_fim) if obra.data_fim else "",
    }

    resultado = gerar_cronograma(obra_info, payload.tipos_projeto)
    atividades_ai = resultado.get("atividades", [])

    if not atividades_ai:
        raise HTTPException(status_code=502, detail="IA nao retornou atividades para o cronograma")

    # Remove atividades anteriores desta obra (re-gerar)
    servicos_antigos = session.exec(
        select(ServicoNecessario).where(
            ServicoNecessario.atividade_id.in_(  # type: ignore[attr-defined]
                select(AtividadeCronograma.id).where(AtividadeCronograma.obra_id == obra_id)
            )
        )
    ).all()
    for s in servicos_antigos:
        session.delete(s)

    atividades_antigas = session.exec(
        select(AtividadeCronograma).where(AtividadeCronograma.obra_id == obra_id)
    ).all()
    for a in atividades_antigas:
        session.delete(a)
    session.flush()

    # Create L1 and L2 activities from AI result
    for ativ_data in atividades_ai:
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
        session.add(l1)
        session.flush()

        # Create services for L1
        for svc_data in ativ_data.get("servicos", []):
            svc = ServicoNecessario(
                atividade_id=l1.id,
                descricao=svc_data["descricao"],
                categoria=svc_data.get("categoria", "outro"),
            )
            session.add(svc)

        # Create L2 sub-activities
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
            session.add(l2)
            session.flush()

            # Create services for L2
            for svc_data in sub_data.get("servicos", []):
                svc = ServicoNecessario(
                    atividade_id=l2.id,
                    descricao=svc_data["descricao"],
                    categoria=svc_data.get("categoria", "outro"),
                )
                session.add(svc)

    session.commit()

    return _build_cronograma_response(obra_id, session)


# ─── 3. Listar cronograma ───────────────────────────────────────────────────


@router.get("/api/obras/{obra_id}/cronograma", response_model=CronogramaResponse)
def listar_cronograma(
    obra_id: UUID,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
) -> CronogramaResponse:
    """Lista o cronograma completo da obra com atividades L1, L2 e servicos."""
    _verify_obra_ownership(obra_id, current_user, session)
    return _build_cronograma_response(obra_id, session)


# ─── 4. Atualizar atividade ─────────────────────────────────────────────────


@router.patch("/api/cronograma/{atividade_id}", response_model=AtividadeCronogramaRead)
def atualizar_atividade(
    atividade_id: UUID,
    payload: AtividadeUpdate,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
) -> AtividadeCronogramaRead:
    """Atualiza status, datas ou valores de uma atividade do cronograma."""
    atividade = session.get(AtividadeCronograma, atividade_id)
    if not atividade:
        raise HTTPException(status_code=404, detail="Atividade nao encontrada")

    # Verify ownership via obra
    obra = session.get(Obra, atividade.obra_id)
    if not obra or obra.user_id != current_user.id:
        raise HTTPException(status_code=404, detail="Atividade nao encontrada")

    updates = payload.model_dump(exclude_unset=True)
    for key, value in updates.items():
        setattr(atividade, key, value)
    atividade.updated_at = datetime.now(timezone.utc)
    session.add(atividade)
    session.commit()
    session.refresh(atividade)

    servicos = _get_servicos_read(atividade.id, session)

    # Fetch sub-activities if L1
    sub_reads: List[AtividadeCronogramaRead] = []
    if atividade.nivel == 1:
        subs = session.exec(
            select(AtividadeCronograma)
            .where(AtividadeCronograma.parent_id == atividade.id)
            .order_by(AtividadeCronograma.ordem)
        ).all()
        for sub in subs:
            sub_servicos = _get_servicos_read(sub.id, session)
            sub_reads.append(_build_atividade_read(sub, [], sub_servicos))

    return _build_atividade_read(atividade, sub_reads, servicos)


# ─── 5. Listar servicos de uma atividade ────────────────────────────────────


@router.get("/api/cronograma/{atividade_id}/servicos", response_model=List[ServicoNecessarioRead])
def listar_servicos(
    atividade_id: UUID,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
) -> List[ServicoNecessarioRead]:
    """Lista servicos necessarios para uma atividade do cronograma."""
    atividade = session.get(AtividadeCronograma, atividade_id)
    if not atividade:
        raise HTTPException(status_code=404, detail="Atividade nao encontrada")

    obra = session.get(Obra, atividade.obra_id)
    if not obra or obra.user_id != current_user.id:
        raise HTTPException(status_code=404, detail="Atividade nao encontrada")

    return _get_servicos_read(atividade_id, session)


# ─── 6. Vincular prestador a servico ────────────────────────────────────────


@router.post("/api/servicos/{servico_id}/vincular", response_model=ServicoNecessarioRead)
def vincular_prestador(
    servico_id: UUID,
    payload: VincularPrestadorRequest,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
) -> ServicoNecessarioRead:
    """Vincula um prestador a um servico necessario."""
    servico = session.get(ServicoNecessario, servico_id)
    if not servico:
        raise HTTPException(status_code=404, detail="Servico nao encontrado")

    # Verify ownership via atividade -> obra
    atividade = session.get(AtividadeCronograma, servico.atividade_id)
    if not atividade:
        raise HTTPException(status_code=404, detail="Servico nao encontrado")
    obra = session.get(Obra, atividade.obra_id)
    if not obra or obra.user_id != current_user.id:
        raise HTTPException(status_code=404, detail="Servico nao encontrado")

    # Verify prestador exists
    prestador = session.get(Prestador, payload.prestador_id)
    if not prestador:
        raise HTTPException(status_code=404, detail="Prestador nao encontrado")

    servico.prestador_id = payload.prestador_id
    servico.updated_at = datetime.now(timezone.utc)
    session.add(servico)
    session.commit()
    session.refresh(servico)

    return ServicoNecessarioRead(
        id=servico.id,
        atividade_id=servico.atividade_id,
        descricao=servico.descricao,
        categoria=servico.categoria,
        prestador_id=servico.prestador_id,
        created_at=servico.created_at,
    )


# ─── 7. Listar checklist de uma atividade ───────────────────────────────────


@router.get("/api/cronograma/{atividade_id}/checklist", response_model=List[ChecklistItemRead])
def listar_checklist_atividade(
    atividade_id: UUID,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
) -> List[ChecklistItemRead]:
    """Lista itens de checklist vinculados a uma atividade do cronograma."""
    atividade = session.get(AtividadeCronograma, atividade_id)
    if not atividade:
        raise HTTPException(status_code=404, detail="Atividade nao encontrada")

    obra = session.get(Obra, atividade.obra_id)
    if not obra or obra.user_id != current_user.id:
        raise HTTPException(status_code=404, detail="Atividade nao encontrada")

    items = session.exec(
        select(ChecklistItem).where(ChecklistItem.atividade_id == atividade_id)
    ).all()

    return [ChecklistItemRead.model_validate(item) for item in items]


# ─── 8. Criar checklist item para atividade ──────────────────────────────────


@router.post("/api/cronograma/{atividade_id}/checklist", response_model=ChecklistItemRead)
def criar_checklist_atividade(
    atividade_id: UUID,
    payload: ChecklistItemCreate,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
) -> ChecklistItemRead:
    """Cria um item de checklist vinculado a uma atividade do cronograma."""
    atividade = session.get(AtividadeCronograma, atividade_id)
    if not atividade:
        raise HTTPException(status_code=404, detail="Atividade nao encontrada")

    obra = session.get(Obra, atividade.obra_id)
    if not obra or obra.user_id != current_user.id:
        raise HTTPException(status_code=404, detail="Atividade nao encontrada")

    item_data = payload.model_dump()
    item_data.pop("etapa_id", None)  # Ignore etapa_id if present
    item = ChecklistItem(
        atividade_id=atividade_id,
        **item_data,
    )
    session.add(item)
    session.commit()
    session.refresh(item)

    return ChecklistItemRead.model_validate(item)


# ─── 9. Criar despesa para atividade ────────────────────────────────────────


@router.post("/api/cronograma/{atividade_id}/despesas", response_model=DespesaRead)
def criar_despesa_atividade(
    atividade_id: UUID,
    payload: DespesaAtividadeCreate,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
) -> DespesaRead:
    """Cria uma despesa vinculada a uma atividade do cronograma."""
    atividade = session.get(AtividadeCronograma, atividade_id)
    if not atividade:
        raise HTTPException(status_code=404, detail="Atividade nao encontrada")

    obra = session.get(Obra, atividade.obra_id)
    if not obra or obra.user_id != current_user.id:
        raise HTTPException(status_code=404, detail="Atividade nao encontrada")

    despesa = Despesa(
        obra_id=obra.id,
        atividade_id=atividade_id,
        valor=payload.valor,
        descricao=payload.descricao,
        data=payload.data,
        categoria=payload.categoria,
    )
    session.add(despesa)
    session.commit()
    session.refresh(despesa)

    return DespesaRead.model_validate(despesa)
