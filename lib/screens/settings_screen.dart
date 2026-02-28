import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurações'),
        centerTitle: false,
      ),
      body: ListView(
        children: [
          // Profile section
          const _SectionHeader('Perfil'),
          Builder(builder: (ctx) {
            final auth = ctx.watch<AuthProvider>();
            return ListTile(
              leading: CircleAvatar(
                radius: 22,
                backgroundColor:
                    Theme.of(ctx).colorScheme.primaryContainer,
                child: Icon(
                  Icons.person,
                  color: Theme.of(ctx).colorScheme.primary,
                ),
              ),
              title: Text(
                auth.userName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(auth.userEmail),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showComingSoon(ctx),
            );
          }),
          const Divider(indent: 16, endIndent: 16),

          // Preferences section
          const _SectionHeader('Preferências'),
          _SettingsTile(
            icon: Icons.notifications_outlined,
            label: 'Notificações',
            subtitle: 'Alertas de documentos e etapas',
            onTap: () => _showComingSoon(context),
          ),
          _SettingsTile(
            icon: Icons.language_outlined,
            label: 'Idioma',
            subtitle: 'Português (BR)',
            onTap: () => _showComingSoon(context),
          ),
          _SettingsTile(
            icon: Icons.dark_mode_outlined,
            label: 'Tema',
            subtitle: 'Claro (padrão)',
            onTap: () => _showComingSoon(context),
          ),
          const Divider(indent: 16, endIndent: 16),

          // About section
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
            onTap: () => _showComingSoon(context),
          ),
          _SettingsTile(
            icon: Icons.description_outlined,
            label: 'Termos de Uso',
            onTap: () => _showComingSoon(context),
          ),
          const Divider(indent: 16, endIndent: 16),

          // Sign out
          Padding(
            padding: const EdgeInsets.all(16),
            child: OutlinedButton.icon(
              onPressed: () async {
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
                  await context.read<AuthProvider>().logout();
                }
              },
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

  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Disponível em breve.')),
    );
  }
}

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
