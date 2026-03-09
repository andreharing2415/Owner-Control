# Plano de Monetização — ObraMaster (v2)

## Context

O ObraMaster é um app Flutter para gestão de obras residenciais (backend FastAPI no Cloud Run, Supabase PostgreSQL). Possui 27 telas, 45+ endpoints, 13 tabelas e **zero infraestrutura de pagamento**. O objetivo é implementar um modelo freemium com 2 planos (Gratuito + Dono da Obra) via RevenueCat, incluindo sistema de convites para profissionais da obra.

---

## 1. Planos (MVP)

| Plano | Preço | Obras | Convites |
|-------|-------|-------|----------|
| **Gratuito** | R$0 | 1 | Nenhum |
| **Dono da Obra** | R$149,90/mês | 1 | Até 3 profissionais |

> Planos Empreendedor e Profissional ficam para fase futura.

---

## 2. Sistema de Convites (exclusivo plano Dono)

### Fluxo
1. Dono vai na tela de convites da obra e insere e-mail + papel (arquiteto/engenheiro/empreiteiro)
2. Backend envia e-mail com magic link para o convidado
3. Convidado baixa o app, cria conta simplificada (nome + e-mail, sem senha — auth via magic link)
4. Convidado aceita o convite e ganha acesso à obra

### Permissões do Convidado
- Vê **todas as etapas** da obra
- Pode **preencher status** de itens do checklist
- Pode **criar novos itens** no checklist (Dono recebe notificação push)
- Pode **adicionar observações** nos itens
- Pode **fazer upload de evidências** (fotos/docs)
- Pode **deixar comentários/notas** em cada etapa
- **NÃO pode**: solicitar análise AI (visual, checklist inteligente, análise de docs), acessar normas, financeiro, prestadores, upload de documentos de projeto, export PDF

### Gestão
- Dono pode remover convidado a qualquer momento (acesso revogado instantaneamente)
- Máximo 3 convidados por obra
- Quando convidado faz qualquer atualização → Dono recebe notificação push: "O andamento da sua obra foi atualizado por [nome]"

---

## 3. Matriz de Restrições

| Funcionalidade | Gratuito | Dono da Obra | Convidado |
|---|---|---|---|
| Obras | 1 | 1 | Acesso à obra do Dono |
| Upload de documento | 1 (max 3MB) | Ilimitado | Não |
| Excluir documento | Não | Sim | Não |
| Análise de documento | 2 páginas | Todas | Não |
| Visualizar PDF inline | Sim (2 pág.) | Sim (todas) | Não |
| Criar etapas | Não | Sim | Não |
| Criar itens checklist | Não | Sim | Sim |
| Preencher checklist | Sim | Sim | Sim |
| Upload evidências | Sim | Sim | Sim |
| Comentários em etapas | Não | Sim | Sim |
| Análise Visual AI | 1/mês | Ilimitado | Não |
| Checklist Inteligente | 1 (lifetime) | Ilimitado | Não |
| Busca de normas | 3 resultados | Todos | Não |
| Prestadores | 3, sem contato | Todos | Não |
| Financeiro | **Completo** | Completo | Não |
| Convidar profissionais | Não | Até 3 | Não |
| Notificações push | Sim | Sim | Sim |

---

## 4. Schema do Banco de Dados

### 4.1 Coluna nova em `User`
```python
# Em server/app/models.py — class User
plan: str = Field(default="gratuito")  # "gratuito" | "dono_da_obra"
```

### 4.2 Tabela `subscription`
```python
class Subscription(SQLModel, table=True):
    id: UUID = Field(default_factory=uuid4, primary_key=True)
    user_id: UUID = Field(foreign_key="user.id", unique=True, index=True)
    plan: str = Field(default="gratuito")
    status: str = Field(default="active")  # active | expired | cancelled | grace_period
    revenuecat_customer_id: Optional[str] = Field(default=None, index=True)
    store: Optional[str] = None  # play_store | app_store
    product_id: Optional[str] = None
    original_purchase_date: Optional[datetime] = None
    expires_at: Optional[datetime] = None
    grace_period_expires_at: Optional[datetime] = None
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)
```

