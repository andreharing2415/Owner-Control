import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "../../providers/subscription_provider.dart";
import "../../services/revenuecat_service.dart";

class PaywallScreen extends StatelessWidget {
  const PaywallScreen({super.key, this.featureMessage});

  /// Optional message explaining which feature triggered the paywall.
  final String? featureMessage;

  /// Shows the paywall as a modal bottom sheet. Returns true if user subscribed.
  static Future<bool?> show(BuildContext context, {String? message}) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => PaywallScreen(featureMessage: message),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Icon(
                Icons.workspace_premium,
                size: 56,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 12),
              Text(
                "Plano Dono da Obra",
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                "R\$ 149,90/mes",
                style: theme.textTheme.titleLarge?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              if (featureMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.lock_outline,
                          color: Colors.orange.shade700, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          featureMessage!,
                          style: TextStyle(
                            color: Colors.orange.shade800,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
              _FeatureRow(
                icon: Icons.description,
                text: "Upload ilimitado de documentos",
              ),
              _FeatureRow(
                icon: Icons.smart_toy,
                text: "Analise visual AI ilimitada",
              ),
              _FeatureRow(
                icon: Icons.checklist,
                text: "Checklist inteligente ilimitado",
              ),
              _FeatureRow(
                icon: Icons.search,
                text: "Busca completa de normas tecnicas",
              ),
              _FeatureRow(
                icon: Icons.people,
                text: "Convide ate 3 profissionais",
              ),
              _FeatureRow(
                icon: Icons.delete_outline,
                text: "Excluir documentos",
              ),
              _FeatureRow(
                icon: Icons.picture_as_pdf,
                text: "Visualizar PDF completo",
              ),
              _FeatureRow(
                icon: Icons.contact_phone,
                text: "Contato completo de prestadores",
              ),
              const SizedBox(height: 28),
              _PurchaseButton(),
              const SizedBox(height: 10),
              _RestoreButton(),
              const SizedBox(height: 8),
              Text(
                "Cancele a qualquer momento. Seus dados sao preservados.",
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.grey[500],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}

class _PurchaseButton extends StatefulWidget {
  @override
  State<_PurchaseButton> createState() => _PurchaseButtonState();
}

class _PurchaseButtonState extends State<_PurchaseButton> {
  bool _loading = false;

  Future<void> _purchase() async {
    setState(() => _loading = true);
    try {
      final success = await RevenueCatService.purchase();
      if (!mounted) return;
      if (success) {
        await context.read<SubscriptionProvider>().sync();
        await context.read<SubscriptionProvider>().load();
        if (mounted) Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Compra cancelada ou indisponivel.")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: _loading ? null : _purchase,
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
      child: _loading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
          : const Text("Assinar Agora"),
    );
  }
}

class _RestoreButton extends StatefulWidget {
  @override
  State<_RestoreButton> createState() => _RestoreButtonState();
}

class _RestoreButtonState extends State<_RestoreButton> {
  bool _loading = false;

  Future<void> _restore() async {
    setState(() => _loading = true);
    try {
      final restored = await RevenueCatService.restore();
      if (!mounted) return;
      if (restored) {
        await context.read<SubscriptionProvider>().sync();
        await context.read<SubscriptionProvider>().load();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Assinatura restaurada!")),
          );
          Navigator.pop(context, true);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Nenhuma assinatura encontrada.")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro ao restaurar: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: _loading ? null : _restore,
      child: _loading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Text("Restaurar compras"),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 22, color: Colors.green),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 14)),
          ),
        ],
      ),
    );
  }
}
