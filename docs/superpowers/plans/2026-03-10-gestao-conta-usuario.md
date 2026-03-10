# Gestão de Conta do Usuário — Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add cancel subscription, delete account, and "Minha Conta" screen to satisfy Google Play requirements.

**Architecture:** Two new backend endpoints (cancel-subscription, delete account) that interact with Stripe API, plus a new Flutter screen with profile display, subscription management, and account deletion. No database migration needed.

**Tech Stack:** FastAPI (Python), Stripe API, Flutter/Dart, Provider pattern

**Spec:** `docs/superpowers/specs/2026-03-10-gestao-conta-usuario-design.md`

---

## Chunk 1: Backend Endpoints

### Task 1: Backend — Cancel Subscription Endpoint

**Files:**
- Modify: `server/app/main.py` (add endpoint after line ~2208, after sync_subscription)

- [ ] **Step 1: Add the cancel-subscription endpoint**

Add this endpoint in `server/app/main.py` after the `sync_subscription` endpoint (around line 2208):

```python
@app.post("/api/subscription/cancel-subscription")
def cancel_subscription(
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
):
    """Cancela a assinatura do usuário no final do período atual."""
    import stripe

    stripe.api_key = os.getenv("STRIPE_SECRET_KEY")
    if not stripe.api_key:
        raise HTTPException(status_code=500, detail="STRIPE_SECRET_KEY não configurado")

    sub = session.exec(
        select(Subscription).where(Subscription.user_id == current_user.id)
    ).first()

    if not sub or sub.status != "active" or not sub.product_id:
        raise HTTPException(status_code=400, detail="Nenhuma assinatura ativa encontrada")

    try:
        stripe.Subscription.modify(sub.product_id, cancel_at_period_end=True)
    except Exception as exc:
        raise HTTPException(status_code=502, detail=f"Erro Stripe: {exc}")

    sub.status = "cancelled"
    sub.updated_at = datetime.utcnow()
    session.add(sub)
    session.commit()

    return {
        "message": "Assinatura cancelada. Acesso mantido até o final do período.",
        "expires_at": sub.expires_at.isoformat() if sub.expires_at else None,
    }
```

- [ ] **Step 2: Test locally**

Run: `cd server && python -c "from app.main import app; print('OK')"`
Expected: OK (no import errors)

- [ ] **Step 3: Commit**

```bash
git add server/app/main.py
git commit -m "feat: add POST /api/subscription/cancel-subscription endpoint"
```

---

### Task 2: Backend — Delete Account Endpoint

**Files:**
- Modify: `server/app/main.py` (add endpoint after cancel-subscription)

- [ ] **Step 1: Add the delete account endpoint**

Add this endpoint in `server/app/main.py` right after the cancel-subscription endpoint:

```python
@app.delete("/api/auth/me")
def delete_account(
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
):
    """Exclui a conta do usuário: anonimiza dados pessoais, mantém dados de obra."""
    import stripe

    # 1. Cancel Stripe subscription if active
    sub = session.exec(
        select(Subscription).where(Subscription.user_id == current_user.id)
    ).first()

    if sub and sub.status == "active" and sub.product_id:
        stripe_key = os.getenv("STRIPE_SECRET_KEY")
        if stripe_key:
            stripe.api_key = stripe_key
            try:
                stripe.Subscription.modify(sub.product_id, cancel_at_period_end=True)
            except Exception:
                pass  # Best effort — don't block deletion
        sub.status = "cancelled"
        sub.updated_at = datetime.utcnow()
        session.add(sub)

    # 2. Anonymize user data
    current_user.nome = "Usuário removido"
    current_user.email = f"{current_user.id}@deleted.local"
    current_user.telefone = None
    current_user.google_id = None
    current_user.password_hash = None
    current_user.ativo = False
    current_user.plan = "gratuito"
    current_user.updated_at = datetime.utcnow()
    session.add(current_user)

    # 3. Cancel pending invites where user is owner
    pending_convites = session.exec(
        select(ObraConvite).where(
            ObraConvite.dono_id == current_user.id,
            ObraConvite.status == "pendente",
        )
    ).all()
    for convite in pending_convites:
        convite.status = "removido"
        session.add(convite)

    session.commit()
    return {"message": "Conta excluída com sucesso"}
```

- [ ] **Step 2: Test locally**

Run: `cd server && python -c "from app.main import app; print('OK')"`
Expected: OK (no import errors)

- [ ] **Step 3: Commit**

```bash
git add server/app/main.py
git commit -m "feat: add DELETE /api/auth/me endpoint for account deletion with anonymization"
```

---

## Chunk 2: Flutter — API Client & Provider Updates

### Task 3: Flutter — Add API Client Methods

**Files:**
- Modify: `mobile/lib/services/api_client.dart` (add after `createCheckoutSession`, around line 1035)

- [ ] **Step 1: Add cancelSubscription and deleteAccount methods**

Add these two methods in `mobile/lib/services/api_client.dart` after `createCheckoutSession()` (line 1035), before the `// ─── Convites` comment:

