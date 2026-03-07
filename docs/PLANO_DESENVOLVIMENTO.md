# Plano de Desenvolvimento — ObraMaster Owner Control

**Versão:** 2.0
**Data:** 2026-03-05
**Status:** Todas as fases implementadas (Flutter + Backend)

---

## Visão Geral do Produto

O **ObraMaster Owner Control** é um app Flutter mobile premium para **donos de obras de alto padrão** que precisam fiscalizar construções sem ser engenheiros. O diferencial estratégico é a **IA multimodal com busca dinâmica de normas técnicas atualizadas na web**.

### Fluxo Principal

```
Obra → Etapas (6 fixas) → Checklist por etapa → Evidências (fotos/docs)
                                 ↑
              IA busca normas → gera checklist dinâmico → score de conformidade
                                 ↑
              Upload de projeto PDF → análise de riscos       (Fase 3)
              Upload de fotos → análise visual                (Fase 4)
              Controle orçamentário → curva S + alertas       (Fase 5)
```

### As 6 Etapas Padrão

1. Planejamento e Projeto
2. Preparação do Terreno
3. Fundações e Estrutura
4. Alvenaria e Cobertura
5. Instalações e Acabamentos
6. Entrega e Pós-obra

---

## Estado Atual da Implementação

| Componente | Backend | Flutter | Observação |
|---|---|---|---|
| Autenticação JWT | ✅ | ✅ | Login, registro, refresh token, logout |
| Obras (CRUD) | ✅ | ✅ | |
| Etapas (6 fixas) | ✅ | ✅ | |
| Checklist + Evidências | ✅ | ✅ | |
| Busca de Normas (IA) | ✅ | ✅ | |
| Dashboard com KPIs | ✅ | ✅ | |
| Export PDF | ✅ | ✅ | |
| Governança Financeira | ✅ | ✅ | Orçamento, despesas, curva S, alertas |
| Document AI | ✅ | ✅ | Upload PDF, análise riscos, detalhe |
| Visual AI | ✅ | ✅ | Foto, análise, achados |
| Prestadores/Fornecedores | ✅ | ✅ | Diretório, avaliações, filtros |
| Checklist Inteligente | ✅ | ✅ | Geração IA, aplicação seletiva |
| **Arquitetura do código** | ✅ | ✅ | Refatorado em models/, services/, screens/ |

### Arquivos Atuais (Flutter)

```
lib/
├── main.dart                          (MaterialApp + AuthGate + providers)
├── models/
│   ├── auth.dart                      (User, AuthTokens, ChecklistInteligenteLog)
│   ├── obra.dart
│   ├── etapa.dart
│   ├── checklist_item.dart
│   ├── evidencia.dart
│   ├── norma.dart
│   ├── financeiro.dart                (OrcamentoEtapa, Despesa, AlertaConfig, RelatorioFinanceiro, CurvaSPonto)
│   ├── documento.dart                 (ProjetoDoc, Risco, AnaliseDocumento)
│   ├── visual_ai.dart                 (AnaliseVisual, Achado)
│   └── prestador.dart                 (Prestador, Avaliacao)
├── services/
│   └── api_client.dart                (HTTP client com JWT auth + todos endpoints)
├── providers/
│   ├── auth_provider.dart             (Login, registro, refresh, token storage)
│   └── obra_provider.dart
└── screens/
    ├── auth/
    │   ├── login_screen.dart
    │   └── registro_screen.dart
    ├── home/
    │   └── home_screen.dart           (Dashboard com KPIs + ações rápidas)
    ├── obras/
    │   └── obras_screen.dart
    ├── etapas/
    │   └── etapas_screen.dart
    ├── checklist/
    │   ├── checklist_screen.dart
    │   └── evidencias_screen.dart
    ├── normas/
    │   ├── normas_screen.dart
    │   └── normas_historico_screen.dart
    ├── financeiro/
    │   ├── financeiro_screen.dart
    │   ├── lancar_despesa_screen.dart
    │   ├── curva_s_screen.dart
    │   └── alertas_config_screen.dart
    ├── documentos/
    │   ├── documentos_screen.dart
    │   ├── analise_documento_screen.dart
    │   └── detalhe_risco_screen.dart
    ├── visual_ai/
    │   ├── visual_ai_screen.dart
    │   └── detalhe_achado_screen.dart
    ├── prestadores/
    │   ├── prestadores_screen.dart
    │   └── detalhe_prestador_screen.dart
    └── checklist_inteligente/
        └── checklist_inteligente_screen.dart
```

