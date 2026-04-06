# Technology Stack — Owner Control (Gestão de Obras)

**Project:** Owner Control / Mestre da Obra
**Type:** Brownfield — existing production codebase
**Researched:** 2026-04-06
**Overall confidence:** HIGH (verified against official docs, multiple sources, direct codebase inspection)

---

## Current Stack (What Exists)

| Layer | Technology | Version | Status |
|-------|-----------|---------|--------|
| Mobile app | Flutter / Dart | SDK ^3.11.0 | Production — correct choice |
| State management | Provider | ^6.1.2 | Production — needs upgrade path |
| Navigation | Implicit Navigator 1.0 | — | Production — needs replacement |
| Backend framework | FastAPI | latest | Production — correct choice |
| ORM | SQLModel + SQLAlchemy | — | Production — sync mode only |
| DB | PostgreSQL + Alembic | pool_size=20, max_overflow=40 | Production — connection pool tuned |
| Background tasks | ThreadPoolExecutor(max_workers=4) | — | Production — acceptable now, will become a ceiling |
| AI providers | Gemini 2.5 Flash → Claude Sonnet → OpenAI GPT-4o | — | Production — well-architected fallback chain |
| Storage | GCS / Supabase / S3-MinIO (runtime switch) | — | Production — good multi-backend abstraction |
| Subscriptions | Stripe (server-side webhooks) | — | Production — see compliance note below |
| PDF generation | fpdf2 (latin1, no unicode) | — | Production — critical limitation |
| Push notifications | Firebase Messaging | ^15.1.5 | Production — correct |
| Crash reporting | Firebase Crashlytics | ^4.3.2 | Production — correct |
| Rate limiting | slowapi | — | Production — correct |
| Auth | JWT (access + refresh) + Google Sign-In | — | Production — correct |

---

## Assessment: What Is Solid and Should Not Change

These choices are proven, well-matched to the domain, and have no meaningful alternatives worth switching to.

### FastAPI + PostgreSQL + SQLModel + Alembic

The standard Python API stack for 2025–2026. FastAPI dominates Python API development for good reason: async-native, automatic OpenAPI, Pydantic validation at zero extra cost. SQLModel integrates with Alembic cleanly. The current migration history (24 migration files since February 2026) is well-structured. **Do not replace this stack.**

The one gap: the engine is running in **synchronous mode** (`create_engine`, not `create_async_engine`). See "What Is Missing" below.

### Gemini → Claude → OpenAI Fallback Chain

This is architecturally sound and production-grade. The `ai_providers.py` abstraction using Protocol classes means you can swap or add providers without touching business logic. Gemini 2.5 Flash as primary for both vision and text is the right cost/performance choice for the construction document analysis use case — it handles PDFs natively (up to 50 MB per file), renders visual symbols on blueprints, and is substantially cheaper than GPT-4o for the volume of page-by-page processing done in `checklist_inteligente`. **Do not change the architecture; do track model releases.** Gemini 3 Flash is now available and delivers better construction document parsing than 2.5 Flash.

### Firebase Messaging + Crashlytics

Both are the industry standard for Flutter apps. No meaningful competitor. Keep as-is.

### Google Cloud Run

Correct infrastructure for a stateless FastAPI backend. The cold-start risk is the only operational concern — see remediation below. **Do not migrate away from Cloud Run.**

---

## What Is Missing or Below Current Best Practice

These are gaps that will cause real problems at scale or under app store review pressure.

### 1. Synchronous SQLAlchemy — The Biggest Technical Debt

**What the code does now:** `create_engine(...)` — blocking sync driver (psycopg2 assumed). All route handlers use `def`, not `async def`. ThreadPoolExecutor for background tasks.

**Why this matters:** Cloud Run handles concurrent requests per instance. With sync SQLAlchemy and `def` routes, each request blocks a thread. FastAPI runs sync routes in a thread pool (default 40 threads). Under concurrent AI-enrichment workloads (the checklist background tasks already use 4 threads), the connection pool saturates and requests queue. Benchmarks: asyncpg yields 10–20x QPS uplift over psycopg2 under concurrent load.

**What to use instead:**
- `create_async_engine` with `asyncpg` as the PostgreSQL driver
- `AsyncSession` from `sqlalchemy.ext.asyncio`
- Convert route handlers to `async def`
- Use FastAPI's `BackgroundTasks` or `asyncio.create_task` for async background work instead of ThreadPoolExecutor

**Migration path is incremental:** SQLModel supports async sessions in recent versions. Alembic migrations are unaffected — they run synchronously at deploy time regardless.

**Confidence:** HIGH — verified with FastAPI official docs and multiple production case studies.

