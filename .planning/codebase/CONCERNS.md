# Codebase Concerns

**Analysis Date:** 2026-04-06

---

## Tech Debt

**No backend service layer (ARQ-02v2):**
- Issue: 7 routers make direct DB queries with duplicated ownership checks, aggregation, and cascade logic. Only `server/app/services/documento_service.py` exists as a service.
- Files: `server/app/routers/obras.py`, `server/app/routers/etapas.py`, `server/app/routers/checklist_inteligente.py`, `server/app/routers/financeiro.py`, `server/app/routers/subscription.py`, `server/app/routers/prestadores.py`, `server/app/routers/convites.py`, `server/app/routers/cronograma.py`
- Impact: Business logic scattered across routers, hard to test, hard to change without regressions.
- Fix approach: Create `server/app/services/` files per domain: `obra_service.py`, `etapa_service.py`, `checklist_service.py`, `financeiro_service.py`, `subscription_service.py`, `prestadores_service.py`, `convites_service.py`.

**Flutter screens make direct API calls without state management (ARQ-01v2):**
- Issue: Every screen instantiates `ApiClient()` directly (`final ApiClient _api = ApiClient()`). No shared state, no cache, no deduplication of in-flight requests, no testability.
- Files: All 40+ files in `lib/screens/`
- Impact: Same data fetched repeatedly across screens; impossible to write unit tests for screen logic.
- Fix approach: Migrate to Riverpod providers with typed state. Inject `ApiClient` via provider.

**Duplicated error handling pattern in 21+ Flutter screens (COMPL-02v2):**
- Issue: Identical `catch (e)` block — check `AuthExpiredException`, show `SnackBar`, navigate to login — repeated in every screen.
- Files: All 21+ files in `lib/screens/`
- Impact: Any change to error UX requires touching 21+ files.
- Fix approach: Create `ApiErrorHandlerMixin` with `withErrorHandling<T>()` method.

**Duplicate migration revision IDs:**
- Issue: Two migration files both declare `revision = "20260309_0014"`: `server/alembic/versions/20260309_0014_add_valor_realizado.py` and `server/alembic/versions/20260309_0014_checklist_unificado.py`. Both point to the same `down_revision = "20260311_0013"`. This breaks `alembic upgrade head` on a fresh database.
- Files: `server/alembic/versions/20260309_0014_add_valor_realizado.py`, `server/alembic/versions/20260309_0014_checklist_unificado.py`
- Impact: New deployments or fresh DB setups will fail with an Alembic multiple heads error.
- Fix approach: Rename one file, assign it a new unique revision ID and chain them sequentially.

**Migration chain revision format inconsistency:**
- Issue: Migrations up to `0022` use full date-prefixed IDs like `"20260319_0022"` but `0023` and `0024` switch to bare `"0023"` / `"0024"` revision strings.
- Files: `server/alembic/versions/20260319_0023_projetodoc_erro_detalhe.py`, `server/alembic/versions/20260319_0024_composite_indexes.py`
- Impact: Minor inconsistency, but breaks convention and can confuse ordering/tooling.
- Fix approach: Rename to full date-prefix format and update `down_revision` references.

**`on_event("startup")` deprecated FastAPI pattern:**
- Issue: `server/app/main.py` uses `@app.on_event("startup")` which is deprecated in FastAPI 0.93+. The codebase runs FastAPI 0.110.0.
- Files: `server/app/main.py` (line 75)
- Impact: Will generate deprecation warnings; will break in a future FastAPI upgrade.
- Fix approach: Replace with `lifespan` context manager pattern using `@asynccontextmanager`.

**`api.dart` is a 2458-line god file:**
- Issue: All API client code, all model classes (`Obra`, `Etapa`, `ChecklistItem`, `AtividadeCronograma`, `Prestador`, etc.) live in a single file.
- Files: `lib/api/api.dart`
- Impact: Hard to navigate, long compile times, merge conflicts.
- Fix approach: Split into `lib/api/client.dart`, `lib/models/obra.dart`, `lib/models/etapa.dart`, etc.

**Unresolved TODO for push notification deep-link:**
- Issue: `// TODO (Fase Auth): navegar para a obra indicada em message.data['obra_id']` — refers to a "Fase Auth" that no longer exists as a phase.
- Files: `lib/services/notification_service.dart` (line 169)
- Impact: Push notifications do not deep-link into the target obra.
- Fix approach: Implement deep-link navigation or remove the TODO and document the limitation.

