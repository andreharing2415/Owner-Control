# Codebase Structure

**Analysis Date:** 2026-04-06

## Directory Layout

```
owner-control/                   # Flutter project root (package: owner_control)
├── lib/                         # All Dart/Flutter application code
│   ├── main.dart                # App entry point, provider setup, Firebase init
│   ├── api/
│   │   └── api.dart             # ApiClient class + all Dart model definitions
│   ├── providers/               # ChangeNotifier state providers
│   ├── screens/                 # Full-screen UI widgets (one file per feature)
│   │   └── widgets/             # Screen-scoped sub-widgets (star_rating)
│   ├── services/                # Platform singletons (auth tokens, ads, notifications)
│   ├── utils/                   # Pure utility functions (no UI, no state)
│   └── widgets/                 # Reusable cross-screen widgets and step components
│       ├── atividade_detalhe/   # Tab widgets for atividade detail screen
│       └── criar_obra/          # Step widgets for obra creation wizard
├── server/                      # Python FastAPI backend
│   ├── app/
│   │   ├── main.py              # FastAPI app, CORS, middleware, router mounting
│   │   ├── models.py            # SQLModel ORM table definitions
│   │   ├── schemas.py           # Pydantic I/O schemas (request/response)
│   │   ├── enums.py             # Domain enums shared across models and schemas
│   │   ├── auth.py              # JWT logic, get_current_user dependency
│   │   ├── db.py                # Engine, session factory, init_db
│   │   ├── subscription.py      # PLAN_CONFIG, feature gates, usage tracking
│   │   ├── helpers.py           # Ownership guards, shared utilities, re-exports
│   │   ├── constants.py         # Static data (ETAPAS_PADRAO list)
│   │   ├── rate_limit.py        # slowapi limiter instance
│   │   ├── storage.py           # File storage abstraction (Supabase/S3/GCS)
│   │   ├── ai_providers.py      # AI provider fallback chain (Gemini→Claude→OpenAI)
│   │   ├── checklist_inteligente.py  # AI checklist generation logic
│   │   ├── cronograma_ai.py     # AI cronograma generation logic
│   │   ├── documentos.py        # Document risk analysis prompts
│   │   ├── visual_ai.py         # Photo AI analysis logic
│   │   ├── normas.py            # Construction standards AI lookup
│   │   ├── pdf.py               # PDF report rendering
│   │   ├── pdf_utils.py         # PDF page-to-image extraction
│   │   ├── push.py              # FCM push dispatch
│   │   ├── notifications.py     # Budget alert notification logic
│   │   ├── email_service.py     # Email sending (invite notifications)
│   │   ├── utils.py             # JSON cleaning and misc utilities
│   │   ├── seed_checklists.py   # Default checklist items per etapa
│   │   ├── routers/             # FastAPI APIRouter modules (one per domain)
│   │   ├── services/            # Business-logic services extracted from routers
│   │   └── templates/           # HTML templates (privacy policy, subscription pages)
│   ├── alembic/                 # Database migration framework
│   │   └── versions/            # Migration files (date-prefixed, 24 migrations)
│   ├── requirements.txt         # Production Python dependencies
│   ├── requirements-dev.txt     # Dev-only Python dependencies
│   ├── Dockerfile               # Cloud Run container image
│   └── deploy-cloudrun.sh       # Cloud Run deployment script
├── android/                     # Android platform code
│   └── app/src/main/kotlin/br/mestredaobra/app/  # Kotlin MainActivity
├── ios/Runner/                  # iOS platform code
├── assets/
│   └── images/                  # App images (logo_horizontal.png, icone.png)
├── test/                        # Flutter tests
├── docs/plans/                  # Planning documents
├── pubspec.yaml                 # Flutter dependencies and configuration
└── analysis_options.yaml        # Dart linter configuration
```

## Directory Purposes

**`lib/api/`:**
- Purpose: Single file `api.dart` serves as both HTTP client and Dart model layer
- Contains: `ApiClient` class, all Dart model classes with `fromJson` factories
- Key files: `lib/api/api.dart` — all API methods and data models in one file
- Note: Models are defined here (not in a separate `models/` dir)

**`lib/providers/`:**
- Purpose: Global reactive state shared across the widget tree
- Contains: One file per provider; providers extend `ChangeNotifier`
- Key files:
  - `lib/providers/auth_provider.dart` — auth state and login methods
  - `lib/providers/subscription_provider.dart` — plan and feature flags
  - `lib/providers/obra_provider.dart` — currently selected obra
  - `lib/providers/tab_refresh_notifier.dart` — lightweight tab refresh signal

