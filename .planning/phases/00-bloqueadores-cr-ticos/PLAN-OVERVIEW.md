# Fase 0 — Plano Executavel

## Objetivo da fase
Estabilizar producao antes de novas features, atendendo integralmente INFRA-01..INFRA-05 com evidencias objetivas de deploy fresh, seguranca de autenticacao, regra correta de cancelamento, PDF UTF-8 e eliminacao de cold start.

## Goal-backward analysis

### Success criterion 1 -> INFRA-01
Verdade observavel: deploy fresh executa migrations sem erro.
Como provar:
- Tarefa 00-01-T01 normaliza IDs/referencias Alembic para cadeia linear unica.
- Tarefa 00-01-T02 valida em banco limpo com `alembic heads`, `alembic history --verbose`, `alembic upgrade head`.
Evidencia final:
- 1 head unico e upgrade concluido sem duplicate revision ou broken down_revision.

### Success criterion 2 -> INFRA-02
Verdade observavel: usuario cancelado segue com acesso pago ate fim do ciclo.
Como provar:
- Tarefa 00-02-T03 remove downgrade imediato no endpoint de cancelamento.
- Tarefa 00-02-T04 move downgrade definitivo para evento final (webhook/expiry path).
- Tarefa 00-02-T05 cobre testes do fluxo temporal de assinatura.
Evidencia final:
- Cancelamento marca fim de periodo sem trocar plano para gratuito na hora.

### Success criterion 3 -> INFRA-03
Verdade observavel: tokens forjados/invalidos sao rejeitados com JWT seguro.
Como provar:
- Tarefa 00-02-T01 troca `python-jose` por `PyJWT>=2.8.0`.
- Tarefa 00-02-T02 adapta encode/decode e tratamento de excecoes mantendo contrato HS256.
- Tarefa 00-02-T05 executa testes de token valido, expirado e forjado.
Evidencia final:
- Dependencia vulneravel removida e autenticacao protegida sem regressao funcional.

### Success criterion 4 -> INFRA-04
Verdade observavel: PDF com caracteres PT-BR mostra acentos corretos.
Como provar:
- Tarefa 00-03-T01 migra geracao de PDF para WeasyPrint + Jinja2 com fonte Unicode.
- Tarefa 00-03-T02 adapta endpoint de exportacao para novo renderer mantendo contrato HTTP.
- Tarefa 00-03-T03 executa testes com strings contendo ã, ç, é, ê, õ e valida byte/output final.
Evidencia final:
- PDF sem substituicoes por `?` ou quadrados para nomes/enderecos/itens em portugues.

### Success criterion 5 -> INFRA-05
Verdade observavel: primeira resposta apos idle < 2s por min-instances=1.
Como provar:
- Tarefa 00-01-T03 atualiza deploy script com `--min-instances=1`.
- Tarefa 00-01-T04 valida configuracao efetiva no Cloud Run e mede latencia pos-idle.
Evidencia final:
- Campo de min instances ativo no servico e medicao dentro da meta.

## Plano por workstream

### 00-01 — Alembic + Cloud Run (INFRA-01, INFRA-05)
Escopo:
- Corrigir cadeia de migrations quebrada/duplicada.
- Tornar `min-instances=1` declarativo no deploy.

Entregaveis:
- Cadeia Alembic linear e aplicavel em banco limpo.
- Deploy script com configuracao anti-cold-start.
- Evidencia de latencia inicial dentro da meta.

Rollback:
- Alembic: manter backup dos arquivos de migration originais em branch; se falhar validacao, restaurar IDs/down_revision anteriores e bloquear merge.
- Cloud Run: rollback de revisao (`gcloud run services update-traffic ...`) para revisao anterior sem min-instances e reabrir investigacao de custo/latencia.

### 00-02 — JWT + Assinatura Stripe (INFRA-02, INFRA-03)
Escopo:
- Migrar autenticacao para PyJWT >=2.8.0.
- Corrigir cancelamento para nao efetuar downgrade imediato.

Entregaveis:
- `python-jose` removido de runtime.
- Fluxo de cancelamento com estado intermediario ate fim do periodo.
- Testes de seguranca e regra de negocio de assinatura passando.

Rollback:
- JWT: manter compatibilidade de claims; se quebrar login/refresh em homologacao, reverter commit de auth/deps e reaplicar hotfix com testes ampliados.
- Stripe: se webhook final falhar em ambiente real, ativar compensacao temporaria por job diario de reconciliacao de expirados.

