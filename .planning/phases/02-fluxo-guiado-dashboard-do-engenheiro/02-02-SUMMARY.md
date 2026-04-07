---
phase: 02-fluxo-guiado-dashboard-do-engenheiro
plan: "02-02"
subsystem: ui
tags: [flutter, dashboard, skeleton-loader, state-management, multi-obra]

requires:
  - phase: 01-pipeline-ia-de-documentos
    provides: ProjetoDoc model and listarProjetos API used in DashboardData

provides:
  - Dashboard multi-obra com KPIs, alertas financeiros e resumo consolidado
  - SkeletonBox/ObraCardSkeleton/KpiRowSkeleton/DashboardSkeleton widgets reutilizaveis
  - Cache de DashboardData por obraId para troca sem flicker

affects:
  - 02-03 (proximo plano de dashboard pode reaproveitar skeleton widgets)
  - 03-sistema-de-papeis (HomeScreen exposta publicamente como HomeScreenState para acesso externo)

tech-stack:
  added:
    - lib/widgets/skeleton_loader.dart (SkeletonBox, ObraCardSkeleton, KpiRowSkeleton, DashboardSkeleton)
  patterns:
    - "Skeleton loader via AnimationController com SingleTickerProviderStateMixin"
    - "Cache Map<String, _DashboardData> por obraId para state preservation"
    - "_MultiObraSummaryRow detecta alertas em cache sem recarregar obras"

key-files:
  created:
    - lib/widgets/skeleton_loader.dart
    - test/home_screen_test.dart
  modified:
    - lib/screens/home_screen.dart

key-decisions:
  - "Cache por obraId em Map dentro do State — simples e eficaz sem biblioteca de state management"
  - "Skeleton via AnimationController local em vez de shimmer package — sem nova dependencia"
  - "_MultiObraSummaryRow so aparece quando ha obras com alerta no cache — evita widget vazio"
  - "_recarregar invalida apenas obraId atual do cache, preservando dados das demais obras"

patterns-established:
  - "SkeletonBox: dimensoes explicitas via width/height, borderRadius configuravel"
  - "DashboardSkeleton: composicao de ObraCardSkeleton + KpiRowSkeleton para replica fiel do layout"

requirements-completed:
  - DASH-01
  - DASH-02
  - DASH-03
  - FLOW-04

duration: 25min
completed: 2026-04-06
---

# Phase 2 Plan 02: Dashboard Multi-Obra Summary

**Dashboard multi-obra com skeleton loaders animados, cache por obraId para troca sem flicker e barra de alertas financeiros consolidada**

## Performance

- **Duration:** 25 min
- **Started:** 2026-04-06T23:52:49Z
- **Completed:** 2026-04-06T~00:20Z
- **Tasks:** 2
- **Files modified:** 3 (home_screen.dart modified, skeleton_loader.dart created, home_screen_test.dart created)

## Accomplishments

- Widget `SkeletonBox` animado com fade-in/fade-out via `AnimationController` substitui `CircularProgressIndicator` em todos os estados de loading
- Cache `Map<String, _DashboardData>` por `obraId` preserva estado ao trocar entre obras sem nova requisicao
- `_MultiObraSummaryRow` exibe barra de alerta consolidada mostrando quantas obras tem desvio orcamentario sem abrir cada uma individualmente
- `_ObraSelector` em chips horizontais permite trocar de obra com um toque, sem perder contexto da obra anterior
- 15 testes novos cobrindo widgets skeleton, modelos e logica de cache

## Task Commits

1. **Task 1: Dashboard multi-obra com KPIs e alertas** - `55217d5` (feat)
2. **Task 2: Loading progressivo e preservacao de estado** - `c1051d1` (feat)

## Files Created/Modified

- `lib/screens/home_screen.dart` - Refatorado: cache por obraId, skeleton loaders, _MultiObraSummaryRow, _ObrasLoadingSkeleton
- `lib/widgets/skeleton_loader.dart` - Novos widgets: SkeletonBox, ObraCardSkeleton, KpiRowSkeleton, DashboardSkeleton
- `test/home_screen_test.dart` - 15 testes: skeleton widgets, modelos (Obra/Etapa/RelatorioFinanceiro), logica de cache

## Decisions Made

- Cache simples em `Map<String, _DashboardData>` dentro do State — evita dependencia de provider/riverpod para este caso
- `_recarregar()` invalida apenas a obra corrente do cache (por `obraId`), preservando dados carregados das outras obras
- `_MultiObraSummaryRow` so renderiza quando ha pelo menos uma obra com `alerta=true` no cache — sem widget vazio ou placeholder
- Skeleton via `AnimationController` local (fade opacity) em vez de adicionar pacote `shimmer` ao `pubspec.yaml`

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- Test assertion `findsOneWidget` para `AnimatedBuilder` falhou porque o MaterialApp adiciona seus proprios `AnimatedBuilder` — corrigido usando `findsWidgets` (auto-fix inline).

## User Setup Required

None - no external service configuration required.

## Known Stubs

None - todos os dados vem da API real via `ApiClient`.

## Next Phase Readiness

- Dashboard multi-obra funcional com skeleton, cache e alertas
- `SkeletonBox`, `ObraCardSkeleton`, `KpiRowSkeleton`, `DashboardSkeleton` disponiveis em `lib/widgets/skeleton_loader.dart` para reutilizacao nos proximos planos
- `HomeScreenState` publico (sem underscore) para MainShell chamar `recarregarObras()`

---
*Phase: 02-fluxo-guiado-dashboard-do-engenheiro*
*Completed: 2026-04-06*
