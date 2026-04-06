"""Testes para GeracaoUnificadaLog — state machine e polling (AI-06)."""

import uuid
from datetime import datetime, timezone

import pytest

from app.models import GeracaoUnificadaLog
from app.schemas import GeracaoUnificadaLogRead, IniciarGeracaoUnificadaRequest
from app.enums import GeracaoUnificadaStatus


# ─── Fixtures ────────────────────────────────────────────────────────────────


def _make_log(**overrides) -> GeracaoUnificadaLog:
    """Retorna um GeracaoUnificadaLog com valores padrão."""
    now = datetime.now(timezone.utc)
    defaults = {
        "id": uuid.uuid4(),
        "obra_id": uuid.uuid4(),
        "status": GeracaoUnificadaStatus.PENDENTE,
        "etapa_atual": None,
        "total_atividades": 0,
        "atividades_geradas": 0,
        "total_itens_checklist": 0,
        "erro_detalhe": None,
        "created_at": now,
        "updated_at": now,
    }
    defaults.update(overrides)
    return GeracaoUnificadaLog(**defaults)


# ─── Testes: enum de estados ──────────────────────────────────────────────────


class TestGeracaoUnificadaStatus:
    """Valida que todos os estados da state machine estao definidos."""

    def test_estados_obrigatorios_existem(self):
        """Todos os 6 estados da state machine devem existir no enum."""
        assert GeracaoUnificadaStatus.PENDENTE == "pendente"
        assert GeracaoUnificadaStatus.ANALISANDO == "analisando"
        assert GeracaoUnificadaStatus.GERANDO == "gerando"
        assert GeracaoUnificadaStatus.CONCLUIDO == "concluido"
        assert GeracaoUnificadaStatus.ERRO == "erro"
        assert GeracaoUnificadaStatus.CANCELADO == "cancelado"

    def test_enum_e_string(self):
        """Valores do enum devem ser strings para serialização JSON direta."""
        for estado in GeracaoUnificadaStatus:
            assert isinstance(estado.value, str)

    def test_pendente_e_estado_inicial(self):
        """Estado inicial do log deve ser PENDENTE."""
        log = _make_log()
        assert log.status == GeracaoUnificadaStatus.PENDENTE


# ─── Testes: modelo GeracaoUnificadaLog ──────────────────────────────────────


class TestGeracaoUnificadaLogModel:
    """Valida campos e defaults do modelo ORM."""

    def test_campos_obrigatorios_presentes(self):
        """Modelo deve ter todos os campos da state machine."""
        campos = GeracaoUnificadaLog.model_fields
        obrigatorios = [
            "id", "obra_id", "status", "etapa_atual",
            "total_atividades", "atividades_geradas",
            "total_itens_checklist", "erro_detalhe",
            "created_at", "updated_at",
        ]
        for campo in obrigatorios:
            assert campo in campos, f"Campo obrigatorio ausente: {campo}"

    def test_defaults_numericos_sao_zero(self):
        """Contadores devem inicializar em zero."""
        log = _make_log()
        assert log.total_atividades == 0
        assert log.atividades_geradas == 0
        assert log.total_itens_checklist == 0

    def test_campos_opcionais_aceitam_none(self):
        """Campos de texto opcional devem aceitar None."""
        log = _make_log(etapa_atual=None, erro_detalhe=None)
        assert log.etapa_atual is None
        assert log.erro_detalhe is None

    def test_etapa_atual_preenchida(self):
        """etapa_atual descreve a etapa em curso para o cliente."""
        log = _make_log(etapa_atual="Gerando cronograma com IA")
        assert log.etapa_atual == "Gerando cronograma com IA"

    def test_contadores_atualizados(self):
        """Contadores devem refletir progresso real."""
        log = _make_log(total_atividades=5, atividades_geradas=3, total_itens_checklist=12)
        assert log.total_atividades == 5
        assert log.atividades_geradas == 3
        assert log.total_itens_checklist == 12

    def test_erro_detalhe_em_estado_erro(self):
        """Log em estado ERRO deve ter erro_detalhe preenchido."""
        log = _make_log(
            status=GeracaoUnificadaStatus.ERRO,
            erro_detalhe="IA nao retornou atividades",
        )
        assert log.status == GeracaoUnificadaStatus.ERRO
        assert log.erro_detalhe == "IA nao retornou atividades"


# ─── Testes: schema de resposta (polling) ────────────────────────────────────


