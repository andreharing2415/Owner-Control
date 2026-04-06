"""Testes para checklist_inteligente — validacao de fonte_doc_trecho (AI-02)."""

import pytest
from unittest.mock import patch, MagicMock

from app.checklist_inteligente import _normalizar_fase2


# ─── Fixtures ────────────────────────────────────────────────────────────────


def _item_valido(**overrides) -> dict:
    """Retorna um item de checklist com todos os campos obrigatorios."""
    base = {
        "etapa_da_obra": "Fundacao e Estrutura",
        "risco": "ALTO",
        "titulo_verificacao": "Verificar impermeabilizacao do poco",
        "norma_tecnica": "NBR NM 313",
        "fonte_doc_trecho": "Planta Estrutural - Folha 3: Poco do elevador 1.60m x 1.20m",
        "por_que_isso_importa": "Se infiltrar agua, a placa do elevador queima.",
        "como_o_proprietario_verifica": {
            "acao_pratica": "Peca o laudo de estanqueidade antes de fecharem a caixa.",
            "medida_ou_regra_minima": "O poco deve ter no minimo 1.50m de profundidade.",
        },
        "dialogo_com_engenheiro": {
            "pergunta_pronta": "Ja fizeram o teste de estanqueidade do poco?",
            "resposta_tranquilizadora": "Sim, esta conforme NBR NM 313.",
        },
        "documento_para_exibir": "ART do elevador",
    }
    base.update(overrides)
    return base


def _raw_checklist(itens: list[dict]) -> dict:
    """Retorna payload de resposta da IA no formato Fase 2."""
    return {
        "sistema_analisado": "elevador",
        "introducao_ao_proprietario": "O elevador exige atencao em todas as fases.",
        "checklist": itens,
    }


# ─── Testes: fonte_doc_trecho obrigatorio ────────────────────────────────────


class TestFonteDocTrechoObrigatorio:
    """Garante que itens sem fonte_doc_trecho sao rejeitados pelo parser."""

    def test_item_com_fonte_valida_e_aceito(self):
        """Item com fonte_doc_trecho preenchido deve ser incluido no resultado."""
        raw = _raw_checklist([_item_valido()])
        resultado = _normalizar_fase2(raw)

        assert len(resultado["itens"]) == 1
        assert resultado["itens_rejeitados_sem_fonte"] == 0

    def test_item_sem_fonte_e_rejeitado(self):
        """Item sem fonte_doc_trecho deve ser rejeitado — campo obrigatorio."""
        item_sem_fonte = _item_valido()
        del item_sem_fonte["fonte_doc_trecho"]

        raw = _raw_checklist([item_sem_fonte])
        resultado = _normalizar_fase2(raw)

        assert len(resultado["itens"]) == 0
        assert resultado["itens_rejeitados_sem_fonte"] == 1

    def test_item_com_fonte_vazia_e_rejeitado(self):
        """Item com fonte_doc_trecho vazia (string) deve ser rejeitado."""
        raw = _raw_checklist([_item_valido(fonte_doc_trecho="")])
        resultado = _normalizar_fase2(raw)

        assert len(resultado["itens"]) == 0
        assert resultado["itens_rejeitados_sem_fonte"] == 1

    def test_item_com_fonte_apenas_espacos_e_rejeitado(self):
        """Item com fonte_doc_trecho de apenas espacos deve ser rejeitado."""
        raw = _raw_checklist([_item_valido(fonte_doc_trecho="   ")])
        resultado = _normalizar_fase2(raw)

        assert len(resultado["itens"]) == 0
        assert resultado["itens_rejeitados_sem_fonte"] == 1

    def test_item_com_fonte_none_e_rejeitado(self):
        """Item com fonte_doc_trecho None deve ser rejeitado."""
        raw = _raw_checklist([_item_valido(fonte_doc_trecho=None)])
        resultado = _normalizar_fase2(raw)

        assert len(resultado["itens"]) == 0
        assert resultado["itens_rejeitados_sem_fonte"] == 1

    def test_mix_itens_validos_e_invalidos(self):
        """Itens validos sao aceitos, invalidos sao rejeitados — processamento isolado."""
        itens = [
            _item_valido(titulo_verificacao="Item valido 1"),
            _item_valido(fonte_doc_trecho=""),  # invalido
            _item_valido(titulo_verificacao="Item valido 2"),
            _item_valido(fonte_doc_trecho=None),  # invalido
        ]
        raw = _raw_checklist(itens)
        resultado = _normalizar_fase2(raw)

        assert len(resultado["itens"]) == 2
        assert resultado["itens_rejeitados_sem_fonte"] == 2

    def test_todos_itens_sem_fonte_resulta_em_lista_vazia(self):
        """Quando todos os itens sao rejeitados, resultado tem lista vazia."""
        itens = [
            _item_valido(fonte_doc_trecho=""),
            _item_valido(fonte_doc_trecho=None),
        ]
        raw = _raw_checklist(itens)
        resultado = _normalizar_fase2(raw)

        assert resultado["itens"] == []
        assert resultado["itens_rejeitados_sem_fonte"] == 2

    def test_checklist_vazio_retorna_resultado_vazio(self):
        """Checklist vazio nao gera erro — retorna normalmente."""
        raw = _raw_checklist([])
        resultado = _normalizar_fase2(raw)

        assert resultado["itens"] == []
        assert resultado["itens_rejeitados_sem_fonte"] == 0


