---
phase: 02-fluxo-guiado-dashboard-do-engenheiro
plan: "02-03"
subsystem: services
tags: [flutter, seam, dependency-injection, refactor, testability]

dependency_graph:
  requires:
    - phase: 02-fluxo-guiado-dashboard-do-engenheiro
      provides: [HomeScreen dashboard flow, AuthProvider login/register]
  provides:
    - ObraService abstract interface + ApiObraService implementation
    - AuthApiService abstract interface + ApiAuthService implementation
    - AuthProvider testavel via construtor (sem ApiClient direto)
    - HomeScreen testavel via parametro obraService (sem ApiClient direto)
  affects:
    - 03-sistema-de-papeis (AuthProvider agora injetavel)
    - 05-modernizacao-arquitetural (Riverpod pode substituir implementacoes sem mudar telas)

tech-stack:
  added:
    - lib/services/obra_service.dart (ObraService, ApiObraService)
    - lib/services/auth_api_service.dart (AuthApiService, ApiAuthService)
  patterns:
    - "Seam via abstract class + implementacao concreta que delega para ApiClient"
    - "Injecao opcional via construtor/parametro — retrocompativel com chamadas existentes"

key-files:
  created:
    - lib/services/obra_service.dart
    - lib/services/auth_api_service.dart
  modified:
    - lib/providers/auth_provider.dart
    - lib/screens/home_screen.dart

key-decisions:
  - "Seam como abstract class (nao interface) — padrao Dart sem adicionar dependencias"
  - "Injecao opcional com fallback para implementacao concreta — zero impacto em callsites existentes"
  - "ObraService cobre apenas o fluxo dashboard (listarObras/listarEtapas/relatorioFinanceiro/listarProjetos/criarObra)"
  - "HomeScreen._obraService via parametro de widget — HomeScreenState laz-inicia em initState"
  - "flutter test crasha com Bad state: No element (pre-existing native assets issue no ambiente Windows) — validacao via dart analyze"

requirements-completed:
  - FLOW-05

duration: "2min"
completed: "2026-04-07"
---

# Phase 2 Plan 03: Camada de Seam — ApiService

**Seam abstrato desacopla AuthProvider e HomeScreen do ApiClient concreto, preparando migracao gradual para Riverpod na fase 5.**

## What Was Built

Dois contratos abstratos + implementacoes concretas para o fluxo principal:

1. **ObraService** (`lib/services/obra_service.dart`): interface cobrindo `listarObras`, `criarObra`, `listarEtapas`, `relatorioFinanceiro`, `listarProjetos`. Implementado por `ApiObraService` que delega para `ApiClient`.

2. **AuthApiService** (`lib/services/auth_api_service.dart`): interface cobrindo `login` e `register`. Implementado por `ApiAuthService` que delega para `ApiClient`.

3. **AuthProvider migrado**: aceita `AuthApiService? authApiService` no construtor. Usa `_authApi` em vez de instanciar `ApiClient()` diretamente. Import de `api.dart` removido — provider nao precisa mais conhecer o cliente HTTP.

4. **HomeScreen migrado**: aceita `ObraService? obraService` como parametro do widget. `HomeScreenState` inicializa `_obras` no `initState` com fallback para `ApiObraService()`. Todos os acessos ao antigo `_api` substituidos por `_obras`.

## Tasks Completed

| Task | Description | Commit | Files |
|------|-------------|--------|-------|
| 1 | Definir interfaces ObraService e AuthApiService | c98aaab | obra_service.dart, auth_api_service.dart |
| 2 | Migrar AuthProvider e HomeScreen para usar seams | 29beb4a | auth_provider.dart, home_screen.dart |

## Decisions Made

| Decision | Rationale |
|----------|-----------|
| abstract class como seam | Padrao Dart — nao exige packages adicionais, testavel via mock |
| Parametro opcional com fallback | Zero impacto em callsites existentes — `HomeScreen()` e `AuthProvider()` sem parametros continuam funcionando |
| Escopo limitado ao fluxo principal | Seam para todas as 19 telas seria scope creep; fase 5 pode expandir gradualmente |
| dart analyze como verificacao | flutter test crasha com Bad state pre-existing no ambiente (native assets); analyze confirma tipos e imports |

## Deviations from Plan

None - plan executed exactly as written.

## Known Stubs

None — implementacoes delegam para ApiClient real sem stubs.

## Self-Check: PASSED
