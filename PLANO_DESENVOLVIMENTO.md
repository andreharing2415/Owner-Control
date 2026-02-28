# Plano de Desenvolvimento — ObraMaster Owner Control

**Versão:** 1.2
**Data:** 2026-02-22
**Status:** Fases 0–7 concluídas ✅ | Auth JWT ✅ | Multi-tenant ✅

---

## Visão Geral do Produto

O **ObraMaster Owner Control** é um app Flutter mobile premium para **donos de obras de alto padrão** que precisam fiscalizar construções sem ser engenheiros. O diferencial estratégico é a **IA multimodal com busca dinâmica de normas técnicas atualizadas na web**.

### Fluxo Principal

```
Obra → Etapas (6 fixas) → Checklist por etapa → Evidências (fotos/docs)
                                 ↓
              IA busca normas → gera checklist dinâmico → score de conformidade
                                 ↓
              Upload de projeto PDF → análise de riscos       (Fase 3 ✅)
              Upload de fotos → análise visual                (Fase 4 ✅)
              Controle orçamentário → curva S + alertas       (Fase 2 ✅)
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

| Componente | Status | Observação |
|---|---|---|
| Obras (CRUD) | ✅ Implementado | |
| Etapas (6 fixas) | ✅ Implementado | |
| Checklist + Evidências | ✅ Implementado | |
| Busca de Normas (IA) | ✅ Implementado | |
| Dashboard com KPIs | ✅ Implementado | Conectado à API real |
| Export PDF | ✅ Implementado | |
| Governança Financeira | ✅ Implementado | Fase 2 |
| Document AI | ✅ Implementado | Fase 3 |
| Visual AI | ✅ Implementado | Fase 4 |

### Estrutura de Arquivos Flutter

```
lib/
├── main.dart                          (MaterialApp + MainShell)
├── api/
│   └── api.dart                       (modelos + ApiClient)
├── models/
│   └── mock_data.dart                 (legado — não usado na HomeScreen)
├── providers/
│   └── obra_provider.dart
└── screens/
    ├── main_shell.dart                (navegação principal)
    ├── home_screen.dart               (dashboard — API real)
    ├── obras_screen.dart
    ├── etapas_screen.dart             (+ Visual AI no menu)
    ├── checklist_screen.dart
    ├── evidencias_screen.dart
    ├── normas_screen.dart
    ├── normas_historico_screen.dart
    ├── financial_screen.dart          (Fase 2)
    ├── lancar_despesa_screen.dart     (Fase 2)
    ├── curvas_screen.dart             (Fase 2)
    ├── alertas_config_screen.dart     (Fase 2)
    ├── relatorio_executivo_screen.dart (Fase 2)
    ├── documents_screen.dart          (Fase 3)
    ├── document_analysis_screen.dart  (Fase 3)
    ├── detalhe_risco_screen.dart      (Fase 3)
    ├── visual_ai_screen.dart          (Fase 4)
    ├── achados_screen.dart            (Fase 4)
    ├── detalhe_achado_screen.dart     (Fase 4)
    ├── timeline_screen.dart
    ├── projects_screen.dart
    └── settings_screen.dart