---

## Fase 0 — Refatoração e Fundação *(Prioridade Crítica)*

> Antes de crescer, organizar. O `main.dart` com 1.350 linhas precisa ser dividido.

### Estrutura de Pastas Proposta

```
lib/
├── main.dart                          (apenas MaterialApp + providers)
├── app/
│   └── routes.dart
├── models/
│   ├── obra.dart
│   ├── etapa.dart
│   ├── checklist_item.dart
│   ├── evidencia.dart
│   └── norma.dart
├── services/
│   ├── api_client.dart
│   ├── obra_service.dart
│   ├── checklist_service.dart
│   └── norma_service.dart
├── providers/
│   ├── obra_provider.dart
│   └── dashboard_provider.dart
├── screens/
│   ├── home/
│   │   ├── home_screen.dart
│   │   └── widgets/
│   │       ├── kpi_row.dart
│   │       ├── orcamento_card.dart
│   │       ├── acoes_rapidas_card.dart
│   │       └── itens_pendentes_card.dart
│   ├── obras/
│   │   └── obras_screen.dart
│   ├── etapas/
│   │   └── etapas_screen.dart
│   ├── checklist/
│   │   ├── checklist_screen.dart
│   │   └── evidencias_screen.dart
│   ├── normas/
│   │   ├── normas_screen.dart
│   │   └── normas_historico_screen.dart
│   ├── financeiro/                    (Fase 2 — criar)
│   ├── documentos/                    (Fase 3 — criar)
│   └── visual_ai/                     (Fase 4 — criar)
└── widgets/
    ├── kpi_card.dart
    ├── status_badge.dart
    └── confidence_bar.dart
```

### Tarefas da Fase 0

- [ ] Extrair modelos de `api.dart` para `models/`
- [ ] Extrair serviços de `api.dart` para `services/`
- [ ] Extrair `ObrasScreen` de `main.dart` para `screens/obras/`
- [ ] Extrair `EtapasScreen` de `main.dart` para `screens/etapas/`
- [ ] Extrair `ChecklistScreen` de `main.dart` para `screens/checklist/`
- [ ] Extrair `EvidenciasScreen` de `main.dart` para `screens/checklist/`
- [ ] Extrair `NormasScreen` de `main.dart` para `screens/normas/`
- [ ] Extrair `NormasHistoricoScreen` de `main.dart` para `screens/normas/`
- [ ] Extrair widgets do `home_screen.dart` para `screens/home/widgets/`
- [ ] Criar `DashboardProvider` para isolar estado do dashboard
- [ ] Configurar rotas nomeadas em `app/routes.dart`
- [ ] Validar que app funciona igual após refatoração

---

## Fase 1 — Verificação do Backend (MVP)

> Garantir que todos os endpoints do MVP estão implementados no backend FastAPI.

### Endpoints Necessários

| Endpoint | Método | Funcionalidade | Status |
|---|---|---|---|
| `/api/obras` | GET | Listar obras | A verificar |
| `/api/obras` | POST | Criar obra | A verificar |
| `/api/obras/{id}` | GET | Detalhes + etapas | A verificar |
| `/api/etapas/{id}/status` | PATCH | Atualizar status | A verificar |
| `/api/etapas/{id}/checklist-items` | GET | Listar itens | A verificar |
| `/api/etapas/{id}/checklist-items` | POST | Criar item | A verificar |
| `/api/checklist-items/{id}` | PATCH | Atualizar item | A verificar |
| `/api/checklist-items/{id}/evidencias` | GET | Listar evidências | A verificar |
| `/api/checklist-items/{id}/evidencias` | POST | Upload evidência | A verificar |
| `/api/etapas/{id}/score` | GET | Score da etapa | A verificar |
| `/api/obras/{id}/export-pdf` | GET | Exportar PDF | A verificar |
| `/api/normas/buscar` | POST | Buscar normas (IA) | A verificar |
| `/api/normas/historico` | GET | Histórico de buscas | A verificar |
| `/api/normas/etapas` | GET | Listar etapas p/ normas | A verificar |

### Tarefas da Fase 1

- [ ] Auditar backend — listar todos os endpoints implementados
- [ ] Implementar endpoints faltantes
- [ ] Testar integração Flutter ↔ Backend em todos os fluxos do MVP
- [ ] Verificar criação automática das 6 etapas ao criar obra

