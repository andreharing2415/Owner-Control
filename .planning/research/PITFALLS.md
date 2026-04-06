# Domain Pitfalls

**Domain:** Brownfield Flutter + FastAPI construction management app
**Researched:** 2026-04-06
**Confidence:** HIGH (all findings verified against actual codebase + official sources)

---

## CRITICAL PITFALLS

These will kill the project, cause data loss, or break production deploys if not fixed before adding new features.

---

### Pitfall 1: Alembic Migration Chain Is Broken in Three Places

**What goes wrong:** Fresh deploys fail. `alembic upgrade head` cannot resolve the chain and errors with "Can't locate revision identified by '0022'".

**Why it happens:** Three distinct bugs coexist in the versions directory:

1. **Duplicate revision IDs.** Two separate files both declare `revision = "20260309_0014"` and `down_revision = "20260311_0013"`:
   - `20260309_0014_add_valor_realizado.py`
   - `20260309_0014_checklist_unificado.py`
   Alembic sees two heads in the same lineage, which is fatal — it cannot determine which file is canonical.

2. **Short-form IDs that do not match the full IDs they reference.** Revision `20260319_0023` declares `down_revision = "0022"` but the actual revision 22 is identified as `"20260319_0022"` (not `"0022"`). Alembic string-matches revision IDs exactly. The lookup fails.

3. **Same short-form problem cascades to revision 0024**, which declares `down_revision = "0023"` — but the actual ID is `"0023"` (not `"20260319_0023"`), so depending on which file gets picked up first, this may or may not resolve.

**Consequences:** Any new environment (CI, staging, new developer machine) cannot run `alembic upgrade head`. The production database that was migrated interactively may work, but any automated deploy pipeline is broken. Adding new migrations on top of this chain before fixing it creates compounding failures.

**Prevention:**
- Delete `20260309_0014_checklist_unificado.py` (or `20260309_0014_add_valor_realizado.py` — pick one, merge its columns into the surviving file).
- Fix `20260319_0023`: change `down_revision = "0022"` to `down_revision = "20260319_0022"` and change `revision = "0023"` to `revision = "20260319_0023"`.
- Fix `20260319_0024`: change `revision = "0024"` to `revision = "20260319_0024"` and `down_revision = "0023"` to `down_revision = "20260319_0023"`.
- Run `alembic history --verbose` to verify a single linear chain before any new migration is created.

**Detection:** `alembic heads` returns more than one result. `alembic upgrade head` errors in a fresh environment.

**Fix this first.** Every new migration written for new features will inherit the broken chain.

---

### Pitfall 2: Stripe Cancellation Immediately Downgrades the User

**What goes wrong:** A paying user clicks "Cancel subscription." The app immediately locks them out of paid features. They were promised access until the end of their billing period.

**Why it happens:** `cancel_subscription()` in `subscription.py` lines 243–250:
```python
sub.status = "cancelled"
sub.plan = "gratuito"        # ← immediate downgrade
current_user.plan = "gratuito"  # ← immediate downgrade
```
This executes synchronously on the cancel call, before the billing period ends. `stripe.Subscription.modify(..., cancel_at_period_end=True)` tells Stripe to wait, but the app's own database is updated immediately to `gratuito`.

**Consequences:** Revenue loss (users who cancel mid-month feel cheated and leave bad reviews). This is a direct financial bug affecting trust in the subscription system. If a new paid tier or dual-role feature is built on top of this system, the same bug propagates to the new tier.

**Prevention:**
- Do not downgrade `plan` or `status` on the cancel call. Only set a `cancel_at` or `cancels_at_period_end = True` flag.
- Let the Stripe webhook `customer.subscription.deleted` (or `customer.subscription.updated` with `cancel_at_period_end=true`) trigger the actual plan downgrade. The webhook handler already exists in the codebase — use it as the single source of truth.
- Store `expires_at` from `current_period_end` on the Subscription record. On every auth check, compare `expires_at` to `now()` rather than trusting `plan` alone.

**Detection:** Cancel a subscription in Stripe test mode. Verify that paid features remain accessible immediately after cancel and that downgrade only happens after `expires_at`.

---

### Pitfall 3: python-jose Has Active CVEs and Is Unmaintained

**What goes wrong:** The JWT library used for all authentication has two 2024 CVEs (CVE-2024-33663: algorithm confusion enabling auth bypass/signature forgery; CVE-2024-33664: JWT bomb DoS via compressed JWE). The library has had no release since 2022.

**Why it happens:** `requirements.txt` pins `python-jose[cryptography]==3.3.0`. FastAPI's own documentation has moved away from python-jose to PyJWT. The CVE-2024-33663 vulnerability allows an attacker to forge tokens if they can send crafted ECDSA key material. The CVE-2024-33664 causes denial of service via high-compression JWE.