### 00-03 — PDF UTF-8 (INFRA-04)
Escopo:
- Trocar renderer atual por WeasyPrint + Jinja2 para Unicode real.

Entregaveis:
- PDF com acentuacao correta em textos PT-BR.
- Endpoint de exportacao mantendo contrato de download.
- Evidencia de regressao visual minima (layout funcional e legivel).

Rollback:
- Preservar implementacao anterior em branch/tag.
- Em caso de falha de runtime de dependencia nativa, fallback temporario para motor anterior com fonte TTF Unicode ate estabilizar build final.

## Lista de tarefas atomicas (checklist)

### Contrato minimo por tarefa
Toda tarefa desta fase deve explicitar os campos abaixo antes da execucao:
- Files: arquivos exatos a alterar
- Action: alteracao concreta e delimitada
- Verify: comando objetivo para validar resultado
- Done: criterio mensuravel de conclusao

### Matriz requirement -> tarefas obrigatorias
- INFRA-01: 00-01-T01, 00-01-T02
- INFRA-02: 00-02-T03, 00-02-T04, 00-02-T05
- INFRA-03: 00-02-T01, 00-02-T02, 00-02-T05
- INFRA-04: 00-03-T01, 00-03-T02, 00-03-T03
- INFRA-05: 00-01-T03, 00-01-T04

### Workstream 00-01
- [ ] 00-01-T01 (Risco: alto)
  - Requirement(s): INFRA-01
  - Files: `server/alembic/versions/20260309_0014_add_valor_realizado.py`, `server/alembic/versions/20260309_0014_checklist_unificado.py`, `server/alembic/versions/20260319_0023_projetodoc_erro_detalhe.py`, `server/alembic/versions/20260319_0024_composite_indexes.py`
  - Action: normalizar revision IDs unicos e ajustar `down_revision` para cadeia linear unica sem bifurcacao.
  - Verify: `cd server && python -m alembic heads && python -m alembic history --verbose`
  - Done: `alembic heads` retorna 1 head e `history` sem referencia quebrada.
- [ ] 00-01-T02 (Risco: medio)
  - Requirement(s): INFRA-01
  - Files: `server/alembic.ini`, `server/alembic/versions/*.py`
  - Action: validar aplicacao da cadeia em banco limpo para garantir deploy fresh.
  - Verify: `cd server && python -m alembic upgrade head`
  - Done: comando conclui sem erro de duplicate revision ou broken `down_revision`.
- [ ] 00-01-T03 (Risco: baixo)
  - Requirement(s): INFRA-05
  - Files: `server/deploy-cloudrun.sh`
  - Action: incluir `--min-instances=1` no comando de deploy Cloud Run.
  - Verify: `cd server && rg -- '--min-instances=1' deploy-cloudrun.sh`
  - Done: script de deploy contem flag de instancia minima fixa.
- [ ] 00-01-T04 (Risco: medio)
  - Requirement(s): INFRA-05
  - Files: `server/deploy-cloudrun.sh`
  - Action: executar deploy de validacao e medir latencia pos-idle com protocolo reproduzivel.
  - Verify: `gcloud run services describe mestreobra-backend --region us-central1 --project mestreobra --format="value(spec.template.scaling.minInstanceCount)"`
  - Done: `minInstanceCount=1` e medicao de 5 requisicoes apos 15 min idle com p95 < 2s.

Gate de saida do plano 00-01:
- Cadeia Alembic linear e validada em banco limpo.
- Deploy script com min instances configurado.
- Protocolo de latencia executado com evidencias.

### Workstream 00-02 - JWT + Assinatura Stripe (INFRA-02, INFRA-03)
- [ ] 00-02-T01 (Risco: medio)
  - Requirement(s): INFRA-03
  - Files: `server/requirements.txt`, `server/requirements-dev.txt`
  - Action: remover `python-jose[cryptography]` e adicionar `PyJWT>=2.8.0` nas dependencias.
  - Verify: `cd server && rg -n 'python-jose|PyJWT' requirements*.txt`
  - Done: dependencia vulneravel removida e PyJWT declarado em versao compativel.
- [ ] 00-02-T02 (Risco: alto)
  - Requirement(s): INFRA-03
  - Files: `server/app/auth.py`
  - Action: migrar encode/decode e excecoes para PyJWT mantendo HS256, claims e respostas HTTP.
  - Verify: `cd server && pytest -q tests -k 'auth or jwt or token'`
  - Done: tokens validos funcionam; tokens expirados/forjados retornam 401.
