# Gestão de Conta do Usuário — Design Spec

**Data:** 2026-03-10
**Escopo:** Cancelamento de assinatura, exclusão de conta, tela "Minha Conta"

## Contexto

O Google Play exige que o app ofereça ao usuário formas claras de cancelar assinatura e excluir conta. Atualmente o app não tem nenhuma dessas funcionalidades.

## Decisões

- **Cancelamento**: endpoint próprio que chama `stripe.Subscription.modify(cancel_at_period_end=True)` — usuário mantém acesso até fim do período pago
- **Exclusão de conta**: soft delete + anonimização imediata — dados pessoais apagados, dados de obra preservados para outros participantes e futuros insights
- **UI**: nova tela "Minha Conta" acessível pelo menu "Mais"
- **Confirmação**: dialog simples (sem re-autenticação)

## Backend — Novos Endpoints

### POST /api/subscription/cancel-subscription

```
Auth: Bearer token (owner)
Request: (sem body)
Response: { "message": "Assinatura cancelada", "expires_at": "2026-04-10T..." }
```

Lógica:
1. Busca `Subscription` do usuário (user_id)
2. Verifica `status == "active"` e `product_id` existe (Stripe subscription ID)
3. Chama `stripe.Subscription.modify(product_id, cancel_at_period_end=True)`
4. Atualiza `subscription.status = "cancelled"`
5. Retorna `expires_at` para informar até quando tem acesso

### DELETE /api/auth/me

```
Auth: Bearer token
Request: (sem body)
Response: 200 { "message": "Conta excluída com sucesso" }
```

Lógica:
1. Se tem assinatura ativa → cancela no Stripe primeiro (mesma lógica acima)
2. Anonimiza o User:
   - `nome = "Usuário removido"`
   - `email = f"{user.id}@deleted.local"` (mantém unique constraint)
   - `telefone = None`
   - `google_id = None`
   - `password_hash = None`
   - `ativo = False`
3. Remove convites pendentes onde user é dono (`status = "removido"`)
4. Commit e retorna 200
5. Dados de obra permanecem intactos (user_id referência mantida, mas dados pessoais anonimizados)

### Sem migration necessária

O modelo `User` já possui campo `ativo: bool = True`. A anonimização usa campos existentes.

## Flutter — Nova Tela "Minha Conta"

**Arquivo:** `mobile/lib/screens/conta/minha_conta_screen.dart`

### Layout

```
┌─────────────────────────────────┐
│  ← Minha Conta                  │
├─────────────────────────────────┤
│  👤 Perfil                      │
│  Nome: João Silva     [Editar]  │
│  Email: joao@email.com          │
│  Telefone: (11) 99999  [Editar] │
├─────────────────────────────────┤
│  📋 Assinatura                  │
│  Plano: Dono da Obra            │
│  Status: Ativo                  │
│  Válido até: 10/04/2026         │
│  [Cancelar Assinatura]          │
├─────────────────────────────────┤
│  ⚠️ Zona de Perigo              │
│  [Excluir minha conta]  (red)   │
└─────────────────────────────────┘
```

### Seção Perfil
- Exibe nome, email, telefone do usuário logado
- Botões "Editar" para nome e telefone (usa endpoint PATCH /api/auth/me existente)
- Email não editável (readonly)

### Seção Assinatura
- Exibe plano atual (`Gratuito` ou `Dono da Obra`)
- Se `dono_da_obra`: exibe status e data de expiração, botão "Cancelar Assinatura"
- Se `gratuito`: exibe apenas plano, sem botão de cancelamento
- Se `cancelled`: exibe "Cancelada — acesso até DD/MM/YYYY", sem botão

### Seção Zona de Perigo
- Botão "Excluir minha conta" com cor vermelha e ícone de warning
- Sempre visível independente do plano

### Diálogos

**Cancelar Assinatura:**
> "Sua assinatura será cancelada ao final do período atual. Você continuará tendo acesso até [data]. Deseja continuar?"
> [Não] [Sim, cancelar]

**Excluir Conta:**
> "Seus dados pessoais serão removidos permanentemente. Os dados das obras serão mantidos para outros participantes. Esta ação não pode ser desfeita. Deseja continuar?"
> [Não] [Sim, excluir]

Após exclusão: faz logout e navega para tela de login.

## Flutter — API Client

Novos métodos em `api_client.dart`:

```dart
Future<Map<String, dynamic>> cancelSubscription()
// POST /api/subscription/cancel-subscription

Future<void> deleteAccount()
// DELETE /api/auth/me
```

## Flutter — Menu "Mais"

Adicionar item "Minha Conta" (ícone `person_outline`) no menu bottom sheet, entre "Prestadores" e "Assinar Plano Dono" / "Sair".

## Fluxo de Dados

```
[Cancelar Assinatura]
  Flutter → POST /api/subscription/cancel-subscription
    → Backend busca Subscription
    → stripe.Subscription.modify(cancel_at_period_end=True)
    → Atualiza DB status="cancelled"
    → Retorna expires_at
  Flutter → Atualiza SubscriptionProvider
  Flutter → Mostra snackbar "Assinatura cancelada"

[Excluir Conta]
  Flutter → DELETE /api/auth/me
    → Backend cancela Stripe (se ativo)
    → Anonimiza User no DB
    → Remove convites pendentes
    → Retorna 200
  Flutter → AuthProvider.logout()
  Flutter → Navega para LoginScreen
```

## Escopo Futuro (não neste sprint)

- Extração de área construída e cômodos/medidas dos projetos
- Cálculo de quantidade de material baseado em medidas
