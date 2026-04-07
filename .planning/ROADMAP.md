# Roadmap: ObraMaster — Owner Control

## Visão Geral

O app já existe como codebase brownfield com 40+ telas e 13 routers de backend. O trabalho é transformá-lo: primeiro estabilizar a infraestrutura de produção (bloqueadores críticos), depois entregar o diferencial real do produto — IA que lê o documento real da obra e gera cronograma+checklist específicos, não templates genéricos. As fases seguintes estruturam o sistema de papéis (engenheiro gestor, dono observador), adicionam evidências diárias (RDO + fotos geotagueadas) e, por último, modernizam a arquitetura interna para sustentar crescimento.

## Phases

**Phase Numbering:**
- Integer phases (0, 1, 2, ...): Trabalho planejado em sequência
- Decimal phases: Inserções urgentes via `/gsd:insert-phase`

**Execution Artifact Standard (GSD):**
- Cada fase deve ter diretório canônico em `.planning/phases/NN-slug/`
- Planos executáveis devem ser arquivos `NN-PP-PLAN.md` (ex: `01-02-PLAN.md`)
- Cada `*-PLAN.md` deve conter frontmatter obrigatório + `<tasks><task>...</task></tasks>`
- Arquivos de apoio por fase: `PLAN-OVERVIEW.md`, `RESEARCH.md` (quando aplicável), `PLAN-CHECK.md` (quando aplicável)

- [x] **Phase 0: Bloqueadores Críticos** - Corrigir 3 bugs de produção + 1 CVE de segurança antes de qualquer feature nova
- [x] **Phase 1: Pipeline IA de Documentos** - IA lê o documento real e gera cronograma+checklist específicos daquele projeto (completed 2026-04-06)
- [x] **Phase 2: Fluxo Guiado + Dashboard do Engenheiro** - Wizard de onboarding linear e dashboard multi-obra profissional (completed 2026-04-07)
- [ ] **Phase 3: Sistema de Papéis** - Engenheiro gerencia, dono observa — permissões corretas antes de qualquer tela role-gated
- [ ] **Phase 4: RDO + Evidências Fotográficas** - Registro diário de obra com fotos geotagueadas e alertas de prazo
- [ ] **Phase 5: Modernização Arquitetural** - Riverpod + go_router + in_app_purchase para compliance e sustentabilidade

## Phase Details

### Phase 0: Bloqueadores Críticos
**Goal**: Produção estável — deploy fresh funciona, autenticação é segura, PDF não corrompe texto, cold start eliminado e cancelamento de assinatura segue o período pago
**Depends on**: Nada (pré-requisito para tudo)
**Execution Dir**: `.planning/phases/00-bloqueadores-cr-ticos`
**Requirements**: INFRA-01, INFRA-02, INFRA-03, INFRA-04, INFRA-05
**Success Criteria** (what must be TRUE):
  1. `alembic upgrade head` em banco limpo completa sem erro de revision ID duplicado
  2. Usuário que cancela assinatura mantém acesso aos recursos pagos até o fim do período já cobrado
  3. Endpoint de autenticação rejeita tokens forjados (CVE-2024-33663 mitigado via PyJWT >=2.8.0)
  4. PDF gerado com nome de obra contendo ã, ç ou é exibe os caracteres corretamente, sem substituição por ? ou quadrado
  5. Primeira requisição ao app após inatividade responde em menos de 2s (min-instances=1 elimina cold start)
**Plans**: 3 planos

Plans:
- [x] 00-01: Corrigir cadeia Alembic (IDs duplicados) e configurar Cloud Run min-instances
- [x] 00-02: Substituir python-jose por PyJWT >=2.8.0 (CVE-2024-33663) e corrigir bug de cancelamento Stripe
- [x] 00-03: Substituir fpdf2 por WeasyPrint+Jinja2 para PDFs com suporte correto a UTF-8/português

### Phase 1: Pipeline IA de Documentos
**Goal**: A IA lê o documento real enviado e gera cronograma+checklist com atividades específicas daquele projeto, citando o trecho do documento que originou cada atividade, na sequência lógica de uma obra
**Depends on**: Phase 0
**Execution Dir**: `.planning/phases/01-pipeline-ia-de-documentos`
**Requirements**: AI-01, AI-02, AI-03, AI-04, AI-05, AI-06, AI-07
**Success Criteria** (what must be TRUE):
  1. Após processar um memorial descritivo com "piscina de 8m²", o cronograma gerado inclui atividade específica de execução de piscina — não aparece em projeto sem piscina
  2. Cada atividade gerada exibe o trecho exato do documento que a originou (`fonte_doc_trecho`) — clicável na tela de resultado
  3. A lista de atividades segue ordem construtiva (fundação aparece antes de acabamento, instalações antes de revestimento) mesmo que o documento não mencione essa ordem
  4. Engenheiro edita uma atividade gerada (renomeia, muda data) e ao reprocessar o documento as edições são preservadas (campo `is_modified` bloqueia sobrescrita)
  5. Status da geração muda de PENDENTE → ANALISANDO → GERANDO → CONCLUIDO visível ao cliente via polling — sem timeout por operação síncrona longa
  6. Ao fechar a tela de espera, o processamento de tokens de IA para (SSE disconnect detectado pelo backend)
