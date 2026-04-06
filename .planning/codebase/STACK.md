# Technology Stack

**Analysis Date:** 2026-04-06

## Languages

**Primary:**
- Dart 3.x (SDK ^3.11.0) - Flutter mobile/web app (`lib/`)
- Python 3.11 - Backend API server (`server/app/`)

**Secondary:**
- Kotlin - Android native integration (`android/`)
- Shell - Deployment scripts (`server/deploy-cloudrun.sh`, `server/restart.sh`)

## Runtime

**Environment:**
- Flutter SDK (Dart 3.11+) for the mobile app
- Python 3.11 (`python:3.11-slim` Docker base image) for the backend

**Package Manager:**
- Dart: `pub` (Flutter) — lockfile at `pubspec.lock`
- Python: `pip` — lockfiles at `server/requirements.txt` and `server/requirements-dev.txt`

**Lockfile:**
- `pubspec.lock` — present and committed
- `server/requirements.txt` — pinned versions, present

## Frameworks

**Core (Flutter):**
- Flutter (Material Design) — cross-platform mobile/web UI

**Core (Backend):**
- FastAPI 0.110.0 — REST API framework (`server/app/main.py`)
- Uvicorn 0.27.1 (standard) — ASGI server
- SQLModel 0.0.16 — ORM built on SQLAlchemy + Pydantic

**Testing:**
- Flutter: `flutter_test` (built-in SDK) + `mockito ^5.4.4`
- Python: `pytest 8.1.1` + `pytest-asyncio 0.23.5`

**Build/Dev (Flutter):**
- `build_runner ^2.4.9` — code generation for mockito
- `flutter_launcher_icons ^0.14.3` — icon generation
- `flutter_native_splash ^2.4.6` — splash screen generation

**Build/Dev (Python):**
- `mypy 1.9.0` — static type checking
- `ruff 0.3.4` — linting/formatting
- `bandit 1.7.8` — security static analysis
- `alembic 1.13.1` — database migrations (`server/alembic/`)

## Key Dependencies

**Critical (Flutter):**
- `provider ^6.1.2` — state management
- `http ^1.2.1` — HTTP client for API calls
- `flutter_secure_storage ^9.2.2` — secure JWT token storage
- `google_sign_in ^6.2.1` — Google OAuth integration
- `local_auth ^2.3.0` — biometric authentication
- `firebase_core ^3.8.1` — Firebase base SDK
- `firebase_messaging ^15.1.5` — push notifications
- `firebase_crashlytics ^4.3.2` — crash reporting

**UI/UX (Flutter):**
- `fl_chart ^0.68.0` — charts and graphs
- `syncfusion_flutter_pdfviewer ^28.2.7` — PDF rendering
- `syncfusion_flutter_xlsio ^28.2.7` — Excel export
- `flutter_svg ^2.0.17` — SVG support
- `cached_network_image ^3.4.1` — network image caching
- `google_mobile_ads ^5.3.0` — AdMob for monetization
- `share_plus ^10.1.4` — native share sheet

**Critical (Backend):**
- `psycopg2-binary 2.9.9` — PostgreSQL driver
- `python-jose[cryptography] 3.3.0` — JWT creation/validation (`server/app/auth.py`)
- `bcrypt 4.1.2` — password hashing
- `stripe 8.0.0` — payment processing (`server/app/routers/subscription.py`)
- `firebase-admin 6.5.0` — push notifications and Google token verification
- `slowapi 0.1.9` — rate limiting (`server/app/rate_limit.py`)

**AI (Backend):**
- `openai 1.75.0` — OpenAI GPT-4o integration
- `anthropic 0.40.0` — Anthropic Claude integration
- `google-generativeai 0.8.0` — Google Gemini integration
- `pymupdf 1.24.0` — PDF parsing for AI document analysis

**Storage (Backend):**
- `boto3 1.34.34` — S3/MinIO compatible storage
- `google-cloud-storage 2.14.0` — Google Cloud Storage
- `fpdf2 2.7.8` — PDF generation

**Utilities (Backend):**
- `httpx 0.27.0` — async HTTP client (Supabase storage, email)
- `python-multipart 0.0.9` — file upload handling
- `python-dateutil 2.9.0` — date parsing
- `email-validator 2.1.1` — email format validation
- `python-magic 0.4.27` — file type detection

## Configuration

**Environment (Flutter):**
- `API_BASE_URL` — injected via `--dart-define` at build time
- Default: `https://mestreobra-backend-530484413221.us-central1.run.app`
- Defined in `lib/api/api.dart` via `String.fromEnvironment`

**Environment (Backend):**
- Loaded from `.env` file via `python-dotenv` (`server/app/main.py`)
- Required: `DATABASE_URL`, `JWT_SECRET_KEY`
- Optional: `REQUIRE_SSL`, `S3_BUCKET`, `FIREBASE_CREDENTIALS_JSON`, etc.

**Build:**
- Android: `android/app/build.gradle.kts` — minSdk from Flutter defaults, compileSdk from Flutter defaults, JVM 17
- Android app ID: `br.mestredaobra.app`
- Android min SDK: 21 (set in `pubspec.yaml` flutter_launcher_icons config)
- Docker: `server/Dockerfile` — python:3.11-slim, exposes port 8080
- Database migrations: `server/alembic/` with `alembic.ini`

## Platform Requirements

**Development:**
- Flutter SDK 3.11+
- Dart SDK ^3.11.0
- Python 3.11
- PostgreSQL (or `DATABASE_URL` pointing to hosted instance)
- Optional: MinIO for local S3 storage (`S3_ENDPOINT_URL`)
- Android NDK 28.2.13676358 (for Android builds)

**Production:**
- Google Cloud Run (`server/deploy-cloudrun.sh`, project `mestreobra`, region `us-central1`)
- Cloud Build for Docker image build/push to GCR
- Service URL: `https://mestreobra-backend-530484413221.us-central1.run.app`
- Container: 1 CPU, 1Gi memory, timeout 300s

---

*Stack analysis: 2026-04-06*
