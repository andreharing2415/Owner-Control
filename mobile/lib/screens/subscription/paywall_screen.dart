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
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
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
                size: 48,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 10),
              Text(
                "Escolha seu plano",
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              if (featureMessage != null) ...[
                const SizedBox(height: 12),
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
              const SizedBox(height: 20),
              // Plan cards side by side
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _PlanCard(
                      planName: "Essencial",
                      price: "R\$ 49,90",
                      planKey: "essencial",
                      highlighted: false,
                      features: const [
                        "Recursos ilimitados",
                        "IA Visual ilimitada",
                        "Checklist inteligente",
                        "Normas completas",
                        "3 convites por obra",
                        "Com anuncios",
                      ],
                      featureIcons: const [
                        Icons.all_inclusive,
                        Icons.smart_toy,
                        Icons.checklist,
                        Icons.search,
                        Icons.people,
                        Icons.ad_units,
                      ],
                      featureColors: const [
                        Colors.green,
                        Colors.green,
                        Colors.green,
                        Colors.green,
                        Colors.green,
                        Colors.orange,
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _PlanCard(
                      planName: "Completo",
                      price: "R\$ 99,90",
                      planKey: "completo",
                      highlighted: true,
                      badge: "Sem ads",
                      features: const [
                        "Recursos ilimitados",
                        "IA Visual ilimitada",
                        "Checklist inteligente",
                        "Normas completas",
                        "3 convites por obra",
                        "Zero anuncios",
                      ],
                      featureIcons: const [
                        Icons.all_inclusive,
                        Icons.smart_toy,
                        Icons.checklist,
                        Icons.search,
                        Icons.people,
                        Icons.block,
                      ],
                      featureColors: const [
                        Colors.green,
                        Colors.green,
                        Colors.green,
                        Colors.green,
                        Colors.green,
                        Colors.green,
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
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

class _PlanCard extends StatefulWidget {
  const _PlanCard({
    required this.planName,
    required this.price,
    required this.planKey,
    required this.highlighted,
    required this.features,
    required this.featureIcons,
    required this.featureColors,
    this.badge,
  });

  final String planName;
  final String price;
  final String planKey;
  final bool highlighted;
  final String? badge;
  final List<String> features;
  final List<IconData> featureIcons;
  final List<Color> featureColors;

  @override
  State<_PlanCard> createState() => _PlanCardState();
}

class _PlanCardState extends State<_PlanCard> {
  bool _loading = false;

  Future<void> _purchase() async {
    setState(() => _loading = true);
    try {
      final api = context.read<SubscriptionProvider>().api;
      final launched = await StripeService.checkout(api, plan: widget.planKey);
      if (!mounted) return;
      if (launched) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Abrindo pagamento... Volte ao app apos concluir.")),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Nao foi possivel abrir o checkout.")),
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
    final theme = Theme.of(context);
    final borderColor = widget.highlighted
        ? theme.colorScheme.primary
        : Colors.grey.shade300;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: borderColor, width: widget.highlighted ? 2 : 1),
        borderRadius: BorderRadius.circular(14),
        color: widget.highlighted
            ? theme.colorScheme.primary.withAlpha(10)
            : null,
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.badge != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                widget.badge!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            )
          else
            const SizedBox(height: 24), // align with badge height
          Text(
            widget.planName,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            "${widget.price}/mes",
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          ...List.generate(widget.features.length, (i) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Icon(
                    widget.featureIcons[i],
                    size: 16,
                    color: widget.featureColors[i],
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      widget.features[i],
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: _loading ? null : _purchase,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              backgroundColor: widget.highlighted
                  ? theme.colorScheme.primary
                  : null,
              textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            child: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text("Assinar"),
          ),
        ],
      ),
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
      final sub = context.read<SubscriptionProvider>();
      await sub.sync();
      if (!mounted) return;
      if (sub.isPaid) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Assinatura confirmada!")),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Nenhuma assinatura ativa encontrada.")),
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
    return TextButton(
      onPressed: _loading ? null : _restore,
      child: _loading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Text("Ja assinei"),
    );
  }
}