- [ ] 00-02-T03 (Risco: alto)
  - Requirement(s): INFRA-02
  - Files: `server/app/routers/subscription.py`
  - Action: ajustar cancelamento para `cancel_at_period_end` sem troca imediata para plano gratuito.
  - Verify: `cd server && pytest -q tests -k 'subscription and cancel'`
  - Done: cancel request nao faz downgrade imediato no banco local.
- [ ] 00-02-T04 (Risco: medio)
  - Requirement(s): INFRA-02
  - Files: `server/app/routers/subscription.py`
  - Action: efetivar downgrade somente no evento terminal da assinatura (webhook/reconciliacao).
  - Verify: `cd server && pytest -q tests -k 'subscription and webhook'`
  - Done: downgrade acontece apenas em evento final de expiracao/cancelamento definitivo.
- [ ] 00-02-T05 (Risco: medio)
  - Requirement(s): INFRA-02, INFRA-03
  - Files: `server/tests/test_auth.py`, `server/tests/test_subscription.py`
  - Action: criar/ajustar testes de regressao de auth e assinatura com cenarios temporais e de seguranca.
  - Verify: `cd server && pytest -q tests -k 'auth or jwt or subscription or cancel'`
  - Done: suite dedicada verde cobrindo token valido/expirado/forjado e cancelamento por periodo.

Checkpoint Onda A (seguranca auth):
- 00-02-T01 concluida
- 00-02-T02 concluida
- Validacao auth/jwt verde

Checkpoint Onda B (regra de assinatura):
- 00-02-T03 concluida
- 00-02-T04 concluida
- 00-02-T05 concluida
- Validacao subscription verde

Gate de saida do plano 00-02:
- PyJWT >= 2.8.0 em runtime sem python-jose.
- Cancelamento sem downgrade imediato e downgrade no evento terminal.
- Testes de auth/subscription aprovados.

### Workstream 00-03
- [ ] 00-03-T01 (Risco: alto)
  - Requirement(s): INFRA-04
  - Files: `server/app/pdf.py`, `server/requirements.txt`
  - Action: implementar renderer WeasyPrint + Jinja2 com suporte Unicode real para texto PT-BR.
  - Verify: `cd server && rg -n 'weasyprint|jinja2' app/pdf.py requirements.txt`
  - Done: renderer novo integrado com biblioteca UTF-8 e sem conversao latin1 com replace.
- [ ] 00-03-T02 (Risco: medio)
  - Requirement(s): INFRA-04
  - Files: `server/app/routers/obras.py`, `server/app/pdf.py`
  - Action: adaptar endpoint de exportacao para usar novo renderer mantendo contrato HTTP existente.
  - Verify: `cd server && pytest -q tests -k 'pdf and obras'`
  - Done: endpoint retorna PDF valido com status e headers inalterados.
- [ ] 00-03-T03 (Risco: medio)
  - Requirement(s): INFRA-04
  - Files: `server/tests/test_pdf.py`
  - Action: validar corpus PT-BR com acentos e caracteres especiais sem corrupcao.
  - Verify: `cd server && pytest -q tests -k 'pdf'`
  - Done: caracteres `ã, ç, é, ê, õ, á, í, ó, ú` legiveis no PDF gerado.

Gate de saida do plano 00-03:
- PDF UTF-8/PT-BR sem corrupcao de caracteres.
- Endpoint de exportacao preservado.
- Evidencia funcional anexada com corpus de acentuacao.

## Dependencias e paralelizacao possivel

Dependencias obrigatorias:
- 00-01-T01 -> 00-01-T02
- 00-02-T01 -> 00-02-T02
- 00-02-T03 -> 00-02-T04
- 00-03-T01 -> 00-03-T02 -> 00-03-T03

Dependencias entre workstreams:
- 00-01 nao bloqueia 00-02 tecnicamente; podem iniciar em paralelo.
- 00-03 pode rodar em paralelo com 00-02, desde que equipe aceite dependencia nativa do WeasyPrint no ambiente.
- Gate final da fase depende de validacao concluida dos 3 workstreams.

Waves recomendadas:
- Wave 1 (paralelo): 00-01-T01, 00-02-T01, 00-02-T03, 00-03-T01
- Wave 2 (paralelo): 00-01-T02, 00-02-T02, 00-02-T04, 00-03-T02
- Wave 3: 00-02-T05, 00-03-T03, 00-01-T03
- Wave 4: 00-01-T04 + consolidacao de evidencias da fase

