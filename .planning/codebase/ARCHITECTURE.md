# Architecture

**Analysis Date:** 2026-04-06

## Pattern Overview

**Overall:** Client-Server with Provider-based state management on the Flutter frontend and a layered FastAPI backend.

**Key Characteristics:**
- Flutter mobile app (Android/iOS) communicates exclusively via REST JSON over HTTPS to a FastAPI backend deployed on Google Cloud Run
- Backend uses SQLModel (SQLAlchemy + Pydantic) with PostgreSQL for persistence, and a multi-provider AI fallback chain (Gemini → Claude → OpenAI) for intelligent features
- Frontend state management uses the Provider package (`ChangeNotifier`) — no Riverpod or Bloc
- Authentication is JWT-based (access token + refresh token) stored in `flutter_secure_storage` on the client
- Subscription/feature gates are enforced server-side via plan configuration in `server/app/subscription.py`

## Layers

**Flutter App Layer:**
- Purpose: Presents UI, manages local state, orchestrates API calls
- Location: `lib/`
- Contains: screens, providers, services, widgets, API client, utils
- Depends on: Backend REST API via `lib/api/api.dart`
- Used by: End users on Android and iOS

**API Client Layer:**
- Purpose: Single class `ApiClient` that wraps all HTTP communication; also holds Dart model classes
- Location: `lib/api/api.dart`
- Contains: All model definitions (`Obra`, `Etapa`, `ChecklistItem`, etc.) and all API call methods
- Depends on: `lib/services/auth_service.dart` for token injection and auto-refresh
- Used by: All screens and providers; instantiated locally per-use (`final _api = ApiClient()`)

**Provider Layer:**
- Purpose: Reactive state shared across the widget tree via `MultiProvider` in `lib/main.dart`
- Location: `lib/providers/`
- Contains:
  - `auth_provider.dart` — AuthStatus enum, login/register/Google/biometric flows
  - `subscription_provider.dart` — Current plan + feature flags
  - `obra_provider.dart` — Currently selected `Obra`
  - `tab_refresh_notifier.dart` — Lightweight notifier to trigger tab data reload
- Depends on: `ApiClient`, `AuthService`
- Used by: Screens via `context.watch<T>()` and `context.read<T>()`

**Service Layer (Flutter):**
- Purpose: Singletons that encapsulate platform integrations
- Location: `lib/services/`
- Contains:
  - `auth_service.dart` — JWT token storage/retrieval in `flutter_secure_storage`, token refresh logic
  - `ad_service.dart` — Google AdMob SDK initialization
  - `notification_service.dart` — Firebase Cloud Messaging (FCM) push setup
- Depends on: Platform SDKs, `flutter_secure_storage`
- Used by: `AuthProvider`, `main.dart`

**Screen Layer:**
- Purpose: Full-screen UI widgets; each feature has its own screen file
- Location: `lib/screens/`
- Contains: 40+ screen files (login, register, home dashboard, obras, etapas, checklist, financial, documents, prestadores, normas, cronograma, AI screens, subscription paywall, etc.)
- Depends on: Providers, `ApiClient`, widget sub-components
- Used by: `MainShell` (tab-based navigator) and screen-to-screen pushes

**Widget Library:**
- Purpose: Reusable, composable UI components
- Location: `lib/widgets/`
- Contains:
  - `ad_banner_widget.dart` — AdMob banner with plan gating
  - `rewarded_dialog.dart` — Rewarded ad dialog
  - `atividade_detalhe/` — Tab widgets for activity detail screen (checklist, info, services)
  - `criar_obra/` — Step widgets for the obra creation wizard
- Depends on: Screens provide data down; widgets call back via callbacks

**FastAPI Router Layer:**
- Purpose: HTTP endpoints organized by domain; each router has its own file
- Location: `server/app/routers/`
- Contains: `auth`, `obras`, `etapas`, `checklist`, `checklist_inteligente`, `normas`, `financeiro`, `documentos`, `visual_ai`, `prestadores`, `subscription`, `convites`, `cronograma`
- Depends on: `auth.get_current_user` (dependency injection), `db.get_session`, models, schemas, business logic modules
- Used by: FastAPI app via `app.include_router(...)` in `server/app/main.py`

