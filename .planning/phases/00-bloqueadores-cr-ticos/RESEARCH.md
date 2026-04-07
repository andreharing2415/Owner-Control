# Fase 0 - Bloqueadores Criticos - RESEARCH

**Data:** 2026-04-06  
**Escopo:** INFRA-01, INFRA-02, INFRA-03, INFRA-04, INFRA-05  
**Base de evidencia:** codigo real em `server/` + artefatos em `.planning/`

## Resumo executivo

A Fase 0 tem 5 bloqueadores que afetam deploy fresh, receita, seguranca de autenticacao, qualidade de relatorio PDF e latencia de producao. Todos os 5 itens possuem evidencia direta no codigo.

Recomendacao principal: executar em 3 ondas curtas e ordenadas:
1. Corrigir cadeia Alembic (INFRA-01) e validar em banco limpo.
2. Corrigir assinatura (INFRA-02) + migrar JWT para PyJWT (INFRA-03).
3. Corrigir PDF UTF-8 (INFRA-04) + ajustar deploy Cloud Run com min-instances=1 (INFRA-05).

## Project Constraints (from CLAUDE.md)

Diretivas aplicaveis para a fase:
- Plataforma permanece Android + iOS, sem web.
- Stack permanece Flutter + FastAPI + PostgreSQL.
- Deploy permanece em Cloud Run (projeto `mestreobra`, regiao `us-central1`).
- Monetizacao permanece Stripe (modelo atual de planos).
- Cadeia de IA Gemini -> Claude -> OpenAI deve ser preservada.
- Auth permanece JWT HS256, access 60 min e refresh 7 dias.

## Matriz de contexto por requisito

| ID | Contexto atual (evidencia) | Impacto atual |
|---|---|---|
| INFRA-01 | Duas migrations com mesmo `revision = "20260309_0014"` em `server/alembic/versions/20260309_0014_add_valor_realizado.py` e `server/alembic/versions/20260309_0014_checklist_unificado.py`; alem disso `20260319_0023_projetodoc_erro_detalhe.py` usa `revision = "0023"` e `down_revision = "0022"`, e `20260319_0024_composite_indexes.py` usa `revision = "0024"`, `down_revision = "0023"`. | Quebra `alembic upgrade head` em ambiente fresh (cadeia inconsistente e IDs duplicados). |
| INFRA-02 | Em `server/app/routers/subscription.py` (`cancel_subscription`), apos `stripe.Subscription.modify(..., cancel_at_period_end=True)`, o codigo faz downgrade imediato: `sub.status = "cancelled"`, `sub.plan = "gratuito"`, `current_user.plan = "gratuito"`. | Usuario perde acesso pago antes do fim do periodo ja cobrado. |
| INFRA-03 | `server/app/auth.py` usa `from jose import JWTError, jwt`; `server/requirements.txt` fixa `python-jose[cryptography]==3.3.0`. Requisito oficial pede PyJWT >= 2.8.0 (CVE-2024-33663). | Exposicao de seguranca em componente critico de autenticacao. |
| INFRA-04 | `server/app/pdf.py` usa `FPDF` + helper `_safe()` com `text.encode("latin1", errors="replace")`, o que substitui caracteres fora de latin1 por `?`. | Corrupcao de texto PT-BR em PDF (nomes/enderecos com acentos). |
| INFRA-05 | `server/deploy-cloudrun.sh` nao define `--min-instances`; deploy usa `gcloud run deploy ... --timeout 300 --memory 1Gi --cpu 1`. | Cold start persiste (tempo de primeira resposta elevado em uso esporadico de canteiro). |

## Evidencias em artefatos .planning

- `.planning/REQUIREMENTS.md` define explicitamente INFRA-01..05 para Phase 0.
- `.planning/ROADMAP.md` descreve os mesmos 5 criterios de sucesso para a fase.
- `.planning/codebase/CONCERNS.md` ja documenta:
  - IDs Alembic duplicados e quebra de fresh deploy.
  - Bug de downgrade imediato no cancelamento Stripe.
  - Risco de `python-jose` e migracao para PyJWT.
- `.planning/research/PITFALLS.md` reforca que Alembic/JWT/Stripe sao bloqueadores de alta prioridade.

## Arquivos alvo por item

### INFRA-01 - Alembic

Arquivos diretamente envolvidos:
- `server/alembic/versions/20260309_0014_add_valor_realizado.py`
- `server/alembic/versions/20260309_0014_checklist_unificado.py`
- `server/alembic/versions/20260319_0023_projetodoc_erro_detalhe.py`
- `server/alembic/versions/20260319_0024_composite_indexes.py`

Arquivos de suporte para validacao:
- `server/alembic.ini`
- `server/app/db.py` (hoje usa `create_all` no startup; risco de drift com Alembic)
- `server/app/main.py`