```

### Estrutura de Arquivos Backend

```
server/app/
├── main.py          (todos os endpoints FastAPI)
├── models.py        (SQLModel — tabelas)
├── schemas.py       (Pydantic — request/response)
├── db.py            (SQLite/PostgreSQL)
├── enums.py
├── storage.py       (S3)
├── pdf.py           (export PDF)
├── normas.py        (Fase 1 — busca normativa IA)
├── documentos.py    (Fase 3 — Document AI)
├── visual_ai.py     (Fase 4 — Visual AI)
└── seed_checklists.py
```

---

## Fase 0 — Refatoração e Fundação ✅

- [x] Extrair screens de `main.dart` para `screens/`
- [x] `main.dart` reduzido a MaterialApp + MainShell
- [x] Navegação via `MainShell` com `NavigationBar`
- [ ] Extrair modelos de `api.dart` para `models/` *(postergado — api.dart organizado por seções)*
- [ ] Extrair serviços de `api.dart` para `services/` *(postergado)*

---

## Fase 1 — Verificação do Backend (MVP) ✅

Todos os endpoints MVP implementados em `server/app/main.py`:

| Endpoint | Método | Status |
|---|---|---|
| `/api/obras` | GET/POST | ✅ |
| `/api/obras/{id}` | GET | ✅ |
| `/api/etapas/{id}/status` | PATCH | ✅ |
| `/api/etapas/{id}/checklist-items` | GET/POST | ✅ |
| `/api/checklist-items/{id}` | PATCH | ✅ |
| `/api/checklist-items/{id}/evidencias` | GET/POST | ✅ |
| `/api/etapas/{id}/score` | GET | ✅ |
| `/api/obras/{id}/export-pdf` | GET | ✅ |
| `/api/normas/buscar` | POST | ✅ |
| `/api/normas/historico` | GET | ✅ |
| `/api/normas/etapas` | GET | ✅ |

---

## Fase 2 — Governança Financeira ✅

- [x] Modelos: `OrcamentoEtapa`, `Despesa`, `AlertaConfig`
- [x] Endpoints: `/api/obras/{id}/orcamento`, `/api/obras/{id}/despesas`, `/api/obras/{id}/relatorio-financeiro`, `/api/obras/{id}/alertas`
- [x] Cálculo de desvio (previsto vs. realizado)
- [x] Dados para Curva S
- [x] `FinancialScreen` — orçamento por etapa + desvios
- [x] `LancarDespesaScreen` — formulário de lançamento
- [x] `CurvaSScreen` — gráfico de progresso financeiro
- [x] `AlertasConfigScreen` — configurar threshold
- [x] `RelatorioExecutivoScreen` — relatório exportável
- [x] Card financeiro integrado no Dashboard

---

## Fase 3 — Document AI ✅

- [x] Modelos: `ProjetoDoc`, `Risco`
- [x] Endpoints: `/api/obras/{id}/projetos`, `/api/projetos/{id}/analisar`, `/api/projetos/{id}/analise`
- [x] Upload e armazenamento de PDF no S3
- [x] Análise de riscos com Claude API (guardrails completos)
- [x] `DocumentsScreen` — upload e listagem
- [x] `DocumentAnalysisScreen` — riscos identificados
- [x] `DetalheRiscoScreen` — detalhe com norma e severidade
- [x] Acesso a Documentos no menu principal (tab 4)

---

## Fase 4 — Visual AI ✅

- [x] Modelos: `AnaliseVisual`, `Achado`
- [x] Endpoints: `/api/etapas/{id}/analise-visual`, `/api/etapas/{id}/analises-visuais`, `/api/analises-visuais/{id}`
- [x] Upload de imagem e análise com Claude Vision
- [x] Classificação de etapa + identificação de achados com severidade
- [x] `VisualAIScreen` — câmera/galeria + histórico por etapa
- [x] `AchadosScreen` — lista com contadores por severidade
- [x] `DetalheAchadoScreen` — detalhe com ação recomendada
- [x] Integrado no menu de cada etapa ("Análise Visual (IA)")

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

## Próximos Passos Possíveis

| Item | Prioridade | Status | Descrição |
|---|---|---|---|
| Testes de integração ApiClient | Alta | ✅ Done | 15 testes unitários em `test/api_client_test.dart` |
| `mock_data.dart` cleanup | Baixa | ✅ Done | Removido junto com telas órfãs `projects_screen`/`timeline_screen` |
| Criação de obra com datas | Média | ✅ Done | Date pickers no formulário + `data_inicio`/`data_fim` enviados à API |
| `.withOpacity` deprecations | Baixa | ✅ Done | Migrado para `.withValues(alpha:)` em checklist/etapas/normas/visual_ai screens |
| Push notifications (FCM) | Baixa | ✅ Done | `push.py` firebase-admin + `DeviceToken` model + `NotificationService` Flutter |
| Autenticação JWT | Alta | ✅ Done | Fase 7: User model, JWT access/refresh, login/register screens, multi-tenant, 401 handling |

---

## Fase 7 — Autenticação JWT ✅

- [x] Model `User` (email, password_hash, nome, telefone, role, ativo)
- [x] `Obra.user_id` FK para multi-tenancy
- [x] `auth.py`: hash bcrypt, JWT HS256 (access 60min, refresh 30d), `get_current_user`
- [x] Endpoints: `POST /api/auth/register`, `POST /api/auth/login`, `POST /api/auth/refresh`, `GET /api/auth/me`
- [x] Todos os ~25 endpoints protegidos com `Depends(get_current_user)`
- [x] Ownership check via `_verify_obra_ownership` / `_verify_etapa_ownership`
- [x] Migration Alembic `20260224_0006_autenticacao.py`
- [x] `AuthService` singleton (flutter_secure_storage)
- [x] `AuthProvider` (ChangeNotifier): checkAuth, login, register, logout
- [x] `ApiClient._headers()` com Bearer token automático
- [x] `AuthExpiredException` + `handleApiError` em 14 telas (21 catch blocks)
- [x] `LoginScreen` + `RegisterScreen` (Material 3)
- [x] `AuthGate` (splash → login → app)
- [x] `SettingsScreen` com dados reais + logout funcional
- [x] `flutter analyze` — zero issues

---

## Histórico de Revisões

| Data | Versão | Descrição | Autor |
|---|---|---|---|
| 2026-02-21 | 1.0 | Criação inicial do plano após análise da spec e código existente | Claude |
| 2026-02-21 | 1.1 | Atualização após implementação completa das Fases 0–4 + HomeScreen com API real | Claude |
| 2026-02-22 | 1.2 | Testes de integração ApiClient (15 testes), criação de obra com datas, cleanup de mock_data e telas órfãs | Claude |
| 2026-02-22 | 1.3 | Push notifications FCM: push.py, DeviceToken, NotificationService, integração em lancar_despesa; fix .withOpacity | Claude |
| 2026-02-24 | 1.4 | Fase 7 Autenticação JWT: User model, auth endpoints, login/register screens, multi-tenant, 401 handling global | Claude |