**Business Logic Layer (Backend):**
- Purpose: Domain logic extracted from routers
- Location: `server/app/` (module-level files)
- Contains:
  - `auth.py` — JWT creation/verification, `get_current_user` FastAPI dependency
  - `subscription.py` — Plan config dict, feature gates, usage tracking
  - `checklist_inteligente.py` — AI checklist generation (streaming + background)
  - `cronograma_ai.py` — AI-powered project timeline generation
  - `documentos.py` — Document risk analysis prompt logic
  - `visual_ai.py` — Photo analysis (IA visual)
  - `normas.py` — Construction standards (normas) AI lookup
  - `ai_providers.py` — Multi-provider AI fallback chain (Gemini → Claude → OpenAI)
  - `storage.py` — Abstracted file storage (Supabase/S3/GCS, chosen via env vars)
  - `pdf.py`, `pdf_utils.py` — PDF rendering and page extraction
  - `push.py` — Firebase Admin push notification dispatch
  - `notifications.py` — Budget alert notification logic
  - `helpers.py` — Shared ownership guards (`_verify_obra_ownership`, `_verify_obra_access`) and re-exports
  - `constants.py` — Static data (default etapas list)
  - `enums.py` — All domain enums (EtapaStatus, ChecklistStatus, ConviteStatus, etc.)
  - `rate_limit.py` — slowapi limiter instance
- Used by: Routers

**Service Layer (Backend):**
- Purpose: Complex business processes extracted from routers (ARQ-01 refactor)
- Location: `server/app/services/`
- Contains:
  - `documento_service.py` — Background AI document analysis, risk-to-checklist conversion, detalhamento extraction
- Used by: `routers/documentos.py`

**Data Layer:**
- Purpose: Database models, schemas, session management
- Location: `server/app/`
- Contains:
  - `models.py` — SQLModel table classes (`User`, `Obra`, `Etapa`, `ChecklistItem`, `Evidencia`, `Despesa`, `ProjetoDoc`, `Risco`, `Prestador`, `AtividadeCronograma`, etc.)
  - `schemas.py` — Pydantic I/O schemas (request bodies, response models) separate from table models
  - `db.py` — Engine creation, `get_session` dependency, `init_db()`
  - `enums.py` — Shared status enums used in both models and schemas
- Used by: All routers and business logic modules

**Database Migrations:**
- Purpose: Schema versioning
- Location: `server/alembic/versions/`
- Contains: 24 migration files, date-prefixed (e.g., `20260319_0022_cronograma_hierarquico.py`)
- Used by: `alembic upgrade head` during deployments

## Data Flow

**Authentication Flow:**

1. User submits credentials on `lib/screens/login_screen.dart`
2. `AuthProvider.login()` calls `ApiClient().login()`
3. `ApiClient` POST `/api/auth/login` → backend validates password via bcrypt
4. Backend returns `{access_token, refresh_token, user}` (JWT HS256, 60min access / 7-day refresh)
5. `AuthService.saveTokens()` persists tokens in `flutter_secure_storage`
6. `AuthProvider` sets `AuthStatus.authenticated`, `AuthGate` renders `MainShell`

**Authenticated API Call Flow:**

1. Screen creates `ApiClient()` and calls a method
2. `ApiClient` attaches `Authorization: Bearer <accessToken>` from `AuthService.instance.accessToken`
3. If response is 401, `AuthService.refreshAccessToken()` hits `/api/auth/refresh` automatically
4. On refresh failure, `AuthExpiredException` is thrown and screens handle logout
5. Backend router dependency `get_current_user` decodes the JWT and loads the `User` from DB

**AI Feature Flow (checklist inteligente, document analysis, visual AI):**

1. Screen triggers generation (e.g., `checklist_inteligente_screen.dart`)
2. API call starts background processing on server (ThreadPoolExecutor, max 4 workers)
3. Server stores status in DB (`processando` → `concluido` / `erro`)
4. Some features stream SSE responses (`StreamingResponse`) directly
5. Client polls or receives streamed tokens to update UI progressively
6. Subscription check enforced at start: `check_and_increment_usage()` raises 402 if limit exceeded

**State Management:**

- Global providers (`AuthProvider`, `SubscriptionProvider`) initialized in `lib/main.dart` via `MultiProvider`
- Local screen state via `StatefulWidget` with `setState`
- Tab refresh coordination via `TabRefreshNotifier` (lightweight `ChangeNotifier` with no data)
- No persistent local cache beyond auth tokens — all data fetched fresh from API per screen load

## Key Abstractions

