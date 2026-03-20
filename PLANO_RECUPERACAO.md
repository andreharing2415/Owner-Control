# Plano de Recuperação de Funcionalidades Perdidas

> Gerado em 2026-03-19. Compara o app antigo (`mobile/lib/`, último commit `cb95aae`)
> com o app atual (`lib/`, branch `claude/brave-lovelace`).
>
> **Regra:** só recuperar o que **não conflita** com a estrutura atual (5 tabs,
> `ApiClient` monolítico em `api.dart`, `AuthService` com `flutter_secure_storage`).

---

## Visão Geral da Navegação Atual (manter)

```
MainShell (5 tabs)
├── 0 Inicio   → HomeScreen (dashboard com seletor de obra)
├── 1 Obra      → ObrasScreen → EtapasScreen / CronogramaScreen
├── 2 Documentos→ DocumentsScreen → DocumentAnalysisScreen
├── 3 Prestadores→ PrestadoresScreen
└── 4 Config    → SettingsScreen  ← hoje é placeholder
```

---

## Sessão 1 — Google Sign-In + Perfil

**Objetivo:** Recuperar login com Google e completar perfil de novo usuário.

### Tarefas

1. Adicionar dependências ao `pubspec.yaml`:
   - `google_sign_in: ^6.2.1`
   - `url_launcher: ^6.2.5`

2. Adicionar endpoint no `api.dart`:
   - `loginWithGoogle(idToken)` → `POST /api/auth/google`
   - `updateProfile({nome, telefone})` → `PATCH /api/auth/me`

3. Atualizar `AuthProvider`:
   - Método `loginWithGoogle()` (fluxo OAuth → backend → JWT)
   - Modelo `User` tipado (em vez de `Map<String, dynamic>`)
   - Método `updateProfile()`

4. Criar `lib/screens/complete_profile_screen.dart`:
   - Formulário nome + telefone após 1o login Google
   - Navega para `MainShell` ao concluir

5. Atualizar `LoginScreen`:
   - Adicionar botão "Entrar com Google" abaixo do botão "Entrar"
   - Usar `SvgPicture` ou ícone do Google
   - Chamar `AuthProvider.loginWithGoogle()`

**Fonte:** `git show da80b48:mobile/lib/screens/auth/login_screen.dart`
e `git show da80b48:mobile/lib/screens/auth/complete_profile_screen.dart`

**Estimativa:** ~250 linhas de código novo/alterado

---

## Sessão 2 — Login Biométrico

**Objetivo:** Permitir login por impressão digital / Face ID.

### Tarefas

1. Adicionar dependência:
   - `local_auth: ^2.3.0`

2. Atualizar `AuthService` (`lib/services/auth_service.dart`):
   - Salvar flag `biometrics_enabled` no secure storage
   - Métodos `isBiometricsEnabled()`, `setBiometricsEnabled(bool)`

3. Atualizar `AuthProvider`:
   - `loginWithBiometrics()` — autentica localmente e usa refresh token salvo
   - `promptBiometricEnrollment()` — dialog pós-login oferecendo ativação

4. Atualizar `LoginScreen`:
   - Botão de biometria (ícone fingerprint) visível quando habilitado
   - Dialog de enrollment após login bem-sucedido (email ou Google)

5. Atualizar `SettingsScreen`:
   - Toggle para ativar/desativar login biométrico

**Fonte:** `git show da80b48:mobile/lib/providers/auth_provider.dart`
e `git show da80b48:mobile/lib/services/secure_storage.dart`

**Estimativa:** ~150 linhas

---

## Sessão 3 — SettingsScreen → Perfil Completo + Minha Conta

**Objetivo:** Transformar o placeholder de Config em tela funcional.

### Tarefas

1. Reescrever `lib/screens/settings_screen.dart`:
   - Cabeçalho com avatar, nome, email do usuário
   - Seções: Conta, Preferências, Sobre
   - Links funcionais: Notificações, Idioma, Tema (toggle dark/light)
   - Link "Minha Conta" → `MinhaContaScreen`
   - Link "Política de Privacidade" / "Termos" → `url_launcher`
   - Botão de logout

2. Criar `lib/screens/minha_conta_screen.dart`:
   - Editar nome e telefone (`updateProfile`)
   - Alterar senha
   - Excluir conta (com confirmação dupla)

**Fonte:** `git show 574f9c4:mobile/lib/screens/perfil/perfil_screen.dart`
e `git show 23945c8:mobile/lib/screens/conta/minha_conta_screen.dart`

**Estimativa:** ~300 linhas

---

## Sessão 4 — Detalhe de Item do Checklist + Verificação Inline

