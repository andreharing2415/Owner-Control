# Especificação Funcional — Mestre da Obra

Plataforma: Mobile (Flutter — Android / iOS)
Backend: FastAPI (Python) no Google Cloud Run
Banco de dados: Supabase PostgreSQL
Versão: 2.0
Data: 2026-03-10
Escopo: Governança da obra para proprietário de alto padrão
Diferencial central: IA multimodal + busca ativa de normas técnicas atualizadas

---

# 1. Visão Geral

Mestre da Obra é uma plataforma premium mobile que permite ao proprietário:

- Validar tecnicamente sua obra sem ser engenheiro
- Monitorar qualidade por etapa com checklists inteligentes
- Controlar orçamento com governança financeira (Curva S)
- Analisar projetos (PDF) via IA documental (Claude)
- Detectar riscos por foto via IA visual (Claude Vision)
- Gerar relatórios executivos em PDF
- Buscar e interpretar normas técnicas (ABNT/NBR) automaticamente
- Convidar profissionais para colaboração na obra
- Gerenciar assinatura premium via Stripe

---

# 2. Arquitetura Técnica

## 2.1 Stack

| Camada | Tecnologia |
|--------|-----------|
| Mobile | Flutter (Dart) — Provider pattern |
| Backend | FastAPI (Python 3.14) |
| Banco de Dados | Supabase PostgreSQL via SQLModel |
| Storage | Supabase S3 |
| Autenticação | JWT custom (bcrypt + python-jose) |
| IA | Claude AI (análise documental + visual) |
| Pagamento | Stripe Checkout (R$149,90/mês) |
| E-mail | Gmail SMTP |
| Push | Firebase Cloud Messaging (FCM) |
| Hosting | Google Cloud Run (us-central1) |

## 2.2 Estrutura do Projeto

```
server/              — Backend FastAPI (Python)
  app/               — main.py, models.py, schemas.py, auth.py, etc.
  alembic/           — 9 migrações de banco
  Dockerfile         — Build para Cloud Run
  deploy-cloudrun.sh — Script de deploy

mobile/              — App Flutter
  lib/
    screens/         — 30 telas
    models/          — 12 arquivos de modelos
    providers/       — 4 providers (auth, obra, subscription, convite)
    services/        — API client, secure storage
    api/             — Definição da API
```

## 2.3 Banco de Dados — 18 Tabelas

| Tabela | Finalidade |
|--------|-----------|
| `user` | Conta do usuário (email, google_id, plano) |
| `obra` | Projeto de obra |
| `etapa` | Etapa da obra (com prazos) |
| `checklistitem` | Item de checklist (3 camadas, grupo, ordem) |
| `evidencia` | Foto/documento vinculado a item |
| `normalog` | Log de buscas de normas |
| `normaresultado` | Resultado de norma encontrada |
| `orcamentoetapa` | Orçamento por etapa |
| `despesa` | Despesa registrada |
| `alertaconfig` | Configuração de alertas de desvio |
| `projetodoc` | Documento PDF carregado |
| `risco` | Risco identificado em documento (3 camadas) |
| `analisevisual` | Análise de foto da obra |
| `achado` | Achado da análise visual |
| `prestador` | Prestador de serviço |
| `avaliacao` | Avaliação de prestador |
| `checklistgeracaolog` | Log de geração de checklist inteligente |
| `checklistgeracaoitem` | Itens sugeridos na geração |
| `devicetoken` | Token FCM para push |
| `subscription` | Assinatura do usuário (Stripe) |
| `usagetracking` | Rastreamento de uso de features limitadas |
| `revenuecatevent` | Evento legado RevenueCat |
| `obraconvite` | Convite de profissional à obra |
| `etapacomentario` | Comentário em etapa |

---

# 3. Módulos Funcionais

## 3.1 Autenticação e Conta

**Status: IMPLEMENTADO**

### Funcionalidades
- Registro por e-mail/senha
- Login por e-mail/senha
- Login via Google Sign-In
- Login biométrico (impressão digital / Face ID)
- Refresh de token JWT automático
- Tela "Minha Conta" com gestão de perfil
- Alteração de nome e telefone
- Exclusão de conta (com cancelamento de assinatura)

### Telas Flutter
- `login_screen.dart` — Login
- `registro_screen.dart` — Registro
- `complete_profile_screen.dart` — Completar perfil (Google)
- `minha_conta_screen.dart` — Gerenciamento de conta

### Endpoints (7)
- `POST /api/auth/register`
- `POST /api/auth/login`
- `POST /api/auth/refresh`
- `GET /api/auth/me`
- `POST /api/auth/google`
- `PATCH /api/auth/me`
- `DELETE /api/auth/me`

---

## 3.2 Gestão de Obras

**Status: IMPLEMENTADO**