**Subscription cancellation immediately downgrades plan:**
- Issue: In `cancel-subscription`, `current_user.plan` and `sub.plan` are set to `"gratuito"` immediately, but `stripe.Subscription.modify(cancel_at_period_end=True)` keeps the Stripe subscription active until the billing period ends. Users lose access they paid for.
- Files: `server/app/routers/subscription.py` (lines 244, 248)
- Impact: Paying users lose features before their paid period expires.
- Fix approach: Only downgrade plan on `customer.subscription.deleted` webhook event, not at cancellation request time.

---

## Known Bugs

**Duplicate revision IDs break fresh Alembic migrations:**
- Symptoms: `alembic upgrade head` on a clean database throws `Multiple head revisions`.
- Files: `server/alembic/versions/20260309_0014_add_valor_realizado.py`, `server/alembic/versions/20260309_0014_checklist_unificado.py`
- Trigger: Any fresh deployment, new developer setup, or CI environment.
- Workaround: Manually delete one of the two files before running migrations.

**SSE stream continues processing after client disconnect (PERF-10v2):**
- Symptoms: After client disconnects mid-stream, the AI checklist generator keeps consuming CPU and API tokens.
- Files: `server/app/routers/checklist_inteligente.py` (`stream_checklist_inteligente`, lines 61-100)
- Trigger: User closes the checklist generation screen mid-stream.
- Workaround: None. Wasted AI API cost per disconnect.

---

## Security Considerations

**SSL not required by default for database connections (SEC-08v2):**
- Risk: Database traffic unencrypted unless `REQUIRE_SSL=1` env var is explicitly set. Default is insecure.
- Files: `server/app/db.py` (lines 14-15)
- Current mitigation: None if env var is absent.
- Recommendations: Invert logic — enable SSL by default, allow explicit `REQUIRE_SSL=false` only for local dev.

**Google OAuth creates account with empty email when Google returns no email (SEC-09v2):**
- Risk: A Google account without an email could create a user with `email=""`, with `nome = "".split("@")[0]` producing an empty string. This could result in an account that cannot be looked up by email.
- Files: `server/app/routers/auth.py` (lines 126-133)
- Current mitigation: Rare edge case; Google enforces email in most flows.
- Recommendations: Add `if not email: raise HTTPException(400, "Google account must have email")`.

**Visual AI image upload has no file size limit (SEC-11v2):**
- Risk: Any authenticated user can upload arbitrarily large images, exhausting S3 storage and memory during processing.
- Files: `server/app/routers/visual_ai.py` (lines 54-56 — reads entire file into memory)
- Current mitigation: Plan limits on `ai_visual_monthly_limit` (count), not size.
- Recommendations: Add `file.file.seek(0, os.SEEK_END); size = file.file.tell()` check before read; reject files > 10 MB.

**Missing Content-Security-Policy header (SEC-12v2):**
- Risk: Backend serves HTML pages (privacy policy, subscription success/cancel). No CSP header exposes these to XSS if any dynamic content is ever added.
- Files: `server/app/main.py` (lines 47-55 — security headers middleware)
- Current mitigation: None.
- Recommendations: Add `Content-Security-Policy: default-src 'self'` to the security headers middleware.

**Production backend URL hardcoded as default in Flutter (SEC-13v2):**
- Risk: Developers building locally without `--dart-define=API_BASE_URL=...` will unknowingly hit production.
- Files: `lib/api/api.dart` (lines 11-14)
- Current mitigation: `// ignore: do_not_use_environment` comment acknowledges the issue.
- Recommendations: Change default to `http://localhost:8000` or remove the default and fail fast if not provided.

**Email of failed login attempts logged in plaintext (SEC-15v2):**
- Risk: Log files expose a list of valid email addresses (user enumeration via logs).
- Files: `server/app/routers/auth.py` (lines 59, 62)
- Current mitigation: None.
- Recommendations: Log only `request.client.host` and omit the email field from failed-login warnings.

**AI enrichment endpoints have no rate limiting:**
- Risk: Authenticated users can call `/api/checklist-items/{item_id}/enriquecer`, `/api/etapas/{etapa_id}/enriquecer-checklist`, and `/api/obras/{obra_id}/enriquecer-todos` without per-request rate limits. These call paid AI APIs and can exhaust AI API budgets.
- Files: `server/app/routers/checklist_inteligente.py` (lines 403, 436, 471)
- Current mitigation: Plan gate (`require_paid`) but no per-minute/per-day rate limiting.
- Recommendations: Add `@limiter.limit("10/day")` decorator matching the document analysis rate.

**Stripe redirect URLs not validated against trusted domain (SEC-16v2):**
- Risk: `STRIPE_SUCCESS_URL` and `STRIPE_CANCEL_URL` env vars used without domain validation. If misconfigured, open redirect vulnerability.
- Files: `server/app/routers/subscription.py` (lines 119-120)
- Current mitigation: Only triggered if env vars are misconfigured.
- Recommendations: Validate URLs start with the expected domain at startup using `BaseSettings`.