**Objetivo:** Recuperar a tela de detalhe de item com evidências e verificação.

### Tarefas

1. Criar `lib/screens/detalhe_item_screen.dart`:
   - Exibe todos os campos do item do checklist
   - Upload de foto (câmera/galeria) como evidência
   - Link para norma relacionada
   - Campo de observação editável

2. Criar widget `lib/screens/widgets/verificacao_inline_widget.dart`:
   - Status conforme / não-conforme
   - Campo de valor numérico quando aplicável
   - Salvar verificação via API

3. Atualizar `ChecklistScreen`:
   - Ao tocar em um item, navegar para `DetalheItemScreen`

**Fonte:** `git show f627da6:mobile/lib/screens/checklist/detalhe_item_screen.dart`
e `git show b8cefc5:mobile/lib/screens/checklist/verificacao_inline_widget.dart`

**Estimativa:** ~350 linhas

---

## Sessão 5 — Edição de Orçamento por Etapa

**Objetivo:** Permitir editar valores previstos/realizados por etapa.

### Tarefas

1. Criar `lib/screens/orcamento_edit_screen.dart`:
   - Lista de etapas com campos "Previsto" e "Realizado" editáveis
   - Totais automáticos
   - Salvar via `POST /api/obras/{id}/orcamento`

2. Integrar na `HomeScreen` (card KPI de orçamento) e/ou `FinanceiroScreen`:
   - Botão "Editar orçamento" que abre `OrcamentoEditScreen`

**Fonte:** `git show b8cefc5:mobile/lib/screens/financeiro/orcamento_edit_screen.dart`

**Estimativa:** ~200 linhas

---

## Sessão 6 — Visualizador de PDF In-App

**Objetivo:** Visualizar documentos PDF sem sair do app.

### Tarefas

1. Adicionar dependência:
   - `syncfusion_flutter_pdfviewer: ^28.2.7`

2. Criar `lib/screens/pdf_viewer_screen.dart`:
   - Recebe URL ou bytes do PDF
   - Toolbar com zoom, busca, navegação de páginas

3. Integrar no `DocumentsScreen`:
   - Ao tocar em documento PDF, abrir `PdfViewerScreen` em vez de `open_filex`

**Fonte:** `git show 574f9c4:mobile/lib/screens/documentos/pdf_viewer_screen.dart`

**Estimativa:** ~100 linhas

---

## Sessão 7 — Sistema de Convites

**Objetivo:** Permitir convidar colaboradores para uma obra.

### Tarefas

1. Adicionar endpoints ao `api.dart`:
   - `criarConvite(obraId, email, papel)` → `POST /api/obras/{id}/convites`
   - `listarConvites(obraId)` → `GET /api/obras/{id}/convites`
   - `cancelarConvite(conviteId)` → `DELETE /api/convites/{id}`
   - `reenviarConvite(conviteId)` → `POST /api/convites/{id}/reenviar`
   - `aceitarConvite(token)` → `POST /api/convites/aceitar`
   - `listarObrasConvidadas()` → `GET /api/convites/minhas-obras`

2. Criar modelos em `api.dart`:
   - `ObraConvite` (id, email, papel, status, criadoEm)

3. Criar `lib/screens/convites_screen.dart`:
   - Lista de convites pendentes/aceitos
   - Formulário para convidar por email
   - Ações: reenviar, cancelar

4. Criar `lib/screens/aceitar_convite_screen.dart`:
   - Aceitar convite via token (deep link ou entrada manual)

5. Integrar:
   - Botão "Convidar" na `ObrasScreen` ou `SettingsScreen`
   - Obras convidadas aparecem na lista de obras do `HomeScreen`

**Fonte:** `git show 6f498ce:mobile/lib/screens/convites/convites_screen.dart`
e `git show 6f498ce:mobile/lib/screens/convites/aceitar_convite_screen.dart`

**Estimativa:** ~400 linhas

---

## Sessão 8 — Revisão de Riscos de Documentos + Detalhamento por Cômodos

**Objetivo:** Telas complementares de IA para análise de documentos.

### Tarefas

1. Criar `lib/screens/riscos_review_screen.dart`:
   - Mostra riscos detectados pela IA em documentos enviados
   - Checkboxes para selecionar riscos relevantes
   - Botão "Aplicar ao checklist" que adiciona itens selecionados

2. Criar `lib/screens/detalhamento_comodos_screen.dart`:
   - Mostra quantitativo por cômodo extraído por IA (área, revestimentos, totais)
   - Tabela navegável por cômodo

3. Integrar no `DocumentAnalysisScreen`:
   - Após análise, mostrar botões "Ver Riscos" e "Quantitativo por Cômodo"

