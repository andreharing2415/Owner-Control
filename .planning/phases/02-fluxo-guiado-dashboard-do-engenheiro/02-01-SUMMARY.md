---
phase: 2
plan: "02-01"
subsystem: navigation
tags: [onboarding, wizard, auto-redirect, ux]
dependency_graph:
  requires: []
  provides: [zero-obras-redirect, post-processing-navigation]
  affects: [main_shell, home_screen, obras_screen, document_analysis_screen]
tech_stack:
  added: []
  patterns: [Flutter Notification bubble-up, guard flag redirect]
key_files:
  created: []
  modified:
    - lib/screens/obras_screen.dart
    - lib/screens/home_screen.dart
    - lib/screens/main_shell.dart
    - lib/screens/document_analysis_screen.dart
    - lib/screens/documents_screen.dart
decisions:
  - "ObraTabNotification (Flutter Notification) desacopla HomeScreen de MainShell para mudanca de aba"
  - "_redirectedToCreate guard evita loop de redirect quando usuario cancela wizard sem criar obra"
  - "DocumentAnalysisScreen aceita Obra opcional — retrocompativel sem quebrar chamadas existentes"
  - "pushReplacement em _navigateToResultado para nao empilhar DocumentAnalysisScreen na stack"
metrics:
  duration: "15min"
  completed: "2026-04-06"
  tasks: 2
  files: 5
requirements:
  - FLOW-01
  - FLOW-02
  - FLOW-03
  - FLOW-05
---

# Phase 2 Plan 01: Wizard Guiado e Redirects Automáticos

**One-liner:** Zero-obras auto-redirect para CriarObraWizard + navegação automática para cronograma após geração IA concluir.

## What Was Built

Fluxo linear guiado do login ao resultado:

1. **Zero-obras redirect (FLOW-01, FLOW-02):** `ObrasScreen` detecta lista vazia na primeira carga e auto-push `CriarObraWizard`. Guard `_redirectedToCreate` evita loop se usuário cancelar. Após criação bem-sucedida, lista recarrega.

2. **Home CTA guiado (FLOW-03):** `_SemObrasView` em `HomeScreen` exibe botão "Criar primeira obra" que dispara `ObraTabNotification`, capturada por `MainShell` via `NotificationListener` para trocar para aba Obras automaticamente — sem acoplar `HomeScreen` ao `MainShell`.

3. **Navegação pós-processamento (FLOW-05):** `DocumentAnalysisScreen` aceita parâmetro opcional `Obra`. Quando o polling de geração unificada detecta status `concluido`, `_navigateToResultado` navega automaticamente para `CronogramaScreen` (obra do tipo construcao) ou `EtapasScreen` (reforma) via `pushReplacement`.

4. **Wiring em DocumentsScreen:** `documents_screen.dart` passa `_obraSelecionada` ao abrir `DocumentAnalysisScreen`, habilitando a navegação automática pós-processamento.

## Tasks Completed

| Task | Description | Commit | Files |
|------|-------------|--------|-------|
| 1 | Zero-obras redirect + Home CTA | fd7f5b2 | obras_screen, home_screen, main_shell |
| 2 | Navegação pós-processamento | 431d343 | document_analysis_screen, documents_screen |

## Decisions Made

| Decision | Rationale |
|----------|-----------|
| Flutter Notification para ObraTabNotification | Desacoplamento — HomeScreen não precisa importar MainShell |
| _redirectedToCreate guard flag | Evita loop quando usuário cancela wizard; reseta após criação bem-sucedida |
| Obra? opcional em DocumentAnalysisScreen | Retrocompatibilidade — não quebra chamadas sem Obra no wizard nem em outros contextos |
| pushReplacement em _navigateToResultado | Resultado substitui DocumentAnalysisScreen na stack; back button vai para documents_screen |

## Deviations from Plan

None - plan executed exactly as written.

## Known Stubs

None — todos os fluxos estão conectados a dados reais.

## Self-Check: PASSED
