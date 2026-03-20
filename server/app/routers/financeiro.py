"""Financeiro router — orcamento, despesas, relatorio, alertas, device-tokens."""

from datetime import datetime, timezone
from typing import List
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException
from sqlmodel import Session, select

from ..db import get_session
from ..models import (
    User, Obra, Etapa, OrcamentoEtapa, Despesa,
    AlertaConfig, DeviceToken,
)
from ..schemas import (
    OrcamentoEtapaCreate, OrcamentoEtapaRead,
    DespesaCreate, DespesaRead,
    AlertaConfigUpdate, AlertaConfigRead,
    EtapaFinanceiroItem, RelatorioFinanceiro,
    DeviceTokenCreate, DeviceTokenRead,
    CurvaSPonto,
)
from ..auth import get_current_user
from ..helpers import _verify_obra_ownership, _verificar_e_notificar_alerta

router = APIRouter(tags=["financeiro"])


@router.post("/api/obras/{obra_id}/orcamento", response_model=List[OrcamentoEtapaRead])
def registrar_orcamento(
    obra_id: UUID,
    payload: List[OrcamentoEtapaCreate],
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
) -> list[OrcamentoEtapa]:
    """Registra ou atualiza o orçamento previsto e realizado por etapa (upsert)."""
    obra = _verify_obra_ownership(obra_id, current_user, session)
    resultado: list[OrcamentoEtapa] = []
    for item in payload:
        existing = session.exec(
            select(OrcamentoEtapa)
            .where(OrcamentoEtapa.obra_id == obra_id)
            .where(OrcamentoEtapa.etapa_id == item.etapa_id)
        ).first()
        if existing:
            existing.valor_previsto = item.valor_previsto
            existing.valor_realizado = item.valor_realizado
            existing.updated_at = datetime.now(timezone.utc)
            session.add(existing)
            resultado.append(existing)
        else:
            orcamento = OrcamentoEtapa(
                obra_id=obra_id,
                etapa_id=item.etapa_id,
                valor_previsto=item.valor_previsto,
                valor_realizado=item.valor_realizado,
            )
            session.add(orcamento)
            resultado.append(orcamento)
    session.commit()
    for o in resultado:
        session.refresh(o)
    return resultado


@router.get("/api/obras/{obra_id}/orcamento", response_model=List[OrcamentoEtapaRead])
def consultar_orcamento(
    obra_id: UUID,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
) -> list[OrcamentoEtapa]:
    """Retorna o orçamento previsto por etapa da obra."""
    obra = _verify_obra_ownership(obra_id, current_user, session)
    return session.exec(
        select(OrcamentoEtapa).where(OrcamentoEtapa.obra_id == obra_id)
    ).all()


@router.post("/api/obras/{obra_id}/despesas", response_model=DespesaRead)
def lancar_despesa(
    obra_id: UUID,
    payload: DespesaCreate,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
) -> Despesa:
    """Lança uma nova despesa na obra."""
    obra = _verify_obra_ownership(obra_id, current_user, session)
    if payload.etapa_id:
        etapa = session.get(Etapa, payload.etapa_id)
        if not etapa or etapa.obra_id != obra_id:
            raise HTTPException(status_code=400, detail="Etapa nao pertence a esta obra")
    despesa = Despesa(obra_id=obra_id, **payload.model_dump(mode="json"))
    session.add(despesa)
    session.commit()
    session.refresh(despesa)

    # Verificar se o lançamento disparou um alerta orçamentário
    _verificar_e_notificar_alerta(obra_id=obra_id, obra=obra, session=session)

    return despesa


@router.get("/api/obras/{obra_id}/despesas", response_model=List[DespesaRead])
def listar_despesas(
    obra_id: UUID,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
) -> list[Despesa]:
    """Lista todas as despesas lançadas na obra."""
    obra = _verify_obra_ownership(obra_id, current_user, session)
    return session.exec(
        select(Despesa).where(Despesa.obra_id == obra_id).order_by(Despesa.data.desc())
    ).all()


