# Revisão Completa de Código — ObraMaster

**Data:** 2026-03-12
**Escopo:** Flutter (`mobile/lib/`) + Backend FastAPI (`server/app/`)
**Objetivo:** Performance, segurança, arquitetura, estrutura de arquivos, complexidade ciclomática

---

## Resumo Executivo

Foram encontrados **52 problemas** no total:

| Severidade | Quantidade |
|------------|-----------|
| Crítico    | 9         |
| Alto       | 17        |
| Médio      | 16        |
| Baixo      | 10        |

A lentidão percebida no app tem causas claras tanto no Flutter quanto no backend, detalhadas abaixo.

---

## Principais Causas da Lentidão

| Causa | Lado | Impacto Estimado |
|-------|------|------------------|
| N+1 API calls sequenciais no Dashboard (7 requests sequenciais) | Flutter | ~1.4s de espera pura por carga |
| `FutureBuilder` re-fetching a cada `setState` | Flutter | Flickering constante + bandwidth desperdiçado |
| API call a cada keystroke sem debounce | Flutter | Hammers backend com chamadas IA desnecessárias |
| N+1 queries em `get_subscription_info` (chamado a cada app launch) | Backend | Queries multiplicados por número de obras |
| N+1 queries em `listar_prestadores`, `obter_obra`, `listar_comentarios` | Backend | 2N+1 queries por request |
| Blocking I/O (AI calls 30-120s) em sync handlers | Backend | Exaure threadpool do FastAPI, bloqueia todos os requests |
| Sem `pool_pre_ping` no connection pool | Backend | Conexões stale falham silenciosamente |
| `IndexedStack` recriando `pages` list a cada build | Flutter | Rebuilds desnecessários em todas as tabs |

---

## Problemas de Segurança Críticos

| Problema | Risco | Arquivo |
|----------|-------|---------|
| Stripe webhook sem secret configurado | Qualquer POST pode dar plano pago a qualquer user | `main.py:2575` |
| JWT secret com default hardcoded | Atacante forja tokens válidos lendo o repo | `auth.py:19` |
| `user_id IS NULL` bypass na ownership check | Acesso a obras de outros usuários | `main.py:367` |
| `aplicar_riscos` aceita `body: dict` sem validação | Leakage de dados entre users via risco IDs | `main.py:1546` |
| `obter_projeto`/`download_projeto_pdf` sem ownership check | Qualquer user acessa PDFs de outros | `main.py:1293` |
| `listar_historico_normas` sem user scoping | Dados de todos os users expostos (LGPD) | `main.py:882` |
| Google OAuth Client ID hardcoded no source | OAuth phishing/quota abuse | `auth_provider.dart:22` |

---

## Detalhamento dos Problemas — Flutter

### CRÍTICOS

#### F1. Dead file `api/api.dart` com URL localhost
**Arquivo:** `mobile/lib/api/api.dart` — linhas 9–12
**Problema:** Arquivo legado com `ApiClient` duplicado, modelos duplicados, e default URL `http://localhost:8000`. Nunca importado, mas confuso e risco se importado acidentalmente.
**Fix:** Deletar `mobile/lib/api/api.dart` inteiramente.

#### F2. N+1 API calls sequenciais no Dashboard
**Arquivo:** `mobile/lib/screens/home/home_screen.dart` — linhas 224–257
**Problema:** `_carregarDashboard` faz até 7 requests HTTP sequenciais (1 etapas + até 6 itens). Cada `await` bloqueia o próximo. Em conexão mobile (~200ms RTT), são 1.4s de espera pura.
**Fix:** Paralelizar com `Future.wait`:
```dart
final etapas = await widget.api.listarEtapas(widget.obra.id);
final futures = etapas.take(6).map((e) =>
  widget.api.listarItens(e.id).catchError((_) => <ChecklistItem>[]));
final results = await Future.wait(futures);
```

#### F3. `FutureBuilder` recria Future a cada `setState`
**Arquivo:** `mobile/lib/screens/checklist/detalhe_item_screen.dart` — linhas 763–809
**Problema:** O `future:` do `FutureBuilder` é uma chamada de método, não um `Future` armazenado. Cada `setState` (toggle de status, salvando observação) dispara um novo fetch de evidências.
**Fix:** Armazenar o future em `initState`:
```dart
late Future<List<Evidencia>> _evidenciasFuture;

@override
void initState() {
  super.initState();
  _evidenciasFuture = widget.api.listarEvidencias(widget.item.id);
}
```