**Fonte:** `git show 6f498ce:mobile/lib/screens/documentos/riscos_review_screen.dart`
e `git show 1ffa7bb:mobile/lib/screens/etapas/detalhamento_comodos_screen.dart`

**Estimativa:** ~350 linhas

---

## Sessão 9 — Monetização (Subscription + Paywall)

> **Nota:** Esta sessão é a mais complexa e pode ser subdividida.
> Requer Stripe configurado no backend e na Play Store/App Store.

### Tarefas

1. Adicionar endpoints ao `api.dart`:
   - `getSubscription()` → `GET /api/subscription/me`
   - `syncSubscription()` → `POST /api/subscription/sync`
   - `createCheckout(plano)` → `POST /api/subscription/create-checkout`
   - `rewardUsage(feature)` → `POST /api/subscription/reward-usage`
   - `cancelSubscription()` → `POST /api/subscription/cancel-subscription`

2. Criar modelo `SubscriptionInfo` em `api.dart`:
   - Campos: plano, maxObras, maxDocumentos, showAds, features habilitadas

3. Criar `lib/providers/subscription_provider.dart`:
   - Carregar assinatura ao iniciar
   - Métodos: `canUseFeature()`, `incrementUsage()`, `isFreePlan`

4. Criar `lib/screens/paywall_screen.dart`:
   - Modal bottom sheet com 3 tiers
   - Comparativo de features
   - Botão "Assinar" que abre Stripe Checkout via `url_launcher`

5. Registrar `SubscriptionProvider` no `main.dart`

6. Integrar feature gating:
   - Handler global para 403 do backend (limite atingido)
   - Mostrar paywall nos pontos de bloqueio

**Fonte:** `git show 6f498ce:mobile/lib/screens/subscription/paywall_screen.dart`,
`git show 6f498ce:mobile/lib/providers/subscription_provider.dart`

**Estimativa:** ~500 linhas

---

## Sessão 10 — AdMob + Analytics (Opcional)

> **Nota:** Só executar se a monetização (Sessão 9) estiver no ar.
> Requer conta AdMob configurada e IDs de anúncio.

### Tarefas

1. Adicionar dependências:
   - `google_mobile_ads: ^5.3.0`
   - `appsflyer_sdk: ^6.15.3`

2. Criar `lib/services/ad_service.dart`:
   - Inicializar SDK, carregar banners e rewarded
   - Gating por plano (só mostra ads para Gratuito/Essencial)

3. Criar `lib/screens/widgets/ad_banner_widget.dart`
4. Criar `lib/screens/widgets/rewarded_dialog.dart`

5. Criar `lib/services/appsflyer_service.dart`:
   - Tracking de eventos (install, signup, subscribe)

6. Integrar banners nas telas principais (Home, Documentos, etc.)

**Fonte:** `git show 1ffa7bb:mobile/lib/services/ad_service.dart`,
`git show 1ffa7bb:mobile/lib/widgets/ad_banner_widget.dart`

**Estimativa:** ~300 linhas

---

## Resumo de Prioridade

| Sessão | Feature | Impacto | Complexidade |
|--------|---------|---------|--------------|
| **1** | Google Sign-In + Perfil | Alto | Média |
| **2** | Login Biométrico | Alto | Baixa |
| **3** | Settings + Minha Conta | Alto | Média |
| **4** | Detalhe Item Checklist | Alto | Média |
| **5** | Edição de Orçamento | Médio | Baixa |
| **6** | PDF Viewer In-App | Médio | Baixa |
| **7** | Sistema de Convites | Médio | Alta |
| **8** | Riscos + Cômodos (IA) | Médio | Média |
| **9** | Monetização (Stripe) | Alto | Alta |
| **10** | AdMob + Analytics | Baixo | Média |

**Ordem recomendada:** 1 → 2 → 3 → 4 → 5 → 6 → 7 → 8 → 9 → 10

---

## Notas Técnicas

- **Código fonte de referência:** Usar `git show <commit>:<path>` para consultar a implementação original.
  Os commits estão na mesma branch, acessíveis pelo histórico.
- **Não portar diretamente:** O app antigo usava providers pesados (`ObraAtualProvider` global,
  `ApiClient` injetado via provider). O app atual usa `ApiClient()` instanciado diretamente.
  Adaptar ao padrão atual, não copiar e colar.
- **Modelos:** O app atual mantém todos os modelos em `api.dart`. Seguir esse padrão (não criar
  arquivos separados de model).
- **Endpoints do backend:** Todos os endpoints listados já existem no servidor FastAPI
  (`server/app/routers/`). Não é necessário alterar o backend.
- **Testes:** O app atual tem `test/api_client_test.dart`. Manter compatibilidade.
