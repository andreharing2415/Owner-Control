"""Testes do pipeline de extração de elementos construtivos (Phase 01 — AI-01)."""

import json
import os
import sys
from datetime import datetime, timezone
from typing import List
from unittest.mock import MagicMock, patch
from uuid import uuid4

import pytest

os.environ.setdefault("JWT_SECRET_KEY", "test-secret-key-for-unit-tests")
os.environ.setdefault("DATABASE_URL", "sqlite:///./test_temp.db")

# ─── Testes — ProjetoDoc schema (Task 1) ──────────────────────────────────────


def test_projetodoc_schema_has_elementos_extraidos():
    """ProjetoDoc model deve ter campo elementos_extraidos."""
    from server.app.models import ProjetoDoc

    doc = ProjetoDoc(
        obra_id=uuid4(),
        arquivo_url="https://example.com/doc.pdf",
        arquivo_nome="projeto.pdf",
    )
    assert hasattr(doc, "elementos_extraidos")
    assert doc.elementos_extraidos is None  # default None


def test_projetodoc_schema_accepts_json_elementos():
    """ProjetoDoc deve aceitar JSON string no campo elementos_extraidos."""
    from server.app.models import ProjetoDoc

    elementos_json = json.dumps([
        {
            "categoria": "Hidráulico",
            "nome": "Tubulação de esgoto PVC 100mm",
            "descricao": "Tubulação de esgoto identificada no banheiro social",
            "especificacao": "PVC rígido diâmetro 100mm conforme NBR 5626",
            "localizacao": "Banheiro social",
            "pagina_referencia": 3,
            "prancha_referencia": "Folha 03 – Planta Hidráulica",
            "confianca": 90,
        }
    ], ensure_ascii=False)

    doc = ProjetoDoc(
        obra_id=uuid4(),
        arquivo_url="https://example.com/doc.pdf",
        arquivo_nome="projeto.pdf",
        elementos_extraidos=elementos_json,
    )
    assert doc.elementos_extraidos is not None
    parsed = json.loads(doc.elementos_extraidos)
    assert len(parsed) == 1
    assert parsed[0]["categoria"] == "Hidráulico"
    assert parsed[0]["nome"] == "Tubulação de esgoto PVC 100mm"
    assert parsed[0]["confianca"] == 90


def test_elemento_construtivo_schema_valid():
    """ElementoConstrutivo deve validar campos obrigatórios e defaults."""
    from server.app.schemas import ElementoConstrutivo

    elem = ElementoConstrutivo(
        categoria="Estrutural",
        nome="Sapata de concreto armado",
    )
    assert elem.categoria == "Estrutural"
    assert elem.nome == "Sapata de concreto armado"
    assert elem.descricao is None
    assert elem.especificacao is None
    assert elem.localizacao is None
    assert elem.pagina_referencia is None
    assert elem.prancha_referencia is None
    assert elem.confianca == 0


def test_elemento_construtivo_schema_full():
    """ElementoConstrutivo deve aceitar todos os campos."""
    from server.app.schemas import ElementoConstrutivo

    elem = ElementoConstrutivo(
        categoria="Elétrico",
        nome="Quadro de distribuição",
        descricao="Quadro de distribuição principal da residência",
        especificacao="40 disjuntores, NBR 5410",
        localizacao="Hall de entrada",
        pagina_referencia=5,
        prancha_referencia="Folha 05 – Planta Elétrica",
        confianca=85,
    )
    assert elem.confianca == 85
    assert elem.pagina_referencia == 5


