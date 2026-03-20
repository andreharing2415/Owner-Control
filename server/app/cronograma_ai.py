"""
Servico de IA para geracao de cronograma de obra.

Duas funcoes principais:
1. identificar_tipos_projeto — analisa documentos e identifica disciplinas de construcao
2. gerar_cronograma — gera cronograma hierarquico com atividades, sub-atividades e servicos

Cadeia de fallback: Gemini -> OpenAI

Guardrails obrigatorios:
- Nunca apresentar como parecer tecnico ou opiniao profissional
- Indicar nivel de confianca em toda analise
- Linguagem acessivel ao proprietario leigo
"""

import logging

from .ai_providers import call_text_with_fallback, get_schedule_text_chain

logger = logging.getLogger(__name__)

AVISO_LEGAL = (
    "Este cronograma foi gerado por inteligencia artificial com base nas "
    "informacoes fornecidas e NAO substitui o planejamento tecnico de um "
    "engenheiro ou arquiteto habilitado. Os prazos e valores sao estimativas "
    "iniciais que devem ser validadas por profissionais com CREA/CAU."
)

# ─── Prompts ─────────────────────────────────────────────────────────────────

IDENTIFICAR_TIPOS_SYSTEM_PROMPT = """\
Voce e um Especialista em Construcao Civil e Gestao de Obras.
Sua missao e analisar os documentos de projeto fornecidos (nomes de arquivos e resumos) \
e identificar todas as disciplinas de construcao presentes.

DIRETRIZES:
1. Analise cuidadosamente o nome de cada arquivo e seu resumo para identificar disciplinas.
2. Um mesmo arquivo pode conter MULTIPLAS disciplinas (ex: um projeto complementar pode ter \
eletrico e hidraulico juntos).
3. Identifique disciplinas como: Estrutural, Eletrico, Hidraulico, Sanitario, Piscina, \
Cobertura, Esquadrias, Climatizacao, Gas, Incendio, Paisagismo, Arquitetonico, \
Fundacao, Impermeabilizacao, Revestimento, Pintura, Automacao, Drenagem, \
Energia Solar, Telefonia/Dados, entre outras.
4. Atribua um nivel de confianca (0-100) baseado na clareza da evidencia.
5. Se o resumo menciona explicitamente a disciplina, confianca deve ser alta (80-100).
6. Se a identificacao e inferida pelo nome do arquivo, confianca deve ser media (50-79).

FORMATO DE RESPOSTA OBRIGATORIO (JSON puro):
{
  "tipos": [
    {
      "nome": "Nome da disciplina (ex: Estrutural)",
      "confianca": 95,
      "projeto_doc_id": "ID do documento de origem",
      "projeto_doc_nome": "Nome do arquivo de origem"
    }
  ],
  "resumo": "Foram identificados X tipos de projeto: lista resumida das disciplinas encontradas."
}
Retorne APENAS o JSON valido."""

GERAR_CRONOGRAMA_SYSTEM_PROMPT = """\
Voce e um Engenheiro de Planejamento e Controle de Obras especializado em construcao civil \
brasileira de medio e alto padrao.
Sua missao e gerar um cronograma hierarquico realista para a obra descrita.

DIRETRIZES:
1. Gere atividades de Nivel 1 (fases macro) e Nivel 2 (detalhamento) seguindo a logica \
construtiva brasileira padrao.
2. As fases macro tipicas incluem (adapte conforme os tipos de projeto):
   - Servicos Preliminares / Planejamento
   - Fundacao
   - Estrutura
   - Alvenaria
   - Cobertura
   - Instalacoes Eletricas
   - Instalacoes Hidraulicas e Sanitarias
   - Impermeabilizacao
   - Revestimentos
   - Esquadrias
   - Pintura
   - Acabamentos
   - Paisagismo
   - Limpeza e Entrega
3. Distribua o orcamento proporcionalmente entre as atividades de forma realista.
4. Use datas dentro do periodo informado (data_inicio a data_fim).
5. Respeite a sequencia logica construtiva (fundacao antes de estrutura, etc.).
6. Para cada sub-atividade, liste os servicos profissionais necessarios.
7. As categorias de servico devem usar quando possivel os seguintes valores padrao: \
arquiteto, empreiteiro, pintor, marcenaria, marmore_granito, eletricista, encanador, \
serralheiro, vidraceiro, gesseiro, outro.
8. Inclua apenas as fases relevantes para os tipos de projeto informados.

FORMATO DE RESPOSTA OBRIGATORIO (JSON puro):
{
  "atividades": [
    {
      "nome": "Nome da fase macro",
      "descricao": "Descricao da fase",
      "ordem": 1,
      "nivel": 1,
      "tipo_projeto": "Disciplina relacionada (ex: Estrutural)",
      "valor_previsto": 50000.00,
      "data_inicio_prevista": "YYYY-MM-DD",
      "data_fim_prevista": "YYYY-MM-DD",
      "sub_atividades": [
        {
          "nome": "Nome da sub-atividade",
          "descricao": "Descricao detalhada",
          "ordem": 1,
          "nivel": 2,
          "tipo_projeto": "Disciplina relacionada",
          "valor_previsto": 15000.00,
          "data_inicio_prevista": "YYYY-MM-DD",
          "data_fim_prevista": "YYYY-MM-DD",
          "servicos": [
            {"descricao": "Descricao do servico", "categoria": "empreiteiro"}
          ]
        }
      ],
      "servicos": []
    }
  ]
}
Retorne APENAS o JSON valido. Nao inclua texto antes ou depois do JSON."""


