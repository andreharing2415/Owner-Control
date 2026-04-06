# External Integrations

**Analysis Date:** 2026-04-06

## APIs & External Services

**AI Providers (Fallback Chain):**
- Google Gemini (`gemini-2.5-flash`) — primary AI provider for all chains
  - SDK/Client: `google-generativeai 0.8.0`
  - Auth: `GEMINI_API_KEY`
  - Implementation: `server/app/ai_providers.py` — `GeminiProvider`
- Anthropic Claude (`claude-sonnet-4-6`, `claude-haiku-4-5-20251001`) — secondary fallback
  - SDK/Client: `anthropic 0.40.0`
  - Auth: `ANTHROPIC_API_KEY`
  - Implementation: `server/app/ai_providers.py` — `ClaudeProvider`
- OpenAI GPT-4o / GPT-4o-mini — tertiary fallback, also supports web search
  - SDK/Client: `openai 1.75.0`
  - Auth: `OPENAI_API_KEY`
  - Implementation: `server/app/ai_providers.py` — `OpenAIProvider`, `OpenAIWebSearchProvider`

**AI Chain configurations** (defined in `server/app/ai_providers.py`):
- `get_document_vision_chain()` — Gemini → Claude → OpenAI (document analysis)
- `get_visual_inspection_chain()` — Gemini → Claude → OpenAI (photo inspection)
- `get_checklist_page_chain()` — Gemini → OpenAI-mini → Claude Haiku (checklist pages)
- `get_checklist_generation_chain()` — Gemini → OpenAI-WebSearch (AI checklist gen)
- `get_schedule_text_chain()` — Gemini → OpenAI (schedule/cronograma generation)

**Payments:**
- Stripe — subscription billing with checkout, webhooks, and customer portal
  - SDK/Client: `stripe 8.0.0`
  - Auth: `STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET`
  - Price IDs: `STRIPE_PRICE_ID_ESSENCIAL`, `STRIPE_PRICE_ID_COMPLETO`, `STRIPE_PRICE_ID` (legacy)
  - Redirect URLs: `STRIPE_SUCCESS_URL`, `STRIPE_CANCEL_URL`
  - Webhook endpoint: `POST /api/webhooks/stripe` (`server/app/routers/subscription.py`)

## Data Storage

**Databases:**
- PostgreSQL — primary relational database
  - Connection: `DATABASE_URL`
  - Client: `psycopg2-binary 2.9.9` via SQLModel/SQLAlchemy
  - Connection pool: 20 min / 40 max overflow, 30-min recycle, pre-ping enabled (`server/app/db.py`)
  - SSL: enforced when `REQUIRE_SSL=1` or `true`
  - Migrations: Alembic (`server/alembic/`, config at `server/alembic.ini`)

**File Storage (multi-backend, auto-selected):**
Defined in `server/app/storage.py`, priority order:
1. **Supabase Storage** (if `SUPABASE_URL` + `SUPABASE_SERVICE_KEY` set) — private buckets via REST API
   - Auth: `SUPABASE_URL`, `SUPABASE_SERVICE_KEY`
2. **S3 / MinIO** (if `S3_ENDPOINT_URL` set) — S3-compatible, used in local dev
   - Auth: `S3_ENDPOINT_URL`, `S3_ACCESS_KEY`, `S3_SECRET_KEY`, `S3_REGION`, `S3_BUCKET`, `S3_PUBLIC_URL`
   - SDK: `boto3 1.34.34`
3. **Google Cloud Storage** (default/production)
   - Default bucket location: `southamerica-east1` (env: `GCS_LOCATION`)
   - SDK: `google-cloud-storage 2.14.0`
   - Bucket configured via `S3_BUCKET` env var (shared name)

**Caching:**
- None detected

## Authentication & Identity

**Auth Provider:**
- Custom JWT (email+password) — primary auth
  - Implementation: `server/app/auth.py`
  - Algorithm: HS256, issuer: `obramaster-api`, audience: `obramaster-app`
  - Access token expiry: 60 minutes
  - Refresh token expiry: 7 days
  - Secret: `JWT_SECRET_KEY`
  - Password hashing: `bcrypt 4.1.2`

- Google OAuth (ID token verification) — sign in with Google
  - Flutter SDK: `google_sign_in ^6.2.1`
  - Backend verification: `google-auth 2.29.0` + `firebase-admin 6.5.0`
  - Flow: Flutter obtains ID token → sends to backend (`POST /api/auth/google`) → verifies with Google

- Biometric authentication — local device auth (PIN/fingerprint/face)
  - Flutter SDK: `local_auth ^2.3.0`
  - Scope: client-side only, unlocks cached JWT

## Notifications

**Push Notifications:**
- Firebase Cloud Messaging (FCM) — mobile push notifications
  - Flutter SDK: `firebase_messaging ^15.1.5` + `firebase_core ^3.8.1`
  - Backend SDK: `firebase-admin 6.5.0`
  - Backend implementation: `server/app/push.py`
  - Config: `FIREBASE_CREDENTIALS_JSON` (path to service account JSON)
  - Graceful degradation: module operates in silent mode when `FIREBASE_CREDENTIALS_JSON` is unset

- Local notifications — in-app notifications
  - Flutter SDK: `flutter_local_notifications ^18.0.1`

