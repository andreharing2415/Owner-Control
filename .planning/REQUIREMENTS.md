# Requirements: ObraMaster — Owner Control

**Defined:** 2026-04-06
**Core Value:** A partir do documento do projeto, a IA gera macro e micro atividades específicas daquela obra — não um template genérico — e isso vira automaticamente o cronograma e o checklist de acompanhamento.

## v1 Requirements

### Infraestrutura Crítica (Bloqueadores)

- [x] **INFRA-01**: Cadeia de migrations Alembic está funcional em deploy fresh (`alembic upgrade head` sem erros)
- [x] **INFRA-02**: Cancelamento de assinatura não downgrade imediato — usuário mantém acesso até fim do período pago
- [x] **INFRA-03**: Autenticação JWT usa PyJWT >=2.8.0 (substituindo python-jose com CVE-2024-33663)
- [x] **INFRA-04**: PDF reports gerados com caracteres portugueses corretos (sem corrupção de ã, ç, é, etc.)
- [x] **INFRA-05**: Cloud Run configurado com `--min-instances=1` (elimina cold starts de 4-8s no canteiro)

### Pipeline IA de Documentos

- [ ] **AI-01**: IA extrai elementos construtivos reais do documento enviado (planta baixa, memorial descritivo, etc.) — não templates genéricos
- [ ] **AI-02**: Atividades geradas citam o trecho exato do documento que as originou (`fonte_doc_trecho`)
- [ ] **AI-03**: Sequência de atividades respeita ordem construtiva padrão (fundação → estrutura → instalações → acabamento)
- [ ] **AI-04**: Cronograma e checklist são um único output hierárquico (macro atividade → micro atividades)
- [ ] **AI-05**: Output da IA é editável — engenheiro pode modificar atividades, datas e ordem sem perder as edições no próximo processamento
- [ ] **AI-06**: Pipeline de geração usa state machine com polling do cliente (não chained synchronous calls que geram timeout)
- [ ] **AI-07**: SSE stream para de processar quando cliente desconecta (elimina gasto desnecessário de tokens de IA)

### Fluxo Principal Guiado

- [ ] **FLOW-01**: Usuário sem obras é redirecionado automaticamente para wizard de criação (não tela em branco)
- [ ] **FLOW-02**: Após criar obra, app navega automaticamente para upload de documento
- [ ] **FLOW-03**: Após processar documento, app navega automaticamente para resultado (cronograma+checklist)
- [ ] **FLOW-04**: Status de processamento da IA visível em tempo real na tela de espera
- [ ] **FLOW-05**: Estrutura de navegação clara — usuário sempre sabe em que etapa do fluxo está

### Dashboard do Engenheiro

- [ ] **DASH-01**: Engenheiro vê todas as suas obras em um dashboard consolidado
- [ ] **DASH-02**: Dashboard mostra % de conclusão, status financeiro e alertas por obra
- [ ] **DASH-03**: Engenheiro pode alternar entre obras sem perder contexto

### Sistema de Papéis (Engenheiro + Dono)

- [ ] **ROLE-01**: Engenheiro é o criador e gestor da obra (inversão do modelo atual onde qualquer usuário cria)
- [ ] **ROLE-02**: Dono de obra é convidado pelo engenheiro e acessa visão restrita da obra específica
- [ ] **ROLE-03**: Dono vê somente a obra para a qual foi convidado — sem visibilidade de outras obras do engenheiro
- [ ] **ROLE-04**: Visão do dono usa linguagem leiga (sem campos técnicos de engenharia)
- [ ] **ROLE-05**: Todas as operações de escrita requerem papel de engenheiro
- [ ] **ROLE-06**: Permissões auditadas em todos os 13 routers antes de qualquer tela role-gated

### Portal do Dono de Obra

- [ ] **OWNER-01**: Dono acessa visão de progresso da sua obra (% conclusão, fotos recentes, próximas etapas)
- [ ] **OWNER-02**: Dono recebe notificações push quando engenheiro atualiza progresso
- [ ] **OWNER-03**: Dono não tem acesso a funcionalidades de gestão (criar etapas, editar cronograma, ver prestadores)

### RDO — Relatório Diário de Obra