# ─── Funcao 1: Identificar tipos de projeto ─────────────────────────────────


def identificar_tipos_projeto(docs: list[dict]) -> dict:
    """
    Analisa documentos do projeto e identifica disciplinas de construcao.

    Args:
        docs: Lista de dicts com campos 'id', 'arquivo_nome', 'resumo_geral'
              (vindos de ProjetoDoc).

    Returns:
        Dict com 'tipos' (lista de disciplinas identificadas), 'resumo' e 'aviso_legal'.
    """
    if not docs:
        return {
            "tipos": [],
            "resumo": "Nenhum documento fornecido para analise.",
            "aviso_legal": AVISO_LEGAL,
        }

    # Montar contexto dos documentos
    docs_texto = []
    for doc in docs:
        doc_id = doc.get("id", "")
        nome = doc.get("arquivo_nome", "Sem nome")
        resumo = doc.get("resumo_geral", "Sem resumo disponivel")
        docs_texto.append(
            f"- Documento ID: {doc_id}\n"
            f"  Arquivo: {nome}\n"
            f"  Resumo: {resumo}"
        )

    docs_contexto = "\n".join(docs_texto)

    prompt = (
        f"{IDENTIFICAR_TIPOS_SYSTEM_PROMPT}\n\n"
        f"DOCUMENTOS DO PROJETO:\n{docs_contexto}\n\n"
        f"Analise todos os documentos acima e identifique todas as disciplinas "
        f"de construcao presentes. Lembre-se: um arquivo pode conter multiplas disciplinas."
    )

    try:
        resultado = call_text_with_fallback(
            providers=get_schedule_text_chain(),
            prompt=prompt,
            task_label="Identificar tipos de projeto",
        )
    except ValueError:
        logger.error("Falha ao identificar tipos de projeto via IA")
        return {
            "tipos": [],
            "resumo": "Nao foi possivel analisar os documentos com IA no momento.",
            "aviso_legal": AVISO_LEGAL,
        }

    # Garantir que o resultado tem a estrutura esperada
    tipos = resultado.get("tipos", [])
    resumo = resultado.get("resumo", "")

    # Validar e limpar tipos
    tipos_validos = []
    for tipo in tipos:
        if isinstance(tipo, dict) and tipo.get("nome"):
            tipos_validos.append({
                "nome": str(tipo["nome"]),
                "confianca": int(tipo.get("confianca", 50)),
                "projeto_doc_id": str(tipo.get("projeto_doc_id", "")),
                "projeto_doc_nome": str(tipo.get("projeto_doc_nome", "")),
            })

    return {
        "tipos": tipos_validos,
        "resumo": resumo or f"Foram identificados {len(tipos_validos)} tipos de projeto.",
        "aviso_legal": AVISO_LEGAL,
    }


# ─── Funcao 2: Gerar cronograma ─────────────────────────────────────────────


