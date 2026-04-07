# Auditoria de Codigo V2 - Owner Control (ObraMaster)

**Data:** 2026-03-19
**Escopo:** Frontend Flutter + Backend FastAPI
**Foco:** Performance, Seguranca, Complexidade Ciclomatica, Arquitetura
**Nota:** Segunda varredura. Itens da V1 ja foram todos corrigidos.

---

## Resumo Executivo

| Categoria | Critico | Alto | Medio | Baixo | Total | Corrigidos |
|-----------|---------|------|-------|-------|-------|------------|
| Seguranca | 2 | 5 | 5 | 4 | 16 | **7** |
| Performance | 3 | 5 | 4 | 1 | 13 | **6** |
| Complexidade | 0 | 3 | 4 | 3 | 10 | **3** |
| Arquitetura | 2 | 4 | 5 | 2 | 13 | **1** |
| **Total** | **7** | **17** | **18** | **10** | **52** | **16** |

> **Progresso:** 16/52 itens corrigidos (31%). 4/7 criticos. 11/17 altos.

---

## FASE 1 - CRITICO (Corrigir Imediatamente)

### SEC-01v2: Sem Validacao de Complexidade de Senha
- **Onde:** `server/app/routers/auth.py` (registro), `server/app/schemas.py` (UserRegister)
- **Problema:** Schema `UserRegister` aceita senhas sem nenhuma validacao. Usuarios podem registrar com "123" ou "a".
- **Correcao:** Adicionar `@field_validator('password')` no Pydantic com minimo 8 caracteres, letras + numeros.

### SEC-02v2: IDOR no Download de Documento (projeto_id)
- **Onde:** `server/app/routers/documentos.py` (~linha 153-175, `download_projeto_pdf`)
- **Problema:** Endpoint verifica ownership da obra, mas NAO verifica que o `projeto_id` pertence a essa obra. Atacante pode acessar PDFs de outras obras adivinhando IDs.
- **Correcao:** Verificar `projeto.obra_id == obra.id` explicitamente antes de servir o arquivo.

### PERF-01v2: N+1 Queries no Modulo Cronograma
- **Onde:** `server/app/routers/cronograma.py` (linhas 105-122, `_build_cronograma_response`)
- **Problema:** Para cada atividade nivel 1, faz query separada de nivel 2. Para cada nivel 2, chama `_get_servicos_read()` separado. 5 L1 x 3 L2 = 16 queries ao inves de 2-3.
- **Correcao:** Batch fetch todas as atividades L2 e servicos em queries unicas com `.in_()`.

### PERF-02v2: Threads Daemon Sem Controle no Checklist Inteligente
- **Onde:** `server/app/routers/checklist_inteligente.py` (linhas 148-153)
- **Problema:** `threading.Thread(daemon=True)` sem pool, sem timeout, sem propagacao de erro. 10 usuarios simultaneos = 10 threads descontroladas. Se o servidor reiniciar, threads daemon morrem silenciosamente sem atualizar status.
- **Correcao:** Usar `asyncio.create_task()` ou `concurrent.futures.ThreadPoolExecutor(max_workers=4)` com error handling que persiste status=ERRO no banco.

### PERF-03v2: Dashboard Home Dispara 3 APIs Pesadas em Paralelo
- **Onde:** `lib/screens/home_screen.dart` (linhas 86-98, `_carregarDashboard`)
- **Problema:** `Future.wait([listarEtapas, relatorioFinanceiro, listarProjetos])` a cada selecao de obra. Relatorio financeiro sozinho faz 30+ queries. Usuario pode estar apenas navegando.
- **Correcao:** Lazy loading por tab — carregar apenas quando a tab for visivel.

### ARQ-01v2: Todos os 40+ Screens Fazem API Calls Direto do Widget
- **Onde:** `lib/screens/` (todas as telas)
- **Problema:** `final ApiClient _api = ApiClient()` instanciado em cada tela. Sem camada de state management. Sem cache, sem deduplicacao de requests, sem reutilizacao de dados entre telas. Impossivel testar.
- **Correcao:** Migrar para Riverpod com providers tipados. ApiClient injetado via Provider, dados compartilhados entre telas.

