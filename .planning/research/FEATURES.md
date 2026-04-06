# Feature Landscape: Gestão de Obras Residenciais (Brasil)

**Domain:** Construction management app — residential, engineer-led, Brazilian market
**Researched:** 2026-04-06
**Confidence:** MEDIUM-HIGH (Brazilian-specific sources verified; some global patterns inferred from Buildertrend/Procore, cross-validated against Vobi, Sienge, Obrafit)

---

## Existing Features (Already Built)

For reference. Do not re-research or re-plan these unless evolution is explicitly needed:

| Feature | Current State |
|---------|--------------|
| Criação e gestão de obras | Done |
| Upload e análise de documentos via IA | Done — needs evolution to project-specific output |
| Cronograma gerado por IA | Done — needs merge with checklist |
| Etapas e checklist de atividades | Done — needs merge with cronograma |
| Controle financeiro (orçamento, despesas) | Done — missing medição, BM, SINAPI |
| Gestão de prestadores | Done — missing subcontractor portal |
| Sistema de convites para colaboradores | Done |
| Push notifications, crash reporting | Done |

---

## Table Stakes

Features the market expects as baseline. Absence makes the product feel incomplete or untrustworthy. Sourced from Buildertrend, Vobi, Obrafit, Sienge, and Brazilian market analysis.

| Feature | Why Expected | Complexity | Gap Status |
|---------|--------------|------------|------------|
| **RDO — Relatório Diário de Obra** | Legally required by Confea Resolução 1.024/2009 and NBR 12.722 for all engineering works. Every competing app (Vobi, Obrafit, Sienge, Kartado) has it. Engineers who manage obras MUST issue RDO. | Medium | MISSING — critical gap |
| **Foto com geotag e timestamp por etapa** | Construction disputes require geotagged, timestamped evidence. All leading platforms (Procore, Buildertrend, Obrafit, Vobi) treat this as non-negotiable. | Low-Med | PARTIAL — photos exist but no geo/timestamp/tagging by phase |
| **Portal do dono da obra (client view)** | The evolution goal explicitly calls for owner as invited guest with restricted view. Buildertrend reports 97% reduction in "how's it going?" calls when portal is live. | Medium | MISSING — invite system exists, dedicated restricted view does not |
| **Dashboard multi-obras para engenheiro** | Engineer managing 3-8 simultaneous obras needs a single aggregated view. Buildertrend, Vobi, Sienge all have this. Flagged as evolution goal. | Medium | MISSING |
| **Controle de medição de serviços (Boletim de Medição)** | BM is the mechanism linking physical progress to financial releases. Required for payment validation with subcontractors and owners. Sienge, Vobi, Obrafit all include it. | High | MISSING |
| **Cronograma físico-financeiro unificado** | Linking schedule progress to financial state is the Brazilian market standard (Sienge calls it "cronograma físico-financeiro"). Tracks what was planned vs. executed vs. paid. | High | PARTIAL — cronograma and financeiro exist separately |
| **Modo offline com sync** | Construction sites have poor connectivity. Identified as a critical requirement across all Brazilian market analyses. Construpoint, PlanGrid, Foco em Obra all support it. | High | UNKNOWN — needs validation |
| **Notificações de atraso e alertas de prazo** | Vobi reports it as a differentiator ("alertas automáticos para atrasos"). Buildertrend embeds delay flags in daily logs. Expected in all scheduling tools. | Low | MISSING |
| **Gestão de compras / solicitação de materiais** | Field teams need to request materials and track deliveries. Obrafit, Sienge, Vobi all include purchase request flows. | Medium | MISSING |
| **Integração com tabela SINAPI** | SINAPI (Caixa Econômica Federal) is the national pricing reference for Brazilian civil construction. All major platforms (Vobi, Sienge, OrçaFascio, Gestor Obras) integrate it. Without it, budget credibility is low for engineers. | Medium | MISSING |

---

## Differentiators