### 4.3 Tabela `usage_tracking`
```python
class UsageTracking(SQLModel, table=True):
    id: UUID = Field(default_factory=uuid4, primary_key=True)
    user_id: UUID = Field(foreign_key="user.id", index=True)
    feature: str  # "ai_visual" | "checklist_inteligente" | "doc_upload"
    period: str   # "2026-03" (YYYY-MM)
    count: int = Field(default=0)
    # UNIQUE(user_id, feature, period)
```

### 4.4 Tabela `revenuecat_event`
```python
class RevenueCatEvent(SQLModel, table=True):
    id: UUID = Field(default_factory=uuid4, primary_key=True)
    event_type: str
    app_user_id: str = Field(index=True)
    product_id: Optional[str] = None
    store: Optional[str] = None
    event_timestamp: Optional[datetime] = None
    expiration_at: Optional[datetime] = None
    raw_payload: Optional[str] = None
    processed: bool = Field(default=False)
    created_at: datetime = Field(default_factory=datetime.utcnow)
```

### 4.5 Tabela `obra_convite` (NOVA — sistema de convites)
```python
class ObraConvite(SQLModel, table=True):
    id: UUID = Field(default_factory=uuid4, primary_key=True)
    obra_id: UUID = Field(foreign_key="obra.id", index=True)
    dono_id: UUID = Field(foreign_key="user.id")  # quem convidou
    convidado_id: Optional[UUID] = Field(default=None, foreign_key="user.id")  # null até aceitar
    email: str  # e-mail do convidado
    papel: str  # "arquiteto" | "engenheiro" | "empreiteiro"
    status: str = Field(default="pendente")  # pendente | aceito | removido
    token: str = Field(index=True)  # token do magic link
    token_expires_at: datetime
    created_at: datetime = Field(default_factory=datetime.utcnow)
    accepted_at: Optional[datetime] = None
```

### 4.6 Tabela `etapa_comentario` (NOVA — comentários em etapas)
```python
class EtapaComentario(SQLModel, table=True):
    id: UUID = Field(default_factory=uuid4, primary_key=True)
    etapa_id: UUID = Field(foreign_key="etapa.id", index=True)
    user_id: UUID = Field(foreign_key="user.id")
    texto: str
    created_at: datetime = Field(default_factory=datetime.utcnow)
```

**Migração Alembic**: `20260310_subscription_and_invites.py`

---

## 5. Arquitetura Backend

### 5.1 Novo arquivo: `server/app/subscription.py`

**PLAN_CONFIG** com limites por plano (gratuito e dono_da_obra).

**Dependencies**:
- `get_user_plan(user)` → retorna config
- `require_paid(user)` → bloqueia free com 403
- `check_and_increment_usage(session, user_id, feature, limit)`
- `get_obra_access(user, obra_id, session)` → verifica se user é dono OU convidado aceito

### 5.2 Feature gates nos endpoints

| Endpoint | Gate |
|---|---|
| `POST /api/obras` | max_obras do plano |
| `POST /api/obras/{id}/projetos` | Free: 1 doc, 3MB. Convidado: bloqueado |
| `DELETE /api/projetos/{id}` | Free: bloqueado. Convidado: bloqueado |
| `POST /api/projetos/{id}/analisar` | Free: max_pages=2. Convidado: bloqueado |
| `POST /api/etapas/{id}/checklist-items` | Free: bloqueado. Convidado: **permitido** |
| `PATCH /api/checklist-items/{id}` | Convidado: **permitido** (preencher status) |
| `POST /api/checklist-items/{id}/evidencias` | Convidado: **permitido** |
| `POST /api/etapas/{id}/analise-visual` | Free: 1/mês. Convidado: bloqueado |
| `POST /api/normas/buscar` | Free: 3 resultados. Convidado: bloqueado |
| `GET /api/prestadores` | Free: 3, sem contato. Convidado: bloqueado |
| `POST /api/obras/{id}/checklist-inteligente/iniciar` | Free: 1 lifetime. Convidado: bloqueado |
| Financeiro | Convidado: bloqueado. Free/Dono: liberado |

