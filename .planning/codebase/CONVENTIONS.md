# Coding Conventions

**Analysis Date:** 2026-04-06

## Naming Patterns

**Files (Dart/Flutter):**
- Screens: `snake_case_screen.dart` — e.g., `financial_screen.dart`, `detalhe_item_screen.dart`
- Providers: `snake_case_provider.dart` — e.g., `auth_provider.dart`, `subscription_provider.dart`
- Services: `snake_case_service.dart` — e.g., `auth_service.dart`, `ad_service.dart`
- Widgets: `snake_case_widget.dart` — e.g., `ad_banner_widget.dart`
- API client: `lib/api/api.dart` (single file)
- Utils: `snake_case.dart` — e.g., `auth_error_handler.dart`, `status_helper.dart`

**Files (Python/FastAPI):**
- Routers: `snake_case.py` — e.g., `obras.py`, `checklist_inteligente.py`
- Models/schemas/helpers: flat files in `server/app/`

**Classes (Dart):**
- Widgets: `PascalCase` — e.g., `HomeScreen`, `FinancialScreen`, `AuthProvider`
- Private widget state: `_PascalCaseState` — e.g., `_HomeScreenState`, `_DetalheItemScreenState`
- Private helper widgets within a file: `_PascalCase` — e.g., `_StatusButton`, `_EvidenciasGrid`, `_DashboardData`
- Data models: `PascalCase` — e.g., `Obra`, `Etapa`, `ChecklistItem`, `AtividadeCronograma`
- Enums: `PascalCase` — e.g., `AuthStatus`

**Classes (Python):**
- Models/schemas: `PascalCase` — e.g., `Obra`, `ObraCreate`, `ObraRead`, `UserRegister`
- Response schemas: `PascalCase` + `Read`/`Create`/`Response` suffix — e.g., `ObraRead`, `TokenResponse`

**Functions/Methods (Dart):**
- Public methods: `camelCase` — e.g., `listarObras()`, `calcularScore()`, `checkAuth()`
- Private methods: `_camelCase` — e.g., `_selecionarObra()`, `_onRefreshRequested()`, `_recarregarRelatorio()`
- Private fields: `_camelCase` — e.g., `_api`, `_obrasFuture`, `_obraSelecionada`

**Functions/Methods (Python):**
- Route handlers: `snake_case` — e.g., `criar_obra()`, `listar_obras()`, `registrar_orcamento()`
- Private helpers: `_snake_case` — e.g., `_verify_obra_ownership()`, `_sanitize_filename()`, `_read_template()`
- Module-level logger: `logger = logging.getLogger(__name__)` in every router/module

**Variables (Dart):**
- camelCase throughout — e.g., `obraId`, `dataInicio`, `relatorioFuture`
- JSON field keys use the API's snake_case directly in string literals: `json["obra_id"]`, `json["data_inicio"]`

**Dart Model Field Naming:**
- Model fields use camelCase (`obraId`, `dataInicio`)
- `fromJson` factory maps snake_case JSON keys to camelCase fields
- API request payloads reconstruct snake_case keys manually

## Code Style

**Formatting (Dart):**
- Tool: `dart format` (enforced by `flutter_lints` via `analysis_options.yaml`)
- Linter: `package:flutter_lints/flutter.yaml` — default recommended ruleset
- `analysis_options.yaml` keeps defaults; no custom rules enabled beyond the included set
- Double quotes preferred for string literals in `lib/api/api.dart`; single quotes elsewhere

**Formatting (Python):**
- Tool: `ruff` (version 0.3.4, listed in `requirements-dev.txt`)
- Type checker: `mypy` (version 1.9.0)
- Security linter: `bandit` (version 1.7.8)
- No `pyproject.toml` — ruff/mypy run without repo-level config file (use defaults)

## Import Organization

**Dart — Order:**
1. Dart SDK imports (`dart:convert`, `dart:async`)
2. Flutter/package imports (`package:flutter/...`, `package:provider/...`)
3. Relative imports within the project (`../api/api.dart`, `../providers/auth_provider.dart`)

**Python — Order (PEP 8 / ruff enforced):**
1. Standard library (`logging`, `os`, `datetime`, `typing`, `uuid`)
2. Third-party packages (`fastapi`, `sqlmodel`, `pydantic`)
3. Relative imports (`..db`, `..models`, `..schemas`, `..auth`, `..helpers`)

