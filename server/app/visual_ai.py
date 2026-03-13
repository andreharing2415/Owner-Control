"""
Servico de analise visual de fotos da obra via IA.

Fase 4 — Visual AI.

Cadeia de fallback: Gemini -> Claude -> OpenAI.

Guardrails obrigatorios:
- Nunca apresentar como parecer tecnico ou opiniao profissional
- Indicar nivel de confianca em toda analise
- Achados de alto nivel exigem recomendacao de validacao profissional
- Linguagem acessivel ao proprietario leigo
"""

import base64
import json
import logging
import os

import anthropic
from openai import OpenAI

from .utils import clean_json_response

logger = logging.getLogger(__name__)

# ─── Etapas padrão para contextualização ─────────────────────────────────────

ETAPAS_PADRAO = [
    "Planejamento e Projeto",
    "Preparação do Terreno",
    "Fundações e Estrutura",
    "Alvenaria e Cobertura",
    "Instalações e Acabamentos",
    "Entrega e Pós-obra",
]

# ─── Prompt do sistema ────────────────────────────────────────────────────────

SYSTEM_PROMPT = f"""Você é um especialista em inspeção visual de obras de construção civil, com foco em identificar problemas, riscos e não-conformidades em fotos de canteiros de obra de alto padrão.

Sua função é analisar uma foto da obra e:
1. Identificar em qual etapa construtiva a imagem se enquadra
2. Identificar achados (findings) relevantes com severidade

As 6 etapas padrão são:
{chr(10).join(f'- {e}' for e in ETAPAS_PADRAO)}

REGRAS OBRIGATÓRIAS:
1. Classifique a etapa construtiva visível na foto (use EXATAMENTE um dos nomes acima, ou null se não for possível determinar)
2. Indique a confiança na classificação da etapa (0-100)
3. Identifique achados concretos e visíveis na foto (não especule além do que é visível)
4. Para cada achado: descreva o problema, classifique a severidade e indique a ação recomendada
5. Severidades: "alto" (risco à segurança ou impacto financeiro relevante), "medio" (exige atenção), "baixo" (observação preventiva)
6. Achados de severidade "alto" DEVEM ter requer_validacao_profissional: true
7. Se não houver achados negativos, retorne lista vazia — não invente problemas
8. NUNCA apresente como laudo técnico ou parecer de engenheiro
9. Linguagem clara e objetiva para proprietário leigo

FORMATO DE RESPOSTA (JSON obrigatório):
{{
  "etapa_inferida": "nome exato da etapa ou null",
  "confianca_etapa": número 0-100,
  "resumo_geral": "resumo em 2-3 frases do que é visível na foto e dos principais achados",
  "aviso_legal": "Esta análise é informativa e NÃO substitui vistoria técnica de engenheiro ou arquiteto habilitado.",
  "achados": [
    {{
      "descricao": "descrição objetiva do achado visível na foto",
      "severidade": "alto" | "medio" | "baixo",
      "acao_recomendada": "o que o proprietário deve fazer (máx 200 chars)",
      "requer_evidencia_adicional": true | false,
      "requer_validacao_profissional": true | false,
      "confianca": número 0-100
    }}
  ]
}}

Retorne SOMENTE o JSON, sem markdown, sem texto adicional."""

# ─── Função principal ─────────────────────────────────────────────────────────


def _detect_media_type(imagem_nome: str) -> str:
    """Detecta media_type pela extensão do arquivo."""
    ext = imagem_nome.rsplit(".", 1)[-1].lower() if "." in imagem_nome else "jpeg"
    media_type_map = {
        "jpg": "image/jpeg",
        "jpeg": "image/jpeg",
        "png": "image/png",
        "gif": "image/gif",
        "webp": "image/webp",
    }
    return media_type_map.get(ext, "image/jpeg")


