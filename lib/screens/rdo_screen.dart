import "package:flutter/material.dart";
import "package:image_picker/image_picker.dart";

import "../api/api.dart";
import "../utils/auth_error_handler.dart";

class RdoScreen extends StatefulWidget {
  const RdoScreen({super.key, required this.obra});

  final Obra obra;

  @override
  State<RdoScreen> createState() => _RdoScreenState();
}

class _RdoScreenState extends State<RdoScreen> {
  final ApiClient _api = ApiClient();
  final ImagePicker _imagePicker = ImagePicker();

  late Future<List<RdoDiario>> _rdosFuture;

  @override
  void initState() {
    super.initState();
    _rdosFuture = _api.listarRdos(widget.obra.id);
  }

  Future<void> _refresh() async {
    setState(() {
      _rdosFuture = _api.listarRdos(widget.obra.id);
    });
  }

  Future<void> _criarRdo() async {
    final dataController = TextEditingController(
      text: DateTime.now().toIso8601String().split("T").first,
    );
    final maoObraController = TextEditingController(text: "0");
    final atividadesController = TextEditingController();
    final observacoesController = TextEditingController();

    String clima = "Ensolarado";
    final fotosSelecionadas = <XFile>[];

    final salvar = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) => AlertDialog(
            title: const Text("Novo RDO"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: dataController,
                    decoration: const InputDecoration(
                      labelText: "Data (YYYY-MM-DD)",
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: clima,
                    decoration: const InputDecoration(labelText: "Clima"),
                    items: const [
                      DropdownMenuItem(value: "Ensolarado", child: Text("Ensolarado")),
                      DropdownMenuItem(value: "Nublado", child: Text("Nublado")),
                      DropdownMenuItem(value: "Chuvoso", child: Text("Chuvoso")),
                      DropdownMenuItem(value: "Parcialmente nublado", child: Text("Parcialmente nublado")),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setLocalState(() => clima = value);
                    },
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: maoObraController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: "Mao de obra (total)"),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: atividadesController,
                    minLines: 3,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: "Atividades realizadas",
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: observacoesController,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: "Observacoes",
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: () async {
                          final foto = await _imagePicker.pickImage(
                            source: ImageSource.camera,
                            imageQuality: 80,
                          );
                          if (foto != null) {
                            setLocalState(() => fotosSelecionadas.add(foto));
                          }
                        },
                        icon: const Icon(Icons.camera_alt_outlined),
                        label: const Text("Tirar foto"),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final foto = await _imagePicker.pickImage(
                            source: ImageSource.gallery,
                            imageQuality: 80,
                          );
                          if (foto != null) {
                            setLocalState(() => fotosSelecionadas.add(foto));
                          }
                        },
                        icon: const Icon(Icons.photo_library_outlined),
                        label: const Text("Galeria"),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "${fotosSelecionadas.length} foto(s) selecionada(s)",
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
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
      },
    );

    if (salvar != true) return;

    try {
      final maoObraTotal = int.tryParse(maoObraController.text.trim()) ?? 0;
      final rdo = await _api.criarRdo(
        obraId: widget.obra.id,
        dataReferencia: dataController.text.trim(),
        clima: clima,
        maoObraTotal: maoObraTotal,
        atividadesExecutadas: atividadesController.text.trim(),
        observacoes: observacoesController.text.trim().isEmpty
            ? null
            : observacoesController.text.trim(),
        fotosUrls: fotosSelecionadas.map((f) => f.path).toList(),
      );

      if (!mounted) return;

      final publicar = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Publicar RDO"),
          content: const Text("Deseja publicar este RDO agora e notificar o dono da obra?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Depois"),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Publicar"),
            ),
          ],
        ),
      );

      if (publicar == true) {
        await _api.publicarRdo(rdo.id);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(publicar == true
              ? "RDO publicado com sucesso."
              : "RDO salvo como rascunho."),
        ),
      );
      await _refresh();
    } catch (e) {
      if (e is AuthExpiredException) {
        if (mounted) handleApiError(context, e);
        return;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erro ao salvar RDO: $e")),
      );
    }
  }

  Future<void> _publicarRdo(RdoDiario rdo) async {
    try {
      await _api.publicarRdo(rdo.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("RDO publicado.")),
      );
      await _refresh();
    } catch (e) {
      if (e is AuthExpiredException) {
        if (mounted) handleApiError(context, e);
        return;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erro ao publicar RDO: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("RDO Diario"),
        actions: [
          IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _criarRdo,
        icon: const Icon(Icons.add),
        label: const Text("Novo RDO"),
      ),
      body: FutureBuilder<List<RdoDiario>>(
        future: _rdosFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Erro: ${snapshot.error}"));
          }

          final rdos = snapshot.data ?? [];
          if (rdos.isEmpty) {
            return const Center(
              child: Text("Nenhum RDO registrado para esta obra."),
            );
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: rdos.length,
              itemBuilder: (context, index) {
                final rdo = rdos[index];
                return Card(
                  child: ListTile(
                    leading: Icon(
                      rdo.publicado ? Icons.campaign : Icons.edit_note,
                      color: rdo.publicado ? Colors.green : Colors.orange,
                    ),
                    title: Text("${rdo.dataReferencia} • ${rdo.clima}"),
                    subtitle: Text(
                      "Mao de obra: ${rdo.maoObraTotal} • Fotos: ${rdo.fotosUrls.length}\n${rdo.atividadesExecutadas}",
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: rdo.publicado
                        ? const Chip(label: Text("Publicado"))
                        : TextButton(
                            onPressed: () => _publicarRdo(rdo),
                            child: const Text("Publicar"),
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