### 5.3 Novos endpoints — Subscription

- `GET /api/subscription/me` — plano, config, uso, limites
- `POST /api/subscription/sync` — fallback RevenueCat REST API
- `POST /api/webhooks/revenuecat` — webhook handler

### 5.4 Novos endpoints — Convites

- `POST /api/obras/{id}/convites` — Dono cria convite (email, papel). Envia e-mail com magic link.
- `GET /api/obras/{id}/convites` — Dono lista convites (pendentes + aceitos)
- `DELETE /api/convites/{id}` — Dono remove convidado (status=removido)
- `POST /api/convites/aceitar` — Convidado aceita convite via token. Cria conta simplificada se não existe.
- `GET /api/convites/minhas-obras` — Convidado lista obras onde foi convidado

### 5.5 Novos endpoints — Comentários em etapas

- `POST /api/etapas/{id}/comentarios` — criar comentário (Dono ou convidado)
- `GET /api/etapas/{id}/comentarios` — listar comentários

### 5.6 Notificações push

Reusar infraestrutura Firebase existente. Novos triggers:
- Convidado preenche checklist → push para Dono
- Convidado cria item → push para Dono
- Convidado adiciona evidência → push para Dono
- Convidado comenta em etapa → push para Dono
- Mensagem padrão: "O andamento da sua obra foi atualizado por [nome do convidado]"

### 5.7 Envio de e-mail (magic link)

Usar Supabase Edge Function ou serviço externo (SendGrid/Resend) para enviar e-mail de convite com magic link:
```
https://mestreobra-backend-....run.app/api/convites/aceitar?token=UUID
```
O link abre deep link no app (ou redirect para Play Store se não instalado).

**Env vars novas no Cloud Run**:
- `REVENUECAT_WEBHOOK_SECRET`
- `REVENUECAT_API_KEY` (para server-side REST API)
- `SENDGRID_API_KEY` ou `RESEND_API_KEY` (para e-mails)

---

## 6. Arquitetura Flutter

### 6.1 Novas dependências (`pubspec.yaml`)
```yaml
purchases_flutter: ^8.0.0
syncfusion_flutter_pdfviewer: ^25.1.0
```

### 6.2 Novos serviços
- `mobile/lib/services/revenuecat_service.dart` — init, purchase, restore

### 6.3 Novos providers
- `mobile/lib/providers/subscription_provider.dart` — plano, limites, uso, compra
- `mobile/lib/providers/convite_provider.dart` — gerenciar convites (para Dono) e obras convidadas (para convidado)

### 6.4 Novos modelos
- `mobile/lib/models/subscription.dart` — SubscriptionInfo
- `mobile/lib/models/convite.dart` — ObraConvite, EtapaComentario

### 6.5 Novos métodos em `api_client.dart`
- `getSubscriptionInfo()`, `syncSubscription()`
- `criarConvite()`, `listarConvites()`, `removerConvite()`, `aceitarConvite()`
- `listarObrasConvidadas()`
- `criarComentario()`, `listarComentarios()`

### 6.6 Novas telas
- `mobile/lib/screens/subscription/paywall_screen.dart` — tela de assinatura (1 plano: Dono R$149,90)
- `mobile/lib/screens/convites/convites_screen.dart` — Dono gerencia convites (adicionar, listar, remover)
- `mobile/lib/screens/convites/aceitar_convite_screen.dart` — Convidado aceita convite

### 6.7 UI patterns para feature gates

**Lock overlay** — botões bloqueados com cadeado + bottom sheet → paywall

**Lista truncada + banner** — normas/prestadores com "Veja todos — Assine"

**Contador de uso** — "0/1 usados este mês" para AI Visual e Checklist Inteligente

**PDF viewer com limite** — free vê só páginas 1-2

**Handler global 403** — `ApiClient` intercepta 403, mostra dialog upgrade

**Modo convidado** — app detecta role=convidado, esconde abas que não tem acesso (financeiro, normas, prestadores, docs, AI). Mostra apenas: Etapas → Checklist → Evidências → Comentários