@router.get("/api/obras/{obra_id}/relatorio-financeiro", response_model=RelatorioFinanceiro)
def relatorio_financeiro(
    obra_id: UUID,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
) -> RelatorioFinanceiro:
    """Calcula desvio orçamentário e prepara dados para curva S."""
    obra = _verify_obra_ownership(obra_id, current_user, session)

    etapas = session.exec(
        select(Etapa).where(Etapa.obra_id == obra_id).order_by(Etapa.ordem)
    ).all()
    orcamentos = session.exec(
        select(OrcamentoEtapa).where(OrcamentoEtapa.obra_id == obra_id)
    ).all()
    despesas = session.exec(
        select(Despesa).where(Despesa.obra_id == obra_id)
    ).all()
    alerta_config = session.exec(
        select(AlertaConfig).where(AlertaConfig.obra_id == obra_id)
    ).first()
    threshold = alerta_config.percentual_desvio_threshold if alerta_config else 10.0

    orcamento_por_etapa = {str(o.etapa_id): o.valor_previsto for o in orcamentos}
    realizado_por_etapa = {str(o.etapa_id): o.valor_realizado for o in orcamentos if o.valor_realizado is not None}
    gasto_por_etapa: dict[str, float] = {}
    for d in despesas:
        key = str(d.etapa_id) if d.etapa_id else "__sem_etapa__"
        gasto_por_etapa[key] = gasto_por_etapa.get(key, 0.0) + d.valor

    por_etapa: list[EtapaFinanceiroItem] = []
    for etapa in etapas:
        previsto = orcamento_por_etapa.get(str(etapa.id), 0.0)
        gasto = realizado_por_etapa.get(str(etapa.id), gasto_por_etapa.get(str(etapa.id), 0.0))
        if previsto > 0:
            desvio_pct = ((gasto - previsto) / previsto) * 100
        else:
            desvio_pct = 0.0
        por_etapa.append(EtapaFinanceiroItem(
            etapa_id=str(etapa.id),
            etapa_nome=etapa.nome,
            valor_previsto=previsto,
            valor_gasto=gasto,
            desvio_percentual=round(desvio_pct, 2),
            alerta=desvio_pct > threshold,
        ))

    total_previsto = sum(e.valor_previsto for e in por_etapa)
    total_gasto = sum(e.valor_gasto for e in por_etapa)
    if total_previsto > 0:
        desvio_total = ((total_gasto - total_previsto) / total_previsto) * 100
    else:
        desvio_total = 0.0

    # ─── Gerar dados da Curva S (acumulado por etapa) ──────────────────
    curva_s: list[CurvaSPonto] = []
    acum_previsto = 0.0
    acum_realizado = 0.0
    for ep in por_etapa:
        acum_previsto += ep.valor_previsto
        acum_realizado += ep.valor_gasto
        curva_s.append(CurvaSPonto(
            data=ep.etapa_nome,
            previsto=round(acum_previsto, 2),
            realizado=round(acum_realizado, 2),
        ))

    return RelatorioFinanceiro(
        obra_id=obra_id,
        total_previsto=total_previsto,
        total_gasto=total_gasto,
        desvio_percentual=round(desvio_total, 2),
        alerta=desvio_total > threshold,
        threshold=threshold,
        por_etapa=por_etapa,
        curva_s=curva_s,
    )


@router.put("/api/obras/{obra_id}/alertas", response_model=AlertaConfigRead)
def configurar_alertas(
    obra_id: UUID,
    payload: AlertaConfigUpdate,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
) -> AlertaConfig:
    """Cria ou atualiza a configuração de alertas de desvio da obra."""
    obra = _verify_obra_ownership(obra_id, current_user, session)
    config = session.exec(
        select(AlertaConfig).where(AlertaConfig.obra_id == obra_id)
    ).first()
    if not config:
        config = AlertaConfig(obra_id=obra_id)
        session.add(config)
    updates = payload.model_dump(exclude_unset=True)
    for key, value in updates.items():
        setattr(config, key, value)
    config.updated_at = datetime.now(timezone.utc)
    session.add(config)
    session.commit()
    session.refresh(config)
    return config


@router.post("/api/obras/{obra_id}/device-tokens", response_model=DeviceTokenRead)
def registrar_device_token(
    obra_id: UUID,
    payload: DeviceTokenCreate,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
) -> DeviceToken:
    """Registra (ou atualiza) o token FCM de um dispositivo para esta obra."""
    obra = _verify_obra_ownership(obra_id, current_user, session)

    # Evitar duplicatas: upsert por token+obra_id
    existing = session.exec(
        select(DeviceToken).where(
            DeviceToken.obra_id == obra_id,
            DeviceToken.token == payload.token,
        )
    ).first()

    if existing:
        existing.platform = payload.platform
        existing.updated_at = datetime.now(timezone.utc)
        session.add(existing)
        session.commit()
        session.refresh(existing)
        return existing

    dt = DeviceToken(obra_id=obra_id, token=payload.token, platform=payload.platform)
    session.add(dt)
    session.commit()
    session.refresh(dt)
    return dt


@router.delete("/api/obras/{obra_id}/device-tokens/{token}", status_code=204)
def remover_device_token(
    obra_id: UUID,
    token: str,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
) -> None:
    """Remove o token FCM de um dispositivo (ex: ao fazer logout ou desativar alertas)."""
    dt = session.exec(
        select(DeviceToken).where(
            DeviceToken.obra_id == obra_id,
            DeviceToken.token == token,
        )
    ).first()
    if dt:
        session.delete(dt)
        session.commit()
