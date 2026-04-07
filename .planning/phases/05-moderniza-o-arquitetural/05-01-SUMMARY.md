---
phase: 05-moderniza-o-arquitetural
plan: "05-01"
subsystem: ui
tags: [flutter, riverpod, provider, state-management]
requires:
  - phase: 03-sistema-de-pap-is-engenheiro-dono
    provides: shell e fluxos por role usados no rollout incremental
provides:
  - providers Riverpod por dominio para auth, assinatura e obra
  - telas principais migradas para consumo via Riverpod
  - remocao parcial de instancia direta de ApiClient nas telas-alvo
affects: [auth, dashboard, owner-progress, navegacao]
tech-stack:
  added: [flutter_riverpod]
  patterns: [provider-bridge, domain-seam-services, incremental-rollout]
key-files:
  created:
    - lib/providers/riverpod_providers.dart
    - lib/services/owner_progress_service.dart
  modified:
    - lib/main.dart
    - lib/providers/auth_provider.dart
    - lib/screens/auth_gate.dart
    - lib/screens/login_screen.dart
    - lib/screens/register_screen.dart
    - lib/screens/complete_profile_screen.dart
    - lib/screens/settings_screen.dart
    - lib/screens/minha_conta_screen.dart
    - lib/screens/obras_screen.dart
    - lib/screens/owner_progresso_screen.dart
    - lib/services/auth_api_service.dart
    - lib/services/obra_service.dart
    - test/widget_test.dart
key-decisions:
  - "Manter Provider legado como bridge no MaterialApp enquanto Riverpod assume criacao dos notifiers"
  - "Migrar primeiro o fluxo principal (auth/settings/obras/owner progresso) para reduzir risco de regressao"
  - "Extrair seams de servico por dominio para remover acoplamento direto de telas ao ApiClient"
patterns-established:
  - "Providers Riverpod em arquivo unico por dominio para rollout incremental"
  - "Telas principais como ConsumerStatefulWidget/ConsumerWidget quando consomem estado global"
requirements-completed: [FLOW-05, DASH-03]
duration: 17min
completed: 2026-04-07
---

# Phase 5 Plan 05-01: Riverpod Incremental Summary

**Fluxo principal do app migrado para Riverpod com bridge de compatibilidade, reduzindo acoplamento direto ao ApiClient em dominios criticos**

## Performance

- **Duration:** 17 min
- **Started:** 2026-04-07T01:24:00Z
- **Completed:** 2026-04-07T01:41:25Z
- **Tasks:** 2
- **Files modified:** 17

## Accomplishments
- Estrutura Riverpod por dominio criada e integrada ao bootstrap da aplicacao.
- Fluxos principais (auth, onboarding, configuracoes, obras, progresso do dono) migrados para consumo de providers Riverpod.
- Seams de servico ampliados para reduzir instancia direta de ApiClient nas telas-alvo.

## Task Commits

1. **Task 1: Definir estrategia de migracao por dominio** - `b1d8638` (feat)
2. **Task 2: Migrar telas do fluxo principal para novos providers** - `1d7e3bf` (feat)

## Files Created/Modified
- `lib/providers/riverpod_providers.dart` - providers Riverpod por dominio e bridge incremental.
- `lib/services/owner_progress_service.dart` - contrato/implementacao para dados de progresso do dono.
- `lib/main.dart` - inicializacao com ProviderScope + bridge para ChangeNotifierProvider legado.
- `lib/screens/auth_gate.dart` - consumo de auth/subscription via Riverpod.
- `lib/screens/login_screen.dart` - login e biometria via provider Riverpod.
- `lib/screens/register_screen.dart` - cadastro via provider Riverpod.
- `lib/screens/complete_profile_screen.dart` - onboarding de perfil via provider Riverpod.
- `lib/screens/settings_screen.dart` - configuracoes e biometria via provider Riverpod.
- `lib/screens/minha_conta_screen.dart` - dados de conta via provider Riverpod.
- `lib/screens/obras_screen.dart` - listagem e exclusao por ObraService em provider Riverpod.
- `lib/screens/owner_progresso_screen.dart` - carregamento por OwnerProgressService com provider Riverpod.
- `lib/services/auth_api_service.dart` - suporte a login Google e updateProfile no seam.
- `lib/services/obra_service.dart` - suporte a deletarObra no seam.
- `test/widget_test.dart` - smoke test com ProviderScope.

## Decisions Made
- Bridge Provider+Riverpod adotada para migracao segura sem reescrever todo o app em um unico plano.
- Primeira onda focada em telas de maior uso para maximizar impacto e minimizar risco.
- Preferencia por seams de servico para manter testabilidade e facilitar fases seguintes.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Tipo inexistente no novo service do owner progress**
- **Found during:** Task 2
- **Issue:** uso de `ItemChecklist` causava erro de compilacao.
- **Fix:** substituido por `ChecklistItem` conforme modelo existente em `lib/api/api.dart`.
- **Files modified:** `lib/services/owner_progress_service.dart`
- **Verification:** `flutter test test/home_screen_test.dart test/widget_test.dart` passou.
- **Committed in:** `1d7e3bf` (parte do commit da Task 2)

**2. [Rule 1 - Bug] Smoke test quebrado apos introduzir ConsumerWidget na raiz**
- **Found during:** Task 2
- **Issue:** `MestreDaObraApp` passou a exigir `ProviderScope` e o teste antigo falhava.
- **Fix:** ajuste do teste para montar `ProviderScope(child: MestreDaObraApp())`.
- **Files modified:** `test/widget_test.dart`
- **Verification:** `flutter test test/home_screen_test.dart test/widget_test.dart` passou.
- **Committed in:** `1d7e3bf` (parte do commit da Task 2)

---

**Total deviations:** 2 auto-fixed (1 blocking, 1 bug)
**Impact on plan:** correcoes necessarias para compilacao/validacao sem expandir escopo funcional.

## Issues Encountered
- Suite completa `flutter test` possui timeouts preexistentes em `test/api_client_test.dart`; validacao focada foi executada nos testes de smoke/home do fluxo principal migrado.

## User Setup Required
None - no external service configuration required.

## Known Stubs
None identified in files altered by this plan.

## Next Phase Readiness
- Base de state management moderno pronta para expandir migracao nos proximos planos da fase 05.
- Fluxos principais ja operando com providers Riverpod e compatibilidade preservada.

## Self-Check: PASSED
- Summary criado em `.planning/phases/05-moderniza-o-arquitetural/05-01-SUMMARY.md`.
- Commits `b1d8638` e `1d7e3bf` localizados no historico.

---
*Phase: 05-moderniza-o-arquitetural*
*Completed: 2026-04-07*