class TestGeracaoUnificadaLogRead:
    """Valida que o schema de resposta serializa corretamente para polling."""

    def _make_read(**overrides) -> GeracaoUnificadaLogRead:
        now = datetime.now(timezone.utc)
        defaults = dict(
            id=uuid.uuid4(),
            obra_id=uuid.uuid4(),
            status=GeracaoUnificadaStatus.PENDENTE,
            etapa_atual=None,
            total_atividades=0,
            atividades_geradas=0,
            total_itens_checklist=0,
            erro_detalhe=None,
            created_at=now,
            updated_at=now,
        )
        defaults.update(overrides)
        return GeracaoUnificadaLogRead(**defaults)

    def test_schema_tem_campos_de_progresso(self):
        """Schema deve expor campos de progresso para o cliente fazer UI de loading."""
        campos = GeracaoUnificadaLogRead.model_fields
        assert "status" in campos
        assert "etapa_atual" in campos
        assert "total_atividades" in campos
        assert "atividades_geradas" in campos
        assert "total_itens_checklist" in campos

    def test_schema_tem_id_e_obra_id(self):
        """Schema deve expor id e obra_id para o cliente identificar o recurso."""
        campos = GeracaoUnificadaLogRead.model_fields
        assert "id" in campos
        assert "obra_id" in campos

    def test_schema_tem_timestamps(self):
        """Schema deve expor created_at e updated_at."""
        campos = GeracaoUnificadaLogRead.model_fields
        assert "created_at" in campos
        assert "updated_at" in campos

    def test_schema_instancia_com_status_pendente(self):
        """Schema deve serializar status PENDENTE corretamente."""
        read = TestGeracaoUnificadaLogRead._make_read(status=GeracaoUnificadaStatus.PENDENTE)
        assert read.status == "pendente"

    def test_schema_instancia_com_status_concluido(self):
        """Schema deve serializar status CONCLUIDO corretamente."""
        read = TestGeracaoUnificadaLogRead._make_read(
            status=GeracaoUnificadaStatus.CONCLUIDO,
            atividades_geradas=8,
            total_itens_checklist=24,
        )
        assert read.status == "concluido"
        assert read.atividades_geradas == 8
        assert read.total_itens_checklist == 24

    def test_schema_instancia_com_status_erro(self):
        """Schema deve serializar status ERRO com erro_detalhe."""
        read = TestGeracaoUnificadaLogRead._make_read(
            status=GeracaoUnificadaStatus.ERRO,
            erro_detalhe="Timeout na chamada IA",
        )
        assert read.status == "erro"
        assert read.erro_detalhe == "Timeout na chamada IA"

    def test_schema_instancia_com_status_cancelado(self):
        """Schema deve serializar status CANCELADO — cliente desconectou."""
        read = TestGeracaoUnificadaLogRead._make_read(status=GeracaoUnificadaStatus.CANCELADO)
        assert read.status == "cancelado"


# ─── Testes: request schema ───────────────────────────────────────────────────


class TestIniciarGeracaoUnificadaRequest:
    """Valida o schema de request para iniciar a geração."""

    def test_request_requer_tipos_projeto(self):
        """Request deve conter lista de tipos_projeto."""
        req = IniciarGeracaoUnificadaRequest(tipos_projeto=["Estrutural", "Hidraulico"])
        assert len(req.tipos_projeto) == 2
        assert "Estrutural" in req.tipos_projeto

    def test_request_com_lista_vazia(self):
        """Request com lista vazia deve ser aceito pelo schema (validacao no endpoint)."""
        req = IniciarGeracaoUnificadaRequest(tipos_projeto=[])
        assert req.tipos_projeto == []


# ─── Testes: state machine — transições válidas ───────────────────────────────


class TestStateMachineTransicoes:
    """Valida a sequencia de transicoes da state machine."""

    def test_transicao_pendente_para_analisando(self):
        """Log pode transitar de PENDENTE para ANALISANDO."""
        log = _make_log(status=GeracaoUnificadaStatus.PENDENTE)
        log.status = GeracaoUnificadaStatus.ANALISANDO
        assert log.status == GeracaoUnificadaStatus.ANALISANDO

    def test_transicao_analisando_para_gerando(self):
        """Log pode transitar de ANALISANDO para GERANDO."""
        log = _make_log(status=GeracaoUnificadaStatus.ANALISANDO)
        log.status = GeracaoUnificadaStatus.GERANDO
        assert log.status == GeracaoUnificadaStatus.GERANDO

    def test_transicao_gerando_para_concluido(self):
        """Log pode transitar de GERANDO para CONCLUIDO."""
        log = _make_log(status=GeracaoUnificadaStatus.GERANDO)
        log.status = GeracaoUnificadaStatus.CONCLUIDO
        assert log.status == GeracaoUnificadaStatus.CONCLUIDO

    def test_transicao_gerando_para_erro(self):
        """Log pode transitar de GERANDO para ERRO em caso de falha."""
        log = _make_log(status=GeracaoUnificadaStatus.GERANDO)
        log.status = GeracaoUnificadaStatus.ERRO
        log.erro_detalhe = "Falha na chamada IA"
        assert log.status == GeracaoUnificadaStatus.ERRO
        assert log.erro_detalhe == "Falha na chamada IA"

    def test_transicao_qualquer_estado_para_cancelado(self):
        """Log pode transitar para CANCELADO de qualquer estado (disconnect SSE)."""
        for estado in [
            GeracaoUnificadaStatus.PENDENTE,
            GeracaoUnificadaStatus.ANALISANDO,
            GeracaoUnificadaStatus.GERANDO,
        ]:
            log = _make_log(status=estado)
            log.status = GeracaoUnificadaStatus.CANCELADO
            assert log.status == GeracaoUnificadaStatus.CANCELADO

    def test_estados_terminais(self):
        """CONCLUIDO, ERRO e CANCELADO sao estados terminais — polling deve parar."""
        terminais = {
            GeracaoUnificadaStatus.CONCLUIDO,
            GeracaoUnificadaStatus.ERRO,
            GeracaoUnificadaStatus.CANCELADO,
        }
        estados_todos = set(GeracaoUnificadaStatus)
        estados_em_andamento = estados_todos - terminais

        assert GeracaoUnificadaStatus.PENDENTE in estados_em_andamento
        assert GeracaoUnificadaStatus.ANALISANDO in estados_em_andamento
        assert GeracaoUnificadaStatus.GERANDO in estados_em_andamento
        assert len(terminais) == 3
