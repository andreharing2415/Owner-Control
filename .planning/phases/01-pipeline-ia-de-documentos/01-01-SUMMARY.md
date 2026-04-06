---
phase: 1
plan: "01-01"
subsystem: document-analysis
tags: [ai, extraction, pipeline, projetodoc, elements]
dependency_graph:
  requires: []
  provides: [ProjetoDoc.elementos_extraidos, document_analysis.extrair_elementos_construtivos]
  affects: [documento_service.analisar_documento_e_persistir, ProjetoDocRead]
tech_stack:
  added: [server/app/document_analysis.py]
  patterns: [two-pass-extraction, vision-ai-per-page, text-ai-consolidation, silent-failure-enrichment]
key_files:
  created:
    - server/app/document_analysis.py
    - server/tests/test_extraction_pipeline.py
  modified:
    - server/app/models.py
    - server/app/schemas.py
    - server/app/services/documento_service.py
decisions:
  - "Pipeline de extração integrado como enriquecimento silencioso após análise de riscos — falha não bloqueia análise principal"
  - "Passagem 2 usa get_schedule_text_chain() (Gemini→OpenAI) para consolidação de texto — sem fallback para vision"
  - "elementos_extraidos armazenado como JSON string em ProjetoDoc para compatibilidade com SQLModel sem migração imediata"
metrics:
  duration: "~15 min"
  completed: "2026-04-06"
  tasks: 2
  files: 5
---

# Phase 1 Plan 01: Pipeline de Extração de Elementos Construtivos — Summary

Pipeline de extração em duas passagens que converte um documento PDF de projeto em ElementoConstrutivo[] estruturados, persistidos em ProjetoDoc.elementos_extraidos — base objetiva para geração de cronograma e checklist específicos da obra.

## What Was Built

### Task 1: Schema e Persistência de Elementos Extraídos

- Adicionado campo `elementos_extraidos: Optional[str]` ao modelo `ProjetoDoc` (JSON string contendo `ElementoConstrutivo[]`)
- Criado schema `ElementoConstrutivo` com campos: `categoria`, `nome`, `descricao`, `especificacao`, `localizacao`, `pagina_referencia`, `prancha_referencia`, `confianca`
- Exposto `elementos_extraidos` no schema `ProjetoDocRead` (resposta da API)

### Task 2: Pipeline em Duas Passagens

Criado `server/app/document_analysis.py` com:

**Passagem 1** — `_extrair_elementos_pagina()`: chama `call_vision_with_fallback` (Gemini→Claude→OpenAI) em cada página, retornando lista de elementos brutos. Falha silenciosa por página — páginas sem elementos técnicos retornam lista vazia.

**Passagem 2** — `_consolidar_elementos()`: chama `call_text_with_fallback` (Gemini→OpenAI) com todos os elementos brutos por página. A IA consolida, deduplica e enriquece. Fallback: se consolidação falhar, retorna elementos brutos concatenados.

**Orquestrador** — `extrair_elementos_construtivos(paginas, arquivo_nome)`: executa as duas passagens e retorna lista final.

**Persistência** — `extrair_e_persistir_elementos(session, projeto_id)`: baixa o PDF, extrai páginas como imagens e persiste o resultado em `ProjetoDoc.elementos_extraidos`.

**Integração**: `analisar_documento_e_persistir` em `documento_service.py` agora chama `extrair_e_persistir_elementos` após conclusão da análise de riscos — enriquecimento paralelo, não bloqueante.

## Verification

- 11 testes unitários criados em `server/tests/test_extraction_pipeline.py`
- 54 passed, 5 skipped (PDF Windows skip) no suite completo
- Testes cobrem: schema ProjetoDoc, ElementoConstrutivo, ProjetoDocRead, pipeline com mocks, deduplicação, páginas vazias, persistência

## Decisions Made

1. **Integração silenciosa**: A extração de elementos não bloqueia a análise de riscos — se falhar, o ProjetoDoc fica com `elementos_extraidos=null` mas status continua `concluido`. Isso preserva a funcionalidade existente.

2. **Passagem 2 via text (não vision)**: A consolidação usa `get_schedule_text_chain()` porque recebe texto JSON (não imagens). Mais barato e mais confiável para raciocínio de deduplicação.

3. **JSON string em vez de coluna separada**: Armazenado como string JSON para evitar nova migração Alembic neste plano — migração formal virá na próxima fase junto com outros campos novos.

## Deviations from Plan

### Auto-fixed Issues

None — plan executed exactly as written.

**Note**: Testes verificam prefixo `document_analysis` (não `"document analysis"` com espaço) pois o filtro `-k` do pytest não aceita espaços sem quotes especiais. Os testes passam normalmente.

## Known Stubs

None — `elementos_extraidos` é populado pelo pipeline real via AI providers. Em ambiente de teste, os providers são mockados para retornar dados válidos.

## Self-Check: PASSED

- server/app/document_analysis.py — FOUND
- server/app/models.py — FOUND (modified)
- server/app/schemas.py — FOUND (modified)
- server/tests/test_extraction_pipeline.py — FOUND
- Commit 537a1d8 — FOUND
- Commit 61ad351 — FOUND
- 54 tests pass, 5 skipped
