"""Testes de geração de PDF — validação de corpus PT-BR sem corrupção de encoding."""

import sys
import os
from unittest.mock import MagicMock
from uuid import uuid4

import pytest

# WeasyPrint requer bibliotecas nativas (GTK/Pango/Cairo).
# Em Linux (Docker) elas estão disponíveis; em Windows/CI sem GTK, pular todos os testes.
try:
    import weasyprint as _weasyprint_check  # noqa: F401
    _WEASYPRINT_AVAILABLE = True
except (ImportError, OSError):
    _WEASYPRINT_AVAILABLE = False

pytestmark = pytest.mark.skipif(
    not _WEASYPRINT_AVAILABLE,
    reason="WeasyPrint nativo não disponível (GTK/Pango/Cairo ausentes — executar em Docker Linux)",
)

# ─── Stubs de modelos para testes unitários ─────────────────────────────────
# Evita importação do módulo de DB (que exige DATABASE_URL real).

class _MockObra:
    def __init__(self, nome, localizacao=None, orcamento=None, tipo="construcao"):
        self.id = uuid4()
        self.nome = nome
        self.localizacao = localizacao
        self.orcamento = orcamento
        self.tipo = tipo


class _MockEtapa:
    def __init__(self, ordem, nome, status="pendente", score=0.0):
        self.id = uuid4()
        self.ordem = ordem
        self.nome = nome
        self.status = status
        self.score = score


class _MockChecklistItem:
    def __init__(self, titulo, status="pendente"):
        self.id = uuid4()
        self.titulo = titulo
        self.status = status


# ─── Corpus PT-BR com todos os caracteres problemáticos ─────────────────────
# Inclui todos os caracteres fora do latin1 básico que o fpdf2+Helvetica corrompia.

CORPUS_OBRA_NOME = "Construção Residencial João & Maria"
CORPUS_LOCALIZACAO = "Rua das Acácias, 42 — Integração, São Paulo/SP"
CORPUS_ETAPA_NOME = "Fundação e Alvenaria Estrutural"
CORPUS_ITENS = [
    "Verificação de alinhamento e nivelamento",
    "Concretagem da laje — resistência ≥ 25 MPa",
    "Instalação hidráulica: tubulações de PVC",
    "Revestimento com argamassa de cimento e areia grossa",
    "Colocação de tijolos cerâmicos (9×19×29 cm)",
    "Pintura com tinta acrílica (cor: branco gelo)",
    "Verificação das vigas e pilares",
    "Impermeabilização da área molhada",
    "Instalação elétrica — circuito trifásico",
    "Execução de passagens para rede de gás natural",
]


def _build_corpus_data():
    """Cria dados de teste com corpus completo PT-BR."""
    obra = _MockObra(
        nome=CORPUS_OBRA_NOME,
        localizacao=CORPUS_LOCALIZACAO,
        orcamento=485_000.00,
    )
    etapa = _MockEtapa(ordem=1, nome=CORPUS_ETAPA_NOME, status="em_andamento", score=67.5)
    itens = [_MockChecklistItem(titulo=t) for t in CORPUS_ITENS]
    itens_map = {str(etapa.id): itens}
    return obra, [etapa], itens_map


# ─── Helpers para validar conteúdo do PDF ────────────────────────────────────

def _extract_pdf_text(pdf_bytes: bytes) -> str:
    """Extrai texto do PDF via pymupdf para validação de conteúdo."""
    import fitz  # pymupdf
    doc = fitz.open(stream=pdf_bytes, filetype="pdf")
    text = ""
    for page in doc:
        text += page.get_text()
    doc.close()
    return text


# ─── Fixture de importação segura do módulo pdf ──────────────────────────────

@pytest.fixture(scope="module")
def pdf_module():
    """Importa server.app.pdf apenas quando WeasyPrint nativo está disponível."""
    sys.path.insert(0, str(__import__("pathlib").Path(__file__).parent.parent.parent))
    os.environ.setdefault("DATABASE_URL", "sqlite:///./test_temp.db")
    import importlib
    return importlib.import_module("server.app.pdf")


# ─── Testes ──────────────────────────────────────────────────────────────────

def test_render_obra_pdf_retorna_bytes(pdf_module):
    """render_obra_pdf deve retornar bytes não-vazios."""
    obra, etapas, itens_map = _build_corpus_data()
    pdf_bytes = pdf_module.render_obra_pdf(obra, etapas, itens_map)
    assert isinstance(pdf_bytes, bytes)
    assert len(pdf_bytes) > 1000, "PDF vazio ou muito pequeno"


def test_pdf_comeca_com_assinatura_pdf(pdf_module):
    """Bytes gerados devem começar com a assinatura %PDF."""
    obra, etapas, itens_map = _build_corpus_data()
    pdf_bytes = pdf_module.render_obra_pdf(obra, etapas, itens_map)
    assert pdf_bytes[:4] == b"%PDF", f"Bytes iniciais inesperados: {pdf_bytes[:8]}"


def test_pdf_preserva_caracteres_ptbr(pdf_module):
    """PDF gerado não deve conter '?' no lugar de caracteres PT-BR acentuados."""
    obra, etapas, itens_map = _build_corpus_data()
    pdf_bytes = pdf_module.render_obra_pdf(obra, etapas, itens_map)

    text = _extract_pdf_text(pdf_bytes)

    # Verifica que caracteres-chave estão presentes sem substituição por '?'
    must_contain = [
        "Construção",
        "João",
        "Acácias",
        "São Paulo",
        "Fundação",
        "Verificação",
        "argamassa",
        "cerâmicos",
        "trifásico",
    ]
    for expected in must_contain:
        assert expected in text, (
            f"Caractere PT-BR corrompido ou ausente: '{expected}' não encontrado no PDF.\n"
            f"Fragmento extraído: {text[:800]}"
        )


def test_pdf_sem_substituicao_por_interrogacao(pdf_module):
    """Nenhum caractere acentuado deve ser substituído por '?' (falha de encoding latin1)."""
    obra, etapas, itens_map = _build_corpus_data()
    pdf_bytes = pdf_module.render_obra_pdf(obra, etapas, itens_map)

    text = _extract_pdf_text(pdf_bytes)

    # Conta '?' no texto extraído — zero é o esperado para corpus PT-BR
    question_marks = text.count("?")
    assert question_marks == 0, (
        f"Encontrado(s) {question_marks} '?' no PDF — provável corrupção de encoding.\n"
        f"Fragmento extraído: {text[:600]}"
    )


def test_pdf_obras_endpoint_contrato_preservado(pdf_module):
    """Endpoint exportar_pdf mantém contrato: retorna bytes iteráveis para StreamingResponse."""
    obra, etapas, itens_map = _build_corpus_data()
    result = pdf_module.render_obra_pdf(obra, etapas, itens_map)
    assert isinstance(result, bytes)
    # O endpoint passa result para iter([pdf_bytes]) — garante que bytes é iterável
    content = list(iter([result]))
    assert content[0] == result
