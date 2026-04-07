---
phase: 02-fluxo-guiado-dashboard-do-engenheiro
verified: 2026-04-06T22:30:00Z
status: human_needed
score: 6/6 must-haves verified
re_verification:
  previous_status: gaps_found
  previous_score: 4/6
  gaps_closed:
    - "troca de obra preserva estado (cache Map<String, _DashboardData> por obraId restaurado em home_screen.dart)"
    - "camada de seam desacopla telas do ApiClient direto (obra_service.dart + auth_api_service.dart criados; AuthProvider e HomeScreen migrados)"
  gaps_remaining: []
  regressions: []
human_verification:
  - test: "Testar fluxo zero-obras no dispositivo"
    expected: "Login sem obras redireciona imediatamente para CriarObraWizard sem tela em branco"
    why_human: "Comportamento de navegacao apos FutureBuilder retornar lista vazia nao e verificavel estaticamente"
  - test: "Testar fluxo pos-processamento"
    expected: "Apos polling detectar status 'concluido', app navega automaticamente para CronogramaScreen ou EtapasScreen"
    why_human: "Requer processar documento de verdade via IA; polling e Timer nao simulaveis sem infraestrutura"
---

# Phase 2: Fluxo Guiado + Dashboard do Engenheiro — Verification Report

**Phase Goal:** Fluxo guiado (onboarding wizard com redirects automaticos) + dashboard multi-obra com KPIs, alertas e seam layer para futura migracao de state management.
**Verified:** 2026-04-06T22:30:00Z
**Status:** human_needed
**Re-verification:** Yes — after recovery of orphaned commits

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|---------|
| 1 | Usuario sem obra entra no wizard sem tela vazia | VERIFIED | obras_screen.dart L123-129: lista vazia dispara `Navigator.push(CriarObraWizard)` com guard `_redirectedToCreate` |
| 2 | Navegacao automatica leva ao proximo passo (criacao -> upload) | VERIFIED | criar_obra_wizard.dart: `_goToPage(2)` apos criar obra leva para StepDocumentos embutido no wizard |
| 3 | Apos processamento, app navega automaticamente para resultado | VERIFIED | document_analysis_screen.dart L79-91: polling detecta `status == 'concluido'` e chama `_navigateToResultado(widget.obra!)` via pushReplacement |
| 4 | Dashboard exibe KPIs consolidados (progresso %, financeiro, alertas) | VERIFIED | home_screen.dart: `_ObraCard` com progressoPercent, `_KpiRow`, `_AlertaFinanceiro` com `relatorio.alerta`; dados de `listarEtapas` + `relatorioFinanceiro` via `Future.wait` |
| 5 | Troca entre obras e instantanea (state preserved, no full reload) | VERIFIED | home_screen.dart L69: `Map<String, _DashboardData> _dashCache`; L100-112: `_selecionarObra` retorna `Future.value(cached)` quando obraId ja esta no cache; L195: `DashboardSkeleton` mostrado apenas no primeiro carregamento |
| 6 | Seam layer desacopla telas do ApiClient direto | VERIFIED | `lib/services/obra_service.dart` (ObraService + ApiObraService, 70 linhas); `lib/services/auth_api_service.dart` (AuthApiService + ApiAuthService, 53 linhas); `home_screen.dart` L52-53: `ObraService? obraService` no construtor, L63-77: `_obras = widget._obraService ?? ApiObraService()`; `auth_provider.dart` L16-17: `AuthApiService? authApiService` no construtor, L59/78: `_authApi.login`/`_authApi.register` — ApiClient nunca instanciado diretamente |

