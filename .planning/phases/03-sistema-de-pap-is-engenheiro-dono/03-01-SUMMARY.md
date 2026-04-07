---
phase: 3
plan: "03-01"
subsystem: backend-auth
tags: [permissions, roles, security, fastapi]
dependency_graph:
  requires: []
  provides: [role-enforcement-backend, require_engineer-dependency, permission-matrix-tests]
  affects: [all-13-routers, auth.py]
tech_stack:
  added: []
  patterns: [require_engineer FastAPI dependency, ENGINEER_ROLES constant, role-based access control]
key_files:
  created:
    - server/tests/test_permissions_matrix.py
  modified:
    - server/app/auth.py
    - server/app/models.py
    - server/app/routers/obras.py
    - server/app/routers/etapas.py
    - server/app/routers/financeiro.py
    - server/app/routers/documentos.py
    - server/app/routers/checklist.py
    - server/app/routers/normas.py
    - server/app/routers/prestadores.py
    - server/app/routers/checklist_inteligente.py
    - server/app/routers/cronograma.py
    - server/app/routers/convites.py
    - server/app/routers/visual_ai.py
decisions:
  - require_engineer como FastAPI Dependency (Depends) — integra naturalmente no ciclo de vida do router sem decoradores extras
  - ENGINEER_ROLES = {owner, admin} — dono_da_obra e convidado bloqueados de escrita por padrao
  - dono_da_obra role adicionado como string no comentario do modelo — sem nova migration (campo ja e string livre)
  - Removida verificacao inline duplicada em criar_prestador e migrar_riscos — consolidada em require_engineer
metrics:
  duration: "8 min"
  completed_date: "2026-04-07"
  tasks_completed: 2
  files_modified: 14
requirements_completed: [ROLE-01, ROLE-02, ROLE-03, ROLE-05, ROLE-06]
---

# Phase 3 Plan 01: Enforce Role-Based Permissions on All Routers Summary

Implementacao de autorizacao por papel (engenheiro vs dono_da_obra) em todos os 13 routers protegidos, via `require_engineer` FastAPI dependency com cobertura de 118 testes unitarios.

## What Was Built

### Task 1: require_engineer e aplicacao nos routers

Adicionado em `server/app/auth.py`:
- `ENGINEER_ROLES = {"owner", "admin"}` — papeis com permissao plena de escrita
- `DONO_DA_OBRA_ROLE = "dono_da_obra"` — papel do dono de obra (somente leitura)
- `require_engineer(current_user: User = Depends(get_current_user)) -> User` — FastAPI dependency que bloqueia `dono_da_obra` e `convidado` com HTTP 403
- `require_role(allowed_roles)` — helper configuravel para casos futuros

Substituicao de `Depends(get_current_user)` por `Depends(require_engineer)` em 33 endpoints de escrita distribuidos em 11 routers:

| Router | Endpoints protegidos |
|--------|---------------------|
| obras | POST /, DELETE /{id} |
| etapas | GET score, PATCH status, PATCH prazo, POST sugerir-grupo |
| financeiro | POST orcamento, POST despesas, PUT alertas, POST/DELETE device-tokens |
| documentos | POST projetos, DELETE projeto, POST analisar, POST aplicar-riscos |
| checklist | DELETE item |
| normas | POST buscar |
| prestadores | POST /, PATCH /{id}, POST avaliacoes |
| checklist_inteligente | GET stream, POST iniciar, POST aplicar, POST migrar, POST geracao-unificada/iniciar |
| cronograma | POST identificar, POST gerar, PATCH atividade, POST vincular, POST checklist, POST despesas |
| convites | POST convites, DELETE convite |
| visual_ai | POST analise-visual |

### Task 2: Testes de matriz papel x operacao

Criado `server/tests/test_permissions_matrix.py` com 118 testes:
- `TestRoleConstants`: valida constantes de role (5 testes)
- `TestRequireEngineerRole`: owner/admin permitidos, dono_da_obra/convidado bloqueados com 403 (6 testes)
- `TestRolePermissionsMatrix`: 33 dominios x 3 papeis = 99 combinacoes parametrizadas
- `TestRequireRoleConfiguravel`: require_role() aceita subconjuntos customizados (5 testes)
- `TestDataIsolation`: _verify_obra_ownership garante isolamento correto (3 testes)

## Decisions Made

- **require_engineer como FastAPI Depends**: integracao idiomatica com o framework — a dependencia e avaliada antes do corpo do endpoint, sem codigo adicional nos handlers.
- **ENGINEER_ROLES = {owner, admin}**: admin existe para operacoes de plataforma; owner e o papel padrao do engenheiro que cria obras.
- **dono_da_obra sem migration**: o campo `User.role` ja e `str` livre — apenas documentado no comentario do model. Uma migration sera adicionada quando houver regra de negocio que requeira validacao no banco.
- **Removidas verificacoes inline duplicadas**: `criar_prestador` tinha `if current_user.role not in ("owner", "admin")` inline; `migrar_riscos_para_checklist` idem. Ambas removidas — consolidadas em `require_engineer`.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Remocao de verificacao inline duplicada em criar_prestador**
- **Found during:** Task 1
- **Issue:** `prestadores.py:criar_prestador` tinha verificacao de role inline `if current_user.role not in ("owner", "admin")` que seria redundante apos require_engineer
- **Fix:** Removida verificacao duplicada; require_engineer ja garante a mesma restricao
- **Files modified:** server/app/routers/prestadores.py
- **Commit:** 699b3c4

**2. [Rule 1 - Bug] Remocao de verificacao inline em migrar_riscos_para_checklist**
- **Found during:** Task 1
- **Issue:** `checklist_inteligente.py:migrar_riscos` tinha verificacao inline identica
- **Fix:** Removida; require_engineer cobre o caso
- **Files modified:** server/app/routers/checklist_inteligente.py
- **Commit:** 699b3c4

## Commits

| Hash | Type | Description |
|------|------|-------------|
| 699b3c4 | feat | implementar require_engineer e aplicar em 13 routers |
| e44560d | test | cobertura de matriz de permissoes papel x operacao |

## Verification

```
pytest tests/ -k "role or permissions or matrix"
118 passed, 118 deselected in 0.66s
```

## Self-Check: PASSED
