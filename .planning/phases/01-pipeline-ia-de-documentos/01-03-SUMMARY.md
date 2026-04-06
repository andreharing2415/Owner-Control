---
phase: 1
plan: "01-03"
subsystem: cronograma-hierarquico
tags: [cronograma, hierarquia, checklist, auto-spawn, preservacao-edicoes]
dependency_graph:
  requires: [01-01, 01-02]
  provides: [AtividadeCronograma.is_modified, AtividadeCronograma.locked, checklist_auto_spawn]
  affects: [cronograma.py, checklist.py, models.py, schemas.py]
tech_stack:
  added: [server/alembic/versions/20260406_0026_atividadecronograma_flags_modificacao.py]
  patterns: [locked-preservation, auto-spawn-checklist, sequencia-construtiva-por-ordem]
key_files:
  created:
    - server/tests/test_cronograma_hierarchy.py
    - server/alembic/versions/20260406_0026_atividadecronograma_flags_modificacao.py
  modified:
    - server/app/models.py
    - server/app/schemas.py
    - server/app/routers/cronograma.py
decisions:
  - "locked=True preserva atividade durante re-geracao — is_modified apenas sinaliza edicao, nao bloqueia sobrescrita"
  - "Auto-spawn cria ChecklistItem com origem=ia para cada nivel=2, usando macro (nivel=1) como grupo"
  - "Checklist items de IA sao deletados junto com atividades nao-locked na re-geracao para manter sincronismo arvore-checklist"
  - "Migration 0026 com server_default=false para retrocompatibilidade com registros existentes"
metrics:
  duration: "~12 min"
  completed: "2026-04-06"
  tasks: 2
  files: 5
requirements:
  - AI-03
  - AI-04
  - AI-05
---

# Phase 1 Plan 03: Arvore Hierarquica Cronograma/Checklist com Preservacao de Edicoes — Summary

Arvore macro/micro unificada em `AtividadeCronograma` com flags `is_modified`/`locked` para preservar edicoes manuais durante reprocessamento, e auto-spawn de `ChecklistItem` para cada micro-atividade gerada por IA — cronograma e checklist nascem sincronizados da mesma fonte.

## What Was Built

### Task 1: Modelo e Flags de Preservacao

- `AtividadeCronograma.is_modified: bool = False` — setado automaticamente para `True` em todo `PATCH` manual via endpoint `atualizar_atividade`
- `AtividadeCronograma.locked: bool = False` — atividade completamente protegida: nunca deletada nem sobrescrita em re-geracao
- `AtividadeCronogramaRead` expoe ambos os campos para o frontend controlar UI de edicao
- `AtividadeUpdate` expandido com `nome`, `descricao`, `data_inicio_prevista`, `data_fim_prevista`, `locked` — engenheiro pode editar qualquer campo e travar a atividade
- Migration `20260406_0026`: adiciona colunas `is_modified BOOLEAN NOT NULL DEFAULT false` e `locked BOOLEAN NOT NULL DEFAULT false` em `atividadecronograma`

### Task 2: Geracao Unificada e Auto-Spawn

**Preservacao na re-geracao:**
- `gerar_cronograma_endpoint` identifica atividades com `locked=True` antes de deletar
- Apenas atividades `locked=False` sao removidas (junto com seus servicos e checklist items de IA)
- Atividades `locked=True` permanecem intactas com dados do engenheiro

**Auto-spawn de ChecklistItem (AI-04/05):**
- Para cada sub-atividade (nivel=2) criada, um `ChecklistItem` e gerado automaticamente
- `titulo`: `"Verificar: {nome_da_atividade}"`
- `grupo`: nome da macro-atividade (nivel=1) — organiza o checklist por fase
- `origem`: `"ia"` — distingue de itens criados manualmente
- `ordem`: herdada da sub-atividade — preserva sequencia construtiva
- Checklist items com `origem="ia"` sao deletados junto com suas atividades na re-geracao

**Sequencia construtiva:**
- Sequencia (fundacao → estrutura → instalacoes → acabamento) e controlada pelo campo `ordem` que a IA atribui
- O router persiste na ordem exata retornada pela IA — sem reordenacao arbitraria

## Verification

- 13 testes unitarios em `server/tests/test_cronograma_hierarchy.py`
- Cobertura: model defaults, macro/micro linkage, flags set/read, schema read, schema update, sequencia construtiva, logica de preservacao locked, auto-spawn nivel=2, spawn nao-cria para nivel=1
- 62 testes passando (excluindo 11 falhas pre-existentes em `test_extraction_pipeline.py` com import path errado — fora do escopo deste plano)
- 5 skipped (PDF tests, apenas em Linux/Docker)

## Decisions Made

1. **`locked` > `is_modified` em hierarquia de protecao**: `is_modified=True` sinaliza ao frontend que a atividade foi editada (highlight, aviso), mas nao bloqueia re-geracao. Apenas `locked=True` garante sobrevivencia. Isso da flexibilidade: engenheiro pode escolher travar ou deixar a IA sobrescrever.

2. **Auto-spawn sincrono**: ChecklistItem criado na mesma transacao de `gerar_cronograma_endpoint`, sem background task. Garante que arvore e checklist estao sempre sincronizados ao final do endpoint.

3. **Grupo do ChecklistItem = macro-atividade**: Agrupa itens do checklist pela fase de obra (ex: "Fundacao", "Estrutura") — alinha com a UX existente que usa `grupo` para organizar o checklist por contexto.

4. **Migration conservadora**: `server_default=false` (sem NOT NULL retroativo via aplicacao) para evitar lock de tabela em deploy com dados existentes.

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None — `is_modified`/`locked` sao persistidos no DB. Auto-spawn cria `ChecklistItem` real na mesma transacao. Nao ha hardcoded values ou placeholders.

## Self-Check: PASSED

Files created:
- `server/tests/test_cronograma_hierarchy.py` — FOUND
- `server/alembic/versions/20260406_0026_atividadecronograma_flags_modificacao.py` — FOUND

Files modified:
- `server/app/models.py` — FOUND (is_modified, locked em AtividadeCronograma)
- `server/app/schemas.py` — FOUND (AtividadeCronogramaRead, AtividadeUpdate expandidos)
- `server/app/routers/cronograma.py` — FOUND (preservacao + auto-spawn)

Commits:
- 5712548 — Task 1 (modelo + schema + migration + router PATCH + testes)
- 01769dd — Task 2 (preservacao locked + auto-spawn checklist)