### ARQ-02v2: Service Layer Incompleta no Backend
- **Onde:** `server/app/services/` (apenas 1 arquivo: `documento_service.py`)
- **Problema:** 7 routers fazem queries diretas ao banco, duplicando logica de ownership check, agregacao, e cascade. Subscription, cronograma, checklist, financeiro, prestadores — todos sem service layer.
- **Correcao:** Criar services para: `obra_service.py`, `etapa_service.py`, `checklist_service.py`, `financeiro_service.py`, `subscription_service.py`, `prestadores_service.py`, `convites_service.py`.

---

## FASE 2 - ALTO (Corrigir Esta Semana)

### SEC-03v2: CORS Regex Permissiva Demais
- **Onde:** `server/app/main.py` (linha 68)
- **Problema:** Regex `https://mestreobra-[a-z0-9.-]*\.run\.app$` aceita qualquer subdominios como `mestreobra-attacker.run.app`.
- **Correcao:** Whitelist explicita de dominios ao inves de regex.

### SEC-04v2: Magic Link Logado em Stderr Quando Email Nao Configurado
- **Onde:** `server/app/email_service.py` (linhas 104-107)
- **Problema:** Token de convite (magic link) logado em texto claro no stderr como fallback.
- **Correcao:** Logar apenas hash do token: `hashlib.sha256(token.encode()).hexdigest()`.

### SEC-05v2: Autorizacao Ausente no Endpoint de Score
- **Onde:** `server/app/routers/etapas.py` (linhas 31-50)
- **Problema:** `/api/etapas/{etapa_id}/score` verifica que a etapa existe, mas NAO verifica que o usuario atual e dono da obra.
- **Correcao:** Adicionar ownership check via `_verify_etapa_ownership()`.

### SEC-06v2: Role-Based Access Ausente em Prestadores
- **Onde:** `server/app/routers/prestadores.py` (linhas 41-61)
- **Problema:** Qualquer usuario autenticado (incluindo `convidado`) pode criar prestadores. Deveria ser restrito a `owner`.
- **Correcao:** Usar `Depends(require_owner)` no endpoint de criacao.

### SEC-07v2: Convite Token Reutilizavel Apos Aceitacao
- **Onde:** `server/app/routers/convites.py` (linhas 159-172)
- **Problema:** Apos aceitar convite, o token permanece valido e pode ser reutilizado. Comparacao de expiracao usa `<` ao inves de `<=`.
- **Correcao:** Invalidar token apos uso (`convite.token = None`) e usar `<=` na comparacao.

### PERF-04v2: Sem Paginacao no Historico de Normas
- **Onde:** `server/app/routers/normas.py` (linhas 109-130)
- **Problema:** `listar_historico_normas()` carrega TODOS os `NormaResultado` para cada log sem limit. 20 logs x 50 resultados = 1000+ registros.
- **Correcao:** Adicionar `.limit(5)` por log e `offset` na query principal.

### PERF-05v2: Indexes Compostos Ausentes
- **Onde:** `server/app/models.py`
- **Problema:** Queries frequentes sem index composto:
  - `ProjetoDoc(obra_id, status)` — usado em documentos router
  - `ChecklistItem(etapa_id, status)` — usado em calcularScore
  - `Despesa(obra_id, data)` — usado em financeiro
  - `AtividadeCronograma(obra_id, nivel)` — usado em cronograma
- **Correcao:** Criar migration com indexes compostos.

### PERF-06v2: Relatorio Financeiro Sem Cache
- **Onde:** `server/app/routers/financeiro.py` (linhas 116-192)
- **Problema:** Recalcula tudo (etapas + orcamentos + despesas) a cada chamada. Dados financeiros so mudam quando nova despesa e inserida.
- **Correcao:** Cache em memoria com TTL de 5 minutos, invalidado ao inserir despesa.

### PERF-07v2: Sem Deduplicacao de Requests no Flutter
- **Onde:** `lib/api/api.dart`
- **Problema:** Se usuario troca rapidamente entre telas, mesma API e chamada multiplas vezes simultaneamente. Sem deduplication de in-flight requests.
- **Correcao:** Map de requests pendentes — reutilizar Future se ja existe chamada identica em andamento.

