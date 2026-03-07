"""
Servico de analise de documentos de projeto via IA.

Fase 3 — Document AI.

Analise pagina por pagina com cadeia de fallback: Claude -> OpenAI -> Gemini.

Guardrails obrigatorios:
- Nunca apresentar como parecer tecnico ou opiniao profissional
- Indicar nivel de confianca em toda analise
- Riscos de alto nivel exigem recomendacao de validacao profissional
- Linguagem acessivel ao proprietario leigo
"""

import base64
import json
import logging
import os

import anthropic
from openai import OpenAI

from .pdf_utils import extrair_paginas_como_imagens

logger = logging.getLogger(__name__)

# ─── Prompt do sistema ────────────────────────────────────────────────────────

SYSTEM_PROMPT = """Voce e um especialista em analise de projetos de construcao civil, com foco em conformidade normativa e gestao de riscos para proprietarios de obras de alto padrao.

Sua funcao e analisar as paginas de um documento de projeto e identificar riscos, inconsistencias e pontos de atencao em linguagem acessivel ao proprietario leigo.

CONTEXTO IMPORTANTE: O usuario e o PROPRIETARIO da obra. Ele NAO e engenheiro, arquiteto, nem tem formacao tecnica. Ele precisa saber EXATAMENTE o que fazer e o que cobrar dos profissionais contratados.

REGRAS OBRIGATORIAS:
1. Identifique riscos concretos e especificos do documento analisado
2. Para cada risco, indique a norma tecnica aplicavel quando houver (ABNT, NR, codigo de obras municipal)
3. Classifique a severidade: "alto" (impacto financeiro ou de seguranca elevado), "medio" (exige atencao), "baixo" (observacao)
4. Traduza o risco tecnico em linguagem clara e objetiva para o proprietario — SEM termos tecnicos
5. Indique nivel de confianca (0-100) baseado na clareza do documento analisado
6. Riscos de nivel "alto" DEVEM ter requer_validacao_profissional: true
7. NUNCA apresente como parecer tecnico ou opiniao juridica
8. Se o documento nao for um projeto de construcao civil, retorne uma lista de riscos vazia com resumo explicativo
9. Para cada risco, forneca instrucoes PRATICAS e CONCRETAS para o proprietario, incluindo:
   - O que pedir ao engenheiro/arquiteto (sem jargao tecnico)
   - Perguntas prontas para fazer ao profissional, COM a resposta que o proprietario deve esperar ouvir para saber que esta tudo certo
   - Documentos e laudos que deve exigir (ART, RRT, laudos, revisoes de projeto, etc.), quando aplicavel

FORMATO DE RESPOSTA (JSON obrigatorio):
{
  "resumo_geral": "resumo em 2-3 frases do documento analisado e dos principais achados",
  "aviso_legal": "Esta analise e informativa e NAO substitui parecer tecnico de engenheiro ou arquiteto habilitado.",
  "riscos": [
    {
      "descricao": "descricao tecnica do risco ou ponto de atencao encontrado no documento",
      "severidade": "alto" | "medio" | "baixo",
      "norma_referencia": "norma aplicavel (ex: NBR 6118:2023, NR-18) ou null",
      "norma_url": "URL para consulta da norma (site da ABNT, planalto.gov.br, etc.) ou null se nao souber a URL exata",
      "traducao_leigo": "o que isso significa para voce como proprietario, em linguagem simples, sem termos tecnicos (max 300 chars)",
      "acao_proprietario": "instrucao direta do que pedir ao engenheiro/arquiteto, sem linguagem tecnica. Ex: 'Peca ao engenheiro que revise a protecao do ferro na fundacao para que dure mais tempo sem enferrujar' (max 300 chars)",
      "perguntas_para_profissional": [
        {
          "pergunta": "pergunta pronta que o proprietario deve fazer ao engenheiro",
          "resposta_esperada": "resumo da mensagem-chave que deve estar na resposta do engenheiro para indicar que esta ok. Nao precisa ser a frase exata, mas o conceito"
        }
      ],
      "documentos_a_exigir": ["documento ou laudo que o proprietario deve cobrar. Ex: 'Revisao do projeto estrutural com ART atualizada', 'Laudo de sondagem do solo', 'Solicite ART/RRT para esta atividade'. Liste apenas quando aplicavel"],
      "requer_validacao_profissional": true | false,
      "confianca": numero 0-100
    }
  ]
}

Retorne SOMENTE o JSON, sem markdown, sem texto adicional."""


# ─── Funcoes auxiliares ──────────────────────────────────────────────────────

def _clean_json_response(text: str) -> str:
    """Remove blocos de markdown se presentes na resposta da IA."""
    cleaned = text.strip()
    if cleaned.startswith("```"):
        lines = cleaned.split("\n")
        cleaned = (
            "\n".join(lines[1:-1])
            if lines[-1].strip() == "```"
            else "\n".join(lines[1:])
        )
    return cleaned


