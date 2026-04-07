"""Testes de projecao de schema por papel (ROLE-04, OWNER-03).

Valida que ChecklistItemOwnerView e AtividadeOwnerView/CronogramaOwnerView:
- Excluem campos tecnicos da experiencia do dono_da_obra
- Preservam todos os campos tecnicos no EngineerView (ChecklistItemRead / AtividadeCronogramaRead)
- Selecionam o serializer correto conforme o papel do usuario

Estrategia: testes unitarios puros — sem banco de dados, sem HTTP client.
"""

import os
from datetime import datetime, date, timezone
from uuid import uuid4

import pytest

# ─── Setup minimo para importar sem DATABASE_URL real ─────────────────────────

os.environ.setdefault("JWT_SECRET_KEY", "test-secret-key-for-role-views")
os.environ.setdefault("DATABASE_URL", "sqlite:///./test_role_views_temp.db")

from app.schemas import (
    ChecklistItemRead,
    ChecklistItemOwnerView,
    AtividadeCronogramaRead,
    AtividadeOwnerView,
    CronogramaResponse,
    CronogramaOwnerView,
    ServicoNecessarioRead,
)
from app.enums import ChecklistStatus


# ─── Fixtures ────────────────────────────────────────────────────────────────


def _make_checklist_item_read(**overrides) -> ChecklistItemRead:
    """Cria ChecklistItemRead completo com todos os campos tecnicos."""
    now = datetime.now(timezone.utc)
    defaults = dict(
        id=uuid4(),
        etapa_id=uuid4(),
        atividade_id=None,
        titulo="Verificar fundacao",
        descricao="Verificar fundacao conforme norma ABNT NBR 6122",
        status=ChecklistStatus.PENDENTE,
        critico=True,
        observacao=None,
        norma_referencia="ABNT NBR 6122",
        origem="ia",
        grupo="Estrutura",
        ordem=1,
        # 3 Camadas — campos tecnicos
        severidade="alta",
        traducao_leigo="A fundacao precisa ser verificada para garantir seguranca",
        dado_projeto='{"valor_referencia": "50cm", "especificacao": "Sapata 50x50cm"}',
        verificacoes="Medir profundidade e largura com trena",
        pergunta_engenheiro="A fundacao atinge a cota prevista em projeto?",
        documentos_a_exigir="Laudo de sondagem, projeto estrutural",
        registro_proprietario=None,
        resultado_cruzamento=None,
        status_verificacao="pendente",
        confianca=90,
        requer_validacao_profissional=True,
        # Fase 6
        projeto_doc_id=uuid4(),
        projeto_doc_nome="Projeto Estrutural.pdf",
        como_verificar="Use trena para medir dimensoes",
        medidas_minimas="50x50cm minimo",
        explicacao_leigo="Certifique-se que os blocos de concreto estao no lugar certo",
        created_at=now,
        updated_at=now,
    )
    defaults.update(overrides)
    return ChecklistItemRead(**defaults)


def _make_atividade_read(nivel: int = 1, **overrides) -> AtividadeCronogramaRead:
    """Cria AtividadeCronogramaRead completa com todos os campos tecnicos."""
    now = datetime.now(timezone.utc)
    today = date.today()
    defaults = dict(
        id=uuid4(),
        obra_id=uuid4(),
        parent_id=None,
        nome="Fundacao",
        descricao="Execucao da fundacao da obra",
        ordem=1,
        nivel=nivel,
        status="em_andamento",
        data_inicio_prevista=today,
        data_fim_prevista=today,
        data_inicio_real=today,
        data_fim_real=None,
        valor_previsto=50000.0,
        valor_gasto=25000.0,
        tipo_projeto="Estrutural",
        is_modified=False,
        locked=False,
        sub_atividades=[],
        servicos=[],
        created_at=now,
        updated_at=now,
    )
    defaults.update(overrides)
    return AtividadeCronogramaRead(**defaults)


# ─── Testes: ChecklistItemOwnerView — campos presentes e ausentes ─────────────


class TestChecklistItemOwnerView:
    """Valida contratos da projecao OwnerView do checklist."""

    def test_owner_view_contains_titulo_descricao_status(self):
        """OwnerView inclui campos basicos de acompanhamento."""
        item = _make_checklist_item_read()
        view = ChecklistItemOwnerView.from_item(item)
        assert view.titulo == item.titulo
        assert view.descricao == item.descricao
        assert view.status == item.status

    def test_owner_view_contains_critico_observacao(self):
        """OwnerView inclui critico e observacao para contexto do dono."""
        item = _make_checklist_item_read(critico=True, observacao="Urgente")
        view = ChecklistItemOwnerView.from_item(item)
        assert view.critico is True
        assert view.observacao == "Urgente"

    def test_owner_view_contains_leigo_fields(self):
        """OwnerView inclui traducao_leigo, explicacao_leigo e como_verificar."""
        item = _make_checklist_item_read()
        view = ChecklistItemOwnerView.from_item(item)
        assert view.traducao_leigo == item.traducao_leigo
        assert view.explicacao_leigo == item.explicacao_leigo
        assert view.como_verificar == item.como_verificar

    def test_owner_view_contains_registro_proprietario(self):
        """OwnerView inclui registro_proprietario para que o dono veja seu proprio registro."""
        item = _make_checklist_item_read(registro_proprietario='{"status": "conforme"}')
        view = ChecklistItemOwnerView.from_item(item)
        assert view.registro_proprietario == '{"status": "conforme"}'

    def test_owner_view_excludes_norma_referencia(self):
        """OwnerView NAO expoe norma_referencia — terminologia tecnica."""
        item = _make_checklist_item_read()
        view = ChecklistItemOwnerView.from_item(item)
        assert not hasattr(view, "norma_referencia")

    def test_owner_view_excludes_severidade(self):
        """OwnerView NAO expoe severidade — classificacao tecnica de risco."""
        item = _make_checklist_item_read()
        view = ChecklistItemOwnerView.from_item(item)
        assert not hasattr(view, "severidade")

    def test_owner_view_excludes_dado_projeto(self):
        """OwnerView NAO expoe dado_projeto — dados internos de cruzamento."""
        item = _make_checklist_item_read()
        view = ChecklistItemOwnerView.from_item(item)
        assert not hasattr(view, "dado_projeto")

    def test_owner_view_excludes_verificacoes(self):
        """OwnerView NAO expoe verificacoes — instrucoes tecnicas do engenheiro."""
        item = _make_checklist_item_read()
        view = ChecklistItemOwnerView.from_item(item)
        assert not hasattr(view, "verificacoes")

    def test_owner_view_excludes_pergunta_engenheiro(self):
        """OwnerView NAO expoe pergunta_engenheiro — formulacao tecnica interna."""
        item = _make_checklist_item_read()
        view = ChecklistItemOwnerView.from_item(item)
        assert not hasattr(view, "pergunta_engenheiro")

    def test_owner_view_excludes_documentos_a_exigir(self):
        """OwnerView NAO expoe documentos_a_exigir — lista tecnica de documentacao."""
        item = _make_checklist_item_read()
        view = ChecklistItemOwnerView.from_item(item)
        assert not hasattr(view, "documentos_a_exigir")

    def test_owner_view_excludes_confianca(self):
        """OwnerView NAO expoe confianca — metrica interna de IA."""
        item = _make_checklist_item_read()
        view = ChecklistItemOwnerView.from_item(item)
        assert not hasattr(view, "confianca")

    def test_owner_view_excludes_requer_validacao_profissional(self):
        """OwnerView NAO expoe requer_validacao_profissional — classificacao tecnica."""
        item = _make_checklist_item_read()
        view = ChecklistItemOwnerView.from_item(item)
        assert not hasattr(view, "requer_validacao_profissional")

    def test_owner_view_excludes_resultado_cruzamento(self):
        """OwnerView NAO expoe resultado_cruzamento — dado interno de analise."""
        item = _make_checklist_item_read()
        view = ChecklistItemOwnerView.from_item(item)
        assert not hasattr(view, "resultado_cruzamento")

    def test_owner_view_excludes_status_verificacao(self):
        """OwnerView NAO expoe status_verificacao — campo interno de workflow."""
        item = _make_checklist_item_read()
        view = ChecklistItemOwnerView.from_item(item)
        assert not hasattr(view, "status_verificacao")

    def test_owner_view_preserves_ids_and_timestamps(self):
        """OwnerView preserva id, etapa_id, atividade_id, created_at, updated_at."""
        item = _make_checklist_item_read()
        view = ChecklistItemOwnerView.from_item(item)
        assert view.id == item.id
        assert view.etapa_id == item.etapa_id
        assert view.created_at == item.created_at
        assert view.updated_at == item.updated_at


# ─── Testes: ChecklistItemRead (EngineerView) — campos tecnicos presentes ────


class TestChecklistItemEngineerView:
    """Valida que ChecklistItemRead (engineer view) preserva todos os campos tecnicos."""

    def test_engineer_view_has_norma_referencia(self):
        """EngineerView (ChecklistItemRead) inclui norma_referencia."""
        item = _make_checklist_item_read()
        assert item.norma_referencia == "ABNT NBR 6122"

    def test_engineer_view_has_severidade(self):
        """EngineerView inclui severidade."""
        item = _make_checklist_item_read()
        assert item.severidade == "alta"

    def test_engineer_view_has_verificacoes(self):
        """EngineerView inclui verificacoes."""
        item = _make_checklist_item_read()
        assert item.verificacoes is not None

    def test_engineer_view_has_pergunta_engenheiro(self):
        """EngineerView inclui pergunta_engenheiro."""
        item = _make_checklist_item_read()
        assert item.pergunta_engenheiro is not None

    def test_engineer_view_has_confianca(self):
        """EngineerView inclui confianca da IA."""
        item = _make_checklist_item_read()
        assert item.confianca == 90

    def test_engineer_view_has_requer_validacao_profissional(self):
        """EngineerView inclui requer_validacao_profissional."""
        item = _make_checklist_item_read()
        assert item.requer_validacao_profissional is True

    def test_engineer_view_has_dado_projeto(self):
        """EngineerView inclui dado_projeto."""
        item = _make_checklist_item_read()
        assert item.dado_projeto is not None

    def test_engineer_view_has_documentos_a_exigir(self):
        """EngineerView inclui documentos_a_exigir."""
        item = _make_checklist_item_read()
        assert item.documentos_a_exigir is not None


# ─── Testes: AtividadeOwnerView e CronogramaOwnerView ────────────────────────


class TestAtividadeOwnerView:
    """Valida projecao do cronograma para o dono da obra."""

    def test_owner_view_contains_nome_descricao_status(self):
        """OwnerView do cronograma inclui nome, descricao e status."""
        ativ = _make_atividade_read()
        view = AtividadeOwnerView.from_atividade(ativ)
        assert view.nome == ativ.nome
        assert view.descricao == ativ.descricao
        assert view.status == ativ.status

    def test_owner_view_contains_datas(self):
        """OwnerView inclui datas previstas e reais para acompanhamento."""
        ativ = _make_atividade_read()
        view = AtividadeOwnerView.from_atividade(ativ)
        assert view.data_inicio_prevista == ativ.data_inicio_prevista
        assert view.data_fim_prevista == ativ.data_fim_prevista
        assert view.data_inicio_real == ativ.data_inicio_real
        assert view.data_fim_real == ativ.data_fim_real

    def test_owner_view_excludes_valor_previsto(self):
        """OwnerView NAO expoe valor_previsto — dado financeiro do engenheiro."""
        ativ = _make_atividade_read()
        view = AtividadeOwnerView.from_atividade(ativ)
        assert not hasattr(view, "valor_previsto")

    def test_owner_view_excludes_valor_gasto(self):
        """OwnerView NAO expoe valor_gasto — dado financeiro do engenheiro."""
        ativ = _make_atividade_read()
        view = AtividadeOwnerView.from_atividade(ativ)
        assert not hasattr(view, "valor_gasto")

    def test_owner_view_excludes_tipo_projeto(self):
        """OwnerView NAO expoe tipo_projeto — classificacao tecnica interna."""
        ativ = _make_atividade_read()
        view = AtividadeOwnerView.from_atividade(ativ)
        assert not hasattr(view, "tipo_projeto")

    def test_owner_view_excludes_is_modified(self):
        """OwnerView NAO expoe is_modified — flag operacional do engenheiro."""
        ativ = _make_atividade_read()
        view = AtividadeOwnerView.from_atividade(ativ)
        assert not hasattr(view, "is_modified")

    def test_owner_view_excludes_locked(self):
        """OwnerView NAO expoe locked — flag de bloqueio operacional."""
        ativ = _make_atividade_read()
        view = AtividadeOwnerView.from_atividade(ativ)
        assert not hasattr(view, "locked")

    def test_owner_view_excludes_servicos(self):
        """OwnerView NAO expoe servicos — lista operacional de servicos do engenheiro."""
        ativ = _make_atividade_read()
        view = AtividadeOwnerView.from_atividade(ativ)
        assert not hasattr(view, "servicos")

    def test_owner_view_projects_sub_atividades_recursively(self):
        """OwnerView projeta sub_atividades recursivamente."""
        sub = _make_atividade_read(nivel=2, nome="Sub-atividade")
        ativ = _make_atividade_read(nivel=1, sub_atividades=[sub])
        view = AtividadeOwnerView.from_atividade(ativ)
        assert len(view.sub_atividades) == 1
        sub_view = view.sub_atividades[0]
        assert sub_view.nome == "Sub-atividade"
        assert not hasattr(sub_view, "valor_previsto")
        assert not hasattr(sub_view, "servicos")

    def test_owner_view_preserves_ids_and_hierarchy(self):
        """OwnerView preserva id, obra_id, parent_id, nivel e ordem."""
        ativ = _make_atividade_read()
        view = AtividadeOwnerView.from_atividade(ativ)
        assert view.id == ativ.id
        assert view.obra_id == ativ.obra_id
        assert view.nivel == ativ.nivel
        assert view.ordem == ativ.ordem


