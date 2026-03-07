import "package:file_picker/file_picker.dart";
import "package:flutter/material.dart";
import "package:image_picker/image_picker.dart";

import "../../models/checklist_item.dart";
import "../../models/etapa.dart";
import "../../services/api_client.dart";
import "evidencias_screen.dart";

class ChecklistScreen extends StatefulWidget {
  const ChecklistScreen({super.key, required this.etapa, required this.api});

  final Etapa etapa;
  final ApiClient api;

  @override
  State<ChecklistScreen> createState() => _ChecklistScreenState();
}

class _ChecklistScreenState extends State<ChecklistScreen> {
  final ImagePicker _imagePicker = ImagePicker();
  late Future<List<ChecklistItem>> _itensFuture;

  @override
  void initState() {
    super.initState();
    _itensFuture = widget.api.listarItens(widget.etapa.id);
  }

  Future<void> _refresh() async {
    setState(() {
      _itensFuture = widget.api.listarItens(widget.etapa.id);
    });
  }

  Future<void> _criarItem() async {
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
              decoration: const InputDecoration(labelText: "Título *"),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: descricaoController,
              decoration: const InputDecoration(labelText: "Descrição"),
              textCapitalization: TextCapitalization.sentences,
            ),
            StatefulBuilder(
              builder: (context, setLocalState) => SwitchListTile(
                title: const Text("Item crítico"),
                subtitle: const Text("Exige evidência obrigatória"),
                value: critico,
                onChanged: (value) =>
                    setLocalState(() => critico = value),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancelar")),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Salvar")),
        ],
      ),
    );

    if (created == true && tituloController.text.trim().isNotEmpty) {
      try {
        await widget.api.criarItem(
          etapaId: widget.etapa.id,
          titulo: tituloController.text.trim(),
          descricao: descricaoController.text.trim(),
          critico: critico,
        );
        await _refresh();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text("Erro: $e")));
        }
      }
    }
  }

  Future<void> _atualizarStatus(ChecklistItem item, String status) async {
    try {
      await widget.api.atualizarItem(itemId: item.id, status: status);
      await _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Erro: $e")));
      }
    }
  }

  Future<void> _uploadEvidencia(ChecklistItem item) async {
    final opcao = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text("Adicionar evidência"),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, "camera"),
            child: const Row(children: [
              Icon(Icons.camera_alt),
              SizedBox(width: 12),
              Text("Tirar foto"),
            ]),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, "galeria"),
            child: const Row(children: [
              Icon(Icons.photo_library),
              SizedBox(width: 12),
              Text("Escolher da galeria"),
            ]),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, "arquivo"),
            child: const Row(children: [
              Icon(Icons.attach_file),
              SizedBox(width: 12),
              Text("Selecionar arquivo"),
            ]),
          ),
        ],
      ),
    );

    if (opcao == null) return;

    try {
      if (opcao == "camera") {
        final image = await _imagePicker.pickImage(
            source: ImageSource.camera, imageQuality: 85);
        if (image == null) return;
        await widget.api
            .uploadEvidenciaImagem(itemId: item.id, image: image);
      } else if (opcao == "galeria") {
        final image = await _imagePicker.pickImage(
            source: ImageSource.gallery, imageQuality: 85);
        if (image == null) return;
        await widget.api
            .uploadEvidenciaImagem(itemId: item.id, image: image);
      } else {
        final result =
            await FilePicker.platform.pickFiles(withReadStream: true);
        if (result == null || result.files.isEmpty) return;
        await widget.api
            .uploadEvidencia(itemId: item.id, file: result.files.first);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Evidência enviada com sucesso.")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro ao enviar evidência: $e")),
        );
      }
    }
  }

  Future<void> _calcularScore() async {
    try {
      final score = await widget.api.calcularScore(widget.etapa.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text("Score da etapa: ${score.toStringAsFixed(1)}%")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Erro: $e")));
      }
    }
  }

  Future<bool> _confirmarRemocao(ChecklistItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Remover item"),
        content: Text("Deseja remover \"${item.titulo}\"?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancelar"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Remover", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    return confirm == true;
  }

  Future<void> _deletarItem(ChecklistItem item) async {
    try {
      await widget.api.deletarItem(item.id);
      await _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Erro ao remover: $e")));
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
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.etapa.nome),
        actions: [
          IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh)),
          IconButton(
            onPressed: _calcularScore,
            icon: const Icon(Icons.assessment),
            tooltip: "Calcular score",
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _criarItem,
        child: const Icon(Icons.add),
      ),
      body: FutureBuilder<List<ChecklistItem>>(
        future: _itensFuture,
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
            onRefresh: _refresh,
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: itens.length,
              itemBuilder: (context, index) {
                final item = itens[index];
                return Dismissible(
                  key: Key(item.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    margin: const EdgeInsets.only(bottom: 4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  confirmDismiss: (_) => _confirmarRemocao(item),
                  onDismissed: (_) => _deletarItem(item),
                  child: Card(
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
                              "Crítico",
                              style: TextStyle(
                                  color: Colors.red, fontSize: 11),
                            ),
                          ),
                      ],
                    ),
                    subtitle:
                        item.descricao != null ? Text(item.descricao!) : null,
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) {
                        switch (value) {
                          case "pendente":
                          case "ok":
                          case "nao_conforme":
                            _atualizarStatus(item, value);
                          case "evidencia":
                            _uploadEvidencia(item);
                          case "ver_evidencias":
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => EvidenciasScreen(
                                      item: item, api: widget.api)),
                            );
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: "pendente",
                          child: Row(children: [
                            Icon(Icons.radio_button_unchecked, size: 18),
                            SizedBox(width: 8),
                            Text("Pendente")
                          ]),
                        ),
                        const PopupMenuItem(
                          value: "ok",
                          child: Row(children: [
                            Icon(Icons.check_circle,
                                size: 18, color: Colors.green),
                            SizedBox(width: 8),
                            Text("OK")
                          ]),
                        ),
                        const PopupMenuItem(
                          value: "nao_conforme",
                          child: Row(children: [
                            Icon(Icons.cancel,
                                size: 18, color: Colors.red),
                            SizedBox(width: 8),
                            Text("Não conforme")
                          ]),
                        ),
                        const PopupMenuDivider(),
                        const PopupMenuItem(
                          value: "evidencia",
                          child: Row(children: [
                            Icon(Icons.add_a_photo, size: 18),
                            SizedBox(width: 8),
                            Text("Adicionar evidência")
                          ]),
                        ),
                        const PopupMenuItem(
                          value: "ver_evidencias",
                          child: Row(children: [
                            Icon(Icons.photo_library, size: 18),
                            SizedBox(width: 8),
                            Text("Ver evidências")
                          ]),
                        ),
                      ],
                    ),
                  ),
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
