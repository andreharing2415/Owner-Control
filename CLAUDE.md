<!-- GSD:project-start source:PROJECT.md -->
## Project

**ObraMaster — Owner Control**

App mobile (Android + iOS) para gerenciamento de obras residenciais. O engenheiro ou mestre de obras cria e gerencia o projeto — sobe a documentação técnica, recebe um cronograma e checklist gerados por IA com base naquele projeto específico, e acompanha execução. O dono da obra é convidado para uma visão de acompanhamento de status, sem acesso de gestão.

**Core Value:** A partir do documento do projeto, a IA gera macro e micro atividades específicas daquela obra — não um template genérico — e isso vira automaticamente o cronograma e o checklist de acompanhamento.

### Constraints

- **Plataforma**: Android + iOS apenas — sem web
- **Stack**: Flutter (Dart 3.11+) + FastAPI (Python 3.11) + PostgreSQL — sem mudança
- **Deploy**: Google Cloud Run (projeto `mestreobra`, região `us-central1`)
- **Monetização**: Planos gratuito/pago via Stripe — manter modelo existente
- **IA**: Cadeia Gemini → Claude → OpenAI via `ai_providers.py` — manter fallback chain
- **Auth**: JWT HS256, 60min access / 7-day refresh — manter modelo de tokens
<!-- GSD:project-end -->

<!-- GSD:stack-start source:codebase/STACK.md -->
## Technology Stack

## Languages
- Dart 3.x (SDK ^3.11.0) - Flutter mobile/web app (`lib/`)
- Python 3.11 - Backend API server (`server/app/`)
- Kotlin - Android native integration (`android/`)
- Shell - Deployment scripts (`server/deploy-cloudrun.sh`, `server/restart.sh`)
## Runtime
- Flutter SDK (Dart 3.11+) for the mobile app
- Python 3.11 (`python:3.11-slim` Docker base image) for the backend
- Dart: `pub` (Flutter) — lockfile at `pubspec.lock`
- Python: `pip` — lockfiles at `server/requirements.txt` and `server/requirements-dev.txt`
- `pubspec.lock` — present and committed
- `server/requirements.txt` — pinned versions, present
## Frameworks
- Flutter (Material Design) — cross-platform mobile/web UI
- FastAPI 0.110.0 — REST API framework (`server/app/main.py`)
- Uvicorn 0.27.1 (standard) — ASGI server
- SQLModel 0.0.16 — ORM built on SQLAlchemy + Pydantic
- Flutter: `flutter_test` (built-in SDK) + `mockito ^5.4.4`
- Python: `pytest 8.1.1` + `pytest-asyncio 0.23.5`
- `build_runner ^2.4.9` — code generation for mockito
- `flutter_launcher_icons ^0.14.3` — icon generation
- `flutter_native_splash ^2.4.6` — splash screen generation
- `mypy 1.9.0` — static type checking
- `ruff 0.3.4` — linting/formatting
- `bandit 1.7.8` — security static analysis
- `alembic 1.13.1` — database migrations (`server/alembic/`)
## Key Dependencies
- `provider ^6.1.2` — state management
- `http ^1.2.1` — HTTP client for API calls
- `flutter_secure_storage ^9.2.2` — secure JWT token storage
- `google_sign_in ^6.2.1` — Google OAuth integration
- `local_auth ^2.3.0` — biometric authentication
- `firebase_core ^3.8.1` — Firebase base SDK
- `firebase_messaging ^15.1.5` — push notifications
- `firebase_crashlytics ^4.3.2` — crash reporting
- `fl_chart ^0.68.0` — charts and graphs
- `syncfusion_flutter_pdfviewer ^28.2.7` — PDF rendering
- `syncfusion_flutter_xlsio ^28.2.7` — Excel export
- `flutter_svg ^2.0.17` — SVG support
- `cached_network_image ^3.4.1` — network image caching
- `google_mobile_ads ^5.3.0` — AdMob for monetization
- `share_plus ^10.1.4` — native share sheet
- `psycopg2-binary 2.9.9` — PostgreSQL driver
- `python-jose[cryptography] 3.3.0` — JWT creation/validation (`server/app/auth.py`)
- `bcrypt 4.1.2` — password hashing
- `stripe 8.0.0` — payment processing (`server/app/routers/subscription.py`)
- `firebase-admin 6.5.0` — push notifications and Google token verification
- `slowapi 0.1.9` — rate limiting (`server/app/rate_limit.py`)
- `openai 1.75.0` — OpenAI GPT-4o integration
- `anthropic 0.40.0` — Anthropic Claude integration
- `google-generativeai 0.8.0` — Google Gemini integration
- `pymupdf 1.24.0` — PDF parsing for AI document analysis
- `boto3 1.34.34` — S3/MinIO compatible storage
- `google-cloud-storage 2.14.0` — Google Cloud Storage
- `fpdf2 2.7.8` — PDF generation
- `httpx 0.27.0` — async HTTP client (Supabase storage, email)
- `python-multipart 0.0.9` — file upload handling
- `python-dateutil 2.9.0` — date parsing
- `email-validator 2.1.1` — email format validation
- `python-magic 0.4.27` — file type detection
## Configuration
- `API_BASE_URL` — injected via `--dart-define` at build time
- Default: `https://mestreobra-backend-530484413221.us-central1.run.app`
- Defined in `lib/api/api.dart` via `String.fromEnvironment`
- Loaded from `.env` file via `python-dotenv` (`server/app/main.py`)
- Required: `DATABASE_URL`, `JWT_SECRET_KEY`
- Optional: `REQUIRE_SSL`, `S3_BUCKET`, `FIREBASE_CREDENTIALS_JSON`, etc.
- Android: `android/app/build.gradle.kts` — minSdk from Flutter defaults, compileSdk from Flutter defaults, JVM 17
- Android app ID: `br.mestredaobra.app`
- Android min SDK: 21 (set in `pubspec.yaml` flutter_launcher_icons config)
- Docker: `server/Dockerfile` — python:3.11-slim, exposes port 8080
- Database migrations: `server/alembic/` with `alembic.ini`
## Platform Requirements
- Flutter SDK 3.11+
- Dart SDK ^3.11.0
- Python 3.11
- PostgreSQL (or `DATABASE_URL` pointing to hosted instance)
- Optional: MinIO for local S3 storage (`S3_ENDPOINT_URL`)
- Android NDK 28.2.13676358 (for Android builds)
- Google Cloud Run (`server/deploy-cloudrun.sh`, project `mestreobra`, region `us-central1`)
- Cloud Build for Docker image build/push to GCR
- Service URL: `https://mestreobra-backend-530484413221.us-central1.run.app`
- Container: 1 CPU, 1Gi memory, timeout 300s
<!-- GSD:stack-end -->