#### F4. Google OAuth Client ID hardcoded
**Arquivo:** `mobile/lib/providers/auth_provider.dart` — linhas 22–27
**Problema:** Client ID commitado como `defaultValue`. Qualquer extração do APK expõe o ID para phishing.
**Fix:** Remover `defaultValue`. Exigir via `--dart-define` no build ou usar `google-services.json`.

### ALTOS

#### F5. `IndexedStack` mantém 4 navegadores vivos + `pages` recriado a cada build
**Arquivo:** `mobile/lib/screens/home/home_screen.dart` — linhas 60–103, 119
**Problema:** `IndexedStack` retém todos os filhos em memória. A lista `pages` é reconstruída dentro de `build()` a cada `setState`, criando novos widgets `Navigator` desnecessariamente.
**Fix:** Mover construção de `pages` para `initState` ou campo. Usar `AutomaticKeepAliveClientMixin`.

#### F6. `notifyListeners` chamado até 4x em `cancelSubscription`
**Arquivo:** `mobile/lib/providers/subscription_provider.dart` — linhas 64–80
**Problema:** Chamadas redundantes: start + 2x dentro de `load()` + finally. Cada listener rebuilda 4 vezes.
**Fix:** Remover `notifyListeners` do `finally` block.

#### F7. API call a cada keystroke sem debounce
**Arquivo:** `mobile/lib/screens/checklist/checklist_screen.dart` — linhas 105–121
**Problema:** `onChanged` chama `sugerirGrupoItem` a cada caractere digitado após 5 chars. "Instalação elétrica" = 14 chamadas IA concorrentes.
**Fix:** Debounce com `Timer` de 400ms:
```dart
Timer? _debounce;
onChanged: (_) {
  _debounce?.cancel();
  _debounce = Timer(const Duration(milliseconds: 400), () async {
    // call sugerirGrupoItem
  });
}
```

#### F8. `IAHubScreen` é StatelessWidget com API calls bloqueantes sem loading
**Arquivo:** `mobile/lib/screens/ia/ia_hub_screen.dart` — linhas 113–218
**Problema:** Usuário tapa "Analisar Foto", nada acontece por 2+ segundos. Sem indicador de loading possível em `StatelessWidget`.
**Fix:** Converter para `StatefulWidget` com `_loading` state.

#### F9. Sort em `build()` de `_ItensPendentesCard`
**Arquivo:** `mobile/lib/screens/home/home_screen.dart` — linhas 633–640
**Problema:** Lista copiada e ordenada a cada rebuild.
**Fix:** Ordenar uma vez no parent durante carregamento.

#### F10. `_formatarValor` duplicado em 2 arquivos
**Arquivos:** `home_screen.dart:586`, `financeiro_screen.dart:41`
**Problema:** Formatação BRL manual duplicada com lógica ligeiramente diferente.
**Fix:** Usar `NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$')` do `package:intl`. Extrair para utility.

### MÉDIOS

#### F11. `context.read` dentro de `Consumer` — não reativo
**Arquivo:** `mobile/lib/screens/home/home_screen.dart` — linhas 282–284
**Problema:** `context.read<AuthProvider>()` dentro de `Consumer<SubscriptionProvider>` não rebuilda quando `AuthProvider` muda.
**Fix:** Usar `context.watch<AuthProvider>()`.

#### F12. Mutação de state em `build()` sem `setState`
**Arquivo:** `mobile/lib/main.dart` — linhas 200–209
**Problema:** `_subscriptionLoaded` é mutado diretamente em `build()`. Frágil se Flutter chamar `build` múltiplas vezes por frame.
**Fix:** Mover lógica para `didChangeDependencies` ou callback dedicado.

#### F13. `.then()` swallowing errors
**Arquivo:** `mobile/lib/screens/etapas/etapas_screen.dart` — linhas 383–384
**Problema:** `.then((_) => _refresh())` perde exceções silenciosamente.
**Fix:** Usar `await` + `if (mounted)` guard.

