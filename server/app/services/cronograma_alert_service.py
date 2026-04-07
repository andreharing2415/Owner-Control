"""Serviço de alertas de cronograma por atraso e proximidade de prazo final."""

from datetime import date
from typing import Any
from uuid import UUID

from sqlmodel import Session, select

from ..models import AtividadeCronograma, DeviceToken, Obra
from ..push import enviar_push_multiplos


def detectar_alertas(session: Session, obra_id: UUID, hoje: date | None = None) -> list[dict[str, Any]]:
    hoje = hoje or date.today()
    obra = session.get(Obra, obra_id)
    if not obra:
        return []

    alertas: list[dict[str, Any]] = []
    atividades = session.exec(
        select(AtividadeCronograma).where(AtividadeCronograma.obra_id == obra_id)
    ).all()

    for atividade in atividades:
        if (
            atividade.status != "concluida"
            and atividade.data_fim_prevista
            and atividade.data_fim_prevista < hoje
        ):
            atraso_dias = (hoje - atividade.data_fim_prevista).days
            alertas.append(
                {
                    "tipo": "atraso_atividade",
                    "atividade_id": str(atividade.id),
                    "atividade_nome": atividade.nome,
                    "atraso_dias": atraso_dias,
                }
            )

    if obra.data_fim:
        dias_restantes = (obra.data_fim - hoje).days
        if 0 <= dias_restantes <= 7:
            alertas.append(
                {
                    "tipo": "prazo_final_proximo",
                    "obra_id": str(obra.id),
                    "obra_nome": obra.nome,
                    "dias_restantes": dias_restantes,
                }
            )

    return alertas


def enviar_alertas_cronograma(session: Session, obra_id: UUID) -> int:
    alertas = detectar_alertas(session, obra_id)
    if not alertas:
        return 0

    tokens = session.exec(
        select(DeviceToken).where(DeviceToken.obra_id == obra_id)
    ).all()
    token_list = [t.token for t in tokens]
    if not token_list:
        return 0

    enviados = 0
    for alerta in alertas:
        if alerta["tipo"] == "atraso_atividade":
            enviados += enviar_push_multiplos(
                token_list,
                "Atraso detectado no cronograma",
                f"Atividade {alerta['atividade_nome']} atrasada há {alerta['atraso_dias']} dia(s).",
                data={
                    "tipo": "alerta_cronograma",
                    "subtipo": "atraso_atividade",
                    "obra_id": str(obra_id),
                    "atividade_id": alerta["atividade_id"],
                },
            )
        elif alerta["tipo"] == "prazo_final_proximo":
            enviados += enviar_push_multiplos(
                token_list,
                "Prazo final da obra próximo",
                f"A obra termina em {alerta['dias_restantes']} dia(s).",
                data={
                    "tipo": "alerta_cronograma",
                    "subtipo": "prazo_final_proximo",
                    "obra_id": str(obra_id),
                },
            )

    return enviados
