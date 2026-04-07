"""Checklist router — CRUD items, verificar, evidencias list."""

import json
from datetime import datetime, timezone
from typing import List, Union
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException
from sqlmodel import Session, select

from ..db import get_session
from ..models import User, ChecklistItem, Evidencia
from ..schemas import (
    ChecklistItemCreate, ChecklistItemRead, ChecklistItemUpdate,
    ChecklistItemOwnerView, EvidenciaRead, RegistrarVerificacaoRequest,
    project_checklist_item_for_role,
)
from ..auth import get_current_user, require_engineer
from ..subscription import get_plan_config
from ..helpers import (
    _verify_etapa_ownership, _verify_etapa_access,
    _notificar_dono_atualizacao,
)

router = APIRouter(tags=["checklist"])


@router.get(
    "/api/etapas/{etapa_id}/checklist-items",
    response_model=List[Union[ChecklistItemRead, ChecklistItemOwnerView]],
)
def listar_itens(
    etapa_id: UUID,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
) -> list[Union[ChecklistItemRead, ChecklistItemOwnerView]]:
    _verify_etapa_access(etapa_id, current_user, session)
    items = session.exec(select(ChecklistItem).where(ChecklistItem.etapa_id == etapa_id)).all()
    return [
        project_checklist_item_for_role(ChecklistItemRead.model_validate(item), current_user.role)
        for item in items
    ]


@router.post("/api/etapas/{etapa_id}/checklist-items", response_model=ChecklistItemRead)
def criar_item(
    etapa_id: UUID,
    payload: ChecklistItemCreate,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
) -> ChecklistItem:
    etapa, role = _verify_etapa_access(etapa_id, current_user, session)
    # Free users não podem criar itens; convidados podem
    if role == "dono" and not get_plan_config(current_user).get("can_create_checklist_items"):
        raise HTTPException(status_code=403, detail="Recurso disponível apenas para assinantes")
    item = ChecklistItem(etapa_id=etapa_id, **payload.model_dump(mode="json"))
    session.add(item)
    session.commit()
    session.refresh(item)
    # Notificar dono se quem criou é convidado
    if role == "convidado":
        _notificar_dono_atualizacao(session, etapa.obra_id, current_user.nome)
    return item


@router.patch("/api/checklist-items/{item_id}", response_model=ChecklistItemRead)
def atualizar_item(
    item_id: UUID,
    payload: ChecklistItemUpdate,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
) -> ChecklistItem:
    item = session.get(ChecklistItem, item_id)
    if not item:
        raise HTTPException(status_code=404, detail="Item nao encontrado")
    etapa, role = _verify_etapa_access(item.etapa_id, current_user, session)
    updates = payload.model_dump(exclude_unset=True, mode="json")
    for key, value in updates.items():
        setattr(item, key, value)
    item.updated_at = datetime.now(timezone.utc)
    session.add(item)
    session.commit()
    session.refresh(item)
    if role == "convidado":
        _notificar_dono_atualizacao(session, etapa.obra_id, current_user.nome)
    return item


@router.delete("/api/checklist-items/{item_id}", status_code=204)
def deletar_item(
    item_id: UUID,
    session: Session = Depends(get_session),
    current_user: User = Depends(require_engineer),
):
    item = session.get(ChecklistItem, item_id)
    if not item:
        raise HTTPException(status_code=404, detail="Item nao encontrado")
    _verify_etapa_ownership(item.etapa_id, current_user, session)
    session.delete(item)
    session.commit()


@router.post("/api/checklist-items/{item_id}/verificar", response_model=ChecklistItemRead)
def verificar_checklist_item(
    item_id: UUID,
    body: RegistrarVerificacaoRequest,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
) -> ChecklistItemRead:
    """Registra verificação do proprietário num item do checklist e cruza com dados do projeto."""
    item = session.get(ChecklistItem, item_id)
    if not item:
        raise HTTPException(status_code=404, detail="Item nao encontrado")

    # Salva registro do proprietário
    registro = {
        "valor_medido": body.valor_medido,
        "status": body.status,
        "foto_ids": body.foto_ids or [],
        "data_verificacao": datetime.now(timezone.utc).isoformat(),
    }
    item.registro_proprietario = json.dumps(registro, ensure_ascii=False)
    item.status_verificacao = body.status

    # Cruzamento com dados do projeto
    dado_projeto = json.loads(item.dado_projeto) if item.dado_projeto else None
    if dado_projeto and body.valor_medido:
        valor_ref = dado_projeto.get("valor_referencia", "")
        especificacao = dado_projeto.get("especificacao", "")
        descricao_proj = dado_projeto.get("descricao", "")

        if body.status == "conforme":
            resultado = {
                "conclusao": "conforme",
                "resumo": f"A verificacao esta de acordo com o projeto ({especificacao}).",
                "acao": None,
                "urgencia": "baixa",
            }
        elif body.status == "divergente":
            resultado = {
                "conclusao": "divergente",
                "resumo": (
                    f"{descricao_proj}: medido {body.valor_medido}, "
                    f"projeto indica {valor_ref}."
                ),
                "acao": "Pergunte ao engenheiro usando a sugestao abaixo.",
                "urgencia": "alta",
            }
        else:
            resultado = {
                "conclusao": "duvida",
                "resumo": (
                    f"Duvida sobre {descricao_proj}. "
                    f"Valor de referencia: {valor_ref}."
                ),
                "acao": "Converse com o engenheiro para esclarecer.",
                "urgencia": "media",
            }
        item.resultado_cruzamento = json.dumps(resultado, ensure_ascii=False)

    item.updated_at = datetime.now(timezone.utc)
    session.add(item)
    session.commit()
    session.refresh(item)
    return ChecklistItemRead.model_validate(item)


@router.get("/api/checklist-items/{item_id}/evidencias", response_model=List[EvidenciaRead])
def listar_evidencias(
    item_id: UUID,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
) -> list[Evidencia]:
    item = session.get(ChecklistItem, item_id)
    if not item:
        raise HTTPException(status_code=404, detail="Item nao encontrado")
    _verify_etapa_access(item.etapa_id, current_user, session)
    return session.exec(select(Evidencia).where(Evidencia.checklist_item_id == item_id)).all()
