"""
Serviço de pesquisa normativa via OpenAI GPT-4o com web search.

Fase 2 — Biblioteca Normativa Dinâmica.

Guardrails obrigatórios (RULES.md):
- Sempre indicar fonte, data e versão da norma
- Indicar se fonte é oficial ou secundária
- Nunca apresentar como parecer técnico
- Exibir nível de confiança em toda análise
- Registrar versão e data de consulta
- Itens críticos exigem evidência
- Achados de alto risco requerem validação profissional
"""

import json
import os
from datetime import datetime
from typing import Optional

from openai import OpenAI

from .seed_checklists import CHECKLIST_PADRAO

# ─── Mapeamento de palavras-chave por etapa (NORMATIVE_KEYWORDS.md) ───────────

KEYWORDS_POR_ETAPA: dict[str, list[str]] = {
    "Planejamento e Projeto": [
        "licenciamento", "projeto executivo", "memoriais descritivos",
        "normas técnicas ABNT", "acessibilidade NBR 9050", "segurança do trabalho NR",
        "alvará de construção", "aprovação de projetos",
    ],
    "Preparacao do Terreno": [
        "terraplanagem", "movimentação de solo", "drenagem provisória",
        "proteção ambiental", "estabilidade de taludes", "NBR 11682",
        "contenção de encostas", "erosão",
    ],
    "Fundacoes e Estrutura": [
        "fundações NBR 6118", "estacas NBR 6122", "concreto armado",
        "armações cobrimento", "ensaios de resistência fck",
        "sondagem SPT NBR 6484", "controle tecnológico do concreto",
    ],
    "Alvenaria e Cobertura": [
        "alvenaria estrutural NBR 15961", "vedação", "impermeabilização NBR 9574",
        "telhado cobertura", "estanqueidade", "juntas de dilatação",
        "blocos cerâmicos NBR 15270",
    ],
    "Instalacoes e Acabamentos": [
        "instalação elétrica NBR 5410", "SPDA NBR 5419", "aterramento",
        "instalação hidráulica NBR 5626", "teste de pressão hidrostática",
        "acabamentos piso revestimento", "HVAC ar condicionado NBR 16280",
    ],
    "Entrega e Pos-obra": [
        "vistoria final obra", "habite-se", "manual do proprietário NBR 17170",
        "as-built", "garantia construtora CDC", "manutenção preventiva",
        "DATEC documento técnico de avaliação",
    ],
}

# ─── Prompt do sistema ────────────────────────────────────────────────────────

SYSTEM_PROMPT = """Você é um assistente especializado em normas técnicas brasileiras de construção civil.

Sua função é pesquisar normas aplicáveis a uma etapa específica de obra e traduzir os requisitos técnicos para linguagem acessível ao proprietário leigo.

REGRAS OBRIGATÓRIAS:
1. Sempre cite a fonte exata (nome da norma, número, órgão emissor, URL quando disponível)
2. Indique se a fonte é OFICIAL (ABNT, governo, agências reguladoras) ou SECUNDÁRIA (associações, guias técnicos)
3. Informe a versão/data de publicação da norma quando disponível
4. NUNCA apresente como parecer técnico ou opinião profissional
5. Sempre inclua nível de confiança (0-100) baseado na qualidade e autoridade da fonte
6. Para achados de ALTO RISCO, inclua recomendação explícita de validação profissional
7. Linguagem: clara, direta, sem jargão técnico excessivo

FORMATO DE RESPOSTA (JSON obrigatório):
{
  "resumo_geral": "texto introdutório em linguagem simples sobre as normas aplicáveis a esta etapa",
  "aviso_legal": "Este resultado é informativo e NÃO substitui parecer técnico de profissional habilitado.",
  "normas": [
    {
      "titulo": "Nome/número da norma ou diretriz",
      "fonte_nome": "ABNT / Ministério X / Nome do órgão",
      "fonte_url": "URL se disponível ou null",
      "fonte_tipo": "oficial" ou "secundaria",
      "versao": "versão ou ano da norma, ex: 'NBR 6118:2023' ou null",
      "data_norma": "ano de publicação ou null",
      "trecho_relevante": "trecho ou resumo do requisito técnico original (máx 300 chars)",
      "traducao_leigo": "o que isso significa para você como proprietário, em linguagem simples (máx 200 chars)",
      "nivel_confianca": número 0-100,
      "risco_nivel": "alto" | "medio" | "baixo" | null,
      "requer_validacao_profissional": true | false
    }
  ],
  "checklist_dinamico": [
    {
      "item": "ação concreta que o proprietário deve verificar ou solicitar",
      "critico": true | false,
      "norma_referencia": "norma que originou este item"
    }
  ]
}

Retorne SOMENTE o JSON, sem markdown, sem texto antes ou depois."""

