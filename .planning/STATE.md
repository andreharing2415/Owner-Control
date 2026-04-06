---
gsd_state_version: 1.0
milestone: v1.0
milestone_name: milestone
status: Ready to plan
last_updated: "2026-04-06T23:18:45.286Z"
progress:
  total_phases: 6
  completed_phases: 1
  total_plans: 20
  completed_plans: 3
---

# Project State

## Current Status

**Active Phase:** 00 — Bloqueadores Críticos
**Started:** 2026-04-06
**Plans:** 3 total, 3 incomplete

## Current Position

Phase 00 — All plans complete. Phase 00 done.

## Phase Progress

- [x] 00-01: Corrigir cadeia Alembic + Cloud Run min-instances
- [x] 00-02: Substituir python-jose por PyJWT + corrigir cancelamento Stripe
- [x] 00-03: Substituir fpdf2 por WeasyPrint+Jinja2

## Decisions

- [00-01] Migração duplicada 0014 fundida como 0014 (checklist_unificado) + 0014b (add_valor_realizado) para preservar histórico
- [00-01] IDs curtos 0023/0024 normalizados para formato longo YYYYMMDD_NNNN
- [00-01] min-instances=1 via flag --min-instances no gcloud run deploy
- [00-02] PyJWT 2.8.0 substitui python-jose — mesmos HS256/claims/contratos HTTP, exceto jwt.PyJWTError
- [00-02] cancel_subscription usa status cancel_pending — plano pago inalterado até webhook deleted
- [00-02] Downgrade para gratuito centralizado no evento customer.subscription.deleted
- [00-02] Testes replicam lógica inline (sem importar router) para evitar dependência de DATABASE_URL
- [00-03] WeasyPrint+Jinja2 substitui fpdf2 — elimina _safe()/latin1 que corrompia acentuação PT-BR
- [00-03] Dockerfile atualizado com libpango/libcairo/libgdk-pixbuf2 para WeasyPrint em python:3.11-slim
- [00-03] Testes PDF com pytestmark.skipif (OSError) — executam em Docker Linux, skipados em Windows

## Notes

Phase 00 is a prerequisite for all feature work. No STATE.md existed at start — created fresh.