**Score:** 6/6 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `lib/screens/obras_screen.dart` | Zero-obras redirect para wizard | VERIFIED | L123-129: redirect com guard flag `_redirectedToCreate` |
| `lib/screens/home_screen.dart` | Dashboard multi-obra com KPIs + cache | VERIFIED | KPIs, alertas, ObraSelector e `_dashCache` por obraId presentes; `DashboardSkeleton` usado em L195, 264 |
| `lib/screens/document_analysis_screen.dart` | Auto-nav para resultado | VERIFIED | L70-91: `_pollStatus` + `_navigateToResultado` implementados |
| `lib/screens/main_shell.dart` | NotificationListener para ObraTabNotification | VERIFIED | L62: `NotificationListener<ObraTabNotification>` captura notificacao e muda aba |
| `lib/widgets/skeleton_loader.dart` | SkeletonBox, ObraCardSkeleton, KpiRowSkeleton, DashboardSkeleton | VERIFIED | 180 linhas; todos os 4 widgets presentes com animacao; importado e usado em home_screen.dart e test/ |
| `lib/services/obra_service.dart` | ObraService + ApiObraService | VERIFIED | 70 linhas; interface abstrata + implementacao concreta delegando para ApiClient |
| `lib/services/auth_api_service.dart` | AuthApiService + ApiAuthService | VERIFIED | 53 linhas; interface abstrata + implementacao concreta delegando para ApiClient |
| `lib/providers/auth_provider.dart` | Parametro AuthApiService injetado | VERIFIED | L16-17: construtor recebe `AuthApiService?`; L59, 78: usa `_authApi` em vez de `ApiClient()` direto |
| `test/home_screen_test.dart` | 15 casos de teste | VERIFIED | 249 linhas; 15 casos cobrindo SkeletonBox, ObraCardSkeleton, KpiRowSkeleton, _DashboardData, cache Map por obraId |

### Key Link Verification

| From | To | Via | Status | Details |
|------|-----|-----|--------|---------|
| ObrasScreen (lista vazia) | CriarObraWizard | Navigator.push + _redirectedToCreate | WIRED | obras_screen.dart L123-129 |
| HomeScreen (_SemObrasView) | Aba Obras | ObraTabNotification.dispatch -> MainShell NotificationListener | WIRED | home_screen.dart (dispatch), main_shell.dart L62 (listener) |
| CriarObraWizard (apos criar) | StepDocumentos (upload) | _goToPage(2) | WIRED | criar_obra_wizard.dart |
| DocumentAnalysisScreen (polling concluido) | CronogramaScreen ou EtapasScreen | _navigateToResultado via pushReplacement | WIRED | document_analysis_screen.dart L79-91 |
| HomeScreen (_selecionarObra) | cache por obraId | Map<String, _DashboardData> _dashCache | WIRED | home_screen.dart L69, L104-107: lookup; L127: store |
| HomeScreen | ObraService | parametro opcional widget._obraService | WIRED | home_screen.dart L52-53, L77 |
| AuthProvider | AuthApiService | parametro construtor opcional | WIRED | auth_provider.dart L16-17, L59, L78 |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|--------------|--------|-------------------|--------|
| `home_screen.dart` _ObraCard | `data.progressoPercent` | listarEtapas via ObraService -> etapasConcluidas / totalEtapas | Yes — real DB query via API | FLOWING |
| `home_screen.dart` _KpiRow | `data.relatorio` | relatorioFinanceiro(obra.id) via ObraService | Yes — real API endpoint | FLOWING |
| `home_screen.dart` _ObraSelector | `obras` (List<Obra>) | listarObras() via ObraService | Yes — real API | FLOWING |
| `home_screen.dart` _dashCache | `Map<String, _DashboardData>` | preenchido por _carregarDashboard L127; retornado via Future.value em L107 | Yes — populado de dados reais, nao hardcoded | FLOWING |

### Behavioral Spot-Checks

