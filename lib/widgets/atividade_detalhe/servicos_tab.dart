import 'package:flutter/material.dart';
import '../../api/api.dart';
import '../../utils/auth_error_handler.dart';

class ServicosTab extends StatefulWidget {
  const ServicosTab({super.key, required this.atividadeId});

  final String atividadeId;

  @override
  State<ServicosTab> createState() => _ServicosTabState();
}

class _ServicosTabState extends State<ServicosTab> {
  final ApiClient _api = ApiClient();
  late Future<List<ServicoNecessario>> _future;

  @override
  void initState() {
    super.initState();
    _future = _api.listarServicos(widget.atividadeId);
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _api.listarServicos(widget.atividadeId);
    });
  }

  Future<void> _vincularPrestador(ServicoNecessario servico) async {
    final controller = TextEditingController();
    final prestadorId = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Vincular prestador"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: "ID do prestador"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text("Vincular"),
          ),
        ],
      ),
    );

    if (prestadorId != null && prestadorId.isNotEmpty) {
      try {
        await _api.vincularPrestador(
          servicoId: servico.id,
          prestadorId: prestadorId,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Prestador vinculado com sucesso.")),
          );
        }
        await _refresh();
      } catch (e) {
        if (e is AuthExpiredException) {
          if (mounted) handleApiError(context, e);
          return;
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Erro: $e")),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ServicoNecessario>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text("Erro: ${snapshot.error}"));
        }
        final servicos = snapshot.data ?? [];
        if (servicos.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.handyman, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text("Nenhum servico necessario",
                    style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: servicos.length,
            itemBuilder: (context, index) {
              final servico = servicos[index];
              return Card(
                child: ListTile(
                  title: Text(servico.descricao),
                  subtitle: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.indigo.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          servico.categoria,
                          style: const TextStyle(
                            color: Colors.indigo,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (servico.prestadorId != null)
                        Text(
                          "Prestador vinculado",
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.green[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                  trailing: servico.prestadorId == null
                      ? TextButton(
                          onPressed: () => _vincularPrestador(servico),
                          child: const Text("Vincular"),
                        )
                      : const Icon(Icons.check_circle,
                          color: Colors.green, size: 20),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