- [ ] **RDO-01**: Engenheiro cria RDO diário (data, clima, mão de obra, atividades realizadas, fotos)
- [ ] **RDO-02**: RDO publicado envia notificação push ao dono da obra
- [ ] **RDO-03**: Dono acessa histórico de RDOs da sua obra
- [ ] **RDO-04**: Fotos do RDO têm geotag e timestamp automáticos

### Evidências Fotográficas

- [ ] **FOTO-01**: Foto capturada via app inclui geolocalização e timestamp automáticos
- [ ] **FOTO-02**: Fotos podem ser associadas a uma etapa ou atividade específica do cronograma

### Notificações Inteligentes

- [ ] **NOTIF-01**: Engenheiro recebe alerta quando etapa está atrasada em relação ao cronograma
- [ ] **NOTIF-02**: Engenheiro recebe alerta quando prazo de obra está próximo

## v2 Requirements

### Offline Mode

- **OFFLINE-01**: App funciona sem conexão em canteiro de obra (checklist, fotos locais)
- **OFFLINE-02**: Sincronização automática quando conexão restaurada

### Integrações Financeiras

- **FIN-01**: Consulta a tabela SINAPI para referência de preços de insumos
- **FIN-02**: Boletim de Medição vinculando % executado por fase a liberação de pagamento

### Comunicação

- **COMM-01**: Envio de RDO e atualizações via WhatsApp Business API
- **COMM-02**: Portal web para dono visualizar progresso sem precisar instalar o app

## Out of Scope

| Feature | Reason |
|---------|--------|
| Web app | Android + iOS apenas — definido pelo usuário |
| BIM / visualização 3D | Alta complexidade, fora do escopo de gestão simplificada |
| ERP completo | Escopo é gestão de obra, não enterprise resource planning |
| Marketplace de prestadores | Negócio diferente do core; desvio de foco |
| CRM de pré-venda | Escopo começa na obra iniciada, não na prospecção |
| Gestão de obras públicas | Exige conformidade com licitação, escopo distinto |
| Controle de estoque | Complexidade de supply chain fora do escopo v1 |
| Mudança de stack | Flutter + FastAPI permanece — decisão arquitetural definitiva |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| INFRA-01 | Phase 0 | Complete |
| INFRA-02 | Phase 0 | Complete |
| INFRA-03 | Phase 0 | Complete |
| INFRA-04 | Phase 0 | Complete |
| INFRA-05 | Phase 0 | Complete |
| AI-01 | Phase 1 | Pending |
| AI-02 | Phase 1 | Pending |
| AI-03 | Phase 1 | Pending |
| AI-04 | Phase 1 | Pending |
| AI-05 | Phase 1 | Pending |
| AI-06 | Phase 1 | Pending |
| AI-07 | Phase 1 | Pending |
| FLOW-01 | Phase 2 | Pending |
| FLOW-02 | Phase 2 | Pending |
| FLOW-03 | Phase 2 | Pending |
| FLOW-04 | Phase 2 | Pending |
| FLOW-05 | Phase 2 | Pending |
| DASH-01 | Phase 2 | Pending |
| DASH-02 | Phase 2 | Pending |
| DASH-03 | Phase 2 | Pending |
| ROLE-01 | Phase 3 | Pending |
| ROLE-02 | Phase 3 | Pending |
| ROLE-03 | Phase 3 | Pending |
| ROLE-04 | Phase 3 | Pending |
| ROLE-05 | Phase 3 | Pending |
| ROLE-06 | Phase 3 | Pending |
| OWNER-01 | Phase 3 | Pending |
| OWNER-02 | Phase 3 | Pending |
| OWNER-03 | Phase 3 | Pending |
| RDO-01 | Phase 4 | Pending |
| RDO-02 | Phase 4 | Pending |
| RDO-03 | Phase 4 | Pending |
| RDO-04 | Phase 4 | Pending |
| FOTO-01 | Phase 4 | Pending |
| FOTO-02 | Phase 4 | Pending |
| NOTIF-01 | Phase 4 | Pending |
| NOTIF-02 | Phase 4 | Pending |

**Coverage:**
- v1 requirements: 37 total
- Mapped to phases: 37
- Unmapped: 0 ✓

---
*Requirements defined: 2026-04-06*
*Last updated: 2026-04-06 after initial definition*
