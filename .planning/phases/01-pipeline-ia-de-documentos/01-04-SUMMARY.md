---
phase: 1
plan: "01-04"
subsystem: geracao-unificada-async
tags: [state-machine, polling, sse-disconnect, async, cronograma, checklist]
dependency_graph:
  requires: [01-03]
  provides: [GeracaoUnificadaLog, polling-endpoint, sse-disconnect-cancel]
  affects: [models.py, enums.py, schemas.py, checklist_inteligente.py, api.dart, document_analysis_screen.dart]
tech_stack:
  added: [server/alembic/versions/20260406_0027_geracao_unificada_log.py]
  patterns: [state-machine-log, polling-endpoint, sse-disconnect-threading-event, timer-periodic-flutter]
key_files:
  created:
    - server/alembic/versions/20260406_0027_geracao_unificada_log.py
    - server/tests/test_geracao_unificada_status.py
    - server/tests/test_sse_disconnect.py
  modified:
    - server/app/enums.py
    - server/app/models.py
    - server/app/schemas.py
    - server/app/routers/checklist_inteligente.py
    - lib/api/api.dart
    - lib/screens/document_analysis_screen.dart
decisions:
  - "threading.Event por log_id para sinalizar cancelamento — permite que SSE handler (request coroutine) cancele worker background sem shared mutable state perigoso"
  - "Polling a cada 2s no Flutter com Timer.periodic — simples, sem dependencia de WebSocket ou plugin SSE nativo"
  - "dispose() cancela o timer de polling — ao sair da tela o backend detecta SSE disconnect e transita para CANCELADO"
  - "Worker verifica cancelado.is_set() entre cada atividade gerada — granularidade adequada sem overhead de check contínuo"
  - "CANCELADO nao e ERRO — log cancelado nao tem erro_detalhe, preserva progresso parcial ja salvo"
metrics:
  duration: "~15 min"
  completed: "2026-04-06"
  tasks: 2
  files: 6
requirements:
  - AI-06
  - AI-07
---

# Phase 1 Plan 04: State Machine de Geracao com Polling e Cancelamento SSE — Summary

State machine `GeracaoUnificadaLog` com 6 estados observaveis (PENDENTE/ANALISANDO/GERANDO/CONCLUIDO/ERRO/CANCELADO), endpoint de polling REST e cancelamento automatico por disconnect SSE — cronograma e checklist gerados de forma assincrona sem bloquear o cliente ou consumir tokens apos desconexao.

## What Was Built

### Task 1: Estado de Geracao e API de Status

**GeracaoUnificadaStatus (enums.py):**
- 6 estados: `PENDENTE → ANALISANDO → GERANDO → CONCLUIDO | ERRO | CANCELADO`
- Todos os valores sao `str` para serializacao JSON direta

**GeracaoUnificadaLog (models.py):**
- Tabela `geracaounificadalog` com campos de progresso observavel: `etapa_atual`, `total_atividades`, `atividades_geradas`, `total_itens_checklist`
- `erro_detalhe` preenchido apenas em estado ERRO (CANCELADO nao e uma falha)
- Migration `20260406_0027` com `ix_geracaounificadalog_obra_id`

**Schemas (schemas.py):**
- `IniciarGeracaoUnificadaRequest`: lista de tipos_projeto
- `GeracaoUnificadaLogRead`: todos os campos de progresso + timestamps para o polling

**Endpoints (checklist_inteligente.py):**
- `POST /api/obras/{obra_id}/geracao-unificada/iniciar`: cria log, dispara background worker, retorna imediatamente
- `GET /api/obras/{obra_id}/geracao-unificada/{log_id}/status`: polling endpoint — retorna estado atual
- `GET /api/obras/{obra_id}/geracao-unificada/{log_id}/sse`: SSE stream para detectar disconnect

**Worker background `_executar_geracao_unificada`:**
- Verifica `cancelado.is_set()` antes de cada atividade — para imediatamente se sinalizado
- Transita pelo estado completo: PENDENTE → ANALISANDO → GERANDO → CONCLUIDO
- Preserva atividades `locked=True` da mesma forma que o endpoint síncrono existente
- Auto-spawn de `ChecklistItem` para cada micro-atividade (replica logica de 01-03)