Step 7b: SKIPPED — requer emulador/dispositivo Android para verificar navegacao e polling. Verificacao estatica do codigo e suficiente para os gaps originais; comportamento em runtime delegado para verificacao humana abaixo.

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|---------|
| FLOW-01 | 02-01 | Usuario sem obras redirecionado para wizard | SATISFIED | obras_screen.dart L123-129 |
| FLOW-02 | 02-01 | Apos criar obra, navega para upload | SATISFIED | criar_obra_wizard.dart: goToPage(2) = StepDocumentos |
| FLOW-03 | 02-01 | Apos processar, navega para resultado | SATISFIED | document_analysis_screen.dart L79-91 |
| FLOW-04 | 02-02 | Status de processamento visivel em tempo real | SATISFIED | document_analysis_screen.dart: `_geracaoLog` renderizado com status/progresso; polling a cada 2s |
| FLOW-05 | 02-01, 02-03 | Estrutura de navegacao clara + seam layer | SATISFIED | Wizard e redirects implementados; seam layer aplicado em home_screen.dart e auth_provider.dart via ObraService e AuthApiService |
| DASH-01 | 02-02 | Dashboard consolidado de obras | SATISFIED | home_screen.dart: FutureBuilder<List<Obra>> com _ObraCard por obra selecionada, ObraSelector para multiplas obras |
| DASH-02 | 02-02 | Dashboard mostra %, financeiro, alertas | SATISFIED | _ObraCard (progressoPercent), _KpiRow (financeiro), _AlertaFinanceiro (relatorio.alerta) |
| DASH-03 | 02-02 | Alternar obras sem perder contexto | SATISFIED | ObraSelector + _dashCache por obraId; DashboardSkeleton apenas no primeiro carregamento por obra |

### Anti-Patterns Found

Nenhum anti-pattern bloqueador encontrado. As instanciacoes diretas de `ApiClient()` em `auth_provider.dart` e `home_screen.dart` que existiam na verificacao anterior foram eliminadas. Os arquivos de seam agora encapsulam corretamente a dependencia.

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| — | — | — | — | Nenhum |

### Human Verification Required

#### 1. Zero-obras redirect no dispositivo

**Test:** Fazer login com conta sem obras criadas
**Expected:** App redireciona automaticamente para CriarObraWizard sem mostrar dashboard vazio
**Why human:** Comportamento condicional de FutureBuilder + addPostFrameCallback; requer execucao real no device

#### 2. Fluxo pos-processamento automatico

**Test:** Subir documento, aguardar geracao IA concluir (polling 2s)
**Expected:** Apos status `concluido`, app navega automaticamente para CronogramaScreen (construcao) ou EtapasScreen (reforma)
**Why human:** Requer processamento real por IA no backend; nao simulavel estaticamente

## Re-verification Summary

Os dois gaps da verificacao anterior foram fechados com sucesso:

**Gap 1 fechado — Cache por obraId (DASH-03):** `lib/widgets/skeleton_loader.dart` existe com 180 linhas contendo `SkeletonBox`, `ObraCardSkeleton`, `KpiRowSkeleton` e `DashboardSkeleton`. `home_screen.dart` tem `_dashCache = Map<String, _DashboardData>()` declarado em L69, populado em L127 apos cada carregamento, e consultado em L104-107 antes de disparar nova requisicao. `test/home_screen_test.dart` tem 249 linhas com 15 casos de teste incluindo cobertura do cache.

**Gap 2 fechado — Seam layer (FLOW-05):** `lib/services/obra_service.dart` (70 linhas) e `lib/services/auth_api_service.dart` (53 linhas) existem com interfaces abstratas e implementacoes concretas. `HomeScreen` aceita `ObraService?` no construtor e usa `_obras` em todos os lugares onde antes era `_api = ApiClient()`. `AuthProvider` aceita `AuthApiService?` no construtor e usa `_authApi.login`/`_authApi.register` sem nenhuma instanciacao de `ApiClient` direta.

**Nenhuma regressao detectada:** Todos os 4 truths que passaram na verificacao anterior (FLOW-01, FLOW-02, FLOW-03, DASH-01/02) continuam verificados.

---

_Verified: 2026-04-06T22:30:00Z_
_Verifier: Claude (gsd-verifier)_
