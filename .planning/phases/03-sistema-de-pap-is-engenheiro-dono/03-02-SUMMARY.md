---
phase: 3
plan: "03-02"
subsystem: backend-schemas
tags: [roles, serialization, fastapi, schemas]
requirements_completed: [ROLE-04, OWNER-03]
completed_date: "2026-04-07"
---

# Phase 3 Plan 02 Summary

Implementadas projecoes de schema por papel no backend.

## Entregas

- Criado contrato de visualizacao para dono em `ChecklistItemOwnerView`, `AtividadeOwnerView` e `CronogramaOwnerView`.
- Mantido contrato tecnico completo para engenheiro com `ChecklistItemRead` e `CronogramaResponse`.
- Adicionados seletores de serializacao por papel:
  - `project_checklist_item_for_role()`
  - `project_cronograma_for_role()`
- Aplicada serializacao role-aware nos routers:
  - `server/app/routers/checklist.py`
  - `server/app/routers/cronograma.py`

## Validacao

Comando executado:

```bash
cd server
python -m pytest -q tests/test_role_views.py tests/test_permissions_matrix.py
```

Resultado: `159 passed`.

## Resultado

Dono recebe payload leigo sem campos tecnicos; engenheiro continua recebendo payload completo.