### 2. Provider → Riverpod (State Management)

**What the code uses now:** `provider: ^6.1.2` with standard `ChangeNotifier` providers (`obra_provider.dart`, `auth_provider.dart`, `subscription_provider.dart`).

**Why this is a problem:** Provider is no longer the recommended approach in the Flutter ecosystem. Riverpod 3.0 (released September 2025) delivers compile-time safety, automatic disposal, and testable providers outside the widget tree. The current codebase has ~50 screens; at that scale, Provider's lack of scoped lifecycle management causes subtle state leaks between screens (a known issue in construction apps where users switch between multiple obras).

**What to use:** Riverpod 3.0. Use `flutter_riverpod: ^3.x` with code generation (`riverpod_annotation`, `riverpod_generator`). Migration is incremental — Provider and Riverpod can coexist in the same app during migration.

**Note:** Riverpod 3.0 is new as of September 2025. If stability concerns exist, Riverpod 2.x remains production-proven and is a large improvement over Provider with the same migration cost.

**Confidence:** HIGH — multiple independent sources confirm Riverpod as the 2025–2026 Flutter standard.

### 3. Navigation — No go_router

**What the code uses now:** Implicit `Navigator.push` / `Navigator.pop` throughout `~50 screens`. There is no centralized routing definition.

**Why this is a problem:** Deep links (notification tap → open specific obra or etapa) are essential for a construction management app where foremen get push notifications. Without `go_router`, deep link handling is manual and brittle. The Firebase Messaging + local notifications integration (`notification_service.dart`) currently has no way to encode typed routes that survive app cold starts.

**What to use:** `go_router: ^15.x` (maintained by the Flutter team). Define all routes declaratively, use route guards for auth/subscription gates, and wire Firebase notification payloads to named routes.

**Confidence:** HIGH — go_router is Flutter's official recommendation for apps requiring deep linking.

### 4. Offline-First Local Cache — Missing Entirely

**What the code does now:** All data is fetched from the server. No local cache. No offline support.

**Why this matters for construction:** Construction sites frequently have poor connectivity (underground, concrete structures). Field workers marking checklist items or uploading photos are blocked when offline. This is the single largest user experience gap relative to competitors like Procore, Fieldwire, and PlanGrid.

**What to add:** Use `drift: ^2.x` (SQLite-based, type-safe, reactive) as the local database. Drift with Riverpod providers creates an offline-first read layer where the UI reads from local SQLite and a background sync service reconciles with the server. Priorities for the domain: checklists (read offline, write queue), evidencias photos (upload queue when back online), financial summary (read only cache).

**Do not use Isar:** Isar's development has been inconsistent; Drift is more stable for relational/structured construction data. Do not use Hive (no SQL, no relationships).

**Confidence:** MEDIUM — based on multiple sources and community consensus; specific sync conflict resolution for this data model needs design work.

### 5. PDF Generation — fpdf2 Is Crippled for Portuguese

**What the code does now:** `pdf.py` uses fpdf2 with the Helvetica font, which is limited to latin1. The `_safe()` function silently replaces non-latin1 characters with `?`. This means all Portuguese special characters (ã, ç, é, ê, õ, ú, í, â, ô, etc.) in PDF reports are corrupted.

**This is a bug in production, not a future concern.**

**What to replace it with:** WeasyPrint + Jinja2. Define report templates as HTML/CSS, render to PDF. Full Unicode (UTF-8), proper Portuguese typography, capable of including embedded photos from evidencias, Curva-S charts rendered as SVG, and professional formatting. WeasyPrint runs on Cloud Run (no browser dependency). The change also enables rich financial reports — currently the financial router has all the data but no PDF export endpoint.

**Alternative:** ReportLab (more control but significantly more boilerplate for the same result). Use WeasyPrint unless a specific chart-embedding requirement forces ReportLab.

**Confidence:** HIGH — fpdf2 latin1 limitation is a documented library constraint, not a configuration issue.

### 6. Background Task Architecture — ThreadPoolExecutor Is a Ceiling

**What the code does now:** A `ThreadPoolExecutor(max_workers=4)` in `checklist_inteligente.py` for AI background processing. Background tasks die if the Cloud Run instance is scaled down mid-processing.

**Why this matters:** AI checklist generation can take 60–180 seconds per multi-page PDF. If Cloud Run scales to zero or the instance restarts, the task and its progress are lost. Users currently see `status: ERRO` with no recovery path.