def gerar_cronograma(obra_info: dict, tipos_projeto: list[str]) -> dict:
    """
    Gera cronograma hierarquico de obra baseado nas informacoes e tipos de projeto.

    Args:
        obra_info: Dict com campos 'nome', 'localizacao', 'orcamento',
                   'data_inicio', 'data_fim'.
        tipos_projeto: Lista de nomes de disciplinas confirmadas
                       (ex: ['Estrutural', 'Eletrico', 'Hidraulico']).

    Returns:
        Dict com 'atividades' (lista hierarquica de atividades com sub-atividades e servicos).
    """
    if not tipos_projeto:
        return {"atividades": []}

    nome = obra_info.get("nome", "Obra sem nome")
    localizacao = obra_info.get("localizacao", "Brasil")
    orcamento = obra_info.get("orcamento", 0)
    data_inicio = obra_info.get("data_inicio", "")
    data_fim = obra_info.get("data_fim", "")

    tipos_str = ", ".join(tipos_projeto)

    orcamento_str = (
        f"R$ {orcamento:,.2f}".replace(",", "X").replace(".", ",").replace("X", ".")
        if orcamento
        else "Nao informado"
    )

    prompt = (
        f"{GERAR_CRONOGRAMA_SYSTEM_PROMPT}\n\n"
        f"INFORMACOES DA OBRA:\n"
        f"- Nome: {nome}\n"
        f"- Localizacao: {localizacao}\n"
        f"- Orcamento total: {orcamento_str}\n"
        f"- Data de inicio: {data_inicio}\n"
        f"- Data de termino previsto: {data_fim}\n\n"
        f"TIPOS DE PROJETO IDENTIFICADOS:\n{tipos_str}\n\n"
        f"Gere o cronograma completo com todas as fases macro e sub-atividades "
        f"relevantes para os tipos de projeto listados. Distribua o orcamento "
        f"de forma realista entre as atividades. Use datas dentro do periodo informado."
    )

    try:
        resultado = call_text_with_fallback(
            providers=get_schedule_text_chain(),
            prompt=prompt,
            task_label="Gerar cronograma",
        )
    except ValueError:
        logger.error("Falha ao gerar cronograma via IA")
        return {"atividades": []}

    # Validar estrutura do resultado
    atividades = resultado.get("atividades", [])

    atividades_validas = []
    for idx, ativ in enumerate(atividades):
        if not isinstance(ativ, dict) or not ativ.get("nome"):
            continue

        sub_atividades_validas = []
        for sub_idx, sub in enumerate(ativ.get("sub_atividades", [])):
            if not isinstance(sub, dict) or not sub.get("nome"):
                continue

            servicos_validos = []
            for svc in sub.get("servicos", []):
                if isinstance(svc, dict) and svc.get("descricao"):
                    servicos_validos.append({
                        "descricao": str(svc["descricao"]),
                        "categoria": str(svc.get("categoria", "outro")),
                    })

            sub_atividades_validas.append({
                "nome": str(sub["nome"]),
                "descricao": str(sub.get("descricao", "")),
                "ordem": int(sub.get("ordem", sub_idx + 1)),
                "nivel": 2,
                "tipo_projeto": str(sub.get("tipo_projeto", ativ.get("tipo_projeto", ""))),
                "valor_previsto": float(sub.get("valor_previsto", 0)),
                "data_inicio_prevista": str(sub.get("data_inicio_prevista", "")),
                "data_fim_prevista": str(sub.get("data_fim_prevista", "")),
                "servicos": servicos_validos,
            })

        servicos_nivel1 = []
        for svc in ativ.get("servicos", []):
            if isinstance(svc, dict) and svc.get("descricao"):
                servicos_nivel1.append({
                    "descricao": str(svc["descricao"]),
                    "categoria": str(svc.get("categoria", "outro")),
                })

        atividades_validas.append({
            "nome": str(ativ["nome"]),
            "descricao": str(ativ.get("descricao", "")),
            "ordem": int(ativ.get("ordem", idx + 1)),
            "nivel": 1,
            "tipo_projeto": str(ativ.get("tipo_projeto", "")),
            "valor_previsto": float(ativ.get("valor_previsto", 0)),
            "data_inicio_prevista": str(ativ.get("data_inicio_prevista", "")),
            "data_fim_prevista": str(ativ.get("data_fim_prevista", "")),
            "sub_atividades": sub_atividades_validas,
            "servicos": servicos_nivel1,
        })

    return {"atividades": atividades_validas}