def _analisar_com_claude(imagem_b64: str, media_type: str, etapa_nome: str, grupo: str | None = None) -> dict:
    """Analisa imagem via Claude Vision API."""
    api_key = os.getenv("ANTHROPIC_API_KEY")
    if not api_key:
        raise ValueError("ANTHROPIC_API_KEY não configurada")

    client = anthropic.Anthropic(api_key=api_key)

    contexto_grupo = f" Categoria/grupo do checklist: '{grupo}'." if grupo else ""

    response = client.messages.create(
        model="claude-sonnet-4-6",
        max_tokens=4096,
        messages=[
            {
                "role": "user",
                "content": [
                    {
                        "type": "image",
                        "source": {
                            "type": "base64",
                            "media_type": media_type,
                            "data": imagem_b64,
                        },
                    },
                    {
                        "type": "text",
                        "text": (
                            f"{SYSTEM_PROMPT}\n\n"
                            f"Analise a foto acima da etapa '{etapa_nome}' desta obra.{contexto_grupo} "
                            f"Identifique a etapa construtiva visível e todos os achados "
                            f"relevantes para o proprietário."
                        ),
                    },
                ],
            }
        ],
    )

    output_text = response.content[0].text if response.content else ""
    if not output_text:
        raise ValueError("Claude não retornou resposta válida")

    return json.loads(clean_json_response(output_text))


def _analisar_com_openai(imagem_b64: str, media_type: str, etapa_nome: str, grupo: str | None = None) -> dict:
    """Analisa imagem via OpenAI GPT-4o Vision (fallback)."""
    api_key = os.getenv("OPENAI_API_KEY")
    if not api_key:
        raise ValueError("OPENAI_API_KEY não configurada para fallback")

    client = OpenAI(api_key=api_key)

    contexto_grupo = f" Categoria/grupo do checklist: '{grupo}'." if grupo else ""

    response = client.chat.completions.create(
        model="gpt-4o",
        messages=[
            {
                "role": "user",
                "content": [
                    {
                        "type": "image_url",
                        "image_url": {"url": f"data:{media_type};base64,{imagem_b64}"},
                    },
                    {
                        "type": "text",
                        "text": (
                            f"{SYSTEM_PROMPT}\n\n"
                            f"Analise a foto acima da etapa '{etapa_nome}' desta obra.{contexto_grupo} "
                            f"Identifique a etapa construtiva visível e todos os achados "
                            f"relevantes para o proprietário."
                        ),
                    },
                ],
            }
        ],
        max_tokens=4096,
    )

    output_text = response.choices[0].message.content or ""
    if not output_text:
        raise ValueError("OpenAI não retornou resposta válida")

    return json.loads(clean_json_response(output_text))


def _analisar_com_gemini(imagem_b64: str, media_type: str, etapa_nome: str, grupo: str | None = None) -> dict:
    """Analisa imagem via Gemini Vision (fallback)."""
    api_key = os.getenv("GEMINI_API_KEY")
    if not api_key:
        raise ValueError("GEMINI_API_KEY nao configurada para fallback")

    import google.generativeai as genai
    from google.generativeai.types import content_types

    genai.configure(api_key=api_key)
    model = genai.GenerativeModel("gemini-2.5-flash")

    contexto_grupo = f" Categoria/grupo do checklist: '{grupo}'." if grupo else ""

    img_bytes = base64.standard_b64decode(imagem_b64)
    parts = [
        content_types.to_part({"mime_type": media_type, "data": img_bytes}),
        (
            f"{SYSTEM_PROMPT}\n\n"
            f"Analise a foto acima da etapa '{etapa_nome}' desta obra.{contexto_grupo} "
            f"Identifique a etapa construtiva visivel e todos os achados "
            f"relevantes para o proprietario."
        ),
    ]

    response = model.generate_content(parts)

    output_text = response.text
    if not output_text:
        raise ValueError("Gemini nao retornou resposta valida")

    return json.loads(clean_json_response(output_text))


def analisar_imagem(imagem_bytes: bytes, imagem_nome: str, etapa_nome: str, grupo: str | None = None) -> dict:
    """
    Analisa uma foto de obra.
    Cadeia de fallback: Gemini -> Claude -> OpenAI.

    Retorna dict com etapa_inferida, confianca_etapa, resumo_geral, aviso_legal e achados.
    """
    media_type = _detect_media_type(imagem_nome)
    imagem_b64 = base64.standard_b64encode(imagem_bytes).decode("utf-8")

    providers = [
        ("Gemini", _analisar_com_gemini),
        ("Claude", _analisar_com_claude),
        ("OpenAI", _analisar_com_openai),
    ]
    last_error = None
    for name, func in providers:
        try:
            resultado = func(imagem_b64, media_type, etapa_nome, grupo)
            logger.info("Analise visual concluida via %s", name)
            return resultado
        except Exception as exc:
            logger.warning("Analise visual falhou via %s: %s", name, exc)
            last_error = exc

    raise ValueError(
        f"Todos os providers falharam na analise visual. Ultimo erro: {last_error}"
    )