## Plano de validacao (comandos e evidencias esperadas)

### INFRA-01 (Alembic)
Comandos:
```bash
cd server
python -m alembic heads
python -m alembic history --verbose
python -m alembic upgrade head
```
Evidencias esperadas:
- `heads` com apenas 1 head.
- `upgrade head` concluido sem erro de revision duplicada/quebrada.

### INFRA-02 (Cancelamento assinatura)
Comandos:
```bash
cd server
pytest -q tests -k "subscription and cancel"
```
Evidencias esperadas:
- Testes confirmam que usuario permanece pago ate fim do periodo.
- Nao ocorre mudanca imediata para plano gratuito no cancelamento.

### INFRA-03 (JWT PyJWT)
Comandos:
```bash
cd server
pip show PyJWT
pytest -q tests -k "auth or jwt or token"
```
Evidencias esperadas:
- `PyJWT` presente em versao >= 2.8.0.
- Cenarios de token forjado/expirado retornam 401.
- Login e refresh continuam operacionais.

### INFRA-04 (PDF UTF-8)
Comandos:
```bash
cd server
pytest -q tests -k "pdf"
# opcional smoke de endpoint:
# curl -H "Authorization: Bearer <token>" "http://localhost:8080/.../pdf" --output teste.pdf
```
Evidencias esperadas:
- PDF com strings PT-BR exibidas corretamente: acao, fundacao, construcao, Joao, orcamento.
- Ausencia de `?`/caracteres corrompidos no documento gerado.

### INFRA-05 (Cloud Run)
Comandos:
```bash
cd server
./deploy-cloudrun.sh

gcloud run services describe mestreobra-backend \
  --region us-central1 \
  --project mestreobra \
  --format="value(spec.template.scaling.minInstanceCount)"
```
Evidencias esperadas:
- Valor `1` para min instances.
- Protocolo de medicao:
  - Idle de 15 minutos
  - 5 requisicoes ao endpoint de health
  - Registrar tempos individuais
  - Aceite: p95 < 2s

## Estrategia de testes e qualidade
- Piramide minima da fase:
  - Unitario: auth decode/claims e regra de cancelamento.
  - Integracao: endpoint cancelamento + fluxo de status subscription.
  - Smoke operacional: alembic em banco limpo e deploy Cloud Run com min instances.
  - Funcional de artefato: PDF com corpus PT-BR de caracteres especiais.
- Regra de aceite de CI:
  - Nenhum merge de Fase 0 sem passar testes de auth/subscription/pdf e validacao de migration chain.

## Sequencia de implementacao recomendada
0. Preflight de ambiente: garantir Python 3.11 no ambiente alvo e executar comandos Alembic via `python -m alembic` no contexto de `server`.
1. Executar 00-01-T01/T02 para remover risco estrutural de deploy fresh.
2. Em paralelo, aplicar 00-02-T01/T03 para abrir frente de seguranca e receita.
3. Concluir 00-02-T02/T04/T05 e fechar INFRA-02/03.
4. Implementar 00-03-T01/T02/T03 e fechar INFRA-04.
5. Aplicar 00-01-T03/T04 em release candidate da fase e validar INFRA-05.
6. Consolidar evidencias por requirement e publicar checklist final de DoD.

## Definition of done da fase
A Fase 0 sera considerada concluida quando todos os pontos abaixo forem verdadeiros:
- [ ] INFRA-01: `alembic upgrade head` executa em banco limpo sem erro.
- [ ] INFRA-02: cancelamento nao faz downgrade imediato; acesso pago mantido ate fim do periodo.
- [ ] INFRA-03: autenticacao roda com `PyJWT>=2.8.0`, sem `python-jose` em producao.
- [ ] INFRA-04: PDF exportado preserva caracteres portugueses corretamente.
- [ ] INFRA-05: Cloud Run com `min-instances=1` efetivo e primeira resposta apos idle < 2s.
- [ ] Suite de testes da fase (auth/subscription/pdf/migrations) executada com sucesso.
- [ ] Plano de rollback documentado e testado por smoke em ambiente de homologacao.
- [ ] Evidencias (logs/comandos/artefatos) anexadas ao resumo da fase para auditoria.

## Template operacional por tarefa (obrigatorio)
Use este template para cada tarefa 00-01-Txx, 00-02-Txx e 00-03-Txx:

- Task ID:
- Requirement(s):
- Files:
- Action:
- Verify:
- Done: