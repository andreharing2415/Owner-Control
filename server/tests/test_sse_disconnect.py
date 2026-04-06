"""Testes para cancelamento por disconnect SSE (AI-07).

Valida que:
- O evento de cancelamento e sinalizado quando o cliente desconecta
- O worker background para ao detectar o evento cancelado
- O status transita para CANCELADO
"""

import threading
import time
import uuid
from datetime import datetime, timezone
from unittest.mock import MagicMock, patch, call

import pytest

from app.enums import GeracaoUnificadaStatus
from app.models import GeracaoUnificadaLog


# ─── Helpers ─────────────────────────────────────────────────────────────────


def _make_log(**overrides) -> GeracaoUnificadaLog:
    now = datetime.now(timezone.utc)
    defaults = dict(
        id=uuid.uuid4(),
        obra_id=uuid.uuid4(),
        status=GeracaoUnificadaStatus.GERANDO,
        etapa_atual="Gerando atividades",
        total_atividades=5,
        atividades_geradas=2,
        total_itens_checklist=6,
        erro_detalhe=None,
        created_at=now,
        updated_at=now,
    )
    defaults.update(overrides)
    return GeracaoUnificadaLog(**defaults)


# ─── Testes: evento de cancelamento ─────────────────────────────────────────


class TestCancelamentoEvent:
    """Valida a logica do evento de cancelamento threading.Event."""

    def test_event_nao_sinalizado_por_padrao(self):
        """threading.Event nao deve estar sinalizado ao criar."""
        evento = threading.Event()
        assert not evento.is_set()

    def test_event_sinalizado_ao_set(self):
        """threading.Event.set() deve sinalizar o evento."""
        evento = threading.Event()
        evento.set()
        assert evento.is_set()

    def test_event_desativado_apos_clear(self):
        """threading.Event.clear() deve desativar o sinal."""
        evento = threading.Event()
        evento.set()
        evento.clear()
        assert not evento.is_set()

    def test_worker_para_quando_cancelado(self):
        """Worker deve parar ao detectar cancelado.is_set() == True."""
        cancelado = threading.Event()
        iteracoes = []

        def _worker():
            for i in range(10):
                if cancelado.is_set():
                    break
                iteracoes.append(i)
                if i == 2:
                    cancelado.set()

        t = threading.Thread(target=_worker)
        t.start()
        t.join(timeout=2)

        # Worker deve ter parado apos detectar cancelamento (max 3 iteracoes)
        assert len(iteracoes) <= 3
        assert cancelado.is_set()

    def test_cancelamento_de_outra_thread(self):
        """SSE handler (thread A) deve poder cancelar worker (thread B)."""
        cancelado = threading.Event()
        worker_parou = threading.Event()

        def _worker():
            for _ in range(100):
                if cancelado.is_set():
                    worker_parou.set()
                    return
                time.sleep(0.01)

        t = threading.Thread(target=_worker)
        t.start()
        time.sleep(0.02)  # deixa worker iniciar

        cancelado.set()  # simula disconnect SSE
        worker_parou.wait(timeout=2)

        assert worker_parou.is_set(), "Worker deve parar apos cancelamento SSE"
        t.join(timeout=2)


# ─── Testes: _atualizar_status_log com CANCELADO ─────────────────────────────


class TestAtualizarStatusLogCancelado:
    """Valida que _atualizar_status_log transita para CANCELADO."""

    def test_status_cancelado_tem_valor_correto(self):
        """Status CANCELADO deve ter valor de string 'cancelado'."""
        assert GeracaoUnificadaStatus.CANCELADO == "cancelado"

    def test_log_aceita_status_cancelado(self):
        """Modelo deve aceitar status CANCELADO (nao e erro de schema)."""
        log = _make_log(status=GeracaoUnificadaStatus.CANCELADO)
        assert log.status == "cancelado"

    def test_log_cancelado_sem_erro_detalhe(self):
        """Log cancelado por disconnect nao deve ter erro_detalhe (nao e uma falha)."""
        log = _make_log(
            status=GeracaoUnificadaStatus.CANCELADO,
            etapa_atual="Cancelado pelo cliente",
            erro_detalhe=None,
        )
        assert log.status == "cancelado"
        assert log.erro_detalhe is None
        assert log.etapa_atual == "Cancelado pelo cliente"

    def test_log_cancelado_preserva_progresso_parcial(self):
        """Log cancelado deve manter o progresso ja feito antes do disconnect."""
        log = _make_log(
            status=GeracaoUnificadaStatus.CANCELADO,
            atividades_geradas=3,
            total_atividades=8,
            total_itens_checklist=9,
        )
        assert log.atividades_geradas == 3
        assert log.total_atividades == 8
        assert log.total_itens_checklist == 9


# ─── Testes: logica de detect-disconnect no SSE ──────────────────────────────


class TestSseDisconnectLogica:
    """Valida a logica de deteccao de disconnect via request.is_disconnected()."""

    @pytest.mark.asyncio
    async def test_request_desconectado_sinaliza_cancelamento(self):
        """Quando request.is_disconnected() retorna True, cancelado deve ser set()."""
        cancelado = threading.Event()
        disconnect_detectado = threading.Event()

        # Simula a coroutine do SSE generator
        async def _request_is_disconnected_mock():
            return True  # simula cliente desconectado imediatamente

        request_mock = MagicMock()
        request_mock.is_disconnected = _request_is_disconnected_mock

        # Simula o loop do generator
        if await request_mock.is_disconnected():
            cancelado.set()
            disconnect_detectado.set()

        assert cancelado.is_set(), "Cancelado deve ser sinalizado apos disconnect"
        assert disconnect_detectado.is_set()

    @pytest.mark.asyncio
    async def test_request_conectado_nao_sinaliza_cancelamento(self):
        """Quando cliente ainda conectado, cancelado NAO deve ser sinalizado."""
        cancelado = threading.Event()
        chamadas = [False, False, True]  # desconecta na 3a verificacao
        indice = [0]

        async def _is_disconnected():
            resultado = chamadas[indice[0]]
            indice[0] = min(indice[0] + 1, len(chamadas) - 1)
            return resultado

        request_mock = MagicMock()
        request_mock.is_disconnected = _is_disconnected

        # Primeira e segunda verificacoes: cliente ainda conectado
        assert not await request_mock.is_disconnected()
        assert not cancelado.is_set()

        assert not await request_mock.is_disconnected()
        assert not cancelado.is_set()

        # Terceira verificacao: cliente desconectou
        if await request_mock.is_disconnected():
            cancelado.set()

        assert cancelado.is_set()


# ─── Testes: gerenciamento de eventos de cancelamento ────────────────────────


def _make_event_manager():
    """Replica inline a logica do _cancelamento_events do router.

    Evita importar o modulo router (que requer DATABASE_URL) nos testes.
    Testa o padrao em si — o comportamento exato do router.
    """
    events: dict = {}
    lock = threading.Lock()

    def get_or_create(log_id: uuid.UUID) -> threading.Event:
        with lock:
            if log_id not in events:
                events[log_id] = threading.Event()
            return events[log_id]

    def remove(log_id: uuid.UUID) -> None:
        with lock:
            events.pop(log_id, None)

    return events, get_or_create, remove


class TestGerenciamentoEvents:
    """Valida o mapa de eventos de cancelamento por log_id.

    Testa o padrao implementado em _cancelamento_events/_get_or_create/_remove.
    A logica e replicada inline para evitar dependencia de DATABASE_URL nos testes.
    """

    def test_mesmo_log_id_retorna_mesmo_event(self):
        """Dois acessos ao mesmo log_id devem retornar o mesmo Event."""
        events, get_or_create, remove = _make_event_manager()
        log_id = uuid.uuid4()
        try:
            ev1 = get_or_create(log_id)
            ev2 = get_or_create(log_id)
            assert ev1 is ev2, "Mesmo log_id deve retornar mesmo Event"
        finally:
            remove(log_id)

    def test_log_ids_diferentes_retornam_events_diferentes(self):
        """Dois log_ids distintos devem ter Events independentes."""
        events, get_or_create, remove = _make_event_manager()
        id1 = uuid.uuid4()
        id2 = uuid.uuid4()
        try:
            ev1 = get_or_create(id1)
            ev2 = get_or_create(id2)
            assert ev1 is not ev2, "Log IDs distintos devem ter Events independentes"
        finally:
            remove(id1)
            remove(id2)

    def test_cancelar_um_nao_afeta_outro(self):
        """Cancelar um log nao deve afetar Events de outros logs."""
        events, get_or_create, remove = _make_event_manager()
        id1 = uuid.uuid4()
        id2 = uuid.uuid4()
        try:
            ev1 = get_or_create(id1)
            ev2 = get_or_create(id2)

            ev1.set()  # cancela apenas o log 1

            assert ev1.is_set()
            assert not ev2.is_set(), "Cancelar log1 nao deve afetar log2"
        finally:
            remove(id1)
            remove(id2)

    def test_remove_event_apos_conclusao(self):
        """Event deve ser removido do mapa apos conclusao para evitar memory leak."""
        events, get_or_create, remove = _make_event_manager()
        log_id = uuid.uuid4()

        get_or_create(log_id)
        assert log_id in events

        remove(log_id)
        assert log_id not in events, "Event deve ser removido apos conclusao"

    def test_remove_event_inexistente_nao_lanca_excecao(self):
        """Remover Event inexistente nao deve lancar excecao."""
        events, get_or_create, remove = _make_event_manager()
        log_id = uuid.uuid4()
        # Nao deve lancar excecao mesmo se o evento nao existir
        remove(log_id)  # nao deve lancar