**Plans**: 4 planos (paralelo: 01-01 e 01-02 podem rodar simultaneamente)

Plans:
- [x] 01-01: Extração em duas passagens — visão por página do documento → `ElementoConstrutivo[]` armazenado em `ProjetoDoc.elementos_extraidos`
- [x] 01-02: Geração fundamentada — `gerar_cronograma_com_evidencias()` recebe elementos extraídos, força LLM a citar `fonte_doc_trecho` por atividade
- [x] 01-03: `AtividadeCronograma` como árvore unificada (macro nivel-1 → micro nivel-2) com `SEQUENCIA_CONSTRUTIVA`, flags `is_modified`/`locked` e auto-spawn de `ChecklistItem`
- [x] 01-04: State machine `GeracaoUnificadaLog` (PENDENTE→CONCLUIDO), polling do cliente e detecção de disconnect SSE

### Phase 2: Fluxo Guiado + Dashboard do Engenheiro
**Goal**: Engenheiro novo entra no app e em menos de 3 cliques está vendo o cronograma gerado pela IA — zero desorientação; engenheiro com múltiplas obras vê tudo consolidado em um dashboard
**Depends on**: Phase 1
**Execution Dir**: `.planning/phases/02-fluxo-guiado-dashboard-do-engenheiro`
**Requirements**: FLOW-01, FLOW-02, FLOW-03, FLOW-04, FLOW-05, DASH-01, DASH-02, DASH-03
**Success Criteria** (what must be TRUE):
  1. Engenheiro sem nenhuma obra ao fazer login é redirecionado automaticamente para a tela de criação de obra — não vê tela em branco ou dashboard vazio
  2. Após criar a obra, o app navega automaticamente para a tela de upload de documento sem o engenheiro precisar encontrar o botão
  3. Após o processamento, o app navega automaticamente para o resultado (cronograma+checklist gerado)
  4. Durante o processamento, o engenheiro vê o status em tempo real (ANALISANDO... → GERANDO ATIVIDADES... → CONCLUÍDO) sem precisar recarregar a tela
  5. Dashboard mostra todas as obras do engenheiro com % de conclusão, situação financeira e alertas de atraso por obra, e o engenheiro alterna entre obras sem perder o estado da tela atual
**Plans**: 3 planos (paralelo: 02-01 e 02-02 rodam simultaneamente)

Plans:
- [x] 02-01: Wizard de criação + navegação automática (zero-obras redirect, auto-navigate após criar obra e após processar documento)
- [x] 02-02: Dashboard multi-obra com % conclusão, status financeiro e alertas — skeleton loaders + lazy tab loading
- [x] 02-03: Camada de seam no `ApiService` (wrapper antes de Provider) preparando migração gradual para Riverpod
**UI hint**: yes

### Phase 3: Sistema de Papéis (Engenheiro + Dono)
**Goal**: Engenheiro gerencia, dono observa — permissões corretas e auditadas em todos os routers antes de qualquer tela role-gated chegar ao usuário
**Depends on**: Phase 2
**Execution Dir**: `.planning/phases/03-sistema-de-pap-is-engenheiro-dono`
**Requirements**: ROLE-01, ROLE-02, ROLE-03, ROLE-04, ROLE-05, ROLE-06, OWNER-01, OWNER-02, OWNER-03

> **Nota de pesquisa:** Esta fase é sensível em segurança. Requer pesquisa de fase antes do planejamento (`/gsd:research-phase 3`) para validar o modelo de permissões nos 13 routers e o design de `require_role()`.

**Success Criteria** (what must be TRUE):
  1. Dono de obra convidado pelo engenheiro vê apenas a obra para qual foi convidado — nenhuma outra obra do mesmo engenheiro é visível ou acessível via API
  2. Dono não consegue criar etapa, editar cronograma, ver prestadores ou executar nenhuma operação de escrita — botões não existem na UI e endpoints retornam 403 sem payload de engenheiro
  3. Tela do dono exibe progresso em linguagem leiga (ex: "Estrutura concluída", "Acabamento em andamento") — sem campos técnicos como `is_modified`, `fonte_doc_trecho` ou nomenclatura de engenharia
  4. Engenheiro vê o app com navegação de gestão completa; dono vê o app com navegação de acompanhamento apenas — o mesmo token de entrada determina qual shell de navegação é carregada
  5. Auditoria de permissões cobre os 13 routers com testes de integração que validam a matriz papel × operação
**Plans**: 4 planos