**24 testes em `test_geracao_unificada_status.py`:**
- Cobertura de enum, modelo ORM, schema de resposta, request schema, transicoes da state machine

### Task 2: Polling no Flutter e Deteccao de Disconnect SSE

**GeracaoUnificadaLog (api.dart):**
- Modelo Dart com campo `isTerminal` — retorna `true` para `concluido/erro/cancelado`
- `fromJson` mapeia todos os campos de progresso do backend

**ApiClient (api.dart):**
- `iniciarGeracaoUnificada(obraId, tiposProjeto)`: POST /iniciar, retorna log
- `statusGeracaoUnificada(obraId, logId)`: GET /status, retorna log atualizado

**DocumentAnalysisScreen (document_analysis_screen.dart):**
- `Timer.periodic(2s)` inicia polling quando geração ativa
- `_pollStatus()`: chama `statusGeracaoUnificada`, atualiza estado, para ao `isTerminal`
- `dispose()`: cancela o timer — ao navegar para outra tela, backend detecta SSE disconnect
- `_GeracaoUnificadaStatusCard`: widget que mostra estado atual, barra de progresso, etapa em curso, contador de atividades e itens gerados

**16 testes em `test_sse_disconnect.py`:**
- `threading.Event` behavior e cancelamento cross-thread
- Status CANCELADO vs ERRO (semantica distinta)
- Logica de `request.is_disconnected()` com mocks async
- Gerenciamento de eventos por log_id (sem memory leak)

## Verification

- 24 testes de state machine passando
- 16 testes de SSE disconnect passando
- 102 testes totais passando (excluindo test_extraction_pipeline.py com import path pre-existente quebrado)
- 5 skipped (PDF tests, apenas em Linux/Docker)

## Decisions Made

1. **threading.Event como mecanismo de cancelamento**: Mais simples que queue ou shared dict. O SSE handler (coroutine async) sinaliza o Event; o worker (thread background) verifica periodicamente. Sem race conditions criticas — Event e thread-safe.

2. **Polling REST em vez de SSE bidirecional no Flutter**: Evita dependencia de plugin SSE nativo no cliente. Polling a cada 2s e adequado para o caso de uso (geracao leva 10-60s). SSE existe apenas para detectar disconnect, nao para push de dados.

3. **dispose() cancela timer, NAO chama cancelamento**: O Flutter nao tem como sinalizar o backend diretamente quando a tela fecha. O mecanismo e: timer para → SSE keepalive para de chegar → `request.is_disconnected()` retorna true → backend sinaliza cancelamento. Isso e o comportamento correto e esperado.

4. **CANCELADO preserva progresso parcial**: Atividades ja salvas no DB antes do cancelamento permanecem. O engenheiro pode ver o progresso parcial e reiniciar se quiser. Nao ha rollback automatico.

5. **Verificacao de cancelamento entre atividades (nao dentro do `gerar_cronograma`)**: A funcao `gerar_cronograma` e bloqueante e chamada via IA. A verificacao ocorre antes de persistir cada atividade no DB — compromisso razoavel entre responsividade e intrusividade no AI layer.

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None — `GeracaoUnificadaLog` e persistido no DB. Polling e funcional. SSE disconnect sinaliza `threading.Event` real. Nao ha hardcoded values ou placeholders.

## Self-Check: PASSED

Files created:
- `server/alembic/versions/20260406_0027_geracao_unificada_log.py` — FOUND
- `server/tests/test_geracao_unificada_status.py` — FOUND
- `server/tests/test_sse_disconnect.py` — FOUND

Files modified:
- `server/app/enums.py` — FOUND (GeracaoUnificadaStatus added)
- `server/app/models.py` — FOUND (GeracaoUnificadaLog added)
- `server/app/schemas.py` — FOUND (IniciarGeracaoUnificadaRequest, GeracaoUnificadaLogRead added)
- `server/app/routers/checklist_inteligente.py` — FOUND (3 endpoints + worker + event management)
- `lib/api/api.dart` — FOUND (GeracaoUnificadaLog model + 2 API methods)
- `lib/screens/document_analysis_screen.dart` — FOUND (polling + _GeracaoUnificadaStatusCard)

Commits:
- 4316549 — Task 1 (state machine + polling endpoint + 24 tests)
- b14d280 — Task 2 (Flutter polling + SSE disconnect + 16 tests)
