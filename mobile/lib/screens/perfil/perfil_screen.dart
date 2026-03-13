import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/obra.dart';
import '../../providers/auth_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../services/api_client.dart';
import '../convites/convites_screen.dart';
import '../prestadores/prestadores_screen.dart';
import '../conta/minha_conta_screen.dart';
import '../../widgets/ad_banner_widget.dart';
import '../subscription/paywall_screen.dart';

class PerfilScreen extends StatelessWidget {
  final Obra obra;
  final ApiClient api;
  final VoidCallback onSelectObra;

  const PerfilScreen({
    super.key,
    required this.obra,
    required this.api,
    required this.onSelectObra,
  });

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final sub = context.watch<SubscriptionProvider>();
    final user = auth.user;
    final isConvidado = user?.isConvidado ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text("Perfil")),
      body: ListView(
        children: [
          // Header do usuario
          Container(
            padding: const EdgeInsets.all(24),
            color: Theme.of(context)
                .colorScheme
                .primaryContainer
                .withValues(alpha: 0.3),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 36,
                  child: Text(
                    (user?.nome ?? "?")[0].toUpperCase(),
                    style: const TextStyle(fontSize: 28),
                  ),
                ),
                const SizedBox(height: 12),
                Text(user?.nome ?? "",
                    style: Theme.of(context).textTheme.titleLarge),
                Text(user?.email ?? "",
                    style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 8),
                Chip(
                  label: Text(
                    sub.isCompleto ? "Plano Completo"
                    : sub.isEssencial ? "Plano Essencial"
                    : sub.isDono ? "Plano Dono da Obra"
                    : "Plano Gratuito",
                  ),
                  backgroundColor:
                      sub.isPaid ? Colors.green.shade100 : Colors.grey.shade200,
                ),
              ],
            ),
          ),

          const AdBannerWidget(),
          // Opcoes
          ListTile(
            leading: const Icon(Icons.swap_horiz),
            title: const Text("Trocar Obra"),
            onTap: onSelectObra,
          ),
          const Divider(height: 1),

          if (!isConvidado) ...[
            ListTile(
              leading: const Icon(Icons.people),
              title: const Text("Convites"),
              subtitle: const Text("Convide profissionais para a obra"),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      ConvitesScreen(obraId: obra.id, obraNome: obra.nome),
                ),
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.engineering),
              title: const Text("Prestadores"),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PrestadoresScreen(api: api),
                ),
              ),
            ),
            const Divider(height: 1),
          ],

          if (!sub.isPaid && !isConvidado) ...[
            ListTile(
              leading: const Icon(Icons.star, color: Colors.amber),
              title: const Text("Assinar Plano"),
              subtitle: const Text("Desbloqueie todas as funcionalidades"),
              onTap: () => PaywallScreen.show(context),
            ),
            const Divider(height: 1),
          ],

          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text("Minha Conta"),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const MinhaContaScreen(),
              ),
            ),
          ),
          const Divider(height: 1),

          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: Text("Sair", style: TextStyle(color: Colors.red.shade700)),
            onTap: () async {
              await context.read<AuthProvider>().logout();
            },
          ),
        ],
      ),
    );
  }
}