### ARQ-03v2: Excecoes em Background Tasks Nao Propagadas
- **Onde:** `server/app/routers/checklist_inteligente.py` (linhas 148-155), `server/app/routers/documentos.py` (linhas 212-216)
- **Problema:** Threads daemon e tasks async nao atualizam status para ERRO quando falham. Erros desaparecem silenciosamente.
- **Correcao:** Wrapper com try/except que persiste `status=ERRO` + `erro_detalhe` no banco.

### ARQ-04v2: Error Handling Inconsistente nos Routers
- **Onde:** `server/app/routers/` (todos)
- **Problema:** 3 padroes diferentes: (1) `detail` string, (2) `detail` + logging, (3) status code sem detail. Alguns `except Exception: pass` (subscription.py:279).
- **Correcao:** Criar `APIError(HTTPException)` padronizado com `error_code`, `detail`, `timestamp`.

### COMPL-01v2: Arquivos God Class >500 Linhas
- **Onde:**
  - `lib/screens/checklist_inteligente_screen.dart` — 756 linhas
  - `lib/screens/home_screen.dart` — 663 linhas
  - `lib/screens/detalhamento_comodos_screen.dart` — 618 linhas
  - `lib/screens/document_analysis_screen.dart` — 601 linhas
  - `lib/screens/cronograma_screen.dart` — 594 linhas
  - `server/app/checklist_inteligente.py` — 787 linhas
  - `server/app/routers/cronograma.py` — 501 linhas
  - `server/app/routers/subscription.py` — 491 linhas
- **Correcao:** Dividir em widgets/funcoes menores com responsabilidade unica.

### COMPL-02v2: Pattern de Error Handling Duplicado em 21+ Telas Dart
- **Onde:** `lib/screens/` — 21+ arquivos com pattern identico
- **Problema:** Bloco `catch (e) { if (e is AuthExpiredException) { if (mounted) handleApiError(context, e); return; } ... SnackBar }` repetido 20+ vezes.
- **Correcao:** Criar mixin `ApiErrorHandlerMixin` com metodo `withErrorHandling<T>()`.

### COMPL-03v2: _cascade_delete_obra_data CC~18
- **Onde:** `server/app/routers/obras.py` (linhas 171-229)
- **Problema:** Funcao com CC~18, 10+ cascade deletes em sequencia com multiplos ifs aninhados.
- **Correcao:** Extrair funcoes por entidade: `_delete_projeto_cascade()`, `_delete_etapa_cascade()`, `_delete_atividade_cascade()`.

---

## FASE 3 - MEDIO (Corrigir em 2 Semanas)

### SEC-08v2: SSL Nao Obrigatorio por Default na DB
- **Onde:** `server/app/db.py` (linhas 14-15)
- **Problema:** SSL so ativado se `REQUIRE_SSL` env var for setada. Default e inseguro.
- **Correcao:** Inverter logica — SSL ativado por default, desativado explicitamente com `REQUIRE_SSL=false`.

### SEC-09v2: Google OAuth Sem Validacao de Email Vazio
- **Onde:** `server/app/routers/auth.py` (linhas 128-133)
- **Problema:** Se Google retornar sem email (raro mas possivel), cria usuario com `email=""` e tenta split em "@".
- **Correcao:** Validar `if not email: raise HTTPException(400, "Google account must have email")`.

### SEC-10v2: Sem Certificate Pinning no Flutter
- **Onde:** `lib/api/api.dart`, `lib/services/auth_service.dart`
- **Problema:** HTTP client sem certificate pinning. Vulneravel a MITM mesmo com certificados validos.
- **Correcao:** Implementar pinning com `SecurityContext.defaultContext`.

### SEC-11v2: Upload Visual AI Sem Limite de Tamanho
- **Onde:** `server/app/routers/visual_ai.py` (linhas 27-58)
- **Problema:** Aceita upload de imagem sem validacao de tamanho. Potencial DoS por storage exhaustion.
- **Correcao:** Validar `file.file.seek(0, SEEK_END)` e rejeitar > 10MB.