Features that set a product apart. Not universally expected, but high-value when present.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| **IA lendo documento real e gerando atividades específicas do projeto** | The core evolution goal. No mainstream Brazilian competitor does this. Buildertrend AI generates generic summaries; nPlan and ALICE do schedule generation from scope docs at enterprise scale but not for small residential obras. This is a genuine gap in the market. | High | Primary differentiator — must be exceptional |
| **Cronograma e checklist como output unificado (macro→micro)** | Most apps treat schedule and checklist as separate modules. Merging them into a single hierarchical output (fase → atividade → sub-atividade) guided by the document is novel. | High | Architectural decision, not just a feature |
| **Portal restrito por papel (engenheiro vs. dono)** | Role-based views are common in enterprise (Procore). For small residential Brazil, having a clean "dono da obra" view that shows progress without exposing costs or internal notes is a meaningful differentiator. Buildertrend allows customizable client portal visibility. | Medium | Validates evolution goal #4 |
| **Updates diários com IA-generated summary para o dono** | Buildertrend reports 6.5-minute average for AI-written client updates (vs. hours manually). A Portuguese-language AI update for the obra owner, based on checklist progress and RDO data, would be highly valued. | Medium | Builds on RDO + AI already in the stack |
| **Histórico fotográfico por etapa com linha do tempo** | Sequential photo timeline per phase (not just a gallery). Clients and engineers can see visual evolution of the work. Buildertrend and Procore both offer this; few Brazilian apps do it well. | Medium | High perceived value, low switching cost for user |
| **Punch list / lista de pendências com responsável e prazo** | Structured snag/deficiency list with assignment and deadline. Separate from the checklist. Essential at handover. Common in Procore and Buildertrend, rare in Brazilian residential apps. | Medium | High value for quality management at entrega |
| **Convite de prestador com visão limitada das tarefas dele** | Subcontractor portal where they see only their tasks, submit completion, upload photos. Buildern has this; Buildertrend has it via limited user access. Not standard in Brazilian small-builder market. | Medium | Extends existing invite system |
| **Orçamento por composição de serviço (EAP + custo unitário)** | Linking each activity in the schedule/checklist to a unit cost (from SINAPI or custom) and generating a detailed budget automatically from the project breakdown. Vobi and Sienge do this; rare in lighter apps. | High | Strong differentiator if AI populates it from document |
| **Relatório de obra automático (PDF export) para envio ao cliente** | Auto-generated periodic report (weekly/monthly) as PDF: cronograma, fotos, financeiro, pendências. Buildertrend's client portal effectively does this in real time. | Low-Med | Perceived professionalism differentiator |
| **Fluxo guiado: criar obra → subir doc → gerar cronograma/checklist** | No competitor in Brazil implements this as an explicit onboarding flow. It reduces time-to-value dramatically and captures the AI differentiation at first use. | Medium | UX differentiator, validates evolution goal #1 |

---

## Anti-Features

Features to explicitly NOT build in the current evolution milestones.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| **ERP completo (compras, fiscal, NF-e)** | Sienge and TOTVS own this space. Competing on ERP scope requires years and enterprise budget. | Deep-link or integrate with existing tools (Conta Azul, OmieERP). Offer API hooks. |
| **BIM / modelagem 3D** | Autodesk Construction Cloud and Sienge have massive head start. BIM is irrelevant for most residential obras being managed by individual engineers. | Accept PDFs, plants, and documents. The AI should read text/table content from these. |
| **Marketplace de prestadores** | A marketplace requires supply-side acquisition (prestadores) in addition to demand-side (engenheiros). Two-sided marketplace is a different product and company. | Let engineers add their own prestadores. Focus on communication and task tracking between known parties. |
| **CRM de vendas e pré-obra** | Vobi positions itself for the full funnel including lead capture and proposals. That's a different user journey and different ICP. | Enter at obra creation, not at lead generation. |
| **Gestão de obras públicas / licitações** | Public contracts (using SINAPI mandatorily, following CONFEA reporting to public clients) have compliance requirements beyond this product's scope. | Target private residential construction explicitly. SINAPI integration is for budget credibility, not compliance. |
| **Gestão de estoque de materiais em canteiro** | Inventory management (entering and consuming stock items per work order) is complex warehouse logic. Obrafit and Sienge handle it but it's not the core loop. | Handle purchase requests and cost tracking. Defer inventory control. |