**Path Aliases:**
- Dart: none — all imports use relative paths (e.g., `../api/api.dart`)
- Python: relative imports only (`from ..models import ...`)

## Error Handling

**Dart — API layer (`lib/api/api.dart`):**
- Every API method checks `response.statusCode != 200` (or appropriate code) and throws `Exception("message")` with a human-readable Portuguese message: `throw Exception("Erro ao listar obras")`
- `AuthExpiredException` is a custom exception thrown when JWT refresh fails
- Refresh logic in `_getWithRefresh` / `_postWithRefresh` wraps every authenticated call

**Dart — Screen layer:**
- Async actions in screens follow the pattern:
  ```dart
  try {
    // await api call
    if (!mounted) return;
    // update state or navigate
  } catch (e) {
    if (e is AuthExpiredException) {
      if (mounted) handleApiError(context, e);
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
  }
  ```
- `handleApiError()` in `lib/utils/auth_error_handler.dart` is the unified handler — call it for `AuthExpiredException` (auto-logout + snackbar). For generic errors, show `formatErrorMessage(e)` in a `SnackBar`
- Always check `if (!mounted) return` before any `setState` or `context` call after an `await`

**Python — Router layer:**
- `raise HTTPException(status_code=4xx, detail="message")` for all client errors
- `raise HTTPException(status_code=404, detail="Item nao encontrado")` — Portuguese detail strings
- `logger.warning(...)` for security-related failures (e.g., failed login attempts) before raising
- `logger.exception(...)` for unexpected internal errors during background processing
- Global handler in `server/app/main.py` catches unhandled `Exception` and returns generic `{"detail": "Erro interno do servidor"}` with status 500

## Logging

**Dart:**
- `debugPrint('[Tag] message: $value')` — tagged with `[ServiceName]` prefix (e.g., `[FCM]`, `[AdService]`, `[AuthService]`)
- No structured logging library — `debugPrint` is stripped in release builds

**Python:**
- `logger = logging.getLogger(__name__)` at module level in every file
- Use `%s` formatting: `logger.error("Unhandled exception: %s", exc, exc_info=True)`
- `logger.warning(...)` for auth failures, `logger.exception(...)` for unexpected errors in background tasks

## Comments

**Dart — Section dividers:**
```dart
// ─── Section Name ────────────────────────────────────────────────────────────
```
Used to separate logical sections within a file (e.g., provider methods, screen state methods).

**Dart — Doc comments:**
- `///` for public classes and methods: `/// Provider de autenticação — gerencia estado de login/logout.`
- Inline comments for field constraints: `final String tipo; // "construcao" | "reforma"`

**Python — Section dividers:**
```python
# ─── Section Name ────────────────────────────────────────────────────────────
```
Same visual separator style as Dart side.

**Python — Module docstrings:**
- Router files begin with `"""RouterName — brief description."""`
- Helper functions use one-line `"""docstring."""`

**Inline TODO format:**
```dart
// TODO (Phase): description
// TODO (Fase Auth): navegar para a obra indicada em message.data['obra_id']
```
Referenced with issue tracking labels like `ARQ-03`, `SEC-01`, `PERF-10`.

## Function Design

**Dart:**
- Screen event handlers are private (`_methodName`)
- State mutations always call `setState(() { ... })`
- Long async operations stored as `Future<T>` fields, rendered with `FutureBuilder<T>`
- Widget constructors always include `{super.key}` or `{Key? key}` parameter

**Python:**
- Route functions are synchronous (`def`) unless explicitly using async features
- Dependency injection via `Depends(get_session)` and `Depends(get_current_user)` on every authenticated route
- Ownership verification always via `_verify_obra_ownership(obra_id, current_user, session)` helper — never inline

## Module Design

**Dart:**
- No barrel files — each import is explicit by relative path
- `lib/api/api.dart` is the single source of all data models and API methods
- `lib/utils/` holds pure utility functions (`auth_error_handler.dart`, `status_helper.dart`)

**Python:**
- `server/app/models.py` — all SQLModel ORM models
- `server/app/schemas.py` — all Pydantic/SQLModel request/response schemas
- `server/app/routers/` — one router file per domain (obras, etapas, financeiro, etc.)
- `server/app/helpers.py` — shared utilities; some are re-exports for backward compatibility

---

*Convention analysis: 2026-04-06*