**Consequences:** If the app handles engineer-vs-owner dual roles (planned feature), a token forgery attack can elevate a read-only owner to engineer permissions. This is not theoretical — there are published exploits for CVE-2024-33663.

**Prevention:**
- Replace `python-jose` with `PyJWT>=2.8.0`. The API is largely compatible for HMAC-signed tokens (the common case here). Migration guide exists at github.com/jpadilla/pyjwt/issues/942.
- If you use only HS256 signing (most likely), the migration is: `from jose import jwt` → `import jwt`, `jwt.decode(token, SECRET, algorithms=["HS256"])` stays the same, `jwt.encode(payload, SECRET, algorithm="HS256")` stays the same.
- Do this before adding the dual-role system. A security fix after role boundaries are in place is harder to audit.

**Detection:** `pip-audit` or `safety check` will flag python-jose immediately.

---

### Pitfall 4: SSE Stream Continues After Client Disconnect

**What goes wrong:** When a user closes the app mid-stream (or navigates away during checklist generation), the SSE generator in `checklist_inteligente.py` continues running, consuming AI API tokens until it finishes.

**Why it happens:** The `/stream` endpoint returns a `StreamingResponse` wrapping `gerar_checklist_stream(...)`. There is no disconnect detection — no `request.is_disconnected()` check inside the generator. Cloud Run keeps the process alive. The AI API call proceeds to completion regardless of whether anyone is receiving.

**Consequences:** With the new unified AI cronograma+checklist feature (a primary goal), this problem gets worse. A single PDF-to-cronograma-to-checklist stream could consume 50,000–200,000 tokens. If 10 users open and close the screen, that is potentially millions of wasted tokens per day.

**Prevention:**
- Pass `request: Request` into the SSE generator. Inside the generator's loop, check `await request.is_disconnected()` and `return` (stop generation) if true.
- Alternatively, replace raw `StreamingResponse` with `sse-starlette` which handles disconnect detection natively.
- Add per-user daily token budgets tracked in `UsageTracking` so runaway costs are bounded even if detection fails.

**Detection:** Open the stream endpoint in a browser, observe Cloud Run logs, close the browser tab, confirm the AI calls stop within one polling cycle.

---

## MODERATE PITFALLS

These will create significant rework or user experience failures during the milestone but are survivable if caught early.

---

### Pitfall 5: Migrating 31 Screens from Direct ApiClient() to Providers Will Break Features If Done Incrementally Without a Seam

**What goes wrong:** The most common brownfield state management migration mistake is introducing providers alongside existing `ApiClient()` calls. Two code paths update the same data. Race conditions and stale cache bugs appear only in specific navigation sequences. 31 screens confirmed with `ApiClient()` instantiation, 178 catch/error-handling sites.

**Why it happens:** The temptation is to migrate screen-by-screen, keeping old screens on `ApiClient()` while new screens use providers. But both paths write to different in-memory representations of the same data. Exemplo: `home_screen.dart` has its own `ApiClient` and `_obrasFuture`. If a new screen creates an obra via a provider, `home_screen.dart`'s `_obrasFuture` does not refresh. The user sees the old list.

**Prevention:**
- Define a "seam" first: a single `ApiService` class (thin wrapper around `ApiClient`) that all providers use. Do not touch screens yet.
- Migrate providers one domain at a time (obras, then etapas, then financeiro). Gate each domain migration behind a feature flag if necessary.
- Only migrate screens after their domain's provider is stable.
- Delete `ApiClient()` instantiation from screens only when the provider is the sole data source for that domain. Never have both active simultaneously for the same data type.
- Use Riverpod's `ref.invalidate()` pattern so any write from any screen triggers a global refresh of that domain's cache.

**Detection:** Two screens showing different counts of the same resource is the primary symptom.

---

### Pitfall 6: Home Screen N+3 API Calls on Every Obra Selection

**What goes wrong:** `home_screen.dart` calls `Future.wait([listarEtapas, relatorioFinanceiro, listarProjetos])` on every obra tap. No caching. On a slow mobile connection (3G in a construction site), this produces a 1–3 second blank dashboard before any content shows.

**Why it happens:** Direct `ApiClient()` calls with no cache layer. `_dashFuture` is recreated on every `_selecionarObra()` call. There is no `staleTime` concept.

**Consequences:** The guided onboarding flow (criar obra → subir documento → ver resultado) hits this wall immediately. The user creates an obra, taps it, sees a spinner. This is the exact moment that must feel instant for onboarding to succeed.

