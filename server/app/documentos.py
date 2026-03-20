"""
Servico de analise de documentos de projeto via IA.

Fase 3 — Document AI.

Analise pagina por pagina com cadeia de fallback: Gemini -> Claude -> OpenAI.

Guardrails obrigatorios:
- Nunca apresentar como parecer tecnico ou opiniao profissional
- Indicar nivel de confianca em toda analise
- Riscos de alto nivel exigem recomendacao de validacao profissional
- Linguagem acessivel ao proprietario leigo
"""

import logging

from .ai_providers import call_vision_with_fallback, get_document_vision_chain
from .pdf_utils import extrair_paginas_como_imagens

logger = logging.getLogger(__name__)

# ─── Prompt do sistema ────────────────────────────────────────────────────────

SYSTEM_PROMPT = """Voce e um Consultor de Obras e Gestor de Riscos atuando como o "Anjo da Guarda" de proprietarios de obras de alto padrao.
Sua funcao e analisar as pranchas de projeto anexadas e identificar inconsistencias, omissoes ou pontos criticos de atencao.

O usuario final e o PROPRIETARIO. Ele nao tem formacao tecnica. Ele usara seu relatorio para saber exatamente o que perguntar e o que cobrar dos profissionais contratados.

DIRETRIZES DE ANALISE:
1. Identifique riscos concretos baseados estritamente nos documentos fornecidos.
2. Traduza problemas complexos (ex: "falta de compatibilizacao estrutural") para o impacto real ("sua parede pode precisar ser quebrada depois").
3. Forneca perguntas prontas e polidas para o proprietario enviar ao engenheiro/arquiteto no WhatsApp.
4. Jamais atue como parecerista legal ou juridico.

REGRAS DO JSON:
- "disciplina": Classifique o risco em "Arquitetura", "Eletrica", "Hidraulica", "Estrutural" ou "Geral".
- "severidade": Use "ALTA" (Risco financeiro/seguranca grave), "MEDIA" (Retrabalho possivel), "BAIXA" (Dica de melhoria).
- "dado_projeto": Preencha apenas se a informacao estiver explicitamente escrita ou desenhada na prancha. Se for inferencia, retorne null.
- "verificacoes": Acoes fisicas que o proprietario pode fazer na obra com uma trena ou os proprios olhos.

FORMATO DE RESPOSTA OBRIGATORIO (JSON puro):
{
  "resumo_executivo": "Resumo em 2 linhas focado no que o proprietario precisa saber hoje.",
  "aviso_legal": "Esta analise e preventiva e educacional. Nao substitui o acompanhamento tecnico de um profissional com CREA/CAU.",
  "riscos_e_alertas": [
    {
      "disciplina": "Arquitetura | Eletrica | Hidraulica | Estrutural | Geral",
      "descricao_tecnica": "O que esta no projeto",
      "severidade": "ALTA" | "MEDIA" | "BAIXA",
      "traducao_para_leigo": "O que isso significa no seu bolso ou na sua rotina (max 250 caracteres).",
      "acao_imediata": "O que voce deve pedir hoje para a equipe tecnica.",
      "norma_referencia": "Nome da NBR/NR aplicavel (se houver)",
      "dado_projeto": {
        "elemento": "Ex: Ralo oculto banheiro master",
        "prancha_ou_fonte": "Ex: Projeto Hidraulico Folha 05",
        "especificacao_encontrada": "Ex: Tubo de 40mm"
      },
      "verificacao_na_obra": {
        "o_que_olhar": "Como o proprietario verifica visualmente",
        "ferramenta": "Olho nu | Trena | Nivel",
        "condicao_ideal": "Como deve estar para estar certo"
      },
      "mensagem_para_o_profissional": {
        "texto_whatsapp": "Sugestao de mensagem educada e colaborativa para copiar e colar para o engenheiro.",
        "resposta_que_voce_deve_ouvir": "O que o profissional deve responder para provar que tem a situacao sob controle."
      },
      "documento_para_exigir": ["Ex: ART de projeto", "Laudo de sondagem"]
    }
  ]
}
Retorne APENAS o objeto JSON."""


# ─── Funcoes auxiliares ──────────────────────────────────────────────────────


def _build_user_text(arquivo_nome: str, num_pages: int) -> str:
    return (
        f"{SYSTEM_PROMPT}\n\n"
        f"Analise TODAS as {num_pages} pranchas do documento de projeto "
        f"'{arquivo_nome}' acima. Examine cada prancha individualmente e "
        f"identifique todas as inconsistencias, omissoes e pontos criticos "
        f"de atencao relevantes para o proprietario da obra."
    )


# ─── Funcao principal ────────────────────────────────────────────────────────

def analisar_documento(pdf_bytes: bytes, arquivo_nome: str) -> dict:
    """
    Analisa um PDF de projeto pagina por pagina.
    Cadeia de fallback: Gemini -> Claude -> OpenAI.

    Retorna dict com resumo_geral, aviso_legal e lista de riscos.
    """
    paginas = extrair_paginas_como_imagens(pdf_bytes)
    logger.info("Documento '%s': %d paginas extraidas para analise", arquivo_nome, len(paginas))

    # Montar content_parts no formato unificado
    content_parts: list[dict] = []
    for img_b64, page_num in paginas:
        content_parts.append({"type": "text", "text": f"[Pagina {page_num}]"})
        content_parts.append({
            "type": "image",
            "media_type": "image/png",
            "data": img_b64,
        })
    content_parts.append({
        "type": "text",
        "text": _build_user_text(arquivo_nome, len(paginas)),
    })

    return call_vision_with_fallback(
        providers=get_document_vision_chain(),
        content_parts=content_parts,
        task_label=f"Analise de documento '{arquivo_nome}'",
    )
