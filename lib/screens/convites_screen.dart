import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../api/api.dart';
import '../utils/auth_error_handler.dart';

class ConvitesScreen extends StatefulWidget {
  const ConvitesScreen({super.key, required this.obraId, required this.obraNome});
  final String obraId;
  final String obraNome;

  @override
  State<ConvitesScreen> createState() => _ConvitesScreenState();
}

class _ConvitesScreenState extends State<ConvitesScreen> {
  final _api = ApiClient();
  late Future<List<ObraConvite>> _future;
  bool _criando = false;

  @override
  void initState() {
    super.initState();
    _future = _api.listarConvites(widget.obraId);
  }

  void _recarregar() {
    setState(() => _future = _api.listarConvites(widget.obraId));
  }

  Future<void> _criarConvite() async {
    final emailCtrl = TextEditingController();
    String papel = 'engenheiro';

    final result = await showDialog<({String email, String papel})>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Convidar colaborador'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: papel,
                decoration: const InputDecoration(
                  labelText: 'Papel',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'engenheiro', child: Text('Engenheiro')),
                  DropdownMenuItem(value: 'arquiteto', child: Text('Arquiteto')),
                  DropdownMenuItem(value: 'empreiteiro', child: Text('Empreiteiro')),
                ],
                onChanged: (v) => setLocal(() => papel = v!),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                final email = emailCtrl.text.trim();
                final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
                if (email.isEmpty || !emailRegex.hasMatch(email)) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Informe um email válido')),
                  );
                  return;
                }
                Navigator.pop(ctx, (email: email, papel: papel));
              },
              child: const Text('Enviar'),
            ),
          ],
        ),
      ),
    );
    emailCtrl.dispose();

    if (result == null || !mounted) return;

    setState(() => _criando = true);
    try {
      await _api.criarConvite(
        obraId: widget.obraId,
        email: result.email,
        papel: result.papel,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Convite enviado!')),
        );
        _recarregar();
      }
    } catch (e) {
      if (mounted) handleApiError(context, e);
    } finally {
      if (mounted) setState(() => _criando = false);
    }
  }

  Future<void> _remover(ObraConvite convite) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remover convite'),
        content: Text('Remover acesso de ${convite.email}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await _api.removerConvite(convite.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Convite removido')),
        );
        _recarregar();
      }
    } catch (e) {
      if (mounted) handleApiError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Convites'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _criando ? null : _criarConvite,
        icon: _criando
            ? const SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.person_add),
        label: const Text('Convidar'),
      ),
      body: FutureBuilder<List<ObraConvite>>(
        future: _future,
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Text('Erro: ${snap.error}'.replaceFirst('Exception: ', '')),
            );
          }
          final convites = snap.data ?? [];
          if (convites.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.group_outlined, size: 56, color: Colors.grey[400]),
                  const SizedBox(height: 12),
                  const Text('Nenhum convite enviado'),
                  const SizedBox(height: 6),
                  const Text(
                    'Convide colaboradores para acompanhar sua obra.',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => _recarregar(),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
              itemCount: convites.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (ctx, i) => _ConviteTile(
                convite: convites[i],
                onRemover: () => _remover(convites[i]),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ConviteTile extends StatelessWidget {
  const _ConviteTile({required this.convite, required this.onRemover});
  final ObraConvite convite;
  final VoidCallback onRemover;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (statusLabel, statusColor) = switch (convite.status) {
      'aceito' => ('Aceito', Colors.green),
      'removido' => ('Removido', Colors.red),
      _ => ('Pendente', Colors.orange),
    };

    String dataCriacao = '';
    try {
      final dt = DateTime.parse(convite.createdAt);
      dataCriacao = DateFormat('dd/MM/yyyy').format(dt);
    } catch (_) {}

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withValues(alpha: 0.15),
          child: Icon(
            convite.isAceito ? Icons.person : Icons.mail_outline,
            color: statusColor,
          ),
        ),
        title: Text(convite.convidadoNome ?? convite.email),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (convite.convidadoNome != null)
              Text(convite.email, style: const TextStyle(fontSize: 12)),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    convite.papel,
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.onSecondaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(fontSize: 11, color: statusColor),
                  ),
                ),
                if (dataCriacao.isNotEmpty) ...[
                  const Spacer(),
                  Text(dataCriacao, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ],
            ),
          ],
        ),
        trailing: convite.status != 'removido'
            ? IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: onRemover,
              )
            : null,
      ),
    );
  }
}