**What to add in the near term:** Cloud Tasks (Google Cloud) as a persistent task queue. The checklist generation job posts to Cloud Tasks on `POST /iniciar`; Cloud Tasks calls a dedicated `/api/internal/process-checklist/{log_id}` endpoint with retries and timeouts. This gives task durability without adding Celery + Redis infrastructure.

**What to avoid:** Do not introduce Celery + Redis on Cloud Run. It requires persistent sidecars (Redis), worker processes, and monitoring. The overhead is disproportionate to the task volume of a B2C construction app. Cloud Tasks is managed, requires no extra infrastructure, and integrates natively with Cloud Run.

**Confidence:** HIGH for Cloud Tasks recommendation; MEDIUM for specific Cloud Tasks vs Pub/Sub choice (both are viable).

### 7. Subscriptions — Stripe on Mobile Has App Store Compliance Risk

**What the code does now:** Stripe (server-side webhooks, `subscription.py`). The mobile app presumably triggers payment flow through `paywall_screen.dart`. The original stack comment in `schemas.py` references "migrate from revenuecat to stripe" (migration `0019_rename_revenuecat_to_stripe.py`).

**The compliance risk:** Google Play's deadline (October 6, 2025) requires all apps selling digital subscriptions to use Google Play Billing for Android. Apple's restrictions still apply outside the US App Store. Using Stripe directly within the app for subscription purchases (not web-initiated purchases) will cause Play Store rejection.