### Funcionalidades
- Criação de obra com nome, orçamento e datas
- Listagem de obras do usuário
- 6 etapas padrão criadas automaticamente ao criar obra
- Visualização detalhada com etapas e progresso
- Exportação de relatório completo em PDF
- Limite de 1 obra no plano gratuito

### Telas Flutter
- `obras_screen.dart` — Lista de obras
- `home_screen.dart` — Dashboard principal
- `etapas_screen.dart` — Etapas da obra

### Endpoints (4)
- `POST /api/obras`
- `GET /api/obras`
- `GET /api/obras/{obra_id}`
- `GET /api/obras/{obra_id}/export-pdf`

---

## 3.3 Checklists e Verificação

**Status: IMPLEMENTADO**

### Funcionalidades
- Checklist por etapa com itens pré-definidos (seed)
- Criação/edição/exclusão de itens
- Marcação de item como concluído
- Upload de evidências (fotos/documentos)
- Dados em 3 camadas: `dado_projeto`, `verificacoes`, `pergunta_engenheiro`, `registro_proprietario`, `resultado_cruzamento`
- Agrupamento e ordenação de itens
- Marcação de severidade (crítico/importante/informativo)
- Score de conformidade por etapa (automático)
- Sugestão de grupo via IA
- Edição inline unificada (checklist + orçamento)

### Telas Flutter
- `checklist_screen.dart` — Checklist principal
- `detalhe_item_screen.dart` — Detalhe do item
- `verificacao_inline_widget.dart` — Verificação inline
- `evidencias_screen.dart` — Gestão de evidências

### Endpoints (8)
- `GET /api/etapas/{etapa_id}/checklist-items`
- `POST /api/etapas/{etapa_id}/checklist-items`
- `PATCH /api/checklist-items/{item_id}`
- `DELETE /api/checklist-items/{item_id}`
- `POST /api/checklist-items/{item_id}/verificar`
- `GET /api/etapas/{etapa_id}/score`
- `PATCH /api/etapas/{etapa_id}/status`
- `PATCH /api/etapas/{etapa_id}/prazo`

---

## 3.4 Checklist Inteligente (IA)

**Status: IMPLEMENTADO**

### Funcionalidades
- Geração automática de checklist a partir de documentos do projeto
- Streaming em tempo real durante geração
- Aplicação seletiva de itens gerados
- Histórico de gerações anteriores

### Telas Flutter
- `checklist_inteligente_screen.dart` — Geração de checklist IA

### Endpoints (5)
- `GET /api/obras/{obra_id}/checklist-inteligente/stream`
- `POST /api/obras/{obra_id}/checklist-inteligente`
- `GET /api/obras/{obra_id}/checklist-inteligente/status`
- `POST /api/checklist-inteligente/aplicar`
- `GET /api/checklist-inteligente/historico`

### Suporte
- `POST /api/etapas/{etapa_id}/checklist-items/sugerir-grupo`

---

## 3.5 Biblioteca Normativa Dinâmica

**Status: IMPLEMENTADO**

### Funcionalidades
- Busca de normas técnicas brasileiras (ABNT, NBR) na internet
- Tradução de linguagem técnica para leiga
- Indicação de confiança do resultado
- Registro de data, fonte e versão da norma
- Histórico de buscas
- Vínculo automático de normas ao checklist da etapa
- Busca automática ao navegar do checklist para normas

### Regras de Negócio
- Sempre indicar: data da norma, fonte, se é versão oficial ou secundária
- Não apresentar como parecer técnico
- Mostrar nível de confiança
- Logar versão da norma usada

### Telas Flutter
- `normas_screen.dart` — Busca de normas
- `normas_historico_screen.dart` — Histórico de buscas

### Endpoints (5)
- `POST /api/normas/buscar`
- `GET /api/normas/historico`
- `GET /api/normas/historico/{log_id}`
- `GET /api/normas/etapas`
- `GET /api/etapas/{etapa_id}/checklist-normas`

---

## 3.6 IA Documental (Análise de Projetos)

**Status: IMPLEMENTADO**

### Funcionalidades
- Upload de documentos PDF do projeto
- Análise automática via Claude AI
- Extração de dados e identificação de riscos
- Cruzamento com normas técnicas
- Visualização inline de PDF (com limite de páginas no plano gratuito)
- Exclusão de documentos

### Telas Flutter
- `documentos_screen.dart` — Gestão de documentos
- `pdf_viewer_screen.dart` — Visualizador PDF inline

### Endpoints (6)
- `POST /api/obras/{obra_id}/projetos`
- `GET /api/obras/{obra_id}/projetos`
- `GET /api/projetos/{projeto_id}`
- `GET /api/projetos/{projeto_id}/pdf`
- `DELETE /api/projetos/{projeto_id}`
- `POST /api/projetos/{projeto_id}/analisar`

---

## 3.7 IA Visual (Análise de Fotos)

