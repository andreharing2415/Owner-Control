---
status: in_progress
current_phase: "00"
current_phase_name: "Bloqueadores Críticos"
last_updated: "2026-04-06"
---

# Project State

## Current Status
**Active Phase:** 00 — Bloqueadores Críticos
**Started:** 2026-04-06
**Plans:** 3 total, 3 incomplete

## Current Position
Phase 00 — Wave 1: 00-01 and 00-02 complete. 00-03 pending.

## Phase Progress
- [x] 00-01: Corrigir cadeia Alembic + Cloud Run min-instances
- [x] 00-02: Substituir python-jose por PyJWT + corrigir cancelamento Stripe
- [ ] 00-03: Substituir fpdf2 por WeasyPrint+Jinja2

## Decisions
- [00-01] Migração duplicada 0014 fundida como 0014 (checklist_unificado) + 0014b (add_valor_realizado) para preservar histórico
- [00-01] IDs curtos 0023/0024 normalizados para formato longo YYYYMMDD_NNNN
- [00-01] min-instances=1 via flag --min-instances no gcloud run deploy
- [00-02] PyJWT 2.8.0 substitui python-jose — mesmos HS256/claims/contratos HTTP, exceto jwt.PyJWTError
- [00-02] cancel_subscription usa status cancel_pending — plano pago inalterado até webhook deleted
- [00-02] Downgrade para gratuito centralizado no evento customer.subscription.deleted
- [00-02] Testes replicam lógica inline (sem importar router) para evitar dependência de DATABASE_URL

## Notes
Phase 00 is a prerequisite for all feature work. No STATE.md existed at start — created fresh.
