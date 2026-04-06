---
phase: 00-bloqueadores-críticos
plan: "00-01"
subsystem: infra
tags: [alembic, postgresql, migrations, cloud-run, deploy]

requires: []
provides:
  - Cadeia Alembic linear sem IDs duplicados (25 migrações, 1 head)
  - deploy-cloudrun.sh com --min-instances=1 para eliminar cold-start
affects:
  - Todos os planos subsequentes que executam deploy fresh no Cloud Run

tech-stack:
  added: []
  patterns:
    - "Revision IDs Alembic: formato longo YYYYMMDD_NNNN para todas as migrações"
    - "Migrações paralelas fundidas como 0014 → 0014b em vez de dois IDs iguais"

key-files:
  created: []
  modified:
    - server/alembic/versions/20260309_0014_add_valor_realizado.py
    - server/alembic/versions/20260309_0014_checklist_unificado.py
    - server/alembic/versions/20260311_0015_fase6_new_fields.py
    - server/alembic/versions/20260319_0023_projetodoc_erro_detalhe.py
    - server/alembic/versions/20260319_0024_composite_indexes.py
    - server/deploy-cloudrun.sh

key-decisions:
  - "Migração duplicada fundida como 0014 (checklist_unificado) + 0014b (add_valor_realizado) em vez de reescrever em arquivo único"
  - "IDs curtos 0023/0024 normalizados para formato longo 20260319_0023/0024 para consistência"
  - "min-instances=1 via flag --min-instances no gcloud run deploy (não via YAML separado)"

patterns-established:
  - "Alembic revision IDs: sempre no formato YYYYMMDD_NNNN"
  - "Migrações paralelas: encadear como A → B em vez de dois nós com mesmo down_revision"

requirements-completed:
  - INFRA-01
  - INFRA-05

duration: 15min
completed: 2026-04-06
---

# Phase 00 Plan 01: Corrigir Cadeia Alembic + Cloud Run min-instances Summary

**Cadeia Alembic linear com 25 migrações e 1 head estável, mais deploy script com min-instances=1 para eliminar cold-start no Cloud Run**

## Performance

- **Duration:** ~15 min
- **Started:** 2026-04-06T22:43:00Z
- **Completed:** 2026-04-06T22:58:48Z
- **Tasks:** 3
- **Files modified:** 6

## Accomplishments

- Eliminados 2 IDs de revisão duplicados (`20260309_0014`) que quebravam `alembic upgrade head` em banco limpo
- Cadeia linear de 25 migrações com um único head (`20260319_0024`) validada via offline SQL generation
- `deploy-cloudrun.sh` atualizado com `--min-instances 1` para manter 1 instância sempre ativa (INFRA-05)

## Task Commits

1. **Task 1: Corrigir cadeia Alembic duplicada** - `4b78c4a` (fix)
2. **Task 2: Validar migration chain** - incluído no Task 1 (validação via offline mode)
3. **Task 3: Ativar min-instances no deploy Cloud Run** - `7b882c8` (feat)

## Files Created/Modified

- `server/alembic/versions/20260309_0014_add_valor_realizado.py` - Revision renomeada de `20260309_0014` para `20260309_0014b`, down_revision atualizado para `20260309_0014`
- `server/alembic/versions/20260309_0014_checklist_unificado.py` - Mantida como `20260309_0014` (revision canônica, sem alteração)
- `server/alembic/versions/20260311_0015_fase6_new_fields.py` - down_revision atualizado de `20260311_0013` para `20260309_0014b`
- `server/alembic/versions/20260319_0023_projetodoc_erro_detalhe.py` - IDs normalizados de `0023`/`0022` para `20260319_0023`/`20260319_0022`
- `server/alembic/versions/20260319_0024_composite_indexes.py` - IDs normalizados de `0024`/`0023` para `20260319_0024`/`20260319_0023`
- `server/deploy-cloudrun.sh` - Adicionado `--min-instances 1` ao gcloud run deploy

## Decisions Made

- Migração `add_valor_realizado` renomeada para `0014b` (em vez de fundir as duas em arquivo único) para preservar histórico e minimizar diff
- IDs curtos `0023`/`0024` normalizados para o padrão longo `YYYYMMDD_NNNN` usado nas demais migrações
- Task 2 validada via `alembic upgrade head --sql` (offline mode) pois não há banco PostgreSQL local — modo offline gera SQL completo do base ao head sem conexão, provando que a cadeia é válida para fresh deploy

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] 20260311_0015 apontava para 0013 em vez de 0014**
- **Found during:** Task 1 (análise da cadeia)
- **Issue:** `20260311_0015_fase6_new_fields.py` tinha `down_revision = "20260311_0013"` — pulava as migrações 0014, criando uma bifurcação
- **Fix:** Atualizado para `down_revision = "20260309_0014b"` para manter sequência linear correta
- **Files modified:** `server/alembic/versions/20260311_0015_fase6_new_fields.py`
- **Verification:** `alembic history --verbose` mostra chain linear 0013 → 0014 → 0014b → 0015
- **Committed in:** `4b78c4a` (Task 1 commit)

---

**Total deviations:** 1 auto-fixed (1 bug)
**Impact on plan:** Fix necessário para a cadeia ser verdadeiramente linear. Sem este fix, `upgrade head` em banco limpo executaria 0015 pulando 0014/0014b (bifurcação implícita).

## Issues Encountered

- Banco PostgreSQL local não disponível — Task 2 validada via `alembic upgrade head --sql` (offline mode), que gera SQL completo de base ao head sem conexão real. Resultado: SQL gerado com sucesso até `20260319_0024` sem erros, confirmando cadeia válida para deploy fresh.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Cadeia Alembic estável: próximo deploy fresh ou migration executa sem erro de duplicate revision
- Cloud Run configurado para min-instances=1: cold-start eliminado após próximo deploy
- Planos 00-02 e 00-03 podem executar em paralelo sem bloqueio desta infra

---
*Phase: 00-bloqueadores-críticos*
*Completed: 2026-04-06*