**Status: IMPLEMENTADO**

### Funcionalidades
- Upload de foto da obra vinculada à etapa
- Classificação automática da etapa pela imagem (Claude Vision)
- Detecção de padrões anômalos
- Geração de achados com severidade e ação recomendada
- Limite: 1 análise/mês no plano gratuito, ilimitado no pago

### Telas Flutter
- `visual_ai_screen.dart` — Análise de foto
- `detalhe_achado_screen.dart` — Detalhe do achado

### Endpoints (3)
- `POST /api/etapas/{etapa_id}/analise-visual`
- `GET /api/etapas/{etapa_id}/analises-visuais`
- `GET /api/analises-visuais/{analise_id}`

---

## 3.8 Governança Financeira

**Status: IMPLEMENTADO**

### Funcionalidades
- Orçamento por etapa (previsto)
- Lançamento de despesas (realizado)
- Comparativo previsto × realizado por etapa
- Relatório financeiro com Curva S
- Alertas de desvio configuráveis (threshold percentual)
- Push notification em caso de desvio

### Telas Flutter
- `financeiro_screen.dart` — Dashboard financeiro
- `orcamento_edit_screen.dart` — Edição de orçamento
- `curva_s_screen.dart` — Visualização Curva S
- `lancar_despesa_screen.dart` — Lançamento de despesas
- `alertas_config_screen.dart` — Configuração de alertas

### Endpoints (7)
- `POST /api/obras/{obra_id}/orcamento`
- `GET /api/obras/{obra_id}/orcamento`
- `POST /api/obras/{obra_id}/despesas`
- `GET /api/obras/{obra_id}/despesas`
- `GET /api/obras/{obra_id}/relatorio-financeiro`
- `PUT /api/obras/{obra_id}/alertas`
- `POST /api/obras/{obra_id}/device-tokens`

---

## 3.9 Prestadores de Serviço

**Status: IMPLEMENTADO**

### Funcionalidades
- Diretório de prestadores de serviço / fornecedores
- Categorização por tipo e subcategoria
- Avaliação e notas (estrelas + comentário)
- Dados de contato (limitado no plano gratuito, completo no pago)

### Telas Flutter
- `prestadores_screen.dart` — Lista de prestadores
- `detalhe_prestador_screen.dart` — Detalhe e avaliações

### Endpoints (7)
- `GET /api/prestadores/subcategorias`
- `POST /api/prestadores`
- `GET /api/prestadores`
- `GET /api/prestadores/{prestador_id}`
- `PATCH /api/prestadores/{prestador_id}`
- `POST /api/prestadores/{prestador_id}/avaliacoes`
- `GET /api/prestadores/{prestador_id}/avaliacoes`

---

## 3.10 Colaboração e Convites

**Status: IMPLEMENTADO**

### Funcionalidades
- Convite de profissionais (arquiteto, engenheiro, mestre de obras)
- Até 3 convites por obra (plano pago)
- Aceite via magic link (sem senha)
- Conta simplificada para convidado
- Comentários/notas em etapas
- Push notification quando convidado atualiza a obra
- Envio de e-mail de convite via Gmail SMTP

### Telas Flutter
- `convites_screen.dart` — Gerenciar convites
- `aceitar_convite_screen.dart` — Aceitar convite

### Endpoints (7)
- `POST /api/obras/{obra_id}/convites`
- `GET /api/obras/{obra_id}/convites`
- `DELETE /api/convites/{convite_id}`
- `POST /api/convites/aceitar`
- `GET /api/convites/minhas-obras`
- `POST /api/etapas/{etapa_id}/comentarios`
- `GET /api/etapas/{etapa_id}/comentarios`

---

## 3.11 Monetização (Stripe)

**Status: IMPLEMENTADO**

### Planos

| Recurso | Gratuito | Dono da Obra (R$149,90/mês) |
|---------|----------|---------------------------|
| Obras | 1 | Ilimitadas |
| Checklist | Básico | Completo + IA |
| IA Visual | 1/mês | Ilimitado |
| PDF Viewer | Páginas limitadas | Completo |
| Convites | — | Até 3 por obra |
| Contato prestadores | Limitado | Completo |
| Exportação PDF | — | Relatório executivo |
| Suporte | — | Prioritário |

### Fluxo de Pagamento
1. Usuário toca em feature bloqueada → tela de paywall
2. App abre URL do Stripe Checkout no browser
3. Stripe processa pagamento
4. Webhook Stripe notifica backend → atualiza plano
5. App sincroniza status da assinatura

### Configuração Stripe
- Product: `prod_U7NwL4d6eMitUq`
- Price: `price_1T99AqI8eh1s0fwjaHUscAfg` (BRL)
- Webhook: `/api/webhooks/stripe`

### Telas Flutter
- `paywall_screen.dart` — Paywall com comparação de planos