### INFRA-02 - Cancelamento Stripe

Arquivos diretamente envolvidos:
- `server/app/routers/subscription.py`

Arquivos de suporte:
- `server/app/models.py` (modelo `Subscription` com `status`, `plan`, `expires_at`)
- `server/app/schemas.py` (retornos de subscription)

### INFRA-03 - JWT PyJWT

Arquivos diretamente envolvidos:
- `server/app/auth.py`
- `server/requirements.txt`

Arquivos de suporte:
- `server/requirements-dev.txt` (se houver auditoria/lock para seguranca)
- rotas que dependem de `get_current_user` (impacto indireto)

### INFRA-04 - PDF UTF-8/PT-BR

Arquivos diretamente envolvidos:
- `server/app/pdf.py`
- `server/app/routers/obras.py` (endpoint de exportacao PDF)

Arquivos de suporte:
- `server/requirements.txt` (entrada de lib de PDF)
- templates/fontes estaticas, se estrategia migrar para HTML->PDF

### INFRA-05 - Cloud Run min instances

Arquivos diretamente envolvidos:
- `server/deploy-cloudrun.sh`

Arquivos de suporte:
- docs operacionais em `.planning/` (se existir checklist de deploy)

## Riscos tecnicos por item

### INFRA-01

- Alto risco de regressao de schema se renomear revision sem ajustar `down_revision` da cadeia inteira.
- Risco operacional: banco de producao ja migrado pode ter estado diferente de banco fresh.
- Risco de drift adicional porque `init_db()` usa `SQLModel.metadata.create_all(engine)` no startup.

Mitigacao:
- Tratar cadeia Alembic como source of truth e validar com banco limpo.
- Garantir cadeia linear unica antes de qualquer nova migration.

### INFRA-02

- Risco financeiro e de experiencia (downgrade precoce).
- Risco de estado divergente entre Stripe e banco local (se webhook atrasar/falhar).

Mitigacao:
- Cancel request apenas marca cancelamento no fim do periodo.
- Downgrade efetivo apenas por webhook de expiracao/cancelamento final.

### INFRA-03

- Risco de quebra de compatibilidade se excecoes e payload decode mudarem no swap da lib.
- Risco de invalidar refresh/access em clientes ja logados.

Mitigacao:
- Manter algoritmo HS256, claims atuais (`iss`, `aud`, `type`, `exp`) e mensagens HTTP inalteradas.
- Testar decode de token valido/invalido/expirado e fluxo de refresh.

### INFRA-04

- Risco de troca de engine de PDF exigir dependencia nativa em runtime (se usar WeasyPrint).
- Risco de quebra de layout/estilo do PDF atual.

Mitigacao:
- Definir estrategia clara: (A) manter fpdf2 com fonte Unicode TTF embutida, ou (B) migrar para WeasyPrint+Jinja2 (como roadmap sugere).
- Incluir teste com texto PT-BR real (acao, fundacao, construcao, Joao, orcamento).

### INFRA-05

- Risco de custo fixo mensal maior com instancia minima.
- Risco de alteracao manual fora de script gerar drift entre ambientes.

Mitigacao:
- Declarar `--min-instances=1` no script de deploy (infra como codigo).
- Validar pos-deploy com `gcloud run services describe` e checagem de spec.

## Dependencias e ordem recomendada

Ordem recomendada para minimizar retrabalho e risco:

1. **INFRA-01 (Alembic)**
- Precede tudo que dependa de deploy fresh/CI.
- Evita empilhar novas mudancas em cadeia quebrada.

2. **INFRA-02 + INFRA-03 (Subscription/JWT)**
- Podem ser executados na mesma onda backend.
- Ambos sao sensiveis (receita + seguranca) e independem de PDF/Cloud Run.

3. **INFRA-04 (PDF)**
- Pode vir apos seguranca/financeiro.
- Requer decisao de biblioteca e validacao funcional visual.

4. **INFRA-05 (Cloud Run)**
- Pode ser aplicado ao fim da fase, junto do deploy da correcao completa.
- Valida melhoria de latencia do pacote final.

Dependencias cruzadas relevantes:
- INFRA-01 deve vir antes de qualquer migration nova.
- INFRA-02 depende de webhook Stripe confiavel para downgrade tardio.
- INFRA-03 depende de atualizar dependencia e imports, com testes de auth.
- INFRA-04 depende de estrategia de engine PDF definida.
- INFRA-05 depende de pipeline de deploy em `server/deploy-cloudrun.sh`.

## Estrategia de validacao por item

### INFRA-01 - Alembic

Validacoes recomendadas:
1. `alembic heads` retorna 1 head apenas.
2. `alembic history --verbose` mostra cadeia linear sem referencia quebrada.
3. Em banco vazio: `alembic upgrade head` conclui sem erro.
4. Smoke de app sobe sem criar schema paralelo indevido.