# ─── Testes: fonte_doc_trecho propagado no item normalizado ──────────────────


class TestFonteDocTrechoPropagado:
    """Garante que fonte_doc_trecho aparece no item normalizado final."""

    def test_fonte_doc_trecho_aparece_no_item(self):
        """fonte_doc_trecho deve estar presente no dict do item normalizado."""
        trecho = "Planta Estrutural - Folha 3: Poco do elevador 1.60m x 1.20m"
        raw = _raw_checklist([_item_valido(fonte_doc_trecho=trecho)])
        resultado = _normalizar_fase2(raw)

        assert "fonte_doc_trecho" in resultado["itens"][0]
        assert resultado["itens"][0]["fonte_doc_trecho"] == trecho

    def test_fonte_doc_trecho_truncada_em_500_chars(self):
        """fonte_doc_trecho com mais de 500 chars deve ser truncada."""
        trecho_longo = "A" * 600
        raw = _raw_checklist([_item_valido(fonte_doc_trecho=trecho_longo)])
        resultado = _normalizar_fase2(raw)

        assert len(resultado["itens"][0]["fonte_doc_trecho"]) == 500

    def test_fonte_doc_trecho_propagada_em_dado_projeto_fonte(self):
        """dado_projeto.fonte deve usar a fonte_doc_trecho, nao string generica."""
        trecho = "Planta Hidraulica - Folha 5: Boiler solar 300L"
        raw = _raw_checklist([_item_valido(fonte_doc_trecho=trecho)])
        resultado = _normalizar_fase2(raw)

        dado = resultado["itens"][0]["dado_projeto"]
        assert dado["fonte"] == trecho[:150]

    def test_campos_outros_preservados(self):
        """Outros campos do item devem continuar intactos apos normalizacao."""
        raw = _raw_checklist([_item_valido(risco="ALTO")])
        resultado = _normalizar_fase2(raw)
        item = resultado["itens"][0]

        assert item["critico"] is True
        assert item["risco_nivel"] == "alto"
        assert item["requer_validacao_profissional"] is True
        assert item["confianca"] == 85
        assert "verificacoes" in item
        assert "pergunta_engenheiro" in item


# ─── Testes: estrutura do resultado ──────────────────────────────────────────


class TestEstruturaResultado:
    """Garante a estrutura correta do dict retornado por _normalizar_fase2."""

    def test_resultado_tem_chaves_obrigatorias(self):
        """Resultado deve ter: caracteristica, introducao_ao_proprietario, itens,
        itens_rejeitados_sem_fonte."""
        raw = _raw_checklist([_item_valido()])
        resultado = _normalizar_fase2(raw)

        assert "caracteristica" in resultado
        assert "introducao_ao_proprietario" in resultado
        assert "itens" in resultado
        assert "itens_rejeitados_sem_fonte" in resultado

    def test_resultado_caracteristica_extraida(self):
        """Campo 'caracteristica' deve vir do campo 'sistema_analisado' da IA."""
        raw = _raw_checklist([_item_valido()])
        resultado = _normalizar_fase2(raw)

        assert resultado["caracteristica"] == "elevador"

    def test_resultado_introducao_extraida(self):
        """Campo 'introducao_ao_proprietario' deve ser extraido corretamente."""
        raw = _raw_checklist([_item_valido()])
        resultado = _normalizar_fase2(raw)

        assert resultado["introducao_ao_proprietario"] == "O elevador exige atencao em todas as fases."
