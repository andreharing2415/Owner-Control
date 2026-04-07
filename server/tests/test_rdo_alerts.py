"""Testes da Fase 4: RDO e alertas de cronograma."""

import os
from datetime import date, timedelta
from types import SimpleNamespace
from uuid import uuid4

os.environ.setdefault("JWT_SECRET_KEY", "test-secret-key-rdo-alert")
os.environ.setdefault("DATABASE_URL", "sqlite:///./test_rdo_alerts.db")

from app.schemas import RdoRead
from app.services.cronograma_alert_service import detectar_alertas, enviar_alertas_cronograma


class _FakeExecResult:
    def __init__(self, data):
        self._data = data

    def all(self):
        return self._data


class _FakeSessionDetect:
    def __init__(self, obra, atividades):
        self._obra = obra
        self._atividades = atividades

    def get(self, _model, _id):
        return self._obra

    def exec(self, _query):
        return _FakeExecResult(self._atividades)


class _FakeSessionSend:
    def __init__(self, tokens):
        self._tokens = tokens

    def exec(self, _query):
        return _FakeExecResult([SimpleNamespace(token=t) for t in self._tokens])


def test_rdo_read_schema_preserves_fotos_urls_list():
    payload = {
        "id": str(uuid4()),
        "obra_id": str(uuid4()),
        "data_referencia": date.today().isoformat(),
        "clima": "Ensolarado",
        "mao_obra_total": 8,
        "atividades_executadas": "Concretagem e armacao",
        "observacoes": "Dia produtivo",
        "fotos_urls": ["https://img/1.jpg", "https://img/2.jpg"],
        "publicado": True,
        "publicado_em": None,
        "created_at": "2026-04-06T12:00:00Z",
        "updated_at": "2026-04-06T12:00:00Z",
    }

    model = RdoRead.model_validate(payload)
    assert len(model.fotos_urls) == 2
    assert model.fotos_urls[0].endswith("1.jpg")


def test_detectar_alertas_detects_overdue_activity():
    obra_id = uuid4()
    hoje = date.today()
    obra = SimpleNamespace(id=obra_id, nome="Casa A", data_fim=hoje + timedelta(days=30))
    atividade_atrasada = SimpleNamespace(
        id=uuid4(),
        nome="Concretagem",
        status="em_andamento",
        data_fim_prevista=hoje - timedelta(days=2),
    )

    session = _FakeSessionDetect(obra=obra, atividades=[atividade_atrasada])
    alertas = detectar_alertas(session, obra_id=obra_id, hoje=hoje)

    assert len(alertas) == 1
    assert alertas[0]["tipo"] == "atraso_atividade"
    assert alertas[0]["atraso_dias"] == 2


def test_detectar_alertas_detects_deadline_window():
    obra_id = uuid4()
    hoje = date.today()
    obra = SimpleNamespace(id=obra_id, nome="Casa B", data_fim=hoje + timedelta(days=7))

    session = _FakeSessionDetect(obra=obra, atividades=[])
    alertas = detectar_alertas(session, obra_id=obra_id, hoje=hoje)

    assert len(alertas) == 1
    assert alertas[0]["tipo"] == "prazo_final_proximo"
    assert alertas[0]["dias_restantes"] == 7


def test_enviar_alertas_cronograma_returns_zero_when_no_tokens(monkeypatch):
    obra_id = uuid4()

    monkeypatch.setattr(
        "app.services.cronograma_alert_service.detectar_alertas",
        lambda _s, _id: [{"tipo": "prazo_final_proximo", "dias_restantes": 5}],
    )

    session = _FakeSessionSend(tokens=[])
    enviados = enviar_alertas_cronograma(session, obra_id)

    assert enviados == 0


def test_enviar_alertas_cronograma_dispatches_push(monkeypatch):
    obra_id = uuid4()

    monkeypatch.setattr(
        "app.services.cronograma_alert_service.detectar_alertas",
        lambda _s, _id: [
            {
                "tipo": "atraso_atividade",
                "atividade_id": str(uuid4()),
                "atividade_nome": "Cobertura",
                "atraso_dias": 3,
            }
        ],
    )

    monkeypatch.setattr(
        "app.services.cronograma_alert_service.enviar_push_multiplos",
        lambda tokens, titulo, corpo, data: len(tokens),
    )

    session = _FakeSessionSend(tokens=["t1", "t2"])
    enviados = enviar_alertas_cronograma(session, obra_id)

    assert enviados == 2