### 6.8 Telas existentes a modificar

| Tela | Modificação |
|---|---|
| `home_screen.dart` | Badge plano. Se convidado: mostra só obra convidada com acesso restrito |
| `obras_screen.dart` | Verificar `canCreateObra`. Se convidado: listar obras convidadas |
| `documentos_screen.dart` | Gates de upload/delete/viewer. Convidado: sem acesso |
| `etapas_screen.dart` | Adicionar aba/seção de comentários. Convidado: vê todas, sem AI |
| `checklist_screen.dart` | Free: sem criar item. Convidado: pode criar + preencher |
| `detalhe_item_screen.dart` | Convidado: pode atualizar status + evidências |
| `visual_ai_screen.dart` | Free: contador 1/mês. Convidado: sem acesso |
| `checklist_inteligente_screen.dart` | Free: 1 lifetime. Convidado: sem acesso |
| `normas_screen.dart` | Free: 3 resultados. Convidado: sem acesso |
| `prestadores_screen.dart` | Free: 3 sem contato. Convidado: sem acesso |
| `main.dart` | Registrar providers. Inicializar RevenueCat. Tratar deep links de convite |

---

## 7. Edge Cases

| Cenário | Comportamento |
|---|---|
| Assinatura Dono expira | Dados preservados. Perde feature gates → volta a free. Convites ficam com status "removido" (convidados perdem acesso). |
| Convidado tenta acessar obra após remoção | 403 — "Você não tem mais acesso a esta obra" |
| Dono tenta convidar 4º profissional | 403 — "Limite de 3 convidados atingido" |
| Convidado tenta solicitar AI | 403 — "Recurso disponível apenas para o proprietário" |
| Magic link expirado | Token expira em 7 dias. Mostrar "Link expirado, solicite novo convite" |
| Convidado já tem conta no app | Ao aceitar convite, vincula à conta existente (match por e-mail) |
| Convidado não tem conta | Cria conta simplificada (nome pedido na tela de aceite, e-mail do convite, sem senha) |
| Dono com doc no pago, expira para free | Doc continua visível, viewer limita 2 páginas, não pode excluir/upload |
| Falha webhook RevenueCat | Fallback via `/api/subscription/sync` |

---

## 8. RevenueCat Config

- **Entitlement**: `premium`
- **Product**: `dono_da_obra_monthly` (R$149,90/mês)
- **Offering**: `default` com 1 package
- **App User ID**: `str(user.id)`
- **Webhook URL**: `https://mestreobra-backend-530484413221.us-central1.run.app/api/webhooks/revenuecat`
- **Env vars**: `REVENUECAT_WEBHOOK_SECRET`, `REVENUECAT_API_KEY`

---

## 9. Arquivos Críticos

### Novos arquivos a criar
| Arquivo | Descrição |
|---|---|
| `server/app/subscription.py` | PLAN_CONFIG, feature gates, helpers |
| `server/alembic/versions/20260310_subscription_and_invites.py` | Migração: 5 tabelas novas + User.plan |
| `mobile/lib/services/revenuecat_service.dart` | SDK RevenueCat |
| `mobile/lib/providers/subscription_provider.dart` | Estado assinatura |
| `mobile/lib/providers/convite_provider.dart` | Gestão de convites |
| `mobile/lib/models/subscription.dart` | SubscriptionInfo |
| `mobile/lib/models/convite.dart` | ObraConvite, EtapaComentario |
| `mobile/lib/screens/subscription/paywall_screen.dart` | Tela de assinatura |
| `mobile/lib/screens/convites/convites_screen.dart` | Gerenciar convites (Dono) |
| `mobile/lib/screens/convites/aceitar_convite_screen.dart` | Aceitar convite (Convidado) |

