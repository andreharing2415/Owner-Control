import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/api.dart';
import '../utils/auth_error_handler.dart';

class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  final _api = ApiClient();
  bool _loading = false;
  String? _selectedPlan;

  Future<void> _assinar(String plano) async {
    setState(() {
      _loading = true;
      _selectedPlan = plano;
    });
    try {
      final checkoutUrl = await _api.createCheckout(plano);
      final uri = Uri.parse(checkoutUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) handleApiError(context, e);
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _selectedPlan = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Planos'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header
          Icon(Icons.workspace_premium, size: 56, color: cs.primary),
          const SizedBox(height: 8),
          Text(
            'Escolha o melhor plano para você',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          // ─── Gratuito ──────────────────────────────────────────────
          _PlanCard(
            title: 'Gratuito',
            price: 'R\$ 0',
            period: '/mês',
            features: const [
              '1 obra',
              '1 documento PDF',
              'Checklist básico',
              'Contém anúncios',
            ],
            isCurrentPlan: true,
            color: Colors.grey,
          ),
          const SizedBox(height: 12),

          // ─── Essencial ─────────────────────────────────────────────
          _PlanCard(
            title: 'Essencial',
            price: 'R\$ 29,90',
            period: '/mês',
            features: const [
              'Obras ilimitadas',
              'Documentos ilimitados',
              'Checklist inteligente (IA)',
              'Análise de riscos (IA)',
              'Normas técnicas',
              'Até 3 convites',
              'Contém anúncios',
            ],
            highlighted: true,
            color: Colors.blue,
            onAssinar: _loading ? null : () => _assinar('essencial'),
            loading: _loading && _selectedPlan == 'essencial',
          ),
          const SizedBox(height: 12),

          // ─── Completo ──────────────────────────────────────────────
          _PlanCard(
            title: 'Completo',
            price: 'R\$ 59,90',
            period: '/mês',
            features: const [
              'Tudo do Essencial',
              'Sem anúncios',
              'Convites ilimitados',
              'Suporte prioritário',
              'Quantitativo por cômodo (IA)',
            ],
            color: Colors.indigo,
            onAssinar: _loading ? null : () => _assinar('completo'),
            loading: _loading && _selectedPlan == 'completo',
          ),
          const SizedBox(height: 24),

          // Footer
          Text(
            'Pagamento processado pelo Stripe. '
            'Cancele a qualquer momento.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.title,
    required this.price,
    required this.period,
    required this.features,
    required this.color,
    this.highlighted = false,
    this.isCurrentPlan = false,
    this.onAssinar,
    this.loading = false,
  });

  final String title;
  final String price;
  final String period;
  final List<String> features;
  final Color color;
  final bool highlighted;
  final bool isCurrentPlan;
  final VoidCallback? onAssinar;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: highlighted ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: highlighted
            ? BorderSide(color: color, width: 2)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const Spacer(),
                if (highlighted)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'POPULAR',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  price,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(period, style: theme.textTheme.bodySmall),
              ],
            ),
            const Divider(height: 20),
            ...features.map((f) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Icon(Icons.check, size: 16, color: color),
                  const SizedBox(width: 8),
                  Expanded(child: Text(f, style: const TextStyle(fontSize: 13))),
                ],
              ),
            )),
            const SizedBox(height: 12),
            if (isCurrentPlan)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: null,
                  child: const Text('Plano atual'),
                ),
              )
            else if (onAssinar != null)
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onAssinar,
                  style: FilledButton.styleFrom(backgroundColor: color),
                  child: loading
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white,
                          ),
                        )
                      : const Text('Assinar'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
