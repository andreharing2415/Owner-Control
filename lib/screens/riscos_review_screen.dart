import 'package:flutter/material.dart';

import '../api/api.dart';
import '../utils/auth_error_handler.dart';

class RiscosReviewScreen extends StatefulWidget {
  const RiscosReviewScreen({super.key, required this.obraId});
  final String obraId;

  @override
  State<RiscosReviewScreen> createState() => _RiscosReviewScreenState();
}

class _RiscosReviewScreenState extends State<RiscosReviewScreen> {
  final _api = ApiClient();
  late Future<List<Risco>> _future;
  final Set<String> _selecionados = {};
  bool _aplicando = false;

  @override
  void initState() {
    super.initState();
    _future = _api.listarRiscosPendentes(widget.obraId);
  }

  Future<void> _aplicar() async {
    if (_selecionados.isEmpty) return;
    setState(() => _aplicando = true);
    try {
      final criados = await _api.aplicarRiscos(
        obraId: widget.obraId,
        riscoIds: _selecionados.toList(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$criados itens adicionados ao checklist!')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) handleApiError(context, e);
    } finally {
      if (mounted) setState(() => _aplicando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Riscos Pendentes'),
      ),
      bottomNavigationBar: _selecionados.isNotEmpty
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton.icon(
                  onPressed: _aplicando ? null : _aplicar,
                  icon: _aplicando
                      ? const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.playlist_add),
                  label: Text('Aplicar ${_selecionados.length} ao checklist'),
                ),
              ),
            )
          : null,
      body: FutureBuilder<List<Risco>>(
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
          final riscos = snap.data ?? [];
          if (riscos.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_outline, size: 56, color: Colors.green[300]),
                  const SizedBox(height: 12),
                  const Text('Todos os riscos já foram aplicados!'),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
            itemCount: riscos.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (ctx, i) {
              final risco = riscos[i];
              final selected = _selecionados.contains(risco.id);
              final (label, color) = _severidadeStyle(risco.severidade);

              return Card(
                child: CheckboxListTile(
                  value: selected,
                  onChanged: (v) {
                    setState(() {
                      if (v == true) {
                        _selecionados.add(risco.id);
                      } else {
                        _selecionados.remove(risco.id);
                      }
                    });
                  },
                  secondary: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ),
                  title: Text(
                    risco.traducaoLeigo,
                    style: theme.textTheme.bodyMedium,
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (risco.normaReferencia != null)
                        Text(
                          risco.normaReferencia!,
                          style: TextStyle(fontSize: 11, color: Colors.blueGrey[600]),
                        ),
                      Row(
                        children: [
                          const Icon(Icons.auto_awesome, size: 12),
                          const SizedBox(width: 4),
                          Text('${risco.confianca}%', style: const TextStyle(fontSize: 11)),
                          if (risco.requerValidacaoProfissional) ...[
                            const SizedBox(width: 8),
                            Icon(Icons.engineering, size: 12, color: Colors.orange[700]),
                            const SizedBox(width: 2),
                            Text(
                              'Validação profissional',
                              style: TextStyle(fontSize: 11, color: Colors.orange[700]),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  (String, Color) _severidadeStyle(String sev) => switch (sev.toLowerCase()) {
    'alto' || 'alta' => ('ALTO', Colors.red),
    'medio' || 'media' => ('MÉDIO', Colors.orange),
    _ => ('BAIXO', Colors.green),
  };
}