def test_projetodoc_read_schema_includes_elementos():
    """ProjetoDocRead deve incluir campo elementos_extraidos."""
    from server.app.schemas import ProjetoDocRead

    now = datetime.now(timezone.utc)
    doc_read = ProjetoDocRead(
        id=uuid4(),
        obra_id=uuid4(),
        arquivo_url="https://example.com/doc.pdf",
        arquivo_nome="projeto.pdf",
        status="concluido",
        created_at=now,
        updated_at=now,
        elementos_extraidos=json.dumps([
            {"categoria": "Arquitetura", "nome": "Parede de alvenaria", "confianca": 75}
        ]),
    )
    assert doc_read.elementos_extraidos is not None
    parsed = json.loads(doc_read.elementos_extraidos)
    assert parsed[0]["categoria"] == "Arquitetura"


def test_projetodoc_read_schema_elementos_optional():
    """ProjetoDocRead deve aceitar elementos_extraidos como None."""
    from server.app.schemas import ProjetoDocRead

    now = datetime.now(timezone.utc)
    doc_read = ProjetoDocRead(
        id=uuid4(),
        obra_id=uuid4(),
        arquivo_url="https://example.com/doc.pdf",
        arquivo_nome="projeto.pdf",
        status="pendente",
        created_at=now,
        updated_at=now,
    )
    assert doc_read.elementos_extraidos is None


# ─── Testes — Pipeline de extração em duas passagens (Task 2) ─────────────────


def test_document_analysis_extraction_module_exists():
    """Módulo document_analysis deve existir e expor a função de extração."""
    from server.app import document_analysis

    assert hasattr(document_analysis, "extrair_elementos_construtivos")


def test_document_analysis_extraction_returns_list():
    """extrair_elementos_construtivos deve retornar lista de dicts."""
    from server.app.document_analysis import extrair_elementos_construtivos

    paginas_mock = [
        ("base64encodedimage1", 1),
        ("base64encodedimage2", 2),
    ]

    passagem1_resultado = [
        {
            "elementos": [
                {
                    "categoria": "Hidráulico",
                    "nome": "Tubulação PVC 100mm",
                    "descricao": "Tubulação principal de esgoto",
                    "especificacao": "PVC 100mm",
                    "localizacao": "Banheiro",
                    "pagina_referencia": 1,
                    "prancha_referencia": "Folha 01",
                    "confianca": 80,
                }
            ]
        },
        {
            "elementos": [
                {
                    "categoria": "Elétrico",
                    "nome": "Quadro de distribuição 40A",
                    "descricao": "Quadro principal",
                    "especificacao": "40 disjuntores",
                    "localizacao": "Hall",
                    "pagina_referencia": 2,
                    "prancha_referencia": "Folha 02",
                    "confianca": 75,
                }
            ]
        },
    ]

    passagem2_resultado = {
        "elementos_consolidados": [
            {
                "categoria": "Hidráulico",
                "nome": "Tubulação PVC 100mm",
                "descricao": "Tubulação principal de esgoto identificada na prancha hidráulica",
                "especificacao": "PVC rígido 100mm conforme NBR 5626",
                "localizacao": "Banheiro social",
                "pagina_referencia": 1,
                "prancha_referencia": "Folha 01",
                "confianca": 85,
            },
            {
                "categoria": "Elétrico",
                "nome": "Quadro de distribuição 40A",
                "descricao": "Quadro de distribuição principal da residência",
                "especificacao": "40 disjuntores conforme NBR 5410",
                "localizacao": "Hall de entrada",
                "pagina_referencia": 2,
                "prancha_referencia": "Folha 02",
                "confianca": 80,
            },
        ]
    }

    with patch("server.app.document_analysis.call_vision_with_fallback") as mock_vision, \
         patch("server.app.document_analysis.call_text_with_fallback") as mock_text:

        # Passagem 1: por página (vision)
        mock_vision.side_effect = [passagem1_resultado[0], passagem1_resultado[1]]
        # Passagem 2: consolidação (text)
        mock_text.return_value = passagem2_resultado

        resultado = extrair_elementos_construtivos(paginas_mock, "projeto.pdf")

    assert isinstance(resultado, list)
    assert len(resultado) == 2
    assert resultado[0]["categoria"] == "Hidráulico"
    assert resultado[1]["categoria"] == "Elétrico"