---

## Feature Dependencies

```
RDO (diário de obra)
  → Foto por etapa com timestamp/geotag  (RDO sem foto é incompleto)
  → Notificação ao dono quando RDO publicado

Portal do dono
  → RDO (conteúdo principal que o dono consome)
  → Cronograma/checklist unificado (dono vê o progresso)
  → Histórico fotográfico por etapa (prova visual)

Cronograma+Checklist unificado
  → IA lendo documento real (popula as atividades)
  → Boletim de Medição (BM mede o % executado por fase)
  → Controle financeiro (BM libera pagamentos)

Boletim de Medição
  → Cronograma físico-financeiro (precisa das fases e pesos)
  → SINAPI ou custo unitário por atividade (precisa do preço)

Dashboard multi-obras (engenheiro)
  → Cronograma unificado (para ver % conclusão por obra)
  → Controle financeiro (para ver estado orçamentário por obra)
  → RDO (para ver se obra foi registrada hoje)

Punch list
  → Checklist de atividades (punch list é subconjunto de pendências)
  → Portal do dono (dono precisa ver as pendências no momento de entrega)

Portal de prestador (subcontractor)
  → Gestão de prestadores (já existe)
  → Checklist de atividades (prestador vê suas tarefas)
  → Boletim de Medição (prestador confirma o que executou)
```

---

## MVP Recommendation for the Next Milestone

The evolution goals are coherent and well-prioritized. Based on market research, the sequence that delivers maximum value without rework:

**Must-have (resolve critical gaps, enable differentiation):**
1. **Fluxo guiado** (obra → documento → IA gera cronograma+checklist unificado): the core differentiator, enables everything else
2. **Cronograma e checklist como output unificado**: architectural change that must happen before adding more features to either
3. **Portal do dono com visão restrita**: owner-facing view is the #1 engagement driver and differentiator for the engineer who sells the app to their client
4. **RDO digital com foto**: legally required; absence is a blocker for professional engineers

**High priority (table stakes being missed):**
5. **Foto com geotag e timestamp por etapa**: upgrades existing photo feature without rework
6. **Notificações de atraso/prazo**: low complexity, high utility for the guiding flow
7. **Dashboard multi-obras para engenheiro**: required for the engineer persona at scale

**Defer to later milestone:**
- Boletim de Medição (high complexity, needed when financial rigor increases)
- SINAPI integration (high value for credibility, but not blocking MVP)
- Punch list (important at handover phase, not day-1 usage)
- AI summary updates for owner (nice to have, builds on RDO)
- Offline mode (important but requires architectural work; validate connectivity constraints first)
- Subcontractor portal (extends invite system; defer until engineer-owner loop is solid)

---

## Brazilian Market Context

| Factor | Implication |
|--------|-------------|
| **RDO is legally mandatory** (Confea Res. 1024/2009) | Any serious engineer will not use an app that doesn't support RDO. This is a hard requirement, not a differentiator. |
| **SINAPI is the national price reference** | Integration (even read-only lookup) dramatically increases budget credibility. API access is available via Caixa/IBGE. |
| **Small obras dominate residential market** | R$99-499/month price range is the target. Sienge/TOTVS are too expensive and complex for this segment. Vobi, Obrafit, Obra na Mão are the real competitors. |
| **Engineers manage multiple obras simultaneously** | The engineer dashboard aggregating all obras is not a luxury — it is the primary interface for the user persona. |
| **Owners are non-technical, mobile-first** | Owner portal must be dead simple: timeline, photos, what's done, what's coming. No jargon. No complex navigation. |
| **Poor site connectivity is common** | Offline-first or at minimum graceful degradation for photo upload and RDO filling is expected by field engineers. |
| **WhatsApp is dominant communication channel** | Construction communication in Brazil happens on WhatsApp. Any notification system that can send to WhatsApp has instant adoption. Construpoint explicitly mentions WhatsApp-based support as a differentiator. |
| **Market is growing rapidly** | Brazil construction market valued at USD 127.63B in 2024, projected USD 236B by 2034 (Yahoo Finance). Digitization is accelerating post-COVID. This is a good time to enter. |