---

## Fase 2 — Governança Financeira *(Epic F)*

> Controle de orçamento por etapa, lançamento de despesas, curva S e alertas de desvio.

### Critérios de Aceitação

- [ ] Orçamento registrado por etapa
- [ ] Desvio (previsto vs. realizado) calculado e exibido
- [ ] Curva S gerada com progresso financeiro
- [ ] Alertas configuráveis por percentual de desvio
- [ ] Relatório executivo consolidado exportável

### Telas Flutter a Criar

| Tela | Funcionalidade |
|---|---|
| `FinanceiroScreen` | Orçamento por etapa + desvios |
| `LancarDespesaScreen` | Formulário de lançamento de despesa |
| `CurvaSScreen` | Gráfico de progresso financeiro (previsto vs. real) |
| `AlertasConfigScreen` | Configurar threshold de alertas |
| `RelatorioExecutivoScreen` | Relatório consolidado exportável |

### Endpoints Backend a Criar

| Endpoint | Método | Funcionalidade |
|---|---|---|
| `/api/obras/{id}/orcamento` | POST | Registrar orçamento por etapa |
| `/api/obras/{id}/orcamento` | GET | Consultar orçamento |
| `/api/obras/{id}/despesas` | POST | Lançar despesa |
| `/api/obras/{id}/despesas` | GET | Listar despesas |
| `/api/obras/{id}/relatorio-financeiro` | GET | Desvio + curva S |
| `/api/obras/{id}/alertas` | PUT | Configurar threshold |

### Modelos de Dados

```
OrcamentoEtapa
  - id, obra_id, etapa_id, valor_previsto

Despesa
  - id, obra_id, etapa_id, valor, descricao, data, comprovante_url

AlertaConfig
  - id, obra_id, percentual_desvio_threshold, notificacao_ativa
```

### Tarefas da Fase 2

- [ ] Criar modelos no banco de dados
- [ ] Implementar endpoints de orçamento e despesas
- [ ] Implementar cálculo de desvio (previsto vs. realizado)
- [ ] Implementar geração de dados para curva S
- [ ] Criar `FinanceiroScreen` no Flutter
- [ ] Criar `LancarDespesaScreen` com upload de comprovante
- [ ] Criar `CurvaSScreen` com gráfico (package `fl_chart`)
- [ ] Criar `AlertasConfigScreen`
- [ ] Criar `RelatorioExecutivoScreen` com export PDF
- [ ] Integrar card financeiro no Dashboard

---

## Fase 3 — Document AI *(Epic D)*

> Upload de projetos em PDF, extração de texto e identificação de riscos com base em normas.

### Critérios de Aceitação

- [ ] PDF enviado, armazenado e indexado
- [ ] Texto extraído e estruturado
- [ ] Riscos identificados com severidade (alto/médio/baixo)
- [ ] Relatório com fonte normativa e linguagem leiga
- [ ] Checklist personalizado gerado a partir da análise

### Telas Flutter a Criar

| Tela | Funcionalidade |
|---|---|
| `DocumentosScreen` | Upload e listagem de projetos PDF |
| `AnaliseDocumentoScreen` | Riscos identificados + checklist personalizado |
| `DetalheRiscoScreen` | Detalhe de risco com norma, severidade e recomendação |

### Endpoints Backend a Criar

| Endpoint | Método | Funcionalidade |
|---|---|---|
| `/api/obras/{id}/projetos` | POST | Upload de PDF |
| `/api/obras/{id}/projetos` | GET | Listar projetos |
| `/api/projetos/{id}` | GET | Detalhes do projeto |
| `/api/projetos/{id}/analisar` | POST | Disparar análise IA |
| `/api/projetos/{id}/analise` | GET | Resultado com riscos |

### Modelos de Dados

```
ProjetoDoc
  - id, obra_id, arquivo_url, arquivo_nome, status (pendente|processando|concluido|erro)
  - data_upload, texto_extraido?

Risco
  - id, projeto_id, descricao, severidade (alto|medio|baixo)
  - norma_referencia?, traducao_leigo, requer_validacao_profissional
  - confianca (0-100)
```

### Guardrails da IA (obrigatórios)

- Sempre indicar fonte, data e versão da norma referenciada
- Informar se a fonte é oficial ou secundária
- Não apresentar como opinião técnica
- Exibir nível de confiança
- Itens de alto risco exigem recomendação de validação profissional