**No audit log for sensitive operations (SEC-14v2):**
- Risk: Account deletion, subscription changes, invite creation, financial writes have no audit trail.
- Files: All routers
- Current mitigation: Standard logger present but logs only errors, not business events.
- Recommendations: Add structured `audit_log(action, user_id, resource_id, detail)` calls for deletion, financial, and auth operations.

**Avaliacao model has no user_id — anyone can rate a provider:**
- Risk: Any authenticated user, including guests, can submit unlimited ratings for any `Prestador`. Ratings are anonymous and can be gamed.
- Files: `server/app/models.py` (lines 274-287), `server/app/routers/prestadores.py` (lines 228-263)
- Current mitigation: None.
- Recommendations: Add `user_id` FK to `Avaliacao`; enforce one-rating-per-user-per-provider unique constraint; restrict to `owner` role.

---

## Performance Bottlenecks

**Home screen fires 3 heavy API calls on every obra selection (PERF-03v2):**
- Problem: `_carregarDashboard` in `lib/screens/home_screen.dart` calls `listarEtapas`, `relatorioFinanceiro`, and `listarProjetos` in parallel via `Future.wait` on every obra switch.
- Files: `lib/screens/home_screen.dart` (around line 86-98)
- Cause: No lazy loading; financial report alone triggers 30+ DB queries.
- Improvement path: Lazy-load per tab — only fetch when the tab is first rendered or explicitly refreshed.

**Financial report loads all records into Python memory (PERF-09v2):**
- Problem: `relatorio_financeiro` loads all `Etapa`, `OrcamentoEtapa`, and `Despesa` rows then aggregates in Python.
- Files: `server/app/routers/financeiro.py` (lines 125-136)
- Cause: Missing SQL aggregation; grows with number of despesas.
- Improvement path: Replace with `func.sum(Despesa.valor).group_by(Despesa.etapa_id)` at query level.

**Prestadores aggregate ratings in Python loop (PERF-08v2):**
- Problem: `listar_prestadores` fetches all `Avaliacao` rows for all matching prestadores and computes averages in Python.
- Files: `server/app/routers/prestadores.py` (lines 92-119)
- Cause: No SQL aggregation.
- Improvement path: Use `func.avg()` and `func.count()` with `GROUP BY prestador_id` in the query.

**No request deduplication in Flutter API client (PERF-07v2):**
- Problem: Rapid screen switching triggers duplicate in-flight requests for the same endpoint with no guard.
- Files: `lib/api/api.dart`
- Cause: No pending-request map.
- Improvement path: Track in-flight `Future`s by URL+params; return existing future if one exists.

**Normas search result history loads unbounded rows (PERF-04v2):**
- Problem: `listar_historico_normas` loads all `NormaResultado` rows for each `NormaLog` without limit.
- Files: `server/app/routers/normas.py` (lines 109-130)
- Cause: No `.limit()` on nested query.
- Improvement path: Add `.limit(5)` per log and paginate the main query.

---

## Fragile Areas

**`_cascade_delete_obra_data` manual cascade chain:**
- Files: `server/app/routers/obras.py` (lines 150-270)
- Why fragile: Cascade delete is implemented as 8+ manual SQL DELETE calls in a specific order. Adding a new model with a FK to any of these tables silently breaks cascade unless this function is updated.
- Safe modification: Any new table with FK to `Obra`, `Etapa`, `ProjetoDoc`, or `AtividadeCronograma` must be added to the corresponding `_delete_*_cascade` helper function.
- Test coverage: No automated tests cover this delete path.

**`processar_checklist_background` + `_background_pool` shutdown behaviour:**
- Files: `server/app/routers/checklist_inteligente.py` (lines 39, 168-183)
- Why fragile: On Cloud Run container shutdown, in-flight background threads are killed mid-processing. The `ChecklistGeracaoLog` row remains in `status=PROCESSANDO` forever with no timeout-based recovery.
- Safe modification: Implement a startup task that resets any stale `PROCESSANDO` logs older than N minutes to `ERRO`.
- Test coverage: No tests.

**Stripe webhook `_resolve_plan_from_stripe` defaults to `"completo"`:**
- Files: `server/app/routers/subscription.py` (lines 311-336)
- Why fragile: If `metadata.plan` is absent and no price ID matches, the function silently grants `completo` (maximum) access. Any Stripe event with unexpected metadata will over-provision users.
- Safe modification: Change default to raise an exception or return `None` and log a warning, rather than defaulting to the most permissive plan.
- Test coverage: No tests.