class TestCronogramaOwnerView:
    """Valida projecao do cronograma completo para o dono."""

    def test_cronograma_owner_view_excludes_financials(self):
        """CronogramaOwnerView NAO expoe total_previsto, total_gasto, desvio."""
        now = datetime.now(timezone.utc)
        ativ = _make_atividade_read()
        cronograma = CronogramaResponse(
            obra_id=ativ.obra_id,
            total_previsto=100000.0,
            total_gasto=50000.0,
            desvio_percentual=-50.0,
            atividades=[ativ],
        )
        view = CronogramaOwnerView.from_cronograma(cronograma)
        assert not hasattr(view, "total_previsto")
        assert not hasattr(view, "total_gasto")
        assert not hasattr(view, "desvio_percentual")

    def test_cronograma_owner_view_preserves_atividades(self):
        """CronogramaOwnerView preserva lista de atividades projetadas."""
        ativ = _make_atividade_read()
        cronograma = CronogramaResponse(
            obra_id=ativ.obra_id,
            total_previsto=100000.0,
            total_gasto=50000.0,
            desvio_percentual=-50.0,
            atividades=[ativ],
        )
        view = CronogramaOwnerView.from_cronograma(cronograma)
        assert len(view.atividades) == 1
        assert view.atividades[0].nome == ativ.nome

    def test_cronograma_owner_view_preserves_obra_id(self):
        """CronogramaOwnerView preserva obra_id para identificacao."""
        obra_id = uuid4()
        cronograma = CronogramaResponse(
            obra_id=obra_id,
            atividades=[],
        )
        view = CronogramaOwnerView.from_cronograma(cronograma)
        assert view.obra_id == obra_id


# ─── Testes: projecao por role ────────────────────────────────────────────────


class TestProjectionByRole:
    """Valida que a serializacao seleciona o schema correto conforme o papel."""

    def test_dono_da_obra_gets_owner_view(self):
        """dono_da_obra deve receber ChecklistItemOwnerView sem campos tecnicos."""
        item = _make_checklist_item_read()

        # Simula logica de selecao de serializer por role
        role = "dono_da_obra"
        if role == "dono_da_obra":
            view = ChecklistItemOwnerView.from_item(item)
        else:
            view = item

        assert isinstance(view, ChecklistItemOwnerView)
        assert not hasattr(view, "norma_referencia")
        assert not hasattr(view, "severidade")

    def test_engineer_gets_full_view(self):
        """owner/admin deve receber ChecklistItemRead com todos os campos tecnicos."""
        item = _make_checklist_item_read()

        # Simula logica de selecao de serializer por role
        role = "owner"
        if role == "dono_da_obra":
            view = ChecklistItemOwnerView.from_item(item)
        else:
            view = item

        assert isinstance(view, ChecklistItemRead)
        assert view.norma_referencia is not None
        assert view.severidade is not None

    def test_convidado_gets_full_view(self):
        """convidado (colaborador tecnico) recebe ChecklistItemRead completo."""
        item = _make_checklist_item_read()

        # Convidados sao colaboradores tecnicos — recebem visao completa
        role = "convidado"
        if role == "dono_da_obra":
            view = ChecklistItemOwnerView.from_item(item)
        else:
            view = item

        assert isinstance(view, ChecklistItemRead)
        assert view.norma_referencia is not None

    def test_cronograma_dono_da_obra_gets_owner_view(self):
        """dono_da_obra no cronograma recebe CronogramaOwnerView sem dados financeiros."""
        ativ = _make_atividade_read()
        cronograma = CronogramaResponse(
            obra_id=ativ.obra_id,
            total_previsto=100000.0,
            total_gasto=50000.0,
            desvio_percentual=-50.0,
            atividades=[ativ],
        )

        role = "dono_da_obra"
        if role == "dono_da_obra":
            view = CronogramaOwnerView.from_cronograma(cronograma)
        else:
            view = cronograma

        assert isinstance(view, CronogramaOwnerView)
        assert not hasattr(view, "total_previsto")
        assert not hasattr(view, "desvio_percentual")

    def test_cronograma_engineer_gets_full_view(self):
        """Engenheiro no cronograma recebe CronogramaResponse com dados financeiros."""
        ativ = _make_atividade_read()
        cronograma = CronogramaResponse(
            obra_id=ativ.obra_id,
            total_previsto=100000.0,
            total_gasto=50000.0,
            desvio_percentual=-50.0,
            atividades=[ativ],
        )

        role = "owner"
        if role == "dono_da_obra":
            view = CronogramaOwnerView.from_cronograma(cronograma)
        else:
            view = cronograma

        assert isinstance(view, CronogramaResponse)
        assert view.total_previsto == 100000.0
        assert view.desvio_percentual == -50.0