### SEC-12v2: Sem CSP Header
- **Onde:** `server/app/main.py` (linhas 47-55)
- **Problema:** Security headers incluem X-Frame-Options, HSTS, etc., mas falta Content-Security-Policy.
- **Correcao:** Adicionar `Content-Security-Policy: default-src 'self'; script-src 'self'`.

### PERF-08v2: Prestadores Agrega Avaliacoes em Python ao Inves de SQL
- **Onde:** `server/app/routers/prestadores.py` (linhas 92-119)
- **Problema:** Busca todas as avaliacoes e calcula media em loop Python. 10 prestadores x 50 avaliacoes = 500 registros processados em Python.
- **Correcao:** Usar `func.avg()` e `func.count()` com GROUP BY no banco.

### PERF-09v2: Relatorio Financeiro Carrega Tudo Sem Agregacao
- **Onde:** `server/app/routers/financeiro.py` (linhas 125-136)
- **Problema:** Carrega TODAS etapas, orcamentos e despesas em memoria. Deveria agregar no banco.
- **Correcao:** `func.sum(Despesa.valor).group_by(Despesa.etapa_id)` ao inves de carregar tudo.

### PERF-10v2: SSE Stream Sem Cleanup em Disconnect do Cliente
- **Onde:** `server/app/routers/checklist_inteligente.py` (linhas 41-80)
- **Problema:** Se cliente desconectar mid-stream, o generator continua rodando, consumindo CPU/memoria.
- **Correcao:** Tratar `GeneratorExit` e cancelar operacao no finally.

### PERF-11v2: Visual AI Insere Achados em Loop ao Inves de Batch
- **Onde:** `server/app/routers/visual_ai.py` (linhas 73-86)
- **Problema:** Loop de `session.add(achado)` para cada achado. Deveria usar `session.add_all()`.
- **Correcao:** `session.add_all(achados_list)` + unico commit.

### ARQ-05v2: Variaveis de Ambiente Nao Validadas no Startup
- **Onde:** `server/app/main.py` (linhas 76-87)
- **Problema:** Se DB falhar no startup, app continua e falha na primeira request. Se S3_BUCKET nao estiver setado, ignora silenciosamente. STRIPE_SECRET_KEY so falha no primeiro checkout.
- **Correcao:** Usar Pydantic `BaseSettings` para validar todas as variaveis obrigatorias no startup. Fail fast.

### ARQ-06v2: Schemas Pydantic Incompletos para Responses Complexas
- **Onde:** `server/app/routers/documentos.py` (linhas 270-273), `server/app/routers/cronograma.py` (linhas 174-179)
- **Problema:** Endpoints retornam dicts sem schema tipado. `{"projeto": {...}, "riscos": [...]}` sem Pydantic model.
- **Correcao:** Criar `ProjetoAnalisisResponse`, `CronogramaResponse` etc. com `response_model=`.

### ARQ-07v2: Sem Testes no Backend (0 arquivos)
- **Onde:** `server/` (nenhum diretorio tests/)
- **Problema:** Zero testes para routers, services, auth, modelos. Impossivel validar regressoes.
- **Correcao:** Criar `server/tests/` com pytest + httpx para integration tests dos endpoints criticos.

### COMPL-04v2: Deep Nesting >4 Niveis em _exportarExcel
- **Onde:** `lib/screens/detalhamento_comodos_screen.dart` (linhas 75-150)
- **Problema:** Funcao de 76 linhas com nesting de 5 niveis (for dentro de for dentro de if).
- **Correcao:** Extrair `_applyHeadersToSheet()`, `_populateComodoRows()`.

### COMPL-05v2: Magic Numbers Hardcoded
- **Onde:** `lib/screens/cronograma_screen.dart` (linhas 181-193), `lib/screens/detalhamento_comodos_screen.dart` (linhas 128-145)
- **Problema:** Thresholds (0, 10, 1000000), indices de coluna, durations hardcoded sem constantes nomeadas.
- **Correcao:** Extrair para constantes: `BUDGET_DEVIATION_CRITICAL`, `STANDARD_ANIMATION_DURATION`, etc.