```dart
  Future<Map<String, dynamic>> cancelSubscription() async {
    final response = await _post("/api/subscription/cancel-subscription");
    if (response.statusCode != 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      throw Exception(body["detail"] ?? "Erro ao cancelar assinatura");
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<void> deleteAccount() async {
    final response = await _delete("/api/auth/me");
    if (response.statusCode != 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      throw Exception(body["detail"] ?? "Erro ao excluir conta");
    }
  }
```

- [ ] **Step 2: Commit**

```bash
git add mobile/lib/services/api_client.dart
git commit -m "feat: add cancelSubscription and deleteAccount to ApiClient"
```

---

### Task 4: Flutter — Add cancelSubscription to SubscriptionProvider

**Files:**
- Modify: `mobile/lib/providers/subscription_provider.dart` (add method after `sync()`)

- [ ] **Step 1: Add cancelSubscription method**

Add this method in `mobile/lib/providers/subscription_provider.dart` after the `sync()` method (line 62), before `clear()`:

```dart
  Future<Map<String, dynamic>> cancelSubscription() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final result = await api.cancelSubscription();
      await load(); // Reload subscription info
      return result;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
```

- [ ] **Step 2: Commit**

```bash
git add mobile/lib/providers/subscription_provider.dart
git commit -m "feat: add cancelSubscription to SubscriptionProvider"
```

---

## Chunk 3: Flutter — Minha Conta Screen & Menu Integration

### Task 5: Flutter — Create Minha Conta Screen

**Files:**
- Create: `mobile/lib/screens/conta/minha_conta_screen.dart`

- [ ] **Step 1: Create the screen file**

Create `mobile/lib/screens/conta/minha_conta_screen.dart`:

```dart
import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "../../providers/auth_provider.dart";
import "../../providers/subscription_provider.dart";

class MinhaContaScreen extends StatefulWidget {
  const MinhaContaScreen({super.key});

  @override
  State<MinhaContaScreen> createState() => _MinhaContaScreenState();
}

class _MinhaContaScreenState extends State<MinhaContaScreen> {
  bool _actionLoading = false;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final sub = context.watch<SubscriptionProvider>();
    final user = auth.user;

    if (user == null) return const SizedBox.shrink();

    return Scaffold(
      appBar: AppBar(title: const Text("Minha Conta")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ─── Perfil ──────────────────────────────────────
          _buildSectionHeader("Perfil"),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildProfileRow(
                    "Nome",
                    user.nome,
                    onEdit: () => _editField(context, "nome", user.nome),
                  ),
                  const Divider(),
                  _buildProfileRow("Email", user.email),
                  const Divider(),
                  _buildProfileRow(
                    "Telefone",
                    user.telefone ?? "Não informado",
                    onEdit: () =>
                        _editField(context, "telefone", user.telefone ?? ""),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // ─── Assinatura ──────────────────────────────────
          _buildSectionHeader("Assinatura"),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoRow(
                    "Plano",
                    sub.isDono ? "Dono da Obra" : "Gratuito",
                    icon: sub.isDono
                        ? Icons.workspace_premium
                        : Icons.card_membership,
                    iconColor: sub.isDono ? Colors.amber : Colors.grey,
                  ),
                  if (sub.info?.status != null) ...[
                    const SizedBox(height: 8),
                    _buildInfoRow(
                      "Status",
                      _statusLabel(sub.info!.status),
                    ),
                  ],
                  if (sub.info?.expiresAt != null) ...[
                    const SizedBox(height: 8),
                    _buildInfoRow(
                      "Válido até",
                      _formatDate(sub.info!.expiresAt!),
                    ),
                  ],
                  if (sub.isDono && sub.info?.status == "active") ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed:
                            _actionLoading ? null : () => _cancelSubscription(),
                        icon: _actionLoading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.cancel_outlined),
                        label: const Text("Cancelar Assinatura"),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // ─── Zona de Perigo ──────────────────────────────
          _buildSectionHeader("Zona de Perigo"),
          Card(
            color: Colors.red.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Ao excluir sua conta, seus dados pessoais serão removidos permanentemente. "
                    "Os dados das obras serão mantidos para outros participantes.",
                    style: TextStyle(fontSize: 13, color: Colors.black87),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed:
                          _actionLoading ? null : () => _deleteAccount(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.warning_amber_rounded),
                      label: const Text("Excluir minha conta"),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── UI Helpers ──────────────────────────────────────────

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.black54,
        ),
      ),
    );
  }

  Widget _buildProfileRow(String label, String value, {VoidCallback? onEdit}) {
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(label,
              style: const TextStyle(
                  fontWeight: FontWeight.w500, color: Colors.black54)),
        ),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 15))),
        if (onEdit != null)
          IconButton(
            icon: const Icon(Icons.edit, size: 18),
            onPressed: onEdit,
            tooltip: "Editar",
          ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value,
      {IconData? icon, Color? iconColor}) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 20, color: iconColor),
          const SizedBox(width: 8),
        ],
        Text("$label: ",
            style: const TextStyle(
                fontWeight: FontWeight.w500, color: Colors.black54)),
        Text(value, style: const TextStyle(fontSize: 15)),
      ],
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case "active":
        return "Ativo";
      case "cancelled":
        return "Cancelado";
      case "expired":
        return "Expirado";
      default:
        return status;
    }
  }

  String _formatDate(String isoDate) {
    try {
      final dt = DateTime.parse(isoDate);
      return "${dt.day.toString().padLeft(2, '0')}/"
          "${dt.month.toString().padLeft(2, '0')}/"
          "${dt.year}";
    } catch (_) {
      return isoDate;
    }
  }

  // ─── Edit Profile ────────────────────────────────────────

  Future<void> _editField(
      BuildContext context, String field, String currentValue) async {
    final controller = TextEditingController(text: currentValue);
    final label = field == "nome" ? "Nome" : "Telefone";

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Editar $label"),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: label),
          keyboardType:
              field == "telefone" ? TextInputType.phone : TextInputType.name,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: const Text("Salvar")),
        ],
      ),
    );

    if (result == null || result.isEmpty || result == currentValue) return;

    try {
      final auth = context.read<AuthProvider>();
      if (field == "nome") {
        await auth.updateProfile(nome: result);
      } else {
        await auth.updateProfile(telefone: result);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("$label atualizado com sucesso")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro ao atualizar: $e")),
        );
      }
    }
  }

  // ─── Cancel Subscription ─────────────────────────────────

  Future<void> _cancelSubscription() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Cancelar assinatura"),
        content: const Text(
          "Sua assinatura será cancelada ao final do período atual. "
          "Você continuará tendo acesso até a data de vencimento.\n\n"
          "Deseja continuar?",
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Não")),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Sim, cancelar"),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _actionLoading = true);
    try {
      final sub = context.read<SubscriptionProvider>();
      final result = await sub.cancelSubscription();
      if (mounted) {
        final expiresAt = result["expires_at"] as String?;
        final msg = expiresAt != null
            ? "Assinatura cancelada. Acesso até ${_formatDate(expiresAt)}."
            : "Assinatura cancelada.";
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro: $e")),
        );
      }
    }
    if (mounted) setState(() => _actionLoading = false);
  }

  // ─── Delete Account ──────────────────────────────────────

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Excluir conta"),
        content: const Text(
          "Seus dados pessoais serão removidos permanentemente. "
          "Os dados das obras serão mantidos para outros participantes.\n\n"
          "Esta ação não pode ser desfeita. Deseja continuar?",
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Não")),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Sim, excluir"),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _actionLoading = true);
    try {
      final api = context.read<AuthProvider>().api;
      await api.deleteAccount();
      if (mounted) {
        await context.read<AuthProvider>().logout();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro: $e")),
        );
        setState(() => _actionLoading = false);
      }
    }
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add mobile/lib/screens/conta/minha_conta_screen.dart
git commit -m "feat: create Minha Conta screen with profile, subscription cancel, account delete"
```