<!-- GSD:conventions-start source:CONVENTIONS.md -->
## Conventions

## Naming Patterns
- Screens: `snake_case_screen.dart` — e.g., `financial_screen.dart`, `detalhe_item_screen.dart`
- Providers: `snake_case_provider.dart` — e.g., `auth_provider.dart`, `subscription_provider.dart`
- Services: `snake_case_service.dart` — e.g., `auth_service.dart`, `ad_service.dart`
- Widgets: `snake_case_widget.dart` — e.g., `ad_banner_widget.dart`
- API client: `lib/api/api.dart` (single file)
- Utils: `snake_case.dart` — e.g., `auth_error_handler.dart`, `status_helper.dart`
- Routers: `snake_case.py` — e.g., `obras.py`, `checklist_inteligente.py`
- Models/schemas/helpers: flat files in `server/app/`
- Widgets: `PascalCase` — e.g., `HomeScreen`, `FinancialScreen`, `AuthProvider`
- Private widget state: `_PascalCaseState` — e.g., `_HomeScreenState`, `_DetalheItemScreenState`
- Private helper widgets within a file: `_PascalCase` — e.g., `_StatusButton`, `_EvidenciasGrid`, `_DashboardData`
- Data models: `PascalCase` — e.g., `Obra`, `Etapa`, `ChecklistItem`, `AtividadeCronograma`
- Enums: `PascalCase` — e.g., `AuthStatus`
- Models/schemas: `PascalCase` — e.g., `Obra`, `ObraCreate`, `ObraRead`, `UserRegister`
- Response schemas: `PascalCase` + `Read`/`Create`/`Response` suffix — e.g., `ObraRead`, `TokenResponse`
- Public methods: `camelCase` — e.g., `listarObras()`, `calcularScore()`, `checkAuth()`
- Private methods: `_camelCase` — e.g., `_selecionarObra()`, `_onRefreshRequested()`, `_recarregarRelatorio()`
- Private fields: `_camelCase` — e.g., `_api`, `_obrasFuture`, `_obraSelecionada`
- Route handlers: `snake_case` — e.g., `criar_obra()`, `listar_obras()`, `registrar_orcamento()`
- Private helpers: `_snake_case` — e.g., `_verify_obra_ownership()`, `_sanitize_filename()`, `_read_template()`
- Module-level logger: `logger = logging.getLogger(__name__)` in every router/module
- camelCase throughout — e.g., `obraId`, `dataInicio`, `relatorioFuture`
- JSON field keys use the API's snake_case directly in string literals: `json["obra_id"]`, `json["data_inicio"]`
- Model fields use camelCase (`obraId`, `dataInicio`)
- `fromJson` factory maps snake_case JSON keys to camelCase fields
- API request payloads reconstruct snake_case keys manually
## Code Style
- Tool: `dart format` (enforced by `flutter_lints` via `analysis_options.yaml`)
- Linter: `package:flutter_lints/flutter.yaml` — default recommended ruleset
- `analysis_options.yaml` keeps defaults; no custom rules enabled beyond the included set
- Double quotes preferred for string literals in `lib/api/api.dart`; single quotes elsewhere
- Tool: `ruff` (version 0.3.4, listed in `requirements-dev.txt`)
- Type checker: `mypy` (version 1.9.0)
- Security linter: `bandit` (version 1.7.8)
- No `pyproject.toml` — ruff/mypy run without repo-level config file (use defaults)
## Import Organization
- Dart: none — all imports use relative paths (e.g., `../api/api.dart`)
- Python: relative imports only (`from ..models import ...`)
## Error Handling
- Every API method checks `response.statusCode != 200` (or appropriate code) and throws `Exception("message")` with a human-readable Portuguese message: `throw Exception("Erro ao listar obras")`
- `AuthExpiredException` is a custom exception thrown when JWT refresh fails
- Refresh logic in `_getWithRefresh` / `_postWithRefresh` wraps every authenticated call
- Async actions in screens follow the pattern:
- `handleApiError()` in `lib/utils/auth_error_handler.dart` is the unified handler — call it for `AuthExpiredException` (auto-logout + snackbar). For generic errors, show `formatErrorMessage(e)` in a `SnackBar`
- Always check `if (!mounted) return` before any `setState` or `context` call after an `await`
- `raise HTTPException(status_code=4xx, detail="message")` for all client errors
- `raise HTTPException(status_code=404, detail="Item nao encontrado")` — Portuguese detail strings
- `logger.warning(...)` for security-related failures (e.g., failed login attempts) before raising
- `logger.exception(...)` for unexpected internal errors during background processing
- Global handler in `server/app/main.py` catches unhandled `Exception` and returns generic `{"detail": "Erro interno do servidor"}` with status 500
## Logging
- `debugPrint('[Tag] message: $value')` — tagged with `[ServiceName]` prefix (e.g., `[FCM]`, `[AdService]`, `[AuthService]`)
- No structured logging library — `debugPrint` is stripped in release builds
- `logger = logging.getLogger(__name__)` at module level in every file
- Use `%s` formatting: `logger.error("Unhandled exception: %s", exc, exc_info=True)`
- `logger.warning(...)` for auth failures, `logger.exception(...)` for unexpected errors in background tasks
## Comments
- `///` for public classes and methods: `/// Provider de autenticação — gerencia estado de login/logout.`
- Inline comments for field constraints: `final String tipo; // "construcao" | "reforma"`
- Router files begin with `"""RouterName — brief description."""`
- Helper functions use one-line `"""docstring."""`
## Function Design
- Screen event handlers are private (`_methodName`)
- State mutations always call `setState(() { ... })`
- Long async operations stored as `Future<T>` fields, rendered with `FutureBuilder<T>`
- Widget constructors always include `{super.key}` or `{Key? key}` parameter
- Route functions are synchronous (`def`) unless explicitly using async features
- Dependency injection via `Depends(get_session)` and `Depends(get_current_user)` on every authenticated route
- Ownership verification always via `_verify_obra_ownership(obra_id, current_user, session)` helper — never inline
## Module Design
- No barrel files — each import is explicit by relative path
- `lib/api/api.dart` is the single source of all data models and API methods
- `lib/utils/` holds pure utility functions (`auth_error_handler.dart`, `status_helper.dart`)
- `server/app/models.py` — all SQLModel ORM models
- `server/app/schemas.py` — all Pydantic/SQLModel request/response schemas
- `server/app/routers/` — one router file per domain (obras, etapas, financeiro, etc.)
- `server/app/helpers.py` — shared utilities; some are re-exports for backward compatibility
<!-- GSD:conventions-end -->