### COMPL-06v2: Codigo de Contexto Documentos Duplicado 3x
- **Onde:** `server/app/routers/checklist_inteligente.py` (linhas 390-402, 444-452, 486-494)
- **Problema:** Bloco identico que monta `contexto_docs` (query ProjetoDoc + Risco + join) aparece 3 vezes.
- **Correcao:** Extrair `_build_documento_contexto(obra_id, session)` e reutilizar.

---

## FASE 4 - BAIXO (Backlog / Melhorias Continuas)

### SEC-13v2: URL de Producao Hardcoded como Default
- **Onde:** `lib/api/api.dart` (linhas 10-14)
- **Problema:** `defaultValue: "https://mestreobra-backend-...run.app"` — desenvolvimento pode acidentalmente apontar para producao.
- **Correcao:** Sem default — forcar `--dart-define=API_BASE_URL=...` ou usar `http://localhost:8000` como dev default.

### SEC-14v2: Sem Audit Logging para Operacoes Sensiveis
- **Onde:** Todos os routers
- **Problema:** Sem log para: mudanca de senha, delete de conta, grant de permissoes, updates financeiros.
- **Correcao:** `audit_log(action, user_id, details)` nos endpoints criticos.

### SEC-15v2: Email Logado em Tentativas de Login Falhas
- **Onde:** `server/app/routers/auth.py` (linhas 59, 62)
- **Problema:** Email do usuario logado em texto claro em tentativas falhas. Pode levar a email enumeration via logs.
- **Correcao:** Logar apenas `request.client.host` sem o email.

### SEC-16v2: Redirect URLs do Stripe Sem Validacao
- **Onde:** `server/app/routers/subscription.py` (linhas 119-120)
- **Problema:** Success/cancel URLs lidas de env sem validar dominio. Open redirect potential.
- **Correcao:** Validar que URLs comecam com dominio confiavel.

### PERF-12v2: Normas Screen Sem Cache de Busca
- **Onde:** `lib/screens/normas_screen.dart` (linhas 47-67)
- **Problema:** Cada busca de norma (etapa+local) faz nova chamada IA (GPT-4o + web search), mesmo para busca identica.
- **Correcao:** Cache em memoria por `"$etapa:$local"`.

### ARQ-08v2: Navegacao Inconsistente (Navigator.push vs GoRouter)
- **Onde:** `lib/screens/main_shell.dart`, `lib/screens/auth_gate.dart`
- **Problema:** Mix de `Navigator.push` e padroes de GoRouter. Sem deep linking.
- **Correcao:** Padronizar em GoRouter com redirect de auth.

### ARQ-09v2: Provider Pattern Incompleto
- **Onde:** `lib/providers/subscription_provider.dart`, `lib/providers/obra_provider.dart`
- **Problema:** `obra_provider.dart` praticamente vazio (~469 bytes). `subscription_provider.dart` sem cache, sem error handling, sem refresh.
- **Correcao:** Implementar providers completos com Riverpod.

### COMPL-07v2: Funcoes com >5 Parametros
- **Onde:** `server/app/routers/checklist_inteligente.py` (linhas 345-370), `lib/screens/cronograma_screen.dart` (`_buildCronogramaRow`)
- **Correcao:** Usar data classes / named parameters.

### COMPL-08v2: Naming Inconsistente
- **Onde:** Multiplos arquivos
- **Problema:** Mix de `dataInicio` / `data_inicio` em Dart. Abreviacoes como `_brl`, `_pct` sem clareza. `_gerar` vs `generate`.
- **Correcao:** Padronizar camelCase no Dart, snake_case no Python. Nomes completos sem abreviacoes.

### COMPL-09v2: TODO Nao Resolvido
- **Onde:** `lib/services/notification_service.dart` (linha 169)
- **Problema:** `// TODO (Fase Auth): navegar para a obra indicada em message.data['obra_id']` — referencia fase inexistente.
- **Correcao:** Resolver ou remover.

---

## Plano de Implantacao