---

### Task 6: Flutter — Add "Minha Conta" to Menu "Mais"

**Files:**
- Modify: `mobile/lib/screens/home/home_screen.dart`

- [ ] **Step 1: Add import for MinhaContaScreen**

Add this import at the top of `mobile/lib/screens/home/home_screen.dart`, with the other screen imports:

```dart
import "../conta/minha_conta_screen.dart";
```

- [ ] **Step 2: Add "Minha Conta" menu item**

In the `_showMaisMenu` method, add a new `ListTile` for "Minha Conta" between the `Divider()` (line 323) and the logout `ListTile` (line 324). The new item goes right before the "Sair" item:

```dart
                ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: const Text("Minha Conta"),
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const MinhaContaScreen(),
                      ),
                    );
                  },
                ),
```

- [ ] **Step 3: Commit**

```bash
git add mobile/lib/screens/home/home_screen.dart
git commit -m "feat: add Minha Conta menu item in home Mais menu"
```

---

## Chunk 4: Deploy & Build

### Task 7: Deploy Backend to Cloud Run

- [ ] **Step 1: Deploy backend**

Run: `bash server/deploy-cloudrun.sh`
Expected: Successful deployment to `mestreobra-backend` service

- [ ] **Step 2: Verify endpoints**

Run:
```bash
curl -s https://mestreobra-backend-530484413221.us-central1.run.app/docs | grep -o "cancel-subscription\|delete.*auth/me"
```
Expected: Both endpoints visible in docs

- [ ] **Step 3: Commit any deploy changes if needed**

---

### Task 8: Build AAB for Google Play

- [ ] **Step 1: Verify version is 2.0.0+2**

Check `mobile/pubspec.yaml` line 5: `version: 2.0.0+2`

- [ ] **Step 2: Build release AAB**

Run:
```bash
cd mobile && flutter build appbundle --release
```
Expected: `build/app/outputs/bundle/release/app-release.aab` generated

- [ ] **Step 3: Upload to Google Play Console**

Upload the new AAB to the internal test track. versionCode 2 should be accepted.

- [ ] **Step 4: Commit all changes**

```bash
git add -A
git commit -m "feat: account management - cancel subscription, delete account, Minha Conta screen"
```