#### F14. `shouldRepaint` com referência de lista
**Arquivo:** `mobile/lib/screens/financeiro/curva_s_screen.dart` — linhas 318–320
**Problema:** `!=` em `List` compara identidade, não conteúdo.
**Fix:** Usar `listEquals` do `foundation.dart`.

#### F15. `void async` method perde exceções
**Arquivo:** `mobile/lib/screens/checklist_inteligente/checklist_inteligente_screen.dart` — linha 270
**Problema:** `void _verDetalhesJob(...)  async` — exceções não capturáveis.
**Fix:** Mudar para `Future<void>`.

#### F16. `ActionChip` ignora valor da norma clicada
**Arquivo:** `mobile/lib/screens/normas/normas_screen.dart` — linhas 216–221
**Problema:** Cada chip mostra uma norma específica mas busca o valor do dropdown. Bug funcional de UX.
**Fix:** Passar o valor da norma para `_buscar()`.

#### F17. `sync()` + `load()` = chamada de rede duplicada
**Arquivo:** `mobile/lib/screens/subscription/paywall_screen.dart` — linhas 219–221
**Problema:** `sync()` já chama `load()` internamente.
**Fix:** Remover `await sub.load()` explícito.

### BAIXOS

#### F18. `context.read` em item builder callback
**Arquivo:** `mobile/lib/screens/checklist/checklist_screen.dart` — linhas 497–498

#### F19. `_severidadeColor` duplicado em 3 arquivos
**Arquivos:** `checklist_screen.dart:891`, `visual_ai_screen.dart:103`, `detalhe_item_screen.dart:848`

#### F20. `_statusColor`/`_statusLabel`/`_statusIcon` duplicados em 5 arquivos
**Arquivos:** `checklist_screen.dart:339`, `etapas_screen.dart:255`, `documentos_screen.dart:240`, `visual_ai_screen.dart:115`

#### F21. `TextEditingController`s não disposed após dialogs
**Arquivo:** `mobile/lib/screens/obras/obras_screen.dart` — linhas 34–117

#### F22. `context.read` em `build()` no `FinanceiroScreen`
**Arquivo:** `mobile/lib/screens/financeiro/financeiro_screen.dart` — linha 123

---

## Detalhamento dos Problemas — Backend

### CRÍTICOS

#### B1. Connection pool sem configuração adequada
**Arquivo:** `server/app/db.py` — linha 9
**Problema:** Sem `pool_pre_ping=True`, sem `pool_recycle`, sem `connect_timeout`. Conexões stale falham silenciosamente no Cloud Run.
**Fix:**
```python
engine = create_engine(
    get_database_url(),
    echo=False,
    pool_size=5,
    max_overflow=10,
    pool_pre_ping=True,
    pool_recycle=1800,
    connect_args={"connect_timeout": 10},
)
```

#### B2. Stripe webhook sem secret — unauthenticated plan upgrade
**Arquivo:** `server/app/main.py` — linhas 2575, 2581
**Problema:** `STRIPE_WEBHOOK_SECRET` é `None` (documentado como PENDENTE). Qualquer POST pode ativar plano pago.
**Fix:**
```python
if not webhook_secret:
    raise HTTPException(status_code=503, detail="Webhook nao configurado")
```

#### B3. Blocking I/O em sync handlers exaure threadpool
**Arquivo:** `server/app/main.py` — linhas 1375–1456, 1605–1691
**Problema:** `analisar_projeto`, `analisar_visual` chamam AI APIs (30-120s) em handlers sync. Bloqueia o threadpool inteiro.
**Fix:** Converter para `async def` + `asyncio.to_thread()` para chamadas bloqueantes.

#### B4. `user_id IS NULL` bypass na ownership check
**Arquivo:** `server/app/main.py` — linhas 364–369
**Problema:** Obras com `user_id = NULL` são acessíveis por qualquer user autenticado.
**Fix:**
```python
if not obra or obra.user_id != user.id:
    raise HTTPException(status_code=404, detail="Obra nao encontrada")
```

#### B5. `aplicar_riscos` sem validação — data leakage cross-user
**Arquivo:** `server/app/main.py` — linhas 1546–1600
**Problema:** `body: dict` sem schema Pydantic. Risco IDs de outros users podem ser passados sem verificação.
**Fix:** Criar `AplicarRiscosRequest` schema + verificar `risco.projeto.obra_id == obra_id`.