Plans:
- [ ] 03-01: Auditoria e implementação de `require_role()` em todos os 13 routers + testes de integração da matriz de permissões
- [ ] 03-02: Projeções de schema em runtime — `ChecklistItemOwnerView` e `ChecklistItemEngineerView` com campos distintos por papel
- [ ] 03-03: Tela de progresso para o dono (linguagem leiga, % conclusão, fotos recentes, próximas etapas)
- [ ] 03-04: Migração para `go_router` com `ShellRoute` para bottom nav condicionado por papel (habilita deep linking e navegação correta por role)
**UI hint**: yes

### Phase 4: RDO + Evidências Fotográficas
**Goal**: Engenheiro registra o dia de obra com fotos geotagueadas; dono recebe notificação e acessa histórico; sistema alerta engenheiro sobre atrasos antes que virem problema
**Depends on**: Phase 3
**Execution Dir**: `.planning/phases/04-rdo-evid-ncias-fotogr-ficas`
**Requirements**: RDO-01, RDO-02, RDO-03, RDO-04, FOTO-01, FOTO-02, NOTIF-01, NOTIF-02
**Success Criteria** (what must be TRUE):
  1. Engenheiro preenche RDO com data, clima, mão de obra, atividades realizadas e fotos — formulário salva e publica com um botão
  2. Ao publicar o RDO, o dono da obra recebe push notification com resumo do dia
  3. Foto capturada via app exibe latitude, longitude e timestamp nos metadados — sem necessidade de o engenheiro digitar nada
  4. Foto pode ser associada a uma atividade específica do cronograma (ex: "Concretagem de laje — bloco A") e aparece vinculada a ela na tela de progresso
  5. Engenheiro recebe alerta push quando uma etapa ultrapassa a data planejada ou quando o prazo final da obra está a 7 dias
**Plans**: 3 planos (paralelo: 04-01 e 04-02 rodam simultaneamente)

Plans:
- [ ] 04-01: Formulário RDO (data, clima, mão de obra, atividades, fotos) + publicação com push notification ao dono
- [ ] 04-02: Integração `geolocator` — geotag + timestamp automáticos em fotos + vinculação de fotos a `AtividadeCronograma`
- [ ] 04-03: Alertas de atraso e prazo (engenheiro) — lógica de comparação cronograma × data atual + disparo via FCM
**UI hint**: yes

### Phase 5: Modernização Arquitetural
**Goal**: Riverpod 3.0 + go_router completo + in_app_purchase substituindo Stripe in-app — app em conformidade com Play Store (obrigatório desde outubro 2025) e arquitetura sustentável para crescimento
**Depends on**: Phase 4
**Execution Dir**: `.planning/phases/05-moderniza-o-arquitetural`
**Requirements**: Sem requirements v1 diretos — esta fase sustenta todos os anteriores e garante compliance de plataforma

> **Nota:** `go_router` começa na Phase 3 (ShellRoute básico). Esta fase completa a migração com named routes e wiring de Firebase Messaging. A migração para in_app_purchase é obrigatória — apps novos publicados na Play Store após outubro 2025 não podem processar pagamentos via Stripe direto dentro do app.

**Success Criteria** (what must be TRUE):
  1. Todas as 40+ telas usam providers Riverpod — nenhuma chama `ApiClient()` diretamente; erro handling centralizado elimina os 21 pontos de duplicação atuais
  2. Todas as rotas do app usam named routes via `go_router` — deep link para qualquer tela funciona a partir de notificação push do Firebase
  3. Assinatura e upgrade de plano no Android passam pelo fluxo nativo `in_app_purchase` (Google Play Billing) — app aprovado sem rejeição de política de pagamento
  4. `lib/api/api.dart` (arquivo deus de 2458 linhas) dividido em módulos por domínio — nenhum arquivo de modelo/cliente ultrapassa 400 linhas
**Plans**: 3 planos (paralelo: 05-01 e 05-02 rodam simultaneamente)

Plans:
- [ ] 05-01: Migração Provider → Riverpod 3.0 por domínio (seam já implantado na Phase 2, migrar providers um domínio por vez)
- [ ] 05-02: Completar go_router com named routes + Firebase Messaging wiring para deep linking via push
- [ ] 05-03: Substituir Stripe in-app por `in_app_purchase` (Google Play Billing / StoreKit 2) + dividir `api.dart` em módulos de domínio

## Progress

**Execution Order:**
Phases executam em ordem numérica: 0 → 1 → 2 → 3 → 4 → 5

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 0. Bloqueadores Críticos | 1/3 | In progress | 00-01 |
| 1. Pipeline IA de Documentos | 4/4 | Complete   | 2026-04-06 |
| 2. Fluxo Guiado + Dashboard | 3/3 | Complete   | 2026-04-07 |
| 3. Sistema de Papéis | 0/4 | Planned (executable) | - |
| 4. RDO + Evidências Fotográficas | 0/3 | Planned (executable) | - |
| 5. Modernização Arquitetural | 0/3 | Planned (executable) | - |
