---
phase: 05-moderniza-o-arquitetural
plan: "05-02"
subsystem: ui
tags: [go_router, deep-link, fcm, navigation]
requires:
  - phase: 03-sistema-de-pap-is-engenheiro-dono
    provides: estrutura de shell por role e guards base
provides:
  - rotas nomeadas centrais no go_router
  - deep link por push integrado ao roteador
  - abertura de rota por notificacao em app aberto/background/cold start
affects: [navigation, notifications, owner-flow]
tech-stack:
  added: []
  patterns: [named-routes, push-to-route-mapping]
key-files:
  created: []
  modified:
    - lib/routes/app_router.dart
    - lib/services/notification_service.dart
    - lib/main.dart
key-decisions:
  - "Mapear payload de notificacao por campos route/type para rota nomeada"
  - "Conectar NotificationService ao AppRouter via callback para evitar dependencia circular"
patterns-established:
  - "Toda rota principal deve ter nome estavel em AppRouteNames"
  - "Push sempre resolve destino via openFromNotificationPayload"
requirements-completed: [OWNER-02]
duration: 3min
completed: 2026-04-07
---

# Phase 5 Plan 05-02: GoRouter Deep Link Summary

**Navegacao centralizada por rotas nomeadas com deep link de notificacao abrindo destino correto em qualquer estado do app**

## Performance

- **Duration:** 3 min
- **Started:** 2026-04-07T01:41:30Z
- **Completed:** 2026-04-07T01:44:11Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments
- Mapa de rotas nomeadas consolidado em `AppRouteNames`.
- Conversao de payload de push em destino de rota com fallback por role.
- Integracao de abertura por notificação em `onMessageOpenedApp` e `getInitialMessage`.

## Task Commits

1. **Task 1: Consolidar mapa de rotas nomeadas** - `07181aa` (feat)
2. **Task 2: Integrar deep link de push no fluxo de navegacao** - `cf13b64` (feat)

## Files Created/Modified
- `lib/routes/app_router.dart` - rotas nomeadas, guard unificado e resolvedor de payload.
- `lib/services/notification_service.dart` - callback de deep link, suporte cold start e payload local.
- `lib/main.dart` - registro do handler de deep link no bootstrap do app.

## Decisions Made
- Resolver destino por `route` explícita quando enviada; caso contrário, inferir por `type`.
- Preservar coerência por role no deep link (owner vs engenheiro/admin).

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None.

## User Setup Required
None - no external service configuration required.

## Known Stubs
None identified in files altered by this plan.

## Next Phase Readiness
- Base de roteamento pronta para evoluir com destinos adicionais por payload.
- App preparado para fase de modularização e evolução de assinatura.

## Self-Check: PASSED
- Summary criado em `.planning/phases/05-moderniza-o-arquitetural/05-02-SUMMARY.md`.
- Commits `07181aa` e `cf13b64` confirmados no histórico.

---
*Phase: 05-moderniza-o-arquitetural*
*Completed: 2026-04-07*