**`lib/screens/`:**
- Purpose: Full-screen widgets; each file is one navigable screen
- Contains: 40+ screen files organized flat (no subdirectories except `widgets/`)
- Key files:
  - `lib/screens/auth_gate.dart` — root routing widget
  - `lib/screens/main_shell.dart` — bottom navigation tab shell
  - `lib/screens/home_screen.dart` — main dashboard with obra selector
  - `lib/screens/login_screen.dart` — login/register entry
  - `lib/screens/obras_screen.dart` — obra list
  - `lib/screens/etapas_screen.dart` — etapas list per obra
  - `lib/screens/checklist_screen.dart` — checklist items per etapa
  - `lib/screens/financial_screen.dart` — financial overview
  - `lib/screens/documents_screen.dart` — document management
  - `lib/screens/cronograma_screen.dart` — project timeline
  - `lib/screens/paywall_screen.dart` — subscription upgrade screen

**`lib/services/`:**
- Purpose: Platform-integrated singletons; instantiated once, used everywhere
- Contains:
  - `lib/services/auth_service.dart` — JWT storage and refresh (Singleton)
  - `lib/services/ad_service.dart` — Google AdMob initialization (Singleton)
  - `lib/services/notification_service.dart` — FCM push setup (Singleton)

**`lib/utils/`:**
- Purpose: Stateless pure utility functions
- Contains:
  - `lib/utils/auth_error_handler.dart` — maps API errors to user messages
  - `lib/utils/status_helper.dart` — status string → UI label/color helpers

**`lib/widgets/`:**
- Purpose: Reusable UI components not tied to a single screen
- Contains:
  - `lib/widgets/ad_banner_widget.dart` — AdMob banner
  - `lib/widgets/rewarded_dialog.dart` — rewarded ad dialog
  - `lib/widgets/atividade_detalhe/` — tabs for atividade detail (checklist_tab, info_tab, servicos_tab)
  - `lib/widgets/criar_obra/` — wizard steps for obra creation (step_tipo, step_cronograma, step_documentos)

**`server/app/routers/`:**
- Purpose: HTTP endpoint definitions organized by domain
- Contains 13 router modules; each uses `APIRouter` with a prefix and tags
- Key files:
  - `server/app/routers/auth.py` — `/api/auth/*`
  - `server/app/routers/obras.py` — `/api/obras/*`
  - `server/app/routers/etapas.py` — etapa CRUD
  - `server/app/routers/checklist.py` — standard checklist endpoints
  - `server/app/routers/checklist_inteligente.py` — AI checklist generation
  - `server/app/routers/financeiro.py` — budget and expenses
  - `server/app/routers/documentos.py` — document upload + AI analysis
  - `server/app/routers/cronograma.py` — AI-powered timeline
  - `server/app/routers/normas.py` — construction standards lookup
  - `server/app/routers/prestadores.py` — service provider directory
  - `server/app/routers/visual_ai.py` — photo AI analysis
  - `server/app/routers/convites.py` — obra invitations
  - `server/app/routers/subscription.py` — plan management + Stripe webhook

**`server/app/services/`:**
- Purpose: Business logic extracted out of routers (ARQ-01 refactor pattern)
- Currently contains: `documento_service.py`
- Future new logic should be added here (not directly in routers)

**`server/alembic/versions/`:**
- Purpose: PostgreSQL schema migrations
- Naming: `YYYYMMDD_NNNN_description.py`
- Generated: Yes (via `alembic revision --autogenerate`)
- Committed: Yes

## Key File Locations

**Entry Points:**
- `lib/main.dart`: Flutter app root, Firebase + provider initialization
- `server/app/main.py`: FastAPI app factory, all middleware and routers

**Configuration:**
- `pubspec.yaml`: Flutter dependencies, assets, launcher icons config
- `server/requirements.txt`: Python production dependencies
- `server/alembic.ini`: Alembic migration config
- `server/Dockerfile`: Container build instructions for Cloud Run

**Core Logic:**
- `lib/api/api.dart`: All Dart models and API methods (single source of truth for client-side types)
- `server/app/models.py`: All SQLModel ORM tables
- `server/app/schemas.py`: All Pydantic request/response schemas
- `server/app/auth.py`: JWT + `get_current_user` dependency
- `server/app/subscription.py`: `PLAN_CONFIG` dict and all feature gate functions
- `server/app/ai_providers.py`: AI provider abstraction and fallback chain

**Testing:**
- `test/` — Flutter test directory (minimal coverage currently)

## Naming Conventions

