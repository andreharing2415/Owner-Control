import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/riverpod_providers.dart';
import '../utils/auth_error_handler.dart';

class MinhaContaScreen extends ConsumerStatefulWidget {
  const MinhaContaScreen({super.key});

  @override
  ConsumerState<MinhaContaScreen> createState() => _MinhaContaScreenState();
}

class _MinhaContaScreenState extends ConsumerState<MinhaContaScreen> {
  bool _saving = false;

  Future<void> _editField({
    required String title,
    required String currentValue,
    required Future<void> Function(String) onSave,
    TextInputType keyboardType = TextInputType.text,
  }) async {
    final controller = TextEditingController(text: currentValue);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          keyboardType: keyboardType,
          autofocus: true,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            hintText: title,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (result == null || result.isEmpty || result == currentValue) return;
    if (!mounted) return;

    setState(() => _saving = true);
    try {
      await onSave(result);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Atualizado com sucesso!')),
        );
      }
    } catch (e) {
      if (mounted) handleApiError(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final user = auth.user ?? {};
    final nome = user['nome'] as String? ?? '';
    final email = user['email'] as String? ?? '';
    final telefone = user['telefone'] as String? ?? '';
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Minha Conta')),
      body: _saving
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                // ─── Perfil ───────────────────────────────────────────
                _SectionHeader('Perfil'),
                ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: const Text('Nome'),
                  subtitle: Text(nome.isNotEmpty ? nome : 'Não informado'),
                  trailing: const Icon(Icons.edit_outlined),
                  onTap: () => _editField(
                    title: 'Nome',
                    currentValue: nome,
                    onSave: (v) => auth.updateProfile(nome: v),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.email_outlined),
                  title: const Text('Email'),
                  subtitle: Text(email),
                  trailing: const Icon(Icons.lock_outline, size: 18),
                ),
                ListTile(
                  leading: const Icon(Icons.phone_outlined),
                  title: const Text('Telefone'),
                  subtitle: Text(telefone.isNotEmpty ? telefone : 'Não informado'),
                  trailing: const Icon(Icons.edit_outlined),
                  onTap: () => _editField(
                    title: 'Telefone',
                    currentValue: telefone,
                    onSave: (v) => auth.updateProfile(telefone: v),
                    keyboardType: TextInputType.phone,
                  ),
                ),
                const Divider(indent: 16, endIndent: 16),

                // ─── Segurança ────────────────────────────────────────
                _SectionHeader('Segurança'),
                ListTile(
                  leading: const Icon(Icons.lock_outline),
                  title: const Text('Alterar senha'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showComingSoon(),
                ),
                const Divider(indent: 16, endIndent: 16),

                // ─── Zona de perigo ───────────────────────────────────
                _SectionHeader('Zona de perigo'),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: OutlinedButton.icon(
                    onPressed: () => _confirmDeleteAccount(),
                    icon: const Icon(Icons.delete_forever, color: Colors.red),
                    label: const Text(
                      'Excluir minha conta',
                      style: TextStyle(color: Colors.red),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Esta ação é irreversível. Todos os seus dados serão apagados.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
    );
  }

  void _showComingSoon() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Disponível em breve.')),
    );
  }

  Future<void> _confirmDeleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded, size: 48, color: Colors.red),
        title: const Text('Excluir conta'),
        content: const Text(
          'Tem certeza? Todos os dados serão permanentemente apagados. '
          'Esta ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      _showComingSoon();
    }
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