---

## Competitor Feature Matrix (Selected)

| Feature | Owner-Control (current) | Vobi | Obrafit | Sienge/Gestor Obras | Buildertrend |
|---------|------------------------|------|---------|---------------------|--------------|
| IA para cronograma | Yes (generic) | No | No | No | No |
| IA lendo documento real | Partial | No | No | No | No |
| Cronograma | Yes | Yes | Yes | Yes | Yes |
| Checklist de atividades | Yes | Yes | Yes | Yes | Yes |
| Cronograma+Checklist unificado | No | No | No | No | No |
| RDO digital | No | Yes | Yes | Yes | Yes |
| Portal do cliente/dono | Invite only | Yes | Yes | Yes | Yes (robust) |
| Foto geotag+timestamp | No | Partial | Yes | Yes | Yes |
| Dashboard multi-obras | No | Yes | Yes | Yes | Yes |
| Boletim de Medição | No | Yes | Yes | Yes | No |
| SINAPI integrado | No | Yes | No | Yes | N/A |
| Punch list | No | No | Partial | No | Yes |
| Offline mode | Unknown | Partial | Partial | Yes | Partial |
| Gestão de compras/materiais | No | Yes | Yes | Yes | Yes |
| Subcontractor portal | No | No | No | No | Yes |
| Notificações de atraso | No | Yes | No | Yes | Yes |
| WhatsApp integration | No | No | No | No | No |

---

## Sources

- Buildertrend feature documentation: https://buildertrend.com/communication/construction-client-portal/
- Buildertrend AI updates (2025): https://buildertrend.com/blog/client-portal-updates/
- Procore vs Buildertrend comparison: https://buildern.com/resources/blog/buildertrend-vs-procore/
- Capterra Procore vs Buildertrend: https://www.capterra.com/compare/56250-70092/Procore-vs-Buildertrend
- Vobi funcionalidades gestão de obras: https://www.vobi.com.br/funcionalidades/gestao-de-obras
- Top 10 apps gestão de obras Brasil 2025: https://www.plataformadeobras.com.br/blog/top-15-apps-de-gestao-de-obras-para-2025-brasil/
- Os 7 melhores softwares de gestão de obras 2025: https://www.construnewsbrasil.com.br/blog/os-7-melhores-softwares-de-gestao-de-obras-em-2025
- RDO obrigatório Confea: https://diariodeobras.net/importancia-do-relatorio-diario-de-obra/
- SINAPI integração software: https://sienge.com.br/blog/tabela-sinapi-no-orcamento-da-obra/
- Boletim de Medição guia: https://www.goepik.com.br/boletim-de-medicao/
- Brazil construction market 2025-2034: https://finance.yahoo.com/news/brazil-construction-industry-report-2025-131800106.html
- AI tools construction project management 2026: https://thedigitalprojectmanager.com/tools/ai-tools-for-construction-project-management/
- Offline construction apps Brazil: https://obrafit.com.br/conheca-6-aplicativos-para-facilitar-o-gerenciamento-de-obra/
- Punch list vs checklist construction: https://blog.ftq360.com/blog/punch-list-vs-checklists-quality-management
- Construpoint WhatsApp + offline: https://www.sienge.com.br/blog/app-construpoint/