### ALTOS

#### B6. N+1 queries em `get_subscription_info`
**Arquivo:** `server/app/main.py` — linhas 2316–2334
**Problema:** Loop por todas as obras do user, fazendo 1 query por obra para contar docs e convites. Chamado a cada launch do app.
**Fix:**
```python
doc_count = session.exec(
    select(func.count(ProjetoDoc.id))
    .join(Obra, Obra.id == ProjetoDoc.obra_id)
    .where(Obra.user_id == current_user.id)
).one()
```

#### B7. N+1 queries em `listar_prestadores` + sem paginação
**Arquivo:** `server/app/main.py` — linhas 1793–1820
**Problema:** 1 query por prestador para avaliações. Sem limit/offset. Tabela inteira carregada.
**Fix:** JOIN + GROUP BY + parâmetros `limit`/`offset`.

#### B8. N+1 em `listar_obras_convidadas` e `listar_comentarios`
**Arquivo:** `server/app/main.py` — linhas 2896–2908, 2964–2975
**Problema:** Cada convite/comentário faz 1-2 `session.get()` queries.
**Fix:** JOIN com eager loading.

#### B9. 97x `datetime.utcnow()` — deprecated, quebra no Python 3.14
**Arquivo:** Todos os `.py` em `server/app/`
**Problema:** `datetime.utcnow()` removido no Python 3.14 (versão local atual).
**Fix:** Replace all por `datetime.now(timezone.utc)`.

#### B10. Background thread cria engine DB por job — connection leak
**Arquivo:** `server/app/main.py` — linhas 2096–2102
**Problema:** Cada thread de background cria novo engine SQLAlchemy sem cleanup.
**Fix:** Passar session factory ao invés de raw URL.

#### B11. JWT secret com default hardcoded
**Arquivo:** `server/app/auth.py` — linha 19
**Problema:** `SECRET_KEY = os.getenv("JWT_SECRET_KEY", "dev-secret-change-in-production")`. Se env var não setada, app inicia com segredo público.
**Fix:**
```python
SECRET_KEY = os.getenv("JWT_SECRET_KEY")
if not SECRET_KEY:
    raise RuntimeError("JWT_SECRET_KEY environment variable not set")
```

#### B12. Batch AI enrichment síncrono — timeout garantido
**Arquivo:** `server/app/main.py` — linhas 3055–3140
**Problema:** Loop sync com 1 AI call por checklist item. 15 itens × 30s = 7.5min. Cloud Run timeout = 60s.
**Fix:** Background task ou parallelizar com `asyncio.gather`.

#### B13. `obter_obra` faz 2N+1 queries + import inline
**Arquivo:** `server/app/main.py` — linhas 473–495
**Problema:** Loop por etapas fazendo 2 queries por etapa. `from sqlalchemy import func` dentro do handler.
**Fix:** Subquery agregada + mover import para topo do arquivo.

#### B14. `listar_historico_normas` sem user scoping — LGPD
**Arquivo:** `server/app/main.py` — linhas 882–900
**Problema:** Retorna consultas de normas de TODOS os users. Dados pessoais de projetos expostos.
**Fix:** Adicionar `user_id` ao `NormaLog` + filtrar por user.

#### B15. `product_id` usado como Stripe subscription ID
**Arquivo:** `server/app/main.py` — linha 2494
**Problema:** Campo semântico errado. Funciona por acidente porque checkout handler salva sub ID nesse campo.
**Fix:** Renomear campo com migration.

### MÉDIOS

#### B16. Race condition em `UsageTracking` — sem unique constraint
**Arquivo:** `server/app/models.py:343`, `subscription.py:111`
**Problema:** Read-then-write sem unique constraint. Requests concorrentes bypassam limites de uso.
**Fix:** `UniqueConstraint('user_id', 'feature', 'period')` + handle `IntegrityError`.

#### B17. Sem ownership check em `obter_projeto`, `download_projeto_pdf`, `obter_analise_visual`
**Arquivo:** `server/app/main.py` — linhas 1293, 1306, 1709
**Problema:** Qualquer user autenticado com UUID válido acessa documentos de outros.
**Fix:** Verificar `projeto.obra.user_id == current_user.id`.

