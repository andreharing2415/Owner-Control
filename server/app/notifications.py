"""Serviço de notificações push — alertas orçamentários e atualizações de convidados."""

import logging
from uuid import UUID

from sqlmodel import Session, select

from .models import Obra, OrcamentoEtapa, Despesa, AlertaConfig, DeviceToken
from .push import enviar_push_multiplos

logger = logging.getLogger(__name__)


def _tokens_por_obra(session: Session, obra_id: UUID) -> list[str]:
    tokens = session.exec(
        select(DeviceToken).where(DeviceToken.obra_id == obra_id)
    ).all()
    return [t.token for t in tokens]


def notificar_dono_atualizacao(session: Session, obra_id: UUID, nome_convidado: str) -> None:
    """Envia push notification ao dono da obra quando convidado faz atualização."""
    try:
        obra = session.get(Obra, obra_id)
        if not obra or not obra.user_id:
            return
        tokens = _tokens_por_obra(session, obra_id)
        if tokens:
            enviar_push_multiplos(
                tokens=tokens,
                titulo="Obra atualizada",
                corpo=f"O andamento da sua obra foi atualizado por {nome_convidado}",
            )
    except Exception as exc:
        logger.warning("Falha ao enviar push de atualização: %s", exc)


def notificar_publicacao_rdo(session: Session, obra_id: UUID, data_referencia: str) -> None:
    """Envia push quando um RDO diário é publicado para acompanhamento do dono."""
    try:
        obra = session.get(Obra, obra_id)
        if not obra:
            return
        tokens = _tokens_por_obra(session, obra_id)
        if not tokens:
            return
        enviar_push_multiplos(
            tokens=tokens,
            titulo="RDO publicado",
            corpo=f"{obra.nome}: diário de obra publicado em {data_referencia}",
            data={"obra_id": str(obra_id), "tipo": "rdo_publicado"},
        )
    except Exception as exc:
        logger.warning("Falha ao enviar push de RDO: %s", exc)


def verificar_e_notificar_alerta(obra_id: UUID, obra: Obra, session: Session) -> None:
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

        tokens = _tokens_por_obra(session, obra_id)
        if not tokens:
            return
        titulo = "⚠️ Alerta Orçamentário"
        corpo = (
            f"{obra.nome}: desvio de {desvio_pct:.1f}% "
            f"(limite: {alerta_config.percentual_desvio_threshold:.0f}%)"
        )
        enviar_push_multiplos(
            tokens,
            titulo,
            corpo,
            data={"obra_id": str(obra_id), "tipo": "alerta_orcamentario"},
        )
    except Exception as exc:
        logger.error("Erro ao verificar alerta push: %s", exc)