### Tarefas da Fase 3

- [ ] Criar modelos no banco de dados
- [ ] Implementar endpoint de upload de PDF
- [ ] Implementar extração de texto (PyPDF2 ou pdfplumber)
- [ ] Integrar IA para identificação de riscos (Claude API)
- [ ] Implementar geração de checklist personalizado
- [ ] Criar `DocumentosScreen` no Flutter
- [ ] Criar `AnaliseDocumentoScreen` com lista de riscos
- [ ] Criar `DetalheRiscoScreen`
- [ ] Adicionar acesso a Documentos no Dashboard

---

## Fase 4 — Visual AI *(Epic E)*

> Upload de fotos da obra, classificação automática de etapa e identificação de achados com severidade.

### Critérios de Aceitação

- [ ] Upload de imagem funcionando
- [ ] Classificação de etapa com acurácia ≥ 90%
- [ ] Achados com severidade e ação recomendada
- [ ] Confiança exibida por achado
- [ ] Solicitação de evidência adicional quando necessário

### Telas Flutter a Criar

| Tela | Funcionalidade |
|---|---|
| `VisualAIScreen` | Upload de foto + resultado da análise |
| `FindingsScreen` | Achados com severidade e ação recomendada |
| `DetalheAchadoScreen` | Detalhe do achado com imagem e recomendação |

### Endpoints Backend a Criar

| Endpoint | Método | Funcionalidade |
|---|---|---|
| `/api/etapas/{id}/analise-visual` | POST | Upload de imagem para análise |
| `/api/etapas/{id}/analises-visuais` | GET | Listar análises da etapa |
| `/api/analises-visuais/{id}` | GET | Resultado completo |

### Modelos de Dados

```
AnaliseVisual
  - id, etapa_id, imagem_url, etapa_inferida, confianca
  - data_analise, status (processando|concluida|erro)

Finding (Achado)
  - id, analise_id, descricao, severidade (alto|medio|baixo)
  - acao_recomendada, requer_evidencia_adicional
  - requer_validacao_profissional, confianca
```

### Tarefas da Fase 4

- [ ] Criar modelos no banco de dados
- [ ] Implementar endpoint de upload e análise de imagem
- [ ] Integrar IA multimodal para classificação visual (Claude API vision)
- [ ] Implementar geração de achados com severidade
- [ ] Criar `VisualAIScreen` no Flutter com câmera + galeria
- [ ] Criar `FindingsScreen` com lista de achados
- [ ] Criar `DetalheAchadoScreen`
- [ ] Integrar análise visual no fluxo de checklist por etapa

---

## Dependências e Packages Flutter

### Já instalados

| Package | Uso |
|---|---|
| `provider` | State management |
| `http` | Comunicação com API |
| `file_picker` | Seleção de arquivos |
| `image_picker` | Câmera e galeria |
| `path_provider` | Storage local |
| `open_filex` | Abrir arquivos |
| `flutter_svg` | Ícones SVG |

### A adicionar conforme fases

| Package | Fase | Uso |
|---|---|---|
| `fl_chart` | Fase 2 | Gráfico da curva S |
| `intl` | Fase 2 | Formatação de moeda e datas |
| `pdf` | Fase 2 | Geração de relatório PDF no cliente |
| `syncfusion_flutter_charts` | Fase 2 (alt.) | Alternativa ao fl_chart |

---

## Guardrails Globais da IA (não negociáveis)

Aplicam-se a todas as fases com componente de IA:

1. **Sempre** indicar fonte, data e versão da norma
2. **Sempre** informar se a fonte é oficial ou secundária
3. **Nunca** apresentar análise como opinião técnica
4. **Sempre** exibir nível de confiança (0–100%)
5. **Sempre** registrar log de versão e data da consulta
6. Evidência **obrigatória** para itens críticos
7. Achados de alto risco **exigem** recomendação clara e solicitação de validação profissional

---

## Métricas de Sucesso do Produto

- 80% dos usuários utilizam checklist em campo
- 70% utilizam o módulo de análise de projetos (IA)
- Redução de rejeições tardias de obra
- Aumento de ARPU com módulo IA premium

---

## Histórico de Revisões

| Data | Versão | Descrição | Autor |
|---|---|---|---|
| 2026-02-21 | 1.0 | Criação inicial do plano após análise da spec e código existente | Claude |
