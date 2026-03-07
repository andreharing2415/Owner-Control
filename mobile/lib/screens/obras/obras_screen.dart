import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "../../models/obra.dart";
import "../../providers/obra_provider.dart";
import "../../services/api_client.dart";

class ObrasScreen extends StatefulWidget {
  const ObrasScreen({super.key, this.modoSelecao = false});

  final bool modoSelecao;

  @override
  State<ObrasScreen> createState() => _ObrasScreenState();
}

class _ObrasScreenState extends State<ObrasScreen> {
  late Future<List<Obra>> _obrasFuture;

  ApiClient get _api => context.read<ObraAtualProvider>().api!;

  @override
  void initState() {
    super.initState();
    _obrasFuture = _api.listarObras();
  }

  Future<void> _refresh() async {
    setState(() {
      _obrasFuture = _api.listarObras();
    });
  }

  Future<void> _criarObra() async {
    final nomeController = TextEditingController();
    final localController = TextEditingController();
    final orcamentoController = TextEditingController();

    final created = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Nova Obra"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nomeController,
              decoration: const InputDecoration(labelText: "Nome da obra *"),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: localController,
              decoration: const InputDecoration(labelText: "Localização"),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: orcamentoController,
              decoration: const InputDecoration(labelText: "Orçamento (R\$)"),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancelar")),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Criar")),
        ],
      ),
    );

    if (created == true && nomeController.text.trim().isNotEmpty) {
      try {
        final orcamento = double.tryParse(
            orcamentoController.text.replaceAll(",", "."));
        await _api.criarObra(
          nome: nomeController.text.trim(),
          localizacao: localController.text.trim(),
          orcamento: orcamento,
        );
        await _refresh();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text("Obra criada com etapas e checklists padrão.")),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Erro ao criar obra: $e")),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Mestre da Obra"),
        actions: [
          IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _criarObra,
        icon: const Icon(Icons.add),
        label: const Text("Nova Obra"),
      ),
      body: FutureBuilder<List<Obra>>(
        future: _obrasFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 48, color: Colors.red),
                    const SizedBox(height: 12),
                    Text("Erro: ${snapshot.error}",
                        textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    ElevatedButton(
                        onPressed: _refresh,
                        child: const Text("Tentar novamente")),
                  ],
                ),
              ),
            );
          }
          final obras = snapshot.data ?? [];
          if (obras.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.home_work_outlined,
                      size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text("Nenhuma obra cadastrada",
                      style: Theme.of(context).textTheme.titleMedium),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: obras.length,
              itemBuilder: (context, index) {
                final obra = obras[index];
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(context)
                          .colorScheme
                          .primaryContainer,
                      child: Icon(Icons.home_work,
                          color: Theme.of(context).colorScheme.primary),
                    ),
                    title: Text(obra.nome),
                    subtitle: obra.localizacao != null
                        ? Text(obra.localizacao!)
                        : null,
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      if (widget.modoSelecao) {
                        Navigator.pop(context, obra);
                      } else {
                        context
                            .read<ObraAtualProvider>()
                            .selecionarObra(obra);
                        Navigator.pop(context);
                      }
                    },
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
