import 'package:flutter/material.dart';
import '../../api/api.dart';
import '../../utils/auth_error_handler.dart';

class ChecklistTab extends StatefulWidget {
  const ChecklistTab({super.key, required this.atividadeId});

  final String atividadeId;

  @override
  State<ChecklistTab> createState() => ChecklistTabState();
}

class ChecklistTabState extends State<ChecklistTab> {
  final ApiClient _api = ApiClient();
  late Future<List<ChecklistItem>> _future;

  @override
  void initState() {
    super.initState();
    _future = _api.listarChecklistAtividade(widget.atividadeId);
  }

  Future<void> refresh() async {
    setState(() {
      _future = _api.listarChecklistAtividade(widget.atividadeId);
    });
  }

  Future<void> criarItem() async {
    final tituloController = TextEditingController();
    final descricaoController = TextEditingController();
    bool critico = false;

    final created = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Novo item"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: tituloController,
              decoration: const InputDecoration(labelText: "Titulo *"),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: descricaoController,
              decoration: const InputDecoration(labelText: "Descricao"),
              textCapitalization: TextCapitalization.sentences,
            ),
            StatefulBuilder(
              builder: (context, setLocalState) => SwitchListTile(
                title: const Text("Item critico"),
                subtitle: const Text("Exige atencao especial"),
                value: critico,
                onChanged: (value) => setLocalState(() => critico = value),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Salvar"),
          ),
        ],
      ),
    );

    if (created == true && tituloController.text.trim().isNotEmpty) {
      try {
        await _api.criarChecklistAtividade(
          atividadeId: widget.atividadeId,
          titulo: tituloController.text.trim(),
          descricao: descricaoController.text.trim(),
          critico: critico,
        );
        await refresh();
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

  Future<void> _atualizarStatus(ChecklistItem item, String status) async {
    try {
      await _api.atualizarItem(itemId: item.id, status: status);
      await refresh();
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

  Color _statusItemColor(String status) {
    switch (status) {
      case "ok":
        return Colors.green;
      case "nao_conforme":
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _statusItemIcon(String status) {
    switch (status) {
      case "ok":
        return Icons.check_circle;
      case "nao_conforme":
        return Icons.cancel;
      default:
        return Icons.radio_button_unchecked;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ChecklistItem>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text("Erro: ${snapshot.error}"));
        }
        final itens = snapshot.data ?? [];
        if (itens.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.checklist, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text("Nenhum item no checklist",
                    style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: refresh,
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: itens.length,
            itemBuilder: (context, index) {
              final item = itens[index];
              return Card(
                child: ListTile(
                  leading: Icon(
                    _statusItemIcon(item.status),
                    color: _statusItemColor(item.status),
                  ),
                  title: Row(
                    children: [
                      Expanded(child: Text(item.titulo)),
                      if (item.critico)
                        Container(
                          margin: const EdgeInsets.only(left: 4),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            "Critico",
                            style:
                                TextStyle(color: Colors.red, fontSize: 11),
                          ),
                        ),
                    ],
                  ),
                  subtitle:
                      item.descricao != null ? Text(item.descricao!) : null,
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) => _atualizarStatus(item, value),
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: "pendente",
                        child: Row(children: [
                          Icon(Icons.radio_button_unchecked, size: 18),
                          SizedBox(width: 8),
                          Text("Pendente"),
                        ]),
                      ),
                      const PopupMenuItem(
                        value: "ok",
                        child: Row(children: [
                          Icon(Icons.check_circle,
                              size: 18, color: Colors.green),
                          SizedBox(width: 8),
                          Text("OK"),
                        ]),
                      ),
                      const PopupMenuItem(
                        value: "nao_conforme",
                        child: Row(children: [
                          Icon(Icons.cancel, size: 18, color: Colors.red),
                          SizedBox(width: 8),
                          Text("Nao conforme"),
                        ]),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