**Prevention:**
- During state management migration, cache obra dashboards in a provider with a 30-second stale window.
- For the onboarding flow specifically, prefetch the dashboard data before the user taps (start the request when the obra appears in the list).
- Consider adding a skeleton loader so the UI is not blank while fetching.

---

### Pitfall 7: Unified AI Cronograma + Checklist Creates a 2–5 Minute Blocking Operation

**What goes wrong:** The new primary goal is generating both cronograma and checklist from a single document upload. Each step (document analysis → cronograma generation → checklist generation) is a separate AI call, each taking 15–45 seconds. Chaining them synchronously produces a 90–180 second blocking operation on a single Cloud Run request.

**Why it happens:** Cloud Run has a 60-second default request timeout (configurable to 3600s, but requires explicit configuration). The current `analisar_projeto` endpoint already runs synchronously ("Roda sincronamente dentro do request para evitar que Cloud Run mate a task" — comment in documentos.py). Chaining three operations makes this worse.

**Consequences:** The `ThreadPoolExecutor(max_workers=4)` for background tasks means that if 4 users trigger the unified generation simultaneously, all workers are saturated. The 5th user's request queues indefinitely. On Cloud Run with multiple instances, the pool is per-instance — there is no cross-instance coordination.

**Prevention:**
- Model the unified flow as a state machine with persistent status: `PENDENTE → ANALISANDO_DOCUMENTO → GERANDO_CRONOGRAMA → GERANDO_CHECKLIST → CONCLUIDO | ERRO`. Store state in a `GeracaoUnificadaLog` table.
- Step 1 (document analysis) runs synchronously within the request (current pattern is fine).
- Steps 2 and 3 run as separate API calls triggered by the client polling the status endpoint.
- This makes each individual request short-lived and Cloud Run-safe.
- Do not chain all three in `ThreadPoolExecutor` — it will saturate the pool and provide no progress visibility.

---

### Pitfall 8: The Dual-Role System Will Conflict With Existing `_verify_obra_ownership` Everywhere

**What goes wrong:** 12 of 14 routers use `_verify_obra_ownership` which checks `obra.user_id == current_user.id`. The invited observer role uses `_verify_obra_access` which is added in `convites.py` but not consistently applied. Adding the engineer-manages/owner-observes role split requires auditing every permission check across every router. Missing even one leaves a privilege escalation.

**Why it happens:** Authorization was added organically. `_verify_obra_ownership` is the default; `_verify_obra_access` was added later for invited users but not retrofitted across all read endpoints.

**Consequences:** An "observer" (dono da obra) calling a write endpoint that forgot to check role gets through if they know the obra_id. The engineer-vs-owner distinction means observers should not be able to trigger AI analysis, modify checklist items, or add expenses — but those endpoints currently only check obra access, not role.

**Prevention:**
- Before building the dual-role feature, audit every endpoint with a permission matrix: which role can read, which can write, which can trigger AI.
- Introduce a `require_role(roles: list[str])` dependency that checks both obra access AND the requester's role within that obra.
- Write integration tests covering the permission matrix before implementing new role-aware screens.

---

### Pitfall 9: GoRouter Navigation Migration Will Cause Ghost Routes If Done Screen-by-Screen

**What goes wrong:** Currently, navigation is imperative (`Navigator.push`, `Navigator.pop`). Migrating 41 screens to GoRouter while some screens still use `Navigator.push` creates "ghost routes" — states where GoRouter's route stack and Flutter's actual navigator stack disagree. Deep links to screens still using `Navigator.push` break.

**Why it happens:** GoRouter intercepts navigation only if the entire subtree uses `context.go()` or `context.push()`. Any `Navigator.push()` call bypasses GoRouter's awareness of the route stack.

**Prevention:**
- Migrate navigation in full shells, not individual screens. The existing `main_shell.dart` is the right unit.
- Use GoRouter's `ShellRoute` for the bottom-nav structure. Migrate all screens in one shell together before moving to the next.
- Add a lint rule or comment convention marking screens as "GoRouter migrated" vs "legacy" so two navigation systems never coexist in the same shell.

---

## MINOR PITFALLS

These cause friction but are easy to fix once identified.

---

### Pitfall 10: AI Hallucination on Construction-Specific Norms

**What goes wrong:** The checklist generates items citing Brazilian ABNT norms (NBR 6118, NBR 9050, etc.). LLMs hallucinate norm content with ~20–30% error rates on specific technical requirements. A homeowner acting on a hallucinated "minimum 2.5cm concrete cover" could make a safety-affecting decision.

**Prevention:**
- Always display the `confianca` score already present in the data model. Low confidence items should show a visual warning.
- The `requer_validacao_profissional` flag already exists — ensure it is surfaced prominently in the UI for structural and electrical items.
- Do not display norm content verbatim as fact without a disclaimer. The existing `aviso_legal` field in `IdentificarProjetosResponse` is the right pattern to follow for all AI output.