**What is safe:** Stripe remains correct for web-initiated purchases (e.g. a user who subscribes through a browser, then unlocks the app on their phone). For in-app subscription purchase flows inside the Flutter app, you need `google_play_billing` (Android) and `storekit_2` (iOS), or a wrapper like `in_app_purchase: ^4.x` (Flutter's official plugin).

**Recommendation:** Use `in_app_purchase` for the in-app purchase flow and retain Stripe for web billing. The backend `subscription.py` can verify purchase receipts from either path. This is the pattern RevenueCat was originally providing — consider whether re-introducing RevenueCat is simpler than implementing dual-path verification logic from scratch.

**Confidence:** HIGH for the compliance risk; MEDIUM for which specific implementation path is best (depends on how the current paywall is wired).

---

## Supporting Libraries — Recommended Additions

| Library | Version | Purpose | Priority |
|---------|---------|---------|----------|
| `go_router` | ^15.x | Deep-link-capable routing | High |
| `flutter_riverpod` | ^3.x | State management replacement | High |
| `riverpod_annotation` | ^3.x | Riverpod code generation | High |
| `drift` | ^2.x | Offline-first SQLite cache | Medium |
| `drift_sqlite_async` | ^0.x | PowerSync integration (future) | Low |
| `geolocator` | ^13.x | GPS coordinates on photo evidence | Medium |
| `in_app_purchase` | ^4.x | Play Store / App Store billing compliance | High |
| `asyncpg` | ^0.30 | Async PostgreSQL driver (backend) | High |
| `weasyprint` | ^62.x | Full-Unicode PDF generation (backend) | High |
| `jinja2` | ^3.1 | PDF/report template rendering (backend) | High |
| `google-cloud-tasks` | ^2.x | Durable background AI processing (backend) | Medium |

---

## Libraries to Keep Unchanged

| Library | Why Keep |
|---------|---------|
| `fl_chart` | Mature, Curva-S already implemented |
| `firebase_messaging` | Industry standard, no replacement needed |
| `firebase_crashlytics` | Industry standard |
| `syncfusion_flutter_pdfviewer` | PDF viewer for construction documents — correct choice |
| `syncfusion_flutter_xlsio` | Excel export — correct choice |
| `google_mobile_ads` | Needed for freemium model |
| `cached_network_image` | Correct for evidence photo display |
| `flutter_secure_storage` | Correct for JWT token storage |
| `local_auth` | Biometric auth — keep |
| `slowapi` | Rate limiting in FastAPI — correct |
| `sqlmodel` | Keep; upgrade to async usage pattern |
| `alembic` | Migration tooling — keep as-is |

---

## Model Version Tracking (AI Chain)

The `ai_providers.py` hardcodes model strings. These require periodic updates as Google/Anthropic/OpenAI release new versions.

| Provider | Current | Next Candidate | Action |
|----------|---------|---------------|--------|
| Gemini | `gemini-2.5-flash` | `gemini-3-flash` | Evaluate — Gemini 3 shows better construction blueprint parsing |
| Claude | `claude-sonnet-4-6` | Current is correct | No change needed |
| Claude fallback | `claude-haiku-4-5-20251001` | Current is correct | No change needed |
| OpenAI | `gpt-4o` | Current is correct | No change needed |
| OpenAI cheap | `gpt-4o-mini` | Current is correct | No change needed |

---

## Infrastructure — Immediate Operational Fix

**Cloud Run minimum instances:** Set `--min-instances=1` on the production service. Cold starts for a FastAPI app loading multiple AI client libraries (google-generativeai, anthropic, openai) take 4–8 seconds. For an app used on construction sites (often a single user per obra, sporadic sessions), cold starts are the single largest source of user-perceived latency. Cost at 256Mi with CPU-during-requests: ~$3–5/month.

**Cloud SQL connection pooling:** Google announced Managed Connection Pooling for Cloud SQL at Cloud Next 2025. If the PostgreSQL instance is Cloud SQL, enable it. This is especially important once the async migration is done — asyncpg creates connections aggressively and the current `pool_size=20, max_overflow=40` may exhaust `max_connections=100` under concurrent AI load.

---

## Alternatives Considered and Rejected

| Category | Recommended | Rejected | Reason Rejected |
|----------|-------------|---------|----------------|
| State management | Riverpod 3 | BLoC | BLoC boilerplate is disproportionate for a B2C app; Riverpod covers all use cases with less code |
| State management | Riverpod 3 | GetX | GetX anti-patterns in navigation and state conflict with clean architecture; not recommended by Flutter team |
| Local DB | Drift | Isar | Isar development unstable; Drift is SQLite-backed with strong relational model matching construction data |
| Local DB | Drift | Hive | Hive has no relational model; wrong for checklist/etapa/obra hierarchies |
| Background tasks | Cloud Tasks | Celery + Redis | Celery requires stateful Redis sidecar; wrong for Cloud Run stateless model |
| PDF | WeasyPrint | ReportLab | WeasyPrint is simpler to template, produces better output for document-heavy reports |
| PDF | WeasyPrint | fpdf2 | fpdf2 has a hard latin1 limitation that corrupts Portuguese characters |
| Subscriptions | in_app_purchase | flutter_stripe (in-app) | App store compliance: Play Store requires Google Play Billing for digital goods as of Oct 2025 |
| Navigation | go_router | AutoRoute | go_router is maintained by Flutter team; AutoRoute adds code-gen complexity with no clear benefit |

---

## Sources

- Flutter official architecture guide: https://docs.flutter.dev/app-architecture/guide
- Flutter state management recommendations: https://docs.flutter.dev/app-architecture/recommendations
- Riverpod 3.0 release: https://codewithandrea.com/newsletter/september-2025/
- Riverpod vs Provider comparison: https://riverpod.dev/docs/from_provider/provider_vs_riverpod
- go_router official recommendation: https://docs.flutter.dev/ui/navigation
- Cloud Run FastAPI performance tuning: https://davidmuraya.com/blog/fastapi-performance-tuning-on-google-cloud-run/
- Cloud Run min-instances and cold start: https://atabak.net/devops/2025/08/23/cloud-run-scaling-concurrency.html
- FastAPI async SQLAlchemy production pattern: https://testdriven.io/blog/fastapi-sqlmodel/
- asyncpg performance benchmarks: https://leapcell.io/blog/building-high-performance-async-apis-with-fastapi-sqlalchemy-2-0-and-asyncpg
- Drift offline-first Flutter: https://777genius.medium.com/building-offline-first-flutter-apps-a-complete-sync-solution-with-drift-d287da021ab0
- Drift vs Isar vs Hive comparison: https://medium.com/@flutter-app/hive-vs-isar-vs-drift-best-offline-db-for-flutter-c6f73cf1241e
- WeasyPrint vs ReportLab: https://dev.to/claudeprime/generate-pdfs-in-python-weasyprint-vs-reportlab-ifi
- Google Play Billing compliance deadline: https://medium.com/@oyetaiwophilip/solving-in-app-purchases-in-flutter-native-google-play-billing-apple-storekit-without-a-cloud-8d2b5737ed36
- Stripe vs in-app purchase compliance 2026: https://adapty.io/blog/can-you-use-stripe-for-in-app-purchases/
- Gemini 2.5 Flash PDF limits: https://discuss.ai.google.dev/t/clarifying-gemini-2-5-flash-api-document-limits-supported-file-types-and-size-constraints/110852
- Gemini 3 construction document parsing: https://www.tensorlake.ai/blog/gemini-3-available
- FastAPI background tasks vs Celery: https://medium.com/@ajaygohil2563/fastapi-background-tasks-internal-architecture-and-comparison-with-celery-5c5897f65725
- Cloud SQL managed connection pooling: https://discuss.google.dev/t/optimizing-performance-and-scaling-with-managed-connection-pooling-for-cloud-sql-for-postgresql/270528