# ─── Função principal ─────────────────────────────────────────────────────────


def _clean_json_normas(text: str) -> str:
    """Remove blocos de markdown se presentes na resposta da IA."""
    cleaned = text.strip()
    if cleaned.startswith("```"):
        lines = cleaned.split("\n")
        cleaned = "\n".join(lines[1:-1]) if lines[-1].strip() == "```" else "\n".join(lines[1:])
    return cleaned


def _parse_normas_json(output_text: str) -> dict:
    """Tenta parsear JSON; se falhar, tenta reparar problemas comuns."""
    cleaned = _clean_json_normas(output_text)
    try:
        return json.loads(cleaned)
    except json.JSONDecodeError:
        cleaned = cleaned.replace("\n", " ").replace("\r", "").replace("\t", " ")
        start = cleaned.find("{")
        end = cleaned.rfind("}") + 1
        if start >= 0 and end > start:
            cleaned = cleaned[start:end]
        try:
            return json.loads(cleaned)
        except json.JSONDecodeError:
            return {
                "resumo_geral": output_text[:500],
                "aviso_legal": "Este resultado é informativo e NÃO substitui parecer técnico de profissional habilitado.",
                "normas": [],
                "checklist_dinamico": [],
            }


def buscar_normas(
    etapa_nome: str,
    disciplina: Optional[str] = None,
    localizacao: Optional[str] = None,
    obra_tipo: Optional[str] = None,
) -> dict:
    """
    Pesquisa normas aplicáveis à etapa.
    Cadeia de fallback: Gemini -> OpenAI (web search).
    Retorna dict com normas, checklist dinâmico e metadados.
    """
    keywords = KEYWORDS_POR_ETAPA.get(etapa_nome, [])
    keywords_str = ", ".join(keywords[:6]) if keywords else etapa_nome

    contexto_extra = []
    if disciplina:
        contexto_extra.append(f"disciplina: {disciplina}")
    if localizacao:
        contexto_extra.append(f"localização: {localizacao}")
    if obra_tipo:
        contexto_extra.append(f"tipo de obra: {obra_tipo}")

    contexto_str = "; ".join(contexto_extra) if contexto_extra else "obra residencial no Brasil"

    query = (
        f"Pesquise normas técnicas brasileiras ABNT e regulamentações aplicáveis à etapa "
        f"'{etapa_nome}' de construção civil. "
        f"Palavras-chave: {keywords_str}. "
        f"Contexto: {contexto_str}. "
        f"Busque normas vigentes, requisitos obrigatórios e boas práticas. "
        f"Inclua número da norma, versão, órgão emissor e principais exigências."
    )

    full_input = f"{SYSTEM_PROMPT}\n\nConsulta: {query}"
    resultado = None

    # --- Gemini (primary) ---
    gemini_key = os.getenv("GEMINI_API_KEY")
    if gemini_key:
        try:
            import google.generativeai as genai
            genai.configure(api_key=gemini_key)
            model = genai.GenerativeModel("gemini-2.5-flash")
            response = model.generate_content(full_input)
            if response.text:
                resultado = _parse_normas_json(response.text)
        except Exception:
            pass

    # --- OpenAI (fallback with web search) ---
    if resultado is None:
        api_key = os.getenv("OPENAI_API_KEY")
        if not api_key:
            raise ValueError("Nenhum provider de IA configurado (GEMINI_API_KEY ou OPENAI_API_KEY)")

        client = OpenAI(api_key=api_key)
        response = client.responses.create(
            model="gpt-4o",
            tools=[{"type": "web_search_preview"}],
            input=full_input,
        )

        output_text = ""
        for item in response.output:
            if hasattr(item, "content"):
                for block in item.content:
                    if hasattr(block, "text"):
                        output_text = block.text
                        break
            if output_text:
                break

        if not output_text:
            raise ValueError("OpenAI não retornou resposta válida")

        resultado = _parse_normas_json(output_text)

    resultado["query_texto"] = query
    resultado["data_consulta"] = datetime.utcnow().isoformat()
    resultado["etapa_nome"] = etapa_nome
    resultado["disciplina"] = disciplina
    resultado["localizacao"] = localizacao

    return resultado