**Flutter Files:**
- Screens: `snake_case_screen.dart` (e.g., `checklist_inteligente_screen.dart`)
- Providers: `snake_case_provider.dart` (e.g., `auth_provider.dart`)
- Services: `snake_case_service.dart` (e.g., `auth_service.dart`)
- Widgets: `snake_case_widget.dart` or `snake_case.dart` for tab/step components
- Utils: `snake_case.dart` (e.g., `status_helper.dart`)

**Flutter Classes:**
- Screens: `PascalCaseScreen` (e.g., `ChecklistInteligenteScreen`)
- Providers: `PascalCaseProvider` (e.g., `AuthProvider`)
- Services: `PascalCaseService` (e.g., `AuthService`)
- Models (in api.dart): `PascalCase` (e.g., `Obra`, `ChecklistItem`)

**Python Files:**
- Router modules: domain noun, singular or plural as natural (e.g., `obras.py`, `checklist_inteligente.py`)
- Business logic modules: domain noun matching the feature (e.g., `documentos.py`, `cronograma_ai.py`)
- All lowercase with underscores

**Python Naming:**
- Models: `PascalCase` matching table name (e.g., `ChecklistItem`, `ObraConvite`)
- Schema classes: `PascalCase` with suffix `Create`, `Read`, `Update`, `Response` (e.g., `ObraCreate`, `ObraRead`, `OkResponse`)
- Router functions: `snake_case` verb + noun (e.g., `criar_obra`, `listar_etapas`)
- Private helpers: `_snake_case` with underscore prefix (e.g., `_verify_obra_ownership`)
- Enums: `PascalCase` class, `UPPER_CASE` values (e.g., `EtapaStatus.PENDENTE`)

**Database Migrations:**
- Format: `YYYYMMDD_NNNN_short_description.py` (e.g., `20260319_0022_cronograma_hierarquico.py`)

## Where to Add New Code

**New Feature Screen (Flutter):**
- Implementation: `lib/screens/<feature_name>_screen.dart`
- If it has sub-tabs or complex sub-widgets: `lib/widgets/<feature_name>/`
- Register navigation: push from existing screen or add to `main_shell.dart` tabs

**New API Call + Model (Flutter):**
- Add Dart model class to `lib/api/api.dart` with `fromJson` factory
- Add method to `ApiClient` class in `lib/api/api.dart`
- No separate file — all client-side data and HTTP calls live in `api.dart`

**New Global State:**
- Create `lib/providers/<name>_provider.dart` extending `ChangeNotifier`
- Register in `MultiProvider` in `lib/main.dart`

**New Backend Endpoint:**
- Add to the appropriate router in `server/app/routers/<domain>.py`
- Add request/response schema to `server/app/schemas.py`
- If adding a new model: add to `server/app/models.py` and create an Alembic migration
- Always inject `current_user: User = Depends(get_current_user)` for protected endpoints
- Always call `_verify_obra_ownership` or `_verify_obra_access` for obra-scoped endpoints

**New Domain/Router (Backend):**
- Create `server/app/routers/<domain>.py` with `router = APIRouter(prefix="/api/<domain>", tags=["<domain>"])`
- Add business logic to `server/app/<domain>.py` or `server/app/services/<domain>_service.py`
- Mount in `server/app/main.py` with `app.include_router(<domain>.router)`

**New AI Feature (Backend):**
- Use `ai_providers.py` via `call_with_fallback(get_text_chain(), prompt)` or `call_vision_with_fallback(...)`
- Do not create new provider initialization code; extend the existing chain if needed
- Long-running jobs: use `ThreadPoolExecutor` pattern from `checklist_inteligente.py`

**Utilities:**
- Shared backend helpers: `server/app/helpers.py` or `server/app/utils.py`
- Shared Flutter helpers: `lib/utils/<name>.dart`
- Backend constants/static data: `server/app/constants.py`

## Special Directories

**`.planning/`:**
- Purpose: GSD planning artifacts (phases, codebase docs)
- Generated: No
- Committed: Yes

**`.claude/skills/`:**
- Purpose: Claude Code skill definitions for common tasks (flutter-screen, backend-endpoint, dev-start, etc.)
- Generated: No
- Committed: Yes

**`server/alembic/versions/`:**
- Purpose: Generated migration scripts
- Generated: Via `alembic revision`
- Committed: Yes

**`build/`:**
- Purpose: Flutter build output
- Generated: Yes
- Committed: No

**`android/`, `ios/`, `linux/`, `macos/`, `web/`, `windows/`:**
- Purpose: Platform-specific native project files
- Generated: Flutter framework tooling
- Committed: Yes (required for platform builds)

---

*Structure analysis: 2026-04-06*