def test_document_analysis_extraction_deduplicates():
    """Pipeline deve consolidar elementos duplicados entre páginas."""
    from server.app.document_analysis import extrair_elementos_construtivos

    paginas_mock = [
        ("base64encodedimage1", 1),
        ("base64encodedimage2", 2),
    ]

    # Mesma tubulação aparece em duas páginas
    passagem1_page1 = {
        "elementos": [
            {
                "categoria": "Hidráulico",
                "nome": "Tubulação PVC 100mm",
                "confianca": 70,
            }
        ]
    }
    passagem1_page2 = {
        "elementos": [
            {
                "categoria": "Hidráulico",
                "nome": "Tubulação PVC 100mm",
                "confianca": 80,
            }
        ]
    }

    # Consolidação retorna apenas 1 elemento
    passagem2_resultado = {
        "elementos_consolidados": [
            {
                "categoria": "Hidráulico",
                "nome": "Tubulação PVC 100mm",
                "descricao": "Tubulação identificada em múltiplas pranchas",
                "confianca": 85,
            }
        ]
    }

    with patch("server.app.document_analysis.call_vision_with_fallback") as mock_vision, \
         patch("server.app.document_analysis.call_text_with_fallback") as mock_text:

        mock_vision.side_effect = [passagem1_page1, passagem1_page2]
        mock_text.return_value = passagem2_resultado

        resultado = extrair_elementos_construtivos(paginas_mock, "projeto.pdf")

    assert len(resultado) == 1
    assert resultado[0]["nome"] == "Tubulação PVC 100mm"


def test_document_analysis_extraction_handles_empty_pages():
    """Pipeline deve lidar com páginas sem elementos identificáveis."""
    from server.app.document_analysis import extrair_elementos_construtivos

    paginas_mock = [("base64encodedimage1", 1)]

    with patch("server.app.document_analysis.call_vision_with_fallback") as mock_vision, \
         patch("server.app.document_analysis.call_text_with_fallback") as mock_text:

        mock_vision.return_value = {"elementos": []}
        mock_text.return_value = {"elementos_consolidados": []}

        resultado = extrair_elementos_construtivos(paginas_mock, "projeto.pdf")

    assert resultado == []


def test_document_analysis_extraction_persists_to_projetodoc():
    """analisar_documento_e_persistir deve salvar elementos_extraidos no ProjetoDoc."""
    from server.app.document_analysis import extrair_e_persistir_elementos

    projeto_id = uuid4()
    projeto_mock = MagicMock()
    projeto_mock.id = projeto_id
    projeto_mock.arquivo_url = "https://example.com/doc.pdf"
    projeto_mock.arquivo_nome = "projeto.pdf"
    projeto_mock.elementos_extraidos = None

    session_mock = MagicMock()
    session_mock.get.return_value = projeto_mock

    elementos_resultado = [
        {
            "categoria": "Estrutural",
            "nome": "Vigas de concreto armado",
            "confianca": 90,
        }
    ]

    with patch("server.app.document_analysis.os.getenv", return_value="test-bucket"), \
         patch("server.app.document_analysis.extract_object_key", return_value="projetos/key"), \
         patch("server.app.document_analysis.download_by_url", return_value=b"%PDF-1.4 fake"), \
         patch("server.app.document_analysis.extrair_paginas_como_imagens", return_value=[("img", 1)]), \
         patch("server.app.document_analysis.extrair_elementos_construtivos", return_value=elementos_resultado):

        extrair_e_persistir_elementos(session_mock, projeto_id)

    # Verifica que elementos foram persistidos no ProjetoDoc
    assert projeto_mock.elementos_extraidos is not None
    parsed = json.loads(projeto_mock.elementos_extraidos)
    assert len(parsed) == 1
    assert parsed[0]["categoria"] == "Estrutural"
    session_mock.add.assert_called()
    session_mock.commit.assert_called()