#### B18. HTML inline em `main.py` — 250+ linhas
**Arquivo:** `server/app/main.py` — linhas 174–229, 2399–2424
**Fix:** Mover para `templates/`.

#### B19. `main.py` é monolito de 3100 linhas
**Arquivo:** `server/app/main.py`
**Problema:** 50+ routes, helpers, dicionários, HTML, tudo em um arquivo.
**Fix:** Separar em `APIRouter` por domínio: auth, obras, financeiro, documentos, visual, checklist, prestadores, subscription, convites.

#### B20. `_clean_json_response` duplicado em 3 módulos
**Arquivos:** `visual_ai.py:94`, `checklist_inteligente.py:270`
**Fix:** Extrair para `utils.py`.

#### B21. Exception message do Google OAuth vazando para client
**Arquivo:** `server/app/main.py` — linha 304
**Fix:** Retornar mensagem genérica.

#### B22. `obter_obra` sem `response_model`
**Arquivo:** `server/app/main.py` — linha 495
**Fix:** Criar schema `ObraDetailResponse`.

#### B23. `/api/normas/buscar` sem usage gate para free users
**Arquivo:** `server/app/main.py` — linhas 801–879
**Problema:** Free users consomem créditos IA sem limites.
**Fix:** Adicionar `check_and_increment_usage`.

#### B24. Nomenclatura `RevenueCat` stale pós-migração Stripe
**Arquivo:** `server/app/models.py` — linhas 328, 333, 354
**Fix:** Renomear com migration: `revenuecat_customer_id` → `stripe_customer_id`, `RevenueCatEvent` → `StripeEvent`.

### BAIXOS

#### B25. `datetime.utcfromtimestamp` deprecated
**Arquivo:** `server/app/main.py` — linhas 2458, 2634, 2655

#### B26. `score_etapa` GET com side-effect de escrita no DB
**Arquivo:** `server/app/main.py` — linhas 644–659

#### B27. `file.filename` sem null check
**Arquivo:** `server/app/main.py` — linhas 779, 1263, 1632

#### B28. `RevenueCatEvent` table armazena eventos Stripe
**Arquivo:** `server/app/models.py` — linha 354

#### B29. `session.commit()` por item no loop de enrichment
**Arquivo:** `server/app/main.py` — linha ~3094

---

## Plano de Ação Consolidado

### Fase 1 — Segurança (Urgente) ⏱️ ~2h

| # | Ação | Arquivos | Issues |
|---|------|----------|--------|
| 1 | Guard `STRIPE_WEBHOOK_SECRET` — retornar 503 se não configurado | `main.py` | B2 |
| 2 | Remover default do `JWT_SECRET_KEY` — crash on startup se não setado | `auth.py` | B11 |
| 3 | Corrigir `_verify_obra_ownership` — rejeitar `user_id IS NULL` | `main.py` | B4 |
| 4 | Adicionar ownership check em `obter_projeto`, `download_projeto_pdf`, `obter_analise_visual` | `main.py` | B17 |
| 5 | Validar `aplicar_riscos` — schema Pydantic + ownership check | `main.py`, `schemas.py` | B5 |
| 6 | Scope `listar_historico_normas` por user | `main.py` | B14 |
| 7 | Remover Google Client ID default | `auth_provider.dart` | F4 |
| 8 | Sanitizar exception messages no login Google | `main.py` | B21 |

### Fase 2 — Performance Flutter (Alto Impacto) ⏱️ ~3h

| # | Ação | Arquivos | Issues |
|---|------|----------|--------|
| 9 | Paralelizar dashboard com `Future.wait` | `home_screen.dart` | F2 |
| 10 | Cachear Future do `FutureBuilder` em state | `detalhe_item_screen.dart` | F3 |
| 11 | Debounce de 400ms no `sugerirGrupoItem` | `checklist_screen.dart` | F7 |
| 12 | Mover `pages` do `IndexedStack` para `initState` | `home_screen.dart` | F5, F6 |
| 13 | Converter `IAHubScreen` para `StatefulWidget` com loading | `ia_hub_screen.dart` | F8 |
| 14 | Remover sort do `build()` | `home_screen.dart` | F9 |
| 15 | Remover `sub.load()` duplicado após `sub.sync()` | `paywall_screen.dart` | F17 |
| 16 | Reduzir `notifyListeners` em `cancelSubscription` | `subscription_provider.dart` | F6 |

