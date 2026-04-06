---
phase: 1
plan: "01-02"
subsystem: backend-ai
tags: [ai, checklist, rastreabilidade, fonte-doc-trecho]
dependency_graph:
  requires: []
  provides: [fonte_doc_trecho_obrigatorio, checklist_rastreavel]
  affects: [checklist_inteligente, checklistgeracaoitem, api_response]
tech_stack:
  added: []
  patterns: [campo_obrigatorio_parser, alembic_migration, pydantic_schema_extension]
key_files:
  created:
    - server/tests/test_checklist_inteligente.py
    - server/alembic/versions/20260406_0025_checklistgeracaoitem_fonte_doc_trecho.py
  modified:
    - server/app/checklist_inteligente.py
    - server/app/models.py
    - server/app/schemas.py
decisions:
  - fonte_doc_trecho e Optional no schema/modelo (retrocompatibilidade com itens legados sem trecho)
  - Truncagem em 500 chars no item normalizado e 150 chars em dado_projeto.fonte
  - Rejeicao silenciosa com log.warning — nao levanta excecao para nao quebrar pipeline SSE
metrics:
  duration_seconds: 272
  completed_date: "2026-04-06"
  tasks_completed: 2
  files_modified: 5
requirements:
  - AI-02
---

# Phase 1 Plan 02: Geracao Fundamentada com fonte_doc_trecho Summary

Implementacao de rastreabilidade obrigatoria: cada atividade gerada por IA agora cita o trecho exato do documento que a originou via campo `fonte_doc_trecho`, com validacao no parser e persistencia em DB + API.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Ajustar prompts e contrato de saida para evidencias | 76c2f44 | checklist_inteligente.py, test_checklist_inteligente.py |
| 2 | Persistir e expor fonte_doc_trecho na API | 3dd52b4 | models.py, schemas.py, checklist_inteligente.py, migration 0025, test_checklist_inteligente.py |

## What Was Built

### Task 1: Prompts e validacao

- `PHASE2_SYSTEM_PROMPT` recebeu diretriz 5 exigindo `fonte_doc_trecho` em cada item do checklist JSON
- `_normalizar_fase2` rejeita itens onde `fonte_doc_trecho` e ausente, vazio ou apenas espacos
- Items rejeitados sao logados com `logger.warning` — pipeline SSE continua sem interromper
- Campo propagado no item normalizado e em `dado_projeto.fonte` (truncado a 150 chars)
- Contador `itens_rejeitados_sem_fonte` adicionado ao dict de retorno para rastreio
- 15 testes unitarios cobrindo todos os cenarios de rejeicao e propagacao

### Task 2: Schema, modelo e persistencia

- `ChecklistGeracaoItem` (ORM): campo `fonte_doc_trecho: Optional[str]`
- `ChecklistGeracaoItemRead` (schema): campo `fonte_doc_trecho: Optional[str] = None`
- `ItemParaAplicar` (schema): campo `fonte_doc_trecho: Optional[str] = None`
- `processar_checklist_background`: persiste `fonte_doc_trecho` ao salvar cada item no DB
- Migration `20260406_0025`: adiciona coluna `fonte_doc_trecho TEXT` em `checklistgeracaoitem`
- 6 testes de schema/API: presenca do campo, opcionalidade e instanciacao com/sem fonte

## Decisions Made

| Decision | Rationale |
|----------|-----------|
| `fonte_doc_trecho` e Optional no ORM/schema | Retrocompatibilidade — itens legados no DB nao tem este campo |
| Rejeicao com warning, sem excecao | Pipeline SSE e incremental; um item invalido nao deve quebrar todo o batch |
| Truncagem a 500 chars (item) e 150 chars (dado_projeto.fonte) | Limita tamanho de storage sem perder contexto legivel |
| Migration Alembic separada | Padrao do projeto — cada mudanca de schema tem sua propria migration |

## Deviations from Plan

None - plan executed exactly as written.

## Verification

- 21 testes passando em `server/tests/test_checklist_inteligente.py`
- Testes pre-existentes (auth, subscription) continuam passando (28 passando)
- 11 falhas em `test_extraction_pipeline.py` sao pre-existentes de outro agente paralelo (plano 01-01), fora do escopo deste plano

## Known Stubs

None — `fonte_doc_trecho` e persistido no DB, exposto no response model e validado no parser.

## Self-Check

Files created/modified:
- `server/app/checklist_inteligente.py` — FOUND
- `server/app/models.py` — FOUND
- `server/app/schemas.py` — FOUND
- `server/tests/test_checklist_inteligente.py` — FOUND
- `server/alembic/versions/20260406_0025_checklistgeracaoitem_fonte_doc_trecho.py` — FOUND

Commits:
- 76c2f44 — Task 1
- 3dd52b4 — Task 2