### Arquivos existentes a modificar
| Arquivo | Modificação |
|---|---|
| `server/app/models.py` | +5 models (Subscription, UsageTracking, RevenueCatEvent, ObraConvite, EtapaComentario), User.plan |
| `server/app/schemas.py` | +schemas para subscription, convites, comentários |
| `server/app/main.py` | Feature gates ~15 endpoints, +8 novos endpoints (subscription/convites/comentários) |
| `server/requirements.txt` | +sendgrid (ou resend) para e-mails |
| `mobile/pubspec.yaml` | +purchases_flutter, +syncfusion_flutter_pdfviewer |
| `mobile/lib/services/api_client.dart` | +métodos subscription/convites/comentários, handler 403 |
| `mobile/lib/providers/auth_provider.dart` | Inicializar RevenueCat após login |
| `mobile/lib/main.dart` | Registrar providers, tratar deep links |
| `mobile/lib/screens/home/home_screen.dart` | Badge plano, modo convidado |
| `mobile/lib/screens/obras/obras_screen.dart` | Gate criar obra, listar obras convidadas |
| `mobile/lib/screens/documentos/documentos_screen.dart` | Gates + PDF viewer inline |
| `mobile/lib/screens/etapas/etapas_screen.dart` | Seção comentários, modo convidado |
| `mobile/lib/screens/checklist/checklist_screen.dart` | Gate criar item (free), permitir convidado |
| `mobile/lib/screens/checklist/detalhe_item_screen.dart` | Modo convidado: status + evidências |
| `mobile/lib/screens/visual_ai/visual_ai_screen.dart` | Gate 1/mês free, bloquear convidado |
| `mobile/lib/screens/checklist_inteligente/checklist_inteligente_screen.dart` | Gate 1 lifetime, bloquear convidado |
| `mobile/lib/screens/normas/normas_screen.dart` | Truncar 3 resultados free, bloquear convidado |
| `mobile/lib/screens/prestadores/prestadores_screen.dart` | 3 sem contato free, bloquear convidado |

---

## 10. Sequência de Implementação

### Fase 1: Backend — Models + Migration
1. Adicionar 5 novos models em `models.py` + `User.plan`
2. Criar migração Alembic
3. Adicionar schemas em `schemas.py`
4. Criar `subscription.py` (PLAN_CONFIG + helpers + gates)

### Fase 2: Backend — Endpoints
5. Endpoints de subscription: `/api/subscription/me`, `sync`, webhook
6. Endpoints de convites: criar, listar, remover, aceitar, minhas-obras
7. Endpoints de comentários: criar, listar
8. Feature gates nos ~15 endpoints existentes
9. Lógica de envio de e-mail (magic link)
10. Notificações push para Dono quando convidado atualiza

### Fase 3: Flutter — Subscription + Convites
11. Dependências no `pubspec.yaml`
12. `RevenueCatService`, `SubscriptionProvider`, `ConviteProvider`
13. Modelos e métodos no `ApiClient`
14. `PaywallScreen`
15. `ConvitesScreen` + `AceitarConviteScreen`
16. Registrar providers, inicializar RevenueCat, deep links

### Fase 4: Flutter — UI Gates + PDF Viewer
17. Handler global 403 no `ApiClient`
18. Gates em cada tela existente (11 telas)
19. Modo convidado (UI simplificada)
20. PDF viewer inline com limite de páginas
21. Seção de comentários na tela de etapas

### Fase 5: Config + Deploy
22. Configurar produto no Google Play Console / App Store Connect
23. Configurar RevenueCat (product, entitlement, offering, webhook)
24. Configurar serviço de e-mail (SendGrid/Resend)
25. Deploy Cloud Run com novas env vars
26. Testes end-to-end

---

## 11. Verificação

1. **Migration**: Rodar `alembic upgrade head`, verificar tabelas criadas
2. **Endpoints subscription**: curl com user free vs dono — confirmar gates
3. **Convites**: Criar convite, verificar e-mail, aceitar, verificar acesso
4. **Feature gates**: Testar cada endpoint restrito com free/dono/convidado
5. **Push notifications**: Convidado atualiza → Dono recebe notificação
6. **RevenueCat sandbox**: Compra teste no Play Store sandbox
7. **PDF viewer**: Free vê 2 páginas, Dono vê todas
8. **Edge cases**: Expiração, remoção de convidado, magic link expirado
