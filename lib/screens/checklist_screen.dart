import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../api/api.dart';
import 'evidencias_screen.dart';
import '../utils/auth_error_handler.dart';

class ChecklistScreen extends StatefulWidget {
  const ChecklistScreen({super.key, required this.etapa});

  final Etapa etapa;

  @override
  State<ChecklistScreen> createState() => _ChecklistScreenState();
}

class _ChecklistScreenState extends State<ChecklistScreen> {
  final ApiClient _api = ApiClient();
  final ImagePicker _imagePicker = ImagePicker();
  late Future<List<ChecklistItem>> _itensFuture;

  @override
  void initState() {
    super.initState();
    _itensFuture = _api.listarItens(widget.etapa.id);
  }

  Future<void> _refresh() async {
    setState(() {
      _itensFuture = _api.listarItens(widget.etapa.id);
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
                onChanged: (value) => setLocalState(() => critico = value),
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
        await _api.criarItem(
          etapaId: widget.etapa.id,
          titulo: tituloController.text.trim(),
          descricao: descricaoController.text.trim(),
          critico: critico,
        );
        await _refresh();
      } catch (e) {
        if (e is AuthExpiredException) { if (mounted) handleApiError(context, e); return; }
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text("Erro: $e")));
        }
      }
    }
  }

  Future<void> _atualizarStatus(ChecklistItem item, String status) async {
    try {
      await _api.atualizarItem(itemId: item.id, status: status);
      await _refresh();
    } catch (e) {
      if (e is AuthExpiredException) { if (mounted) handleApiError(context, e); return; }
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
        await _api.uploadEvidenciaImagem(itemId: item.id, image: image);
      } else if (opcao == "galeria") {
        final image = await _imagePicker.pickImage(
            source: ImageSource.gallery, imageQuality: 85);
        if (image == null) return;
        await _api.uploadEvidenciaImagem(itemId: item.id, image: image);
      } else {
        final result =
            await FilePicker.platform.pickFiles(withData: true, withReadStream: true);
        if (result == null || result.files.isEmpty) return;
        await _api.uploadEvidencia(itemId: item.id, file: result.files.first);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Evidência enviada com sucesso.")),
        );
      }
    } catch (e) {
      if (e is AuthExpiredException) { if (mounted) handleApiError(context, e); return; }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro ao enviar evidência: $e")),
        );
      }
    }
  }

  Future<void> _verEvidencias(ChecklistItem item) async {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EvidenciasScreen(item: item)),
    );
  }

  Future<void> _calcularScore() async {
    try {
      final score = await _api.calcularScore(widget.etapa.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text("Score da etapa: ${score.toStringAsFixed(1)}%")),
        );
      }
    } catch (e) {
      if (e is AuthExpiredException) { if (mounted) handleApiError(context, e); return; }
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Erro: $e")));
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
                return Card(
                  child: ListTile(
                    leading: Icon(
                      _statusItemIcon(item.status),
                      color: _statusItemColor(item.status),
                    ),
                    title: Row(
                      children: [
                        Expanded(child: Text(item.titulo)),
                        if (item.origem == "ia")
                          Container(
                            margin: const EdgeInsets.only(left: 4),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.indigo.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              "IA",
                              style: TextStyle(
                                  color: Colors.indigo, fontSize: 11,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
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
                              style:
                                  TextStyle(color: Colors.red, fontSize: 11),
                            ),
                          ),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (item.descricao != null)
                          Text(item.descricao!),
                        if (item.normaReferencia != null &&
                            item.normaReferencia!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              item.normaReferencia!,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.blueGrey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                      ],
                    ),
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
                            _verEvidencias(item);
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
                            Icon(Icons.cancel, size: 18, color: Colors.red),
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
                );
              },
            ),
          );
        },
      ),
    );
  }
}
