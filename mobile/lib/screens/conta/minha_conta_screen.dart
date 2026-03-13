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
                    sub.isCompleto ? "Completo"
                    : sub.isEssencial ? "Essencial"
                    : sub.isDono ? "Dono da Obra"
                    : "Gratuito",
                    icon: sub.isPaid
                        ? Icons.workspace_premium
                        : Icons.card_membership,
                    iconColor: sub.isPaid ? Colors.amber : Colors.grey,
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
                  if (sub.isPaid && sub.info?.status == "active") ...[
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
    if (!context.mounted) return;

    try {
      final auth = context.read<AuthProvider>();
      if (field == "nome") {
        await auth.updateProfile(nome: result);
      } else {
        await auth.updateProfile(telefone: result);
      }
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("$label atualizado com sucesso")),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erro ao atualizar: $e")),
      );
    }
  }

  // ─── Cancel Subscription ─────────────────────────────────

  Future<void> _cancelSubscription() async {
    final sub = context.read<SubscriptionProvider>();
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
      final result = await sub.cancelSubscription();
      if (!mounted) return;
      final expiresAt = result["expires_at"] as String?;
      final msg = expiresAt != null
          ? "Assinatura cancelada. Acesso até ${_formatDate(expiresAt)}."
          : "Assinatura cancelada.";
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erro: $e")),
      );
    }
    if (mounted) setState(() => _actionLoading = false);
  }

  // ─── Delete Account ──────────────────────────────────────

  Future<void> _deleteAccount() async {
    final auth = context.read<AuthProvider>();
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
      await auth.api.deleteAccount();
      if (!mounted) return;
      await auth.logout();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erro: $e")),
      );
      setState(() => _actionLoading = false);
    }
  }
}
