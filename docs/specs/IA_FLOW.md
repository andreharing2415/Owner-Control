# Fluxo IA Normativa - Entradas e Saidas

## Objetivo
Descrever o fluxo de IA normativa com entradas, saidas, logs e guardrails.

## Requisitos funcionais
- Receber etapa e contexto de obra para busca normativa.
- Buscar normas em fontes web e registrar fonte, data e versao.
- Extrair diretrizes e gerar checklist dinamico.
- Apresentar traducao leiga, sem parecer tecnico.
- Exibir nivel de confianca em cada resposta.

## Dados de entrada
- Etapa da obra.
- Disciplina (se aplicavel).
- Palavras-chave (ver docs/NORMATIVE_KEYWORDS.md).
- Localizacao (UF/cidade).
- Tipo de obra (opcional).

## Dados de saida
- Lista de normas com fonte, data e versao.
- Diretrizes extraidas e estruturadas.
- Checklist dinamico auditavel.
- Nivel de confianca por item.

## Fluxo (alto nivel)
1. Receber etapa e contexto.
2. Montar query com palavras-chave da etapa.
3. Buscar normas em fontes web.
4. Classificar fonte como oficial ou secundaria.
5. Extrair trechos relevantes e metadados.
6. Traduzir para linguagem leiga.
7. Gerar checklist dinamico.
8. Registrar logs de consulta.

## Logs obrigatorios
- Fonte, data e versao da norma.
- Tipo de fonte (oficial ou secundaria).
- Data e hora da consulta.
- Nivel de confianca.

## Guardrails
- Nao apresentar como parecer tecnico.
- Evidencia obrigatoria para itens criticos.
- Achados de risco alto exigem recomendacao clara e solicitacao de validacao profissional.

## Criterios de aceite
- Fluxo documentado com entradas e saidas.
- Registro de fonte, data e versao definido.
- Nivel de confianca previsto em toda analise.

