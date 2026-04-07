import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/api.dart';
import '../providers/riverpod_providers.dart';
import 'minha_conta_screen.dart';
import 'paywall_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final sub = ref.watch(subscriptionProvider);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurações'),
        centerTitle: false,
      ),
      body: ListView(
        children: [
          // ─── Cabeçalho do perfil ──────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: cs.primaryContainer,
                  child: Text(
                    _initials(auth.userName),
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: cs.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        auth.userName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        auth.userEmail,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(indent: 16, endIndent: 16),

          // ─── Conta ────────────────────────────────────────────────────
          const _SectionHeader('Conta'),
          _SettingsTile(
            icon: Icons.person_outline,
            label: 'Minha Conta',
            subtitle: 'Editar perfil, senha e mais',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MinhaContaScreen()),
            ),
          ),
          _SettingsTile(
            icon: Icons.workspace_premium,
            label: 'Plano',
            subtitle: switch (sub.plan) {
              'essencial' => 'Essencial',
              'completo' || 'dono_da_obra' => 'Completo',
              _ => 'Gratuito',
            },
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PaywallScreen()),
              );
              if (context.mounted) await ref.read(subscriptionProvider).sync();
            },
          ),

          // ─── Preferências ─────────────────────────────────────────────
          const _SectionHeader('Preferências'),
          const _BiometricsTile(),
          _SettingsTile(
            icon: Icons.notifications_outlined,
            label: 'Notificações',
            subtitle: 'Alertas de documentos e etapas',
            onTap: () => _showComingSoon(context),
          ),
          const Divider(indent: 16, endIndent: 16),

          // ─── Sobre ────────────────────────────────────────────────────
          const _SectionHeader('Sobre'),
          _SettingsTile(
            icon: Icons.info_outlined,
            label: 'Versão do app',
            subtitle: '1.0.0 (build 1)',
            onTap: null,
          ),
          _SettingsTile(
            icon: Icons.privacy_tip_outlined,
            label: 'Política de Privacidade',
            onTap: () => _openUrl('$apiBaseUrl/privacy'),
          ),
          _SettingsTile(
            icon: Icons.description_outlined,
            label: 'Termos de Uso',
            onTap: () => _openUrl('$apiBaseUrl/terms'),
          ),
          const Divider(indent: 16, endIndent: 16),

          // ─── Logout ───────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: OutlinedButton.icon(
              onPressed: () => _confirmLogout(context),
              icon: const Icon(Icons.logout, color: Colors.red),
              label: const Text(
                'Sair da conta',
                style: TextStyle(color: Colors.red),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.red, width: 1),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    if (parts.isNotEmpty && parts[0].isNotEmpty) return parts[0][0].toUpperCase();
    return 'U';
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sair da conta'),
        content: const Text('Tem certeza que deseja sair?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sair'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      final container = ProviderScope.containerOf(context, listen: false);
      await container.read(authProvider).logout();
    }
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Disponível em breve.')),
    );
  }
}

// ─── Toggle de biometria ──────────────────────────────────────────────────────

class _BiometricsTile extends ConsumerStatefulWidget {
  const _BiometricsTile();

  @override
  ConsumerState<_BiometricsTile> createState() => _BiometricsTileState();
}

class _BiometricsTileState extends ConsumerState<_BiometricsTile> {
  bool _available = false;
  bool _enabled = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final auth = ref.read(authProvider);
    final available = await auth.isBiometricsAvailable();
    final enabled = await auth.isBiometricsEnabled();
    if (mounted) {
      setState(() {
        _available = available;
        _enabled = enabled;
        _loaded = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || !_available) return const SizedBox.shrink();
    return SwitchListTile(
      secondary: const Icon(Icons.fingerprint),
      title: const Text('Login biométrico'),
      subtitle: const Text('Entrar com impressão digital ou rosto'),
      value: _enabled,
      onChanged: (val) async {
        await ref.read(authProvider).setBiometricsEnabled(val);
        setState(() => _enabled = val);
      },
    );
  }
}

// ─── Widgets auxiliares ───────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.label,
    this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.onSurface),
      title: Text(label),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      trailing: onTap != null ? const Icon(Icons.chevron_right) : null,
      onTap: onTap,
    );
  }
}