def _build_user_text(arquivo_nome: str, num_pages: int) -> str:
    return (
        f"{SYSTEM_PROMPT}\n\n"
        f"Analise TODAS as {num_pages} paginas do documento de projeto "
        f"'{arquivo_nome}' acima. Examine cada pagina individualmente e "
        f"identifique todos os riscos, inconsistencias e pontos de atencao "
        f"relevantes para o proprietario da obra."
    )


# ─── Analise via Claude (pagina por pagina) ──────────────────────────────────

def _analisar_com_claude(paginas: list[tuple[str, int]], arquivo_nome: str) -> dict:
    """Analisa documento pagina por pagina via Claude Vision API."""
    api_key = os.getenv("ANTHROPIC_API_KEY")
    if not api_key:
        raise ValueError("ANTHROPIC_API_KEY nao configurada")

    client = anthropic.Anthropic(api_key=api_key)

    content_blocks: list[dict] = []
    for img_b64, page_num in paginas:
        content_blocks.append({
            "type": "text",
            "text": f"[Pagina {page_num}]",
        })
        content_blocks.append({
            "type": "image",
            "source": {
                "type": "base64",
                "media_type": "image/png",
                "data": img_b64,
            },
        })

    content_blocks.append({
        "type": "text",
        "text": _build_user_text(arquivo_nome, len(paginas)),
    })

    response = client.messages.create(
        model="claude-sonnet-4-6",
        max_tokens=4096,
        messages=[{"role": "user", "content": content_blocks}],
    )

    output_text = response.content[0].text if response.content else ""
    if not output_text:
        raise ValueError("Claude nao retornou resposta valida")

    return json.loads(_clean_json_response(output_text))


# ─── Analise via OpenAI (pagina por pagina) ──────────────────────────────────

def _analisar_com_openai(paginas: list[tuple[str, int]], arquivo_nome: str) -> dict:
    """Analisa documento pagina por pagina via OpenAI GPT-4o Vision."""
    api_key = os.getenv("OPENAI_API_KEY")
    if not api_key:
        raise ValueError("OPENAI_API_KEY nao configurada para fallback")

    client = OpenAI(api_key=api_key)

    content_parts: list[dict] = []
    for img_b64, page_num in paginas:
        content_parts.append({
            "type": "text",
            "text": f"[Pagina {page_num}]",
        })
        content_parts.append({
            "type": "image_url",
            "image_url": {"url": f"data:image/png;base64,{img_b64}"},
        })

    content_parts.append({
        "type": "text",
        "text": _build_user_text(arquivo_nome, len(paginas)),
    })

    response = client.chat.completions.create(
        model="gpt-4o",
        messages=[{"role": "user", "content": content_parts}],
        max_tokens=4096,
    )

    output_text = response.choices[0].message.content or ""
    if not output_text:
        raise ValueError("OpenAI nao retornou resposta valida")

    return json.loads(_clean_json_response(output_text))


# ─── Analise via Gemini (pagina por pagina) ──────────────────────────────────

def _analisar_com_gemini(paginas: list[tuple[str, int]], arquivo_nome: str) -> dict:
    """Analisa documento pagina por pagina via Gemini Vision."""
    api_key = os.getenv("GEMINI_API_KEY")
    if not api_key:
        raise ValueError("GEMINI_API_KEY nao configurada para fallback")

    import google.generativeai as genai
    from google.generativeai.types import content_types

    genai.configure(api_key=api_key)
    model = genai.GenerativeModel("gemini-2.0-flash")

    parts = []
    for img_b64, page_num in paginas:
        parts.append(f"[Pagina {page_num}]")
        img_bytes = base64.standard_b64decode(img_b64)
        parts.append(content_types.to_part({"mime_type": "image/png", "data": img_bytes}))

    parts.append(_build_user_text(arquivo_nome, len(paginas)))

    response = model.generate_content(parts)

    output_text = response.text
    if not output_text:
        raise ValueError("Gemini nao retornou resposta valida")

    return json.loads(_clean_json_response(output_text))


# ─── Funcao principal ────────────────────────────────────────────────────────

def analisar_documento(pdf_bytes: bytes, arquivo_nome: str) -> dict:
    """
    Analisa um PDF de projeto pagina por pagina.
    Cadeia de fallback: Claude -> OpenAI -> Gemini.

    Retorna dict com resumo_geral, aviso_legal e lista de riscos.
    """
    paginas = extrair_paginas_como_imagens(pdf_bytes)
    logger.info("Documento '%s': %d paginas extraidas para analise", arquivo_nome, len(paginas))

    providers = [
        ("Claude", _analisar_com_claude),
        ("OpenAI", _analisar_com_openai),
        ("Gemini", _analisar_com_gemini),
    ]
    last_error = None
    for name, func in providers:
        try:
            resultado = func(paginas, arquivo_nome)
            logger.info("Analise de documento concluida via %s", name)
            return resultado
        except Exception as exc:
            logger.warning("Analise de documento falhou via %s: %s", name, exc)
            last_error = exc

    raise ValueError(
        f"Todos os providers falharam na analise do documento. Ultimo erro: {last_error}"
    )