```
Semana 1 (FASE 1 - Critico):
  [x] SEC-01v2: Validacao de complexidade de senha — field_validator no UserRegister (min 8, letra+numero)
  [x] SEC-02v2: Fix IDOR em documentos — ownership check em deletar, analisar, obter_analise
  [x] PERF-01v2: Resolver N+1 no cronograma — batch fetch L1+L2+servicos em 2 queries
  [x] PERF-02v2: Thread pool controlado no checklist inteligente — ThreadPoolExecutor(4) + error handling
  [ ] PERF-03v2: Lazy loading no dashboard home
  [ ] ARQ-01v2: State management com Riverpod (inicio)
  [ ] ARQ-02v2: Service layer (inicio — subscription, cronograma, checklist)

Semana 2 (FASE 2 - Alto):
  [x] SEC-03v2: Whitelist CORS explicita — regex restrita ao dominio exato do Cloud Run
  [x] SEC-04v2: Nao logar magic links — token hash no fallback log
  [x] SEC-05v2: Auth check no score endpoint — _verify_etapa_ownership adicionado
  [x] SEC-06v2: Role check em prestadores — require owner/admin na criacao
  [x] SEC-07v2: Invalidar convite token apos uso — token=None + comparacao <=
  [x] PERF-04v2: Paginacao no historico de normas — offset + batch fetch resultados
  [x] PERF-05v2: Indexes compostos — migration 0024 com 6 indexes
  [x] PERF-06v2: Cache no relatorio financeiro — Cache-Control private max-age=60
  [x] PERF-07v2: Request deduplication no ApiClient — _deduplicatedGet em 4 endpoints
  [x] ARQ-03v2: Error handling em background tasks — coberto por PERF-02v2 (ThreadPoolExecutor + error persist)
  [ ] ARQ-04v2: Padronizar error responses
  [ ] COMPL-01v2: Dividir god classes (inicio)
  [ ] COMPL-02v2: Mixin de error handling no Dart
  [x] COMPL-03v2: Refatorar _cascade_delete_obra_data — 4 funcoes menores extraidas

Semana 3-4 (FASE 3 - Medio):
  [ ] SEC-08v2: SSL obrigatorio por default
  [ ] SEC-09v2: Validacao email Google OAuth
  [ ] SEC-10v2: Certificate pinning Flutter
  [ ] SEC-11v2: Limite de tamanho upload Visual AI
  [ ] SEC-12v2: Adicionar CSP header
  [ ] PERF-08v2: Agregacao SQL em prestadores
  [ ] PERF-09v2: Agregacao SQL no financeiro
  [ ] PERF-10v2: Cleanup SSE stream
  [ ] PERF-11v2: Batch insert achados
  [ ] ARQ-05v2: Validacao de env vars no startup
  [ ] ARQ-06v2: Schemas Pydantic para responses complexas
  [ ] ARQ-07v2: Testes backend com pytest
  [ ] COMPL-04v2: Reduzir nesting em _exportarExcel
  [ ] COMPL-05v2: Extrair magic numbers para constantes
  [x] COMPL-06v2: Extrair _build_documento_contexto — helper unico substitui 3 blocos duplicados

Mes 2+ (FASE 4 - Backlog):
  [ ] SEC-13v2: Remover URL producao hardcoded
  [ ] SEC-14v2: Audit logging
  [ ] SEC-15v2: Nao logar email em login falho
  [ ] SEC-16v2: Validar redirect URLs do Stripe
  [ ] PERF-12v2: Cache busca de normas
  [ ] ARQ-08v2: Padronizar navegacao com GoRouter
  [ ] ARQ-09v2: Completar providers Riverpod
  [ ] COMPL-07v2: Reduzir parametros de funcoes
  [ ] COMPL-08v2: Padronizar naming
  [ ] COMPL-09v2: Resolver TODO pendente
```

---

## Metricas de Sucesso

- **Seguranca:** Zero IDOR; senhas fortes obrigatorias; tokens invalidados apos uso; RBAC em todos os endpoints
- **Performance:** Zero N+1 queries; paginacao em todos os endpoints de lista; cache em relatorios; request deduplication
- **Complexidade:** Nenhum arquivo > 500 linhas; CC < 15 em todas as funcoes; zero codigo duplicado > 5 linhas
- **Arquitetura:** Service layer cobrindo 100% dos routers; state management via Riverpod; 80%+ coverage de testes backend