Evidencia de aceite:
- Log de upgrade completo + saida de `heads/history` anexada em artefato da fase.

### INFRA-02 - Stripe cancelamento

Validacoes recomendadas:
1. Usuario ativo cancela assinatura e permanece com plano pago ate `expires_at`.
2. Endpoint de cancelamento nao altera `current_user.plan` para `gratuito` imediatamente.
3. Webhook de evento final (cancel/deleted) efetiva downgrade.
4. `GET /api/subscription/me` reflete status intermediario coerente.

Evidencia de aceite:
- Sequencia de estados antes/depois do cancelamento + apos webhook final.

### INFRA-03 - PyJWT

Validacoes recomendadas:
1. `requirements.txt` sem `python-jose`; com `PyJWT>=2.8.0`.
2. Login gera access/refresh validos.
3. Token invalido/expirado continua retornando 401 com mensagem esperada.
4. Fluxo protegido com `get_current_user` funciona sem regressao.

Evidencia de aceite:
- Testes de auth (unitarios/integracao) + auditoria de dependencia sem CVE alvo.

### INFRA-04 - PDF UTF-8/PT-BR

Validacoes recomendadas:
1. Exportar PDF com strings contendo `ã, ç, é, ê, õ, á, í, ó, ú`.
2. Abrir PDF e verificar caracteres corretos em titulo, obra, etapa e itens.
3. Validar que nao existem `?` por substituicao de encoding.

Evidencia de aceite:
- Amostra de PDF com texto de teste e checklist de caracteres.

### INFRA-05 - Cloud Run min-instances

Validacoes recomendadas:
1. Script contem `--min-instances=1`.
2. Pos-deploy: `gcloud run services describe` mostra `minInstanceCount=1` (ou campo equivalente).
3. Medir primeira requisicao apos idle e comparar com baseline (esperado < 2s no objetivo da fase).

Evidencia de aceite:
- Config efetiva da revisao + medicao de latencia de cold start reduzido.

## Environment availability (maquina atual)

Checagem real executada no ambiente local:

| Dependencia | Necessario para | Disponivel | Versao observada | Observacao |
|---|---|---|---|---|
| python | backend scripts/testes | Sim | 3.14.3 | Projeto alvo e Python 3.11; risco de incompatibilidade local |
| pip | deps Python | Sim | 26.0.1 | - |
| alembic CLI | validar INFRA-01 | Nao | - | executar via venv do projeto/`python -m alembic` |
| gcloud | deploy INFRA-05 | Sim | 561.0.0 | apto para validar Cloud Run |
| docker | ambiente local opcional | Sim | 29.2.1 | suporte para testes locais |

Impedimentos identificados:
- Sem runtime Python 3.11 detectado localmente.
- Sem comando `alembic` global detectado.

Fallback pratico:
- Rodar validacoes via ambiente do `server/` com deps instaladas (`python -m alembic ...`) em vez de depender de `alembic` global.

## Decisoes de implementacao recomendadas

1. **Alembic:** normalizar IDs para padrao date-prefix e cadeia linear unica; nao criar migration nova antes de corrigir as 4 migrations problematica.
2. **Stripe:** cancelar no periodo final sem downgrade imediato; downgrade final centralizado em webhook.
3. **JWT:** migrar para PyJWT mantendo claims, algoritmo HS256 e sem alterar contrato HTTP.
4. **PDF:** adotar estrategia Unicode real (preferencia do roadmap: WeasyPrint+Jinja2); evitar workaround de encoding latin1 com replace.
5. **Cloud Run:** tornar `min-instances=1` declarativo no script para evitar drift operacional.

## Arquivos potencialmente impactados pela implementacao

- `server/alembic/versions/20260309_0014_add_valor_realizado.py`
- `server/alembic/versions/20260309_0014_checklist_unificado.py`
- `server/alembic/versions/20260319_0023_projetodoc_erro_detalhe.py`
- `server/alembic/versions/20260319_0024_composite_indexes.py`
- `server/app/routers/subscription.py`
- `server/app/auth.py`
- `server/app/pdf.py`
- `server/app/routers/obras.py` (se ajuste de chamada/headers PDF for necessario)
- `server/requirements.txt`
- `server/deploy-cloudrun.sh`
- `server/app/db.py` e `server/app/main.py` (avaliacao complementar para remover `create_all` em producao)

## Conclusao

A Fase 0 esta bem delimitada e possui evidencia objetiva no codigo e no planejamento. O maior risco tecnico imediato esta em INFRA-01 (cadeia Alembic) e INFRA-02/03 (receita + seguranca). Com a ordem recomendada acima, a fase pode ser executada com baixo retrabalho e criterios de aceite verificaveis.
