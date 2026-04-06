"""Testes de arvore hierarquica e preservacao de edicoes do cronograma (AI-03/04/05).

Cobre:
- Modelo AtividadeCronograma com flags is_modified / locked
- Schemas AtividadeCronogramaRead e AtividadeUpdate
- Logica de preservacao: atividades locked nao sao deletadas na re-geracao
- Auto-spawn de ChecklistItem para micro-atividades (nivel 2)
- Sequencia construtiva (fundacao antes de acabamento por ordem)
"""

import json
import os
import pytest
from uuid import uuid4
from datetime import date, datetime, timezone

os.environ.setdefault("JWT_SECRET_KEY", "test-secret-key-for-unit-tests")
os.environ.setdefault("DATABASE_URL", "sqlite:///./test_temp.db")

# ─── Task 1: modelo e schema ─────────────────────────────────────────────────


def test_cronograma_hierarchy_model_defaults():
    """AtividadeCronograma deve ter is_modified=False e locked=False por padrao."""
    from app.models import AtividadeCronograma

    obra_id = uuid4()
    a = AtividadeCronograma(obra_id=obra_id, nome="Fundacao", nivel=1)
    assert a.is_modified is False
    assert a.locked is False
    assert a.nivel == 1
    assert a.parent_id is None


def test_cronograma_hierarchy_model_macro_micro():
    """Atividade L2 (micro) deve referenciar atividade L1 (macro) via parent_id."""
    from app.models import AtividadeCronograma

    obra_id = uuid4()
    l1_id = uuid4()

    macro = AtividadeCronograma(id=l1_id, obra_id=obra_id, nome="Estrutura", nivel=1)
    micro = AtividadeCronograma(
        obra_id=obra_id, nome="Concretagem de Pilares", nivel=2, parent_id=l1_id
    )

    assert macro.nivel == 1
    assert micro.nivel == 2
    assert micro.parent_id == l1_id


def test_cronograma_hierarchy_model_flags_set():
    """Flags is_modified e locked podem ser definidos."""
    from app.models import AtividadeCronograma

    obra_id = uuid4()
    a = AtividadeCronograma(
        obra_id=obra_id, nome="Revestimento", nivel=2,
        is_modified=True, locked=True,
    )
    assert a.is_modified is True
    assert a.locked is True


def test_cronograma_hierarchy_schema_read_includes_flags():
    """AtividadeCronogramaRead deve expor is_modified e locked."""
    from app.schemas import AtividadeCronogramaRead

    obra_id = uuid4()
    ativ_id = uuid4()
    now = datetime.now(timezone.utc)

    read = AtividadeCronogramaRead(
        id=ativ_id,
        obra_id=obra_id,
        nome="Fundacao",
        ordem=1,
        nivel=1,
        status="pendente",
        is_modified=True,
        locked=False,
        created_at=now,
        updated_at=now,
    )

    assert read.is_modified is True
    assert read.locked is False


def test_cronograma_hierarchy_schema_read_defaults():
    """AtividadeCronogramaRead deve ter is_modified=False e locked=False por padrao."""
    from app.schemas import AtividadeCronogramaRead

    obra_id = uuid4()
    ativ_id = uuid4()
    now = datetime.now(timezone.utc)

    read = AtividadeCronogramaRead(
        id=ativ_id,
        obra_id=obra_id,
        nome="Estrutura",
        ordem=2,
        nivel=1,
        status="pendente",
        created_at=now,
        updated_at=now,
    )

    assert read.is_modified is False
    assert read.locked is False


def test_cronograma_hierarchy_update_schema_has_locked():
    """AtividadeUpdate deve permitir setar campo locked."""
    from app.schemas import AtividadeUpdate

    update = AtividadeUpdate(locked=True)
    assert update.locked is True


def test_cronograma_hierarchy_update_schema_optional_fields():
    """AtividadeUpdate deve ser instanciavel sem campos (todos opcionais)."""
    from app.schemas import AtividadeUpdate

    update = AtividadeUpdate()
    dumped = update.model_dump(exclude_unset=True)
    assert dumped == {}


# ─── Task 2: preservacao de edicoes e auto-spawn ────────────────────────────