### Endpoints (7)
- `GET /api/subscription/me`
- `POST /api/subscription/create-checkout`
- `GET /api/subscription/success`
- `GET /api/subscription/cancel`
- `POST /api/subscription/sync`
- `POST /api/subscription/cancel-subscription`
- `POST /api/webhooks/stripe`

---

# 4. Diferencial Estratégico — IA com Busca de Normas

## 4.1 Arquitetura Funcional da IA

### Camadas Implementadas:
1. **Classificador de Etapa** — identifica a disciplina (estrutura, elétrica, etc.)
2. **Motor de Busca Externa** — busca normas na internet
3. **RAG** — Retrieval Augmented Generation para contextualizar
4. **Tradutor Técnico → Leigo** — converte linguagem técnica
5. **Gerador de Checklist** — cria checklist acionável a partir de normas
6. **Módulo de Evidência e Risco** — vincula riscos e evidências
7. **Validador de Confiabilidade** — indica nível de confiança

## 4.2 Regras Obrigatórias
- Sempre indicar: data da norma, fonte, versão oficial ou secundária
- Não apresentar como parecer técnico
- Mostrar nível de confiança
- Logar versão da norma usada

---

# 5. Resumo Quantitativo

| Métrica | Quantidade |
|---------|-----------|
| Telas Flutter | 30 |
| Endpoints API | 70+ |
| Tabelas no banco | 18+ |
| Providers Flutter | 4 |
| Modelos Flutter | 12 |
| Migrações Alembic | 9 |
| Módulos backend | 16 |

---

# 6. Fases de Implementação

## FASE 0 — Conteúdo Base + Estrutura Normativa ✅
- Taxonomia de etapas
- Mapeamento etapa → palavras-chave de norma
- Definição do fluxo IA com busca externa

## FASE 1 — MVP ✅
- Cadastro de obra com 6 etapas padrão
- Checklists por etapa (fixos + editáveis)
- Evidências por foto
- Score de conformidade por etapa
- Exportação PDF

## FASE 2 — IA com Busca Normativa ✅
- Motor de busca de normas na internet
- Tradução para leigo
- Checklist dinâmico baseado em norma
- Histórico de buscas
- Auto-busca ao navegar do checklist

## FASE 3 — IA Documental ✅
- Upload de PDF de projetos
- Análise via Claude AI
- Identificação de riscos (3 camadas)
- Visualizador PDF inline

## FASE 4 — IA Visual ✅
- Upload de foto da obra
- Classificação da etapa pela imagem (Claude Vision)
- Detecção de anomalias
- Geração de achados com severidade

## FASE 5 — Governança Financeira ✅
- Orçamento por etapa
- Lançamento de despesas
- Curva S
- Alertas de desvio configuráveis

## FASE 6 — Monetização + Colaboração ✅
- Plano Gratuito + Dono da Obra (Stripe Checkout)
- Feature gates em toda a API
- Convites de profissionais (magic link)
- Comentários em etapas
- Gmail SMTP para e-mails
- Gestão de conta (cancelar assinatura, excluir conta)

---

# 7. Pendências e Próximos Passos

### Configuração Pendente
- [ ] `STRIPE_WEBHOOK_SECRET` — aguardando `whsec_` do Stripe Dashboard
- [ ] `SENDGRID_API_KEY` — migrar de Gmail SMTP para SendGrid em produção

### Funcionalidades Futuras
- [ ] Notificações push aprimoradas (resumo semanal)
- [ ] Dashboard executivo consolidado
- [ ] Benchmarking entre obras
- [ ] Marketplace de especialistas
- [ ] Integração BIM/IFC avançada
- [ ] Modo offline com sync

---

# 8. Priorização MoSCoW (Atualizada)

### Must (IMPLEMENTADO) ✅
- Estrutura da obra e etapas
- Checklists (fixos + inteligentes)
- IA normativa dinâmica
- IA documental (análise de projetos)
- IA visual (análise de fotos)
- Governança financeira (orçamento, despesas, Curva S)
- Evidências e verificações
- Monetização com Stripe
- Colaboração com convites

### Should (PARCIAL)
- Alertas avançados ✅
- Prestadores de serviço ✅
- Push notifications ✅
- Dashboard consolidado — pendente

### Could (FUTURO)
- Benchmarking entre obras
- Marketplace de especialistas
- Modo offline

### Won't (DESCARTADO)
- Frontend web (deletado — app mobile only)
- Integração BIM/IFC avançada
- Leitura nativa DWG
- RevenueCat (migrado para Stripe)

---

# 9. Métricas de Sucesso

- 80% dos usuários usam checklist em campo
- 70% utilizam IA de análise de projeto
- Redução de reprovação tardia em obras
- Conversão free → pago > 5%
- Retenção mensal > 70% (plano pago)
- NPS > 50