---

### Pitfall 11: Large PDF Upload Followed by Immediate Analysis Loads PDF Into Memory Twice

**What goes wrong:** Upload stores the PDF in S3. Analysis downloads it back from S3. For a 50MB architectural drawing, this means 100MB of memory pressure on the Cloud Run instance (50MB upload buffer + 50MB download for analysis). With 3 concurrent requests, this exceeds the default 256MB Cloud Run memory limit.

**Prevention:**
- During the upload flow, cache the raw bytes in a temporary location (or pass them directly to analysis) rather than round-tripping to S3.
- Or: set Cloud Run memory to 512MB minimum for the worker handling document analysis.
- Gate large uploads behind the paid plan (already in place — confirm the `max_doc_size_mb` limit is enforced before the file is held in memory, not after).

---

### Pitfall 12: Onboarding Flow Will Fail If The "Empty State" Is Not First-Class

**What goes wrong:** The guided onboarding goal (criar obra → subir documento → ver resultado) assumes the user reaches each step. The current `home_screen.dart` shows an empty obras list with no call to action. New users who do not know to tap "+" will exit the app.

**Why it happens:** Empty states were not designed for the onboarding flow — they were designed as fallbacks. The screen assumes the user already knows what to do.

**Prevention:**
- The onboarding wizard (`criar_obra_wizard.dart`) already exists. Make it the default destination for new users (zero obras) rather than the empty home screen.
- After obra creation, auto-navigate to the document upload screen rather than returning to the home list.
- The "see result" step must be a single tap from the document upload confirmation, not require the user to navigate back to the obra and find the checklist screen.

---

## Phase-Specific Warnings

| Phase Topic | Likely Pitfall | Mitigation |
|---|---|---|
| Migration chain fix | New migrations added before chain is repaired will compound the break | Fix chain (Pitfall 1) in the very first commit of the milestone |
| Stripe fix | Building new subscription tiers before fixing cancel bug means two code paths carry the bug | Fix cancel flow (Pitfall 2) before adding any new plan tier |
| JWT replacement | python-jose migration can be done in a single PR; delay increases CVE exposure | Replace before dual-role lands (Pitfall 3) |
| State management migration | Incremental screen migration without seam causes stale data bugs | Define the seam layer first, migrate providers before screens (Pitfall 5) |
| Unified AI generation | Naive implementation chains 3 AI calls synchronously, hits Cloud Run timeout | Use state machine with polling (Pitfall 7) |
| Dual-role system | Every router needs permission audit before new screens are built | Write permission matrix and integration tests first (Pitfall 8) |
| Navigation refactor | Mixing GoRouter and Navigator.push causes ghost routes | Migrate by shell, not by screen (Pitfall 9) |
| Onboarding flow | Empty state on home screen kills first-run conversion | Reroute zero-obras users to wizard by default (Pitfall 12) |

---

## Sources

- Alembic duplicate revision analysis: direct inspection of `server/alembic/versions/` directory
- Stripe cancel bug: direct inspection of `server/app/routers/subscription.py` lines 243–252; confirmed against [Stripe cancel subscriptions documentation](https://docs.stripe.com/billing/subscriptions/cancel)
- python-jose CVEs: [CVE-2024-33663 (algorithm confusion)](https://www.vicarius.io/vsociety/posts/algorithm-confusion-in-python-jose-cve-2024-33663), [CVE-2024-33664 (DoS)](https://github.com/advisories/GHSA-cjwg-qfpm-7377), [FastAPI migration discussion](https://github.com/fastapi/fastapi/discussions/9587), [PyJWT migration guide](https://github.com/jpadilla/pyjwt/issues/942)
- SSE disconnect: [FastAPI SSE disconnect discussion](https://github.com/fastapi/fastapi/discussions/7572), [sse-starlette library](https://github.com/sysid/sse-starlette)
- ThreadPoolExecutor scaling: [FastAPI background task limitations](https://github.com/fastapi/fastapi/discussions/6728), [FastAPI Cloud Run scaling discussion](https://github.com/fastapi/fastapi/discussions/5927)
- Flutter navigation migration: [Real-world 100k-line migration post-mortem](https://dev.to/arslanyousaf12/how-i-survived-migrating-100k-lines-of-flutter-code-to-navigator-20-and-what-almost-broke-me-5cil)
- LLM hallucination rates on documents: [Evolution.ai PDF limitations](https://www.evolution.ai/post/limitations-generative-ai-to-read-pdfs)
- Riverpod 3.0 migration changes: [Riverpod official docs](https://riverpod.dev/docs/whats_new)