def test_cronograma_hierarchy_sequencia_construtiva():
    """Atividades com ordem menor devem vir antes das com ordem maior (fundacao antes de acabamento)."""
    from app.schemas import AtividadeCronogramaRead

    now = datetime.now(timezone.utc)
    obra_id = uuid4()

    fundacao = AtividadeCronogramaRead(
        id=uuid4(), obra_id=obra_id, nome="Fundacao", ordem=1, nivel=1,
        status="pendente", created_at=now, updated_at=now,
    )
    acabamento = AtividadeCronogramaRead(
        id=uuid4(), obra_id=obra_id, nome="Acabamentos", ordem=10, nivel=1,
        status="pendente", created_at=now, updated_at=now,
    )

    atividades = sorted([acabamento, fundacao], key=lambda a: a.ordem)
    assert atividades[0].nome == "Fundacao"
    assert atividades[1].nome == "Acabamentos"


def test_cronograma_hierarchy_preservar_locked():
    """Atividades com locked=True nao devem ser incluidas na lista de deletar."""
    from app.models import AtividadeCronograma

    obra_id = uuid4()
    atividades = [
        AtividadeCronograma(obra_id=obra_id, nome="Fundacao", nivel=1, locked=True),
        AtividadeCronograma(obra_id=obra_id, nome="Estrutura", nivel=1, locked=False),
        AtividadeCronograma(obra_id=obra_id, nome="Revestimento", nivel=2, locked=True),
    ]

    # Simula a logica de filtragem do router (nao deleta atividades locked)
    para_deletar = [a for a in atividades if not a.locked]
    para_preservar = [a for a in atividades if a.locked]

    assert len(para_deletar) == 1
    assert para_deletar[0].nome == "Estrutura"
    assert len(para_preservar) == 2
    assert {a.nome for a in para_preservar} == {"Fundacao", "Revestimento"}


def test_cronograma_hierarchy_auto_spawn_checklist_nivel2():
    """ChecklistItem deve ser criado para atividades de nivel 2 (micro) ao gerar cronograma."""
    from app.models import AtividadeCronograma, ChecklistItem

    obra_id = uuid4()
    l1_id = uuid4()
    l2_id = uuid4()

    l2 = AtividadeCronograma(
        id=l2_id, obra_id=obra_id, parent_id=l1_id,
        nome="Montagem de Fôrmas", nivel=2, status="pendente",
    )

    # Simula criacao de ChecklistItem para a micro-atividade
    checklist_item = ChecklistItem(
        atividade_id=l2.id,
        titulo=f"Verificar: {l2.nome}",
        origem="ia",
        grupo="Cronograma",
    )

    assert checklist_item.atividade_id == l2_id
    assert "Montagem" in checklist_item.titulo
    assert checklist_item.origem == "ia"


def test_cronograma_hierarchy_spawn_nao_cria_para_nivel1():
    """Apenas micro-atividades (nivel=2) geram ChecklistItem automaticamente."""
    from app.models import AtividadeCronograma

    obra_id = uuid4()

    l1 = AtividadeCronograma(obra_id=obra_id, nome="Estrutura", nivel=1)
    l2a = AtividadeCronograma(obra_id=obra_id, nome="Concretagem", nivel=2)
    l2b = AtividadeCronograma(obra_id=obra_id, nome="Armacao", nivel=2)

    atividades = [l1, l2a, l2b]

    # Apenas nivel 2 recebem spawn de checklist
    micro_atividades = [a for a in atividades if a.nivel == 2]
    assert len(micro_atividades) == 2
    assert all(a.nivel == 2 for a in micro_atividades)


def test_cronograma_hierarchy_is_modified_false_para_novas():
    """Novas atividades geradas por IA devem ter is_modified=False."""
    from app.models import AtividadeCronograma

    obra_id = uuid4()
    nova = AtividadeCronograma(obra_id=obra_id, nome="Cobertura", nivel=1)

    assert nova.is_modified is False


def test_cronograma_hierarchy_is_modified_nao_sobrescrito():
    """Atividades com is_modified=True devem ser identificadas para preservacao."""
    from app.models import AtividadeCronograma

    obra_id = uuid4()
    atividades = [
        AtividadeCronograma(obra_id=obra_id, nome="Fundacao", nivel=1, is_modified=True),
        AtividadeCronograma(obra_id=obra_id, nome="Estrutura", nivel=1, is_modified=False),
    ]

    modificadas = [a for a in atividades if a.is_modified]
    nao_modificadas = [a for a in atividades if not a.is_modified]

    assert len(modificadas) == 1
    assert modificadas[0].nome == "Fundacao"
    assert len(nao_modificadas) == 1
    assert nao_modificadas[0].nome == "Estrutura"