**Crash Reporting:**
- Firebase Crashlytics — production crash reporting
  - Flutter SDK: `firebase_crashlytics ^4.3.2`

## Email

**Email Providers (priority order, all optional):**
Implementation in `server/app/email_service.py`:

1. Generic SMTP (primary) — Umbler, Gmail, or any SMTP provider
   - Auth: `SMTP_HOST`, `SMTP_USER`, `SMTP_PASSWORD`, `SMTP_PORT` (default 587), `SMTP_FROM`, `EMAIL_FROM_NAME`
2. Gmail SMTP (legacy fallback)
   - Auth: `GMAIL_USER`, `GMAIL_APP_PASSWORD`
3. SendGrid — transactional email
   - Auth: `SENDGRID_API_KEY`, `EMAIL_FROM`
4. Resend — transactional email
   - Auth: `RESEND_API_KEY`, `EMAIL_FROM`

**Use case:** Magic link invites for obra collaborators (`server/app/email_service.py`)

## Monetization

**Advertising:**
- Google AdMob — display ads for free-tier users
  - Flutter SDK: `google_mobile_ads ^5.3.0`
  - Controlled by `show_ads` flag from subscription plan config (`server/app/subscription.py`)

**Subscription Plans:**
- `gratuito` — free tier with ads and usage limits
- `essencial` — paid tier (Stripe `STRIPE_PRICE_ID_ESSENCIAL`)
- `completo` — paid tier (Stripe `STRIPE_PRICE_ID_COMPLETO`)
- Rewarded usage: watch-ad-to-unlock feature with `can_watch_rewarded` flag

## CI/CD & Deployment

**Hosting:**
- Google Cloud Run — backend API
  - Project: `mestreobra` (env: `GCP_PROJECT`)
  - Service: `mestreobra-backend` (env: `CLOUD_RUN_SERVICE`)
  - Region: `us-central1`
  - Image registry: Google Container Registry (`gcr.io/mestreobra/mestreobra-backend`)
  - Build: Cloud Build via `gcloud builds submit`

**CI Pipeline:**
- None detected (manual deploy via `server/deploy-cloudrun.sh`)

**Mobile Distribution:**
- Android release signing: keystore at `android/upload-keystore.jks`
  - Key alias: `upload` (configured in `android/app/build.gradle.kts`)

## Webhooks & Callbacks

**Incoming:**
- `POST /api/webhooks/stripe` — Stripe subscription events
  - Handled events: `checkout.session.completed`, `customer.subscription.updated`, `customer.subscription.deleted`, `invoice.payment_succeeded`, `invoice.payment_failed`
  - Signature verification: `STRIPE_WEBHOOK_SECRET` via `stripe.Webhook.construct_event()`
  - Implementation: `server/app/routers/subscription.py`

- `GET /api/convites/aceitar?token={token}` — magic link invite acceptance
  - Deep link intercepted by Flutter app
  - Implementation: `server/app/routers/convites.py`

**Outgoing:**
- Email via SMTP/SendGrid/Resend for invite notifications
- Push notifications via FCM to registered device tokens

## Environment Configuration

**Required env vars (backend):**
- `DATABASE_URL` — PostgreSQL connection string
- `JWT_SECRET_KEY` — JWT signing secret

**Optional env vars (backend):**
- `REQUIRE_SSL` — enforce SSL on DB connection (`1`/`true`)
- `S3_BUCKET` — storage bucket name
- `SUPABASE_URL`, `SUPABASE_SERVICE_KEY` — Supabase storage
- `S3_ENDPOINT_URL`, `S3_ACCESS_KEY`, `S3_SECRET_KEY`, `S3_REGION`, `S3_PUBLIC_URL` — S3/MinIO
- `GCS_LOCATION` — GCS bucket region (default: `southamerica-east1`)
- `GEMINI_API_KEY` — Google Gemini AI
- `ANTHROPIC_API_KEY` — Anthropic Claude AI
- `OPENAI_API_KEY` — OpenAI GPT
- `FIREBASE_CREDENTIALS_JSON` — path to Firebase service account JSON
- `STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET` — Stripe billing
- `STRIPE_PRICE_ID_ESSENCIAL`, `STRIPE_PRICE_ID_COMPLETO`, `STRIPE_PRICE_ID` — Stripe price IDs
- `STRIPE_SUCCESS_URL`, `STRIPE_CANCEL_URL` — Stripe redirect URLs
- `SMTP_HOST`, `SMTP_USER`, `SMTP_PASSWORD`, `SMTP_PORT`, `SMTP_FROM` — generic SMTP
- `GMAIL_USER`, `GMAIL_APP_PASSWORD` — Gmail SMTP fallback
- `SENDGRID_API_KEY` — SendGrid email
- `RESEND_API_KEY` — Resend email
- `EMAIL_FROM`, `EMAIL_FROM_NAME` — sender identity
- `APP_BASE_URL` — public URL for magic links

**Secrets location:**
- Backend: `.env` file in `server/` directory (loaded by `python-dotenv`)
- Android signing: `android/upload-keystore.jks` (keystore file)
- Firebase: path referenced by `FIREBASE_CREDENTIALS_JSON` (typically mounted as Cloud Run secret)

---

*Integration audit: 2026-04-06*