### Fase 3 — Performance Backend (Alto Impacto) ⏱️ ~4h

| # | Ação | Arquivos | Issues |
|---|------|----------|--------|
| 17 | Configurar connection pool (`pool_pre_ping`, `pool_recycle`) | `db.py` | B1 |
| 18 | Resolver N+1 em `get_subscription_info` com query agregada | `main.py` | B6 |
| 19 | Resolver N+1 em `listar_prestadores` + adicionar paginação | `main.py` | B7 |
| 20 | Resolver N+1 em `obter_obra` com subquery | `main.py` | B13 |
| 21 | Resolver N+1 em `listar_obras_convidadas` e `listar_comentarios` | `main.py` | B8 |
| 22 | Converter rotas IA para `async def` + `asyncio.to_thread()` | `main.py` | B3 |
| 23 | Background task para batch AI enrichment | `main.py` | B12 |
| 24 | Fix background thread DB — usar session factory | `main.py` | B10 |

### Fase 4 — Estabilidade & Bugs ⏱️ ~2h

| # | Ação | Arquivos | Issues |
|---|------|----------|--------|
| 25 | Substituir 97x `datetime.utcnow()` + `utcfromtimestamp` | Todos `.py` | B9, B25 |
| 26 | Corrigir `shouldRepaint` com `listEquals` | `curva_s_screen.dart` | F14 |
| 27 | Fix `void async` → `Future<void>` | `checklist_inteligente_screen.dart` | F15 |
| 28 | Fix `.then()` → `await` + mounted guard | `etapas_screen.dart` | F13 |
| 29 | Fix mutação em `build()` sem `setState` | `main.dart` | F12 |
| 30 | Adicionar `UniqueConstraint` em `UsageTracking` | `models.py` + migration | B16 |
| 31 | Guard `file.filename` contra `None` | `main.py` | B27 |

### Fase 5 — Arquitetura & Manutenibilidade ⏱️ ~6h

| # | Ação | Arquivos | Issues |
|---|------|----------|--------|
| 32 | Deletar `api/api.dart` (dead code) | `api/api.dart` | F1 |
| 33 | Extrair helpers Flutter para `utils/theme_helpers.dart` | Múltiplos screens | F10, F19, F20 |
| 34 | Usar `NumberFormat` para `_formatarValor` | `home_screen.dart`, `financeiro_screen.dart` | F10 |
| 35 | Dispose `TextEditingController`s após dialogs | `obras_screen.dart` | F21 |
| 36 | Separar `main.py` em APIRouters por domínio | `server/app/` | B19 |
| 37 | Extrair `_clean_json_response` para `utils.py` | `visual_ai.py`, `checklist_inteligente.py` | B20 |
| 38 | Mover HTML inline para `templates/` | `main.py` | B18 |
| 39 | Renomear campos RevenueCat → Stripe + migrations | `models.py` | B15, B24, B28 |
| 40 | Adicionar usage gate em `/api/normas/buscar` | `main.py` | B23 |
| 41 | Criar `response_model` para `obter_obra` | `main.py`, `schemas.py` | B22 |
| 42 | Corrigir `ActionChip` normas para usar valor clicado | `normas_screen.dart` | F16 |

---

## Ordem de Execução Recomendada

```
Fase 1 (Segurança)     ████████░░░░░░░░░░░░  ~2h   — URGENTE
Fase 2 (Perf Flutter)  ████████████░░░░░░░░  ~3h   — Impacto direto na UX
Fase 3 (Perf Backend)  ████████████████░░░░  ~4h   — Impacto direto na UX
Fase 4 (Estabilidade)  ██████████████████░░  ~2h   — Previne crashes
Fase 5 (Arquitetura)   ████████████████████  ~6h   — Manutenibilidade
                                        Total: ~17h
```

**Prioridade absoluta:** Fases 1 + 2 + 3 resolvem a lentidão percebida E fecham vulnerabilidades de segurança.