<!-- GSD:architecture-start source:ARCHITECTURE.md -->
## Architecture

## Pattern Overview
- Flutter mobile app (Android/iOS) communicates exclusively via REST JSON over HTTPS to a FastAPI backend deployed on Google Cloud Run
- Backend uses SQLModel (SQLAlchemy + Pydantic) with PostgreSQL for persistence, and a multi-provider AI fallback chain (Gemini → Claude → OpenAI) for intelligent features
- Frontend state management uses the Provider package (`ChangeNotifier`) — no Riverpod or Bloc
- Authentication is JWT-based (access token + refresh token) stored in `flutter_secure_storage` on the client
- Subscription/feature gates are enforced server-side via plan configuration in `server/app/subscription.py`
## Layers
- Purpose: Presents UI, manages local state, orchestrates API calls
- Location: `lib/`
- Contains: screens, providers, services, widgets, API client, utils
- Depends on: Backend REST API via `lib/api/api.dart`
- Used by: End users on Android and iOS
- Purpose: Single class `ApiClient` that wraps all HTTP communication; also holds Dart model classes
- Location: `lib/api/api.dart`
- Contains: All model definitions (`Obra`, `Etapa`, `ChecklistItem`, etc.) and all API call methods
- Depends on: `lib/services/auth_service.dart` for token injection and auto-refresh
- Used by: All screens and providers; instantiated locally per-use (`final _api = ApiClient()`)
- Purpose: Reactive state shared across the widget tree via `MultiProvider` in `lib/main.dart`
- Location: `lib/providers/`
- Contains:
- Depends on: `ApiClient`, `AuthService`
- Used by: Screens via `context.watch<T>()` and `context.read<T>()`
- Purpose: Singletons that encapsulate platform integrations
- Location: `lib/services/`
- Contains:
- Depends on: Platform SDKs, `flutter_secure_storage`
- Used by: `AuthProvider`, `main.dart`
- Purpose: Full-screen UI widgets; each feature has its own screen file
- Location: `lib/screens/`
- Contains: 40+ screen files (login, register, home dashboard, obras, etapas, checklist, financial, documents, prestadores, normas, cronograma, AI screens, subscription paywall, etc.)
- Depends on: Providers, `ApiClient`, widget sub-components
- Used by: `MainShell` (tab-based navigator) and screen-to-screen pushes
- Purpose: Reusable, composable UI components
- Location: `lib/widgets/`
- Contains:
- Depends on: Screens provide data down; widgets call back via callbacks
- Purpose: HTTP endpoints organized by domain; each router has its own file
- Location: `server/app/routers/`
- Contains: `auth`, `obras`, `etapas`, `checklist`, `checklist_inteligente`, `normas`, `financeiro`, `documentos`, `visual_ai`, `prestadores`, `subscription`, `convites`, `cronograma`
- Depends on: `auth.get_current_user` (dependency injection), `db.get_session`, models, schemas, business logic modules
- Used by: FastAPI app via `app.include_router(...)` in `server/app/main.py`
- Purpose: Domain logic extracted from routers
- Location: `server/app/` (module-level files)
- Contains:
- Used by: Routers
- Purpose: Complex business processes extracted from routers (ARQ-01 refactor)
- Location: `server/app/services/`
- Contains:
- Used by: `routers/documentos.py`
- Purpose: Database models, schemas, session management
- Location: `server/app/`
- Contains:
- Used by: All routers and business logic modules
- Purpose: Schema versioning
- Location: `server/alembic/versions/`
- Contains: 24 migration files, date-prefixed (e.g., `20260319_0022_cronograma_hierarquico.py`)
- Used by: `alembic upgrade head` during deployments
## Data Flow
- Global providers (`AuthProvider`, `SubscriptionProvider`) initialized in `lib/main.dart` via `MultiProvider`
- Local screen state via `StatefulWidget` with `setState`
- Tab refresh coordination via `TabRefreshNotifier` (lightweight `ChangeNotifier` with no data)
- No persistent local cache beyond auth tokens — all data fetched fresh from API per screen load
## Key Abstractions
- Purpose: Single HTTP client for all backend calls; also the Dart model layer
- Pattern: Instantiated per-use (no singleton); auto-refreshes JWT on 401; throws `AuthExpiredException` when refresh fails
- Contains Dart classes: `Obra`, `Etapa`, `ChecklistItem`, `Evidencia`, `NormaResultado`, `Prestador`, `SubscriptionInfo`, `RelatorioFinanceiro`, etc.
- Purpose: FastAPI dependency that validates Bearer token and returns the `User` ORM object
- Pattern: Injected via `Depends(get_current_user)` in every protected router function
- Purpose: Ownership guards used in every obra-scoped router call
- `_verify_obra_ownership` — requires caller to be the obra owner
- `_verify_obra_access` — allows owner OR invited collaborator
- Purpose: Central plan configuration dictionary; `check_obra_limit()`, `require_paid()`, `check_and_increment_usage()` enforce limits
- Pattern: Called at the start of endpoints before business logic
- Purpose: Tries Gemini → Claude → OpenAI in order; first success wins
- Pattern: Protocol-based (VisionProvider, TextProvider); concrete implementations returned by `get_vision_chain()`, `get_text_chain()`, `get_document_vision_chain()`
## Entry Points
- Location: `lib/main.dart`
- Triggers: Flutter runtime on device startup
- Responsibilities: Initialize Firebase, Crashlytics, AuthService, AdMob; register providers; mount `AuthGate`
- Location: `lib/screens/auth_gate.dart`
- Triggers: App startup after `main()`
- Responsibilities: Watch `AuthProvider.status`, route to `LoginScreen`, `CompleteProfileScreen`, or `MainShell`
- Location: `lib/screens/main_shell.dart`
- Triggers: `AuthGate` when authenticated
- Responsibilities: 5-tab `NavigationBar` (Home, Obras, Documentos, Prestadores, Config); per-tab `Navigator` stack; `IndexedStack` for state persistence
- Location: `server/app/main.py`
- Triggers: Uvicorn on Cloud Run startup
- Responsibilities: Configure CORS, rate limiter, security headers, global exception handler; call `init_db()`; mount all 13 routers
## Error Handling
- Global exception handler in `main.py` returns `{"detail": "Erro interno do servidor"}` for all unhandled exceptions (prevents leaking stack traces)
- Router-level `HTTPException` with explicit status codes (401, 403, 404, 409, 402)
- Auth failures always return 401 with localized Portuguese message
- Ownership checks raise 404 (not 403) to avoid information leakage about existence
- `ApiClient` catches 401 and attempts token refresh before propagating
- `AuthExpiredException` propagated to screens, which call `context.read<AuthProvider>().logout()`
- Screen-level `try/catch` with `ScaffoldMessenger.showSnackBar` for user-visible errors
- Firebase Crashlytics captures uncaught exceptions in `FlutterError.onError` and `PlatformDispatcher.onError`
## Cross-Cutting Concerns
- Backend: Python `logging` module with `logger = logging.getLogger(__name__)` in each module
- Frontend: `debugPrint('[ServiceName] message')` pattern
- Backend: Pydantic field validators on schemas (e.g., password strength in `UserRegister`)
- Frontend: Local form validation in screens before API calls
- Backend: `Depends(get_current_user)` injected into every protected endpoint
- Frontend: `AuthService` singleton manages token lifecycle; `ApiClient` auto-refreshes on 401
- slowapi decorators on sensitive auth endpoints (`/register`, `/login`) — 10 requests/minute limit
- Every obra is scoped to `user_id`; all obra-scoped endpoints call `_verify_obra_ownership` or `_verify_obra_access`
- Invited collaborators stored in `ObraConvite` table; `_verify_obra_access` checks both owner and invitees
<!-- GSD:architecture-end -->

<!-- GSD:workflow-start source:GSD defaults -->
## GSD Workflow Enforcement

Before using Edit, Write, or other file-changing tools, start work through a GSD command so planning artifacts and execution context stay in sync.

Use these entry points:
- `/gsd:quick` for small fixes, doc updates, and ad-hoc tasks
- `/gsd:debug` for investigation and bug fixing
- `/gsd:execute-phase` for planned phase work

Do not make direct repo edits outside a GSD workflow unless the user explicitly asks to bypass it.
<!-- GSD:workflow-end -->



<!-- GSD:profile-start -->
## Developer Profile

> Profile not yet configured. Run `/gsd:profile-user` to generate your developer profile.
> This section is managed by `generate-claude-profile` -- do not edit manually.
<!-- GSD:profile-end -->
