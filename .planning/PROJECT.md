# ObraMaster — Owner Control

## What This Is

App mobile (Android + iOS) para gerenciamento de obras residenciais. O engenheiro ou mestre de obras cria e gerencia o projeto — sobe a documentação técnica, recebe um cronograma e checklist gerados por IA com base naquele projeto específico, e acompanha execução. O dono da obra é convidado para uma visão de acompanhamento de status, sem acesso de gestão.

## Core Value

A partir do documento do projeto, a IA gera macro e micro atividades específicas daquela obra — não um template genérico — e isso vira automaticamente o cronograma e o checklist de acompanhamento.

## Requirements

### Validated

- ✓ Autenticação JWT com refresh token, Google OAuth e biometria — existente
- ✓ Criação e gestão de obras — existente
- ✓ Etapas e checklist de atividades — existente
- ✓ Upload e análise de documentos via IA — existente
- ✓ Cronograma gerado por IA — existente (mas com gaps de qualidade)
- ✓ Controle financeiro (orçamento, despesas, alertas) — existente
- ✓ Gestão de prestadores — existente
- ✓ Sistema de convites para colaboradores — existente
- ✓ Planos de assinatura com Stripe — existente
- ✓ Push notifications via FCM — existente
- ✓ Deploy no Google Cloud Run — existente

### Active

- [ ] Fluxo principal guiado e linear: criar obra → subir documento → processar → ver cronograma/checklist — hoje o fluxo existe mas é obscuro e fragmentado
- [ ] IA que lê o documento real e gera atividades específicas daquele projeto, respeitando a sequência lógica de construção (fundação → estrutura → acabamento) — hoje gera template genérico
- [ ] Cronograma e checklist são o mesmo output unificado (macro atividades → micro atividades) gerado do documento — hoje são sistemas separados
- [ ] Engenheiro como usuário principal: cria a obra, sobe o projeto, gerencia tudo — inversão do modelo atual
- [ ] Dono de obra como usuário secundário: é convidado pelo engenheiro, acessa visão de acompanhamento de status apenas — restrito à obra para a qual foi convidado
- [ ] Dashboard do engenheiro agrega dados de todas as suas obras (visão multi-obra)
- [ ] Dashboard do dono mostra apenas a obra à qual foi convidado
- [ ] Output da IA é editável: engenheiro pode ajustar atividades, datas e ordem gerados
- [ ] Estrutura de navegação clara e fluida — hoje o usuário se perde entre telas sem saber o próximo passo

### Out of Scope

- Web app — apenas Android + iOS (Flutter mobile)
- Mudança de stack — Flutter + FastAPI permanece
- Funcionalidades de gestão para o dono de obra — ele só acompanha, quem gerencia é o engenheiro

## Context

**Codebase existente (brownfield):** App Flutter com 40+ telas, FastAPI backend com 13 routers, PostgreSQL com 24 migrations, IA multi-provider (Gemini → Claude → OpenAI), Stripe para assinaturas, Firebase para push e crashlytics, deploy no Cloud Run.

**Problema central de UX:** O fluxo crítico (subir documento → gerar cronograma/checklist) existe tecnicamente mas é fragmentado entre telas sem conexão óbvia. O usuário não tem guia de "próximo passo".

**Problema central de IA:** O checklist inteligente e o cronograma AI geram atividades genéricas que não refletem o conteúdo real do documento enviado. O modelo deve extrair atividades do documento E ordenar pela sequência padrão de uma obra.

**Inversão de papéis:** O sistema atual trata quem cria a obra como "dono". O modelo desejado é engenheiro = criador/gestor, dono = convidado com visão restrita. A infraestrutura de convites (`ObraConvite`) já existe e pode ser estendida.

**Tech debt crítico identificado:**
- `lib/api/api.dart` — arquivo deus de 2458 linhas (modelos + cliente HTTP juntos)
- 40+ telas com `ApiClient()` direto sem state management centralizado
- Erro handling duplicado em 21+ telas
- Zero testes no backend
- Migration Alembic com IDs duplicados (quebra fresh deploy)
- Stripe cancellation downgrade imediato (bug financeiro)

## Constraints

- **Plataforma**: Android + iOS apenas — sem web
- **Stack**: Flutter (Dart 3.11+) + FastAPI (Python 3.11) + PostgreSQL — sem mudança
- **Deploy**: Google Cloud Run (projeto `mestreobra`, região `us-central1`)
- **Monetização**: Planos gratuito/pago via Stripe — manter modelo existente
- **IA**: Cadeia Gemini → Claude → OpenAI via `ai_providers.py` — manter fallback chain
- **Auth**: JWT HS256, 60min access / 7-day refresh — manter modelo de tokens

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Engenheiro é o usuário principal, dono é convidado | Inversão do modelo atual — engenheiro gerencia, dono acompanha | — Pending |
| Cronograma e checklist são o mesmo output (macro → micro) | Elimina duplicidade e fragmentação — um documento vira um plano unificado | — Pending |
| IA deve basear-se no documento + sequência lógica de obra | O output genérico não agrega valor; o diferencial é a especificidade por projeto | — Pending |
| Output da IA é ponto de partida editável, não definitivo | Engenheiro conhece o canteiro — precisa poder ajustar o que a IA propôs | — Pending |
| Manter `ObraConvite` como base para o papel de dono | Infraestrutura já existe, evita reescrever auth/permissões do zero | — Pending |
| Engenheiro vê todas as suas obras no dashboard; dono vê apenas a obra do convite | Isolamento de dados por papel — dono não tem visibilidade de outras obras do mesmo engenheiro | — Pending |

## Evolution

Este documento evolui a cada transição de fase e marco de milestone.

**Após cada fase** (via `/gsd:transition`):
1. Requirements invalidados? → Mover para Out of Scope com motivo
2. Requirements validados? → Mover para Validated com referência de fase
3. Novos requirements? → Adicionar em Active
4. Decisões a registrar? → Adicionar em Key Decisions
5. "What This Is" ainda preciso? → Atualizar se drifted

**Após cada milestone** (via `/gsd:complete-milestone`):
1. Revisão completa de todas as seções
2. Core Value check — ainda é a prioridade certa?
3. Auditoria de Out of Scope — motivos ainda válidos?
4. Atualizar Context com estado atual

---
*Last updated: 2026-04-06 after initialization*