**`ApiClient` (lib/api/api.dart):**
- Purpose: Single HTTP client for all backend calls; also the Dart model layer
- Pattern: Instantiated per-use (no singleton); auto-refreshes JWT on 401; throws `AuthExpiredException` when refresh fails
- Contains Dart classes: `Obra`, `Etapa`, `ChecklistItem`, `Evidencia`, `NormaResultado`, `Prestador`, `SubscriptionInfo`, `RelatorioFinanceiro`, etc.

**`get_current_user` (server/app/auth.py):**
- Purpose: FastAPI dependency that validates Bearer token and returns the `User` ORM object
- Pattern: Injected via `Depends(get_current_user)` in every protected router function

**`_verify_obra_ownership` / `_verify_obra_access` (server/app/helpers.py):**
- Purpose: Ownership guards used in every obra-scoped router call
- `_verify_obra_ownership` — requires caller to be the obra owner
- `_verify_obra_access` — allows owner OR invited collaborator

**`PLAN_CONFIG` + feature gate functions (server/app/subscription.py):**
- Purpose: Central plan configuration dictionary; `check_obra_limit()`, `require_paid()`, `check_and_increment_usage()` enforce limits
- Pattern: Called at the start of endpoints before business logic

**`call_with_fallback` / AI provider chain (server/app/ai_providers.py):**
- Purpose: Tries Gemini → Claude → OpenAI in order; first success wins
- Pattern: Protocol-based (VisionProvider, TextProvider); concrete implementations returned by `get_vision_chain()`, `get_text_chain()`, `get_document_vision_chain()`

## Entry Points

**Flutter App:**
- Location: `lib/main.dart`
- Triggers: Flutter runtime on device startup
- Responsibilities: Initialize Firebase, Crashlytics, AuthService, AdMob; register providers; mount `AuthGate`

**AuthGate:**
- Location: `lib/screens/auth_gate.dart`
- Triggers: App startup after `main()`
- Responsibilities: Watch `AuthProvider.status`, route to `LoginScreen`, `CompleteProfileScreen`, or `MainShell`

**MainShell:**
- Location: `lib/screens/main_shell.dart`
- Triggers: `AuthGate` when authenticated
- Responsibilities: 5-tab `NavigationBar` (Home, Obras, Documentos, Prestadores, Config); per-tab `Navigator` stack; `IndexedStack` for state persistence

**FastAPI App:**
- Location: `server/app/main.py`
- Triggers: Uvicorn on Cloud Run startup
- Responsibilities: Configure CORS, rate limiter, security headers, global exception handler; call `init_db()`; mount all 13 routers

## Error Handling

**Strategy:** Centralized on both ends

**Backend Patterns:**
- Global exception handler in `main.py` returns `{"detail": "Erro interno do servidor"}` for all unhandled exceptions (prevents leaking stack traces)
- Router-level `HTTPException` with explicit status codes (401, 403, 404, 409, 402)
- Auth failures always return 401 with localized Portuguese message
- Ownership checks raise 404 (not 403) to avoid information leakage about existence

**Frontend Patterns:**
- `ApiClient` catches 401 and attempts token refresh before propagating
- `AuthExpiredException` propagated to screens, which call `context.read<AuthProvider>().logout()`
- Screen-level `try/catch` with `ScaffoldMessenger.showSnackBar` for user-visible errors
- Firebase Crashlytics captures uncaught exceptions in `FlutterError.onError` and `PlatformDispatcher.onError`

## Cross-Cutting Concerns

**Logging:**
- Backend: Python `logging` module with `logger = logging.getLogger(__name__)` in each module
- Frontend: `debugPrint('[ServiceName] message')` pattern

**Validation:**
- Backend: Pydantic field validators on schemas (e.g., password strength in `UserRegister`)
- Frontend: Local form validation in screens before API calls

**Authentication:**
- Backend: `Depends(get_current_user)` injected into every protected endpoint
- Frontend: `AuthService` singleton manages token lifecycle; `ApiClient` auto-refreshes on 401

**Rate Limiting:**
- slowapi decorators on sensitive auth endpoints (`/register`, `/login`) — 10 requests/minute limit

**Multi-tenancy:**
- Every obra is scoped to `user_id`; all obra-scoped endpoints call `_verify_obra_ownership` or `_verify_obra_access`
- Invited collaborators stored in `ObraConvite` table; `_verify_obra_access` checks both owner and invitees

---

*Architecture analysis: 2026-04-06*