**`init_db()` called at startup but migrations run separately:**
- Files: `server/app/db.py` (line 29), `server/app/main.py` (lines 75-87)
- Why fragile: `SQLModel.metadata.create_all(engine)` and Alembic are both used. On a fresh database, `create_all` can create tables that bypass the migration chain. Schema drift between models and Alembic migrations is possible.
- Safe modification: Remove `create_all` from production startup; use `alembic upgrade head` as the single source of truth.
- Test coverage: No tests.

---

## Scaling Limits

**`ThreadPoolExecutor(max_workers=4)` for AI background tasks:**
- Current capacity: 4 concurrent background checklist generation jobs per process instance.
- Limit: Cloud Run scales horizontally so total concurrency = 4 × instances. But each job can consume minutes of compute and multiple AI API calls.
- Scaling path: Move background AI processing to a task queue (e.g., Cloud Tasks or Celery with Redis) to decouple from the HTTP server process.

**DB connection pool: `pool_size=20, max_overflow=40`:**
- Current capacity: 60 total connections per process.
- Limit: Cloud Run auto-scales instances; with 10 instances that is 600 simultaneous connections to Postgres. Managed Postgres (Cloud SQL) defaults to 100 connections.
- Scaling path: Use a connection pooler (e.g., PgBouncer or Cloud SQL Auth Proxy with pgbouncer mode) in front of the DB.

---

## Dependencies at Risk

**`fastapi==0.110.0` — uses deprecated `on_event` pattern:**
- Risk: `@app.on_event("startup")` will be removed in a future FastAPI version.
- Impact: Startup logic for DB and S3 init silently broken on upgrade.
- Migration plan: Replace with `lifespan` context manager before upgrading FastAPI.

**`python-jose[cryptography]==3.3.0` for JWT:**
- Risk: `python-jose` is known to have had security advisories. The `[cryptography]` extra pins on `cryptography` package. No active maintainer since 2022.
- Impact: JWT signing/verification is security-critical.
- Migration plan: Migrate to `PyJWT` which is actively maintained and security-audited.

**`google-generativeai==0.8.0` (Gemini SDK):**
- Risk: Google has released `google-genai` as the new canonical SDK replacing `google-generativeai`. The old SDK is in maintenance mode.
- Impact: Gemini models or API versions may require the new SDK.
- Migration plan: Migrate `server/app/ai_providers.py` `GeminiProvider` to `google-genai` SDK.

---

## Missing Critical Features

**No backend tests (ARQ-07v2):**
- Problem: Zero test files exist in `server/`. No pytest, no httpx integration tests.
- Blocks: Cannot safely refactor routers or models. No regression detection.
- Flutter tests exist: `test/api_client_test.dart` covers `ApiClient` model parsing only; no widget tests for screens, no integration tests.

**No password change / password reset flow:**
- Problem: The `PATCH /api/auth/me` endpoint only updates `nome` and `telefone`. There is no endpoint to change password or send a reset email.
- Blocks: Users who registered with email/password and forget their password have no recovery path.

**No environment variable validation at startup (ARQ-05v2):**
- Problem: `STRIPE_SECRET_KEY`, `S3_BUCKET`, `DATABASE_URL`, `GEMINI_API_KEY`, etc., are only checked at call time. A misconfigured deployment starts successfully and fails on first user action.
- Files: `server/app/main.py` (lines 75-87)
- Blocks: Silent production failures that are hard to diagnose.
- Fix approach: Use Pydantic `BaseSettings` to validate all required env vars at startup.

---

## Test Coverage Gaps

**All backend routers — zero test coverage:**
- What's not tested: Auth flow, ownership enforcement, subscription gate logic, cascade delete, Stripe webhook handling, AI background task error recovery.
- Files: All files in `server/app/routers/`
- Risk: Any refactoring or new feature can silently break auth or data access.
- Priority: High

**Stripe webhook handling:**
- What's not tested: `checkout.session.completed` plan assignment, `customer.subscription.deleted` downgrade, idempotency of duplicate events.
- Files: `server/app/routers/subscription.py` (lines 355-491)
- Risk: Billing bugs result in users getting free access or losing paid access.
- Priority: High

**`_cascade_delete_obra_data` integrity:**
- What's not tested: Deleting an obra with all related entities does not leave orphaned rows.
- Files: `server/app/routers/obras.py` (lines 150-270)
- Risk: Leaked DB rows per deleted obra accumulate silently.
- Priority: High

**Flutter screen business logic:**
- What's not tested: No widget tests for any of the 40+ screens. Only `ApiClient` model parsing is covered.
- Files: All `lib/screens/` files
- Risk: UI regressions introduced with no automated detection.
- Priority: Medium

---

*Concerns audit: 2026-04-06*
