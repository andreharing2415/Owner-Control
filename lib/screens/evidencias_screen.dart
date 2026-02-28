import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import '../api/api.dart';
import '../utils/auth_error_handler.dart';

class EvidenciasScreen extends StatefulWidget {
  const EvidenciasScreen({super.key, required this.item});

  final ChecklistItem item;

  @override
  State<EvidenciasScreen> createState() => _EvidenciasScreenState();
}

class _EvidenciasScreenState extends State<EvidenciasScreen> {
  final ApiClient _api = ApiClient();
  late Future<List<Evidencia>> _evidenciasFuture;

  @override
  void initState() {
    super.initState();
    _evidenciasFuture = _api.listarEvidencias(widget.item.id);
  }

  Future<void> _refresh() async {
    setState(() {
      _evidenciasFuture = _api.listarEvidencias(widget.item.id);
    });
  }

  IconData _mimeIcon(String? mimeType) {
    if (mimeType == null) return Icons.attach_file;
    if (mimeType.startsWith("image/")) return Icons.image;
    if (mimeType == "application/pdf") return Icons.picture_as_pdf;
    return Icons.attach_file;
  }

  String _formatBytes(int? bytes) {
    if (bytes == null) return "";
    if (bytes < 1024) return "$bytes B";
    if (bytes < 1024 * 1024) return "${(bytes / 1024).toStringAsFixed(1)} KB";
    return "${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Evidências: ${widget.item.titulo}"),
        actions: [
          IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: FutureBuilder<List<Evidencia>>(
        future: _evidenciasFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Erro: ${snapshot.error}"));
          }
          final evidencias = snapshot.data ?? [];
          if (evidencias.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.photo_library_outlined,
                      size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text("Nenhuma evidência registrada",
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  const Text("Adicione evidências no checklist."),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: evidencias.length,
              itemBuilder: (context, index) {
                final ev = evidencias[index];
                return Card(
                  child: ListTile(
                    leading: Icon(_mimeIcon(ev.mimeType), size: 32),
                    title:
                        Text(ev.arquivoNome, overflow: TextOverflow.ellipsis),
                    subtitle: Text(_formatBytes(ev.tamanhoBytes)),
                    trailing: IconButton(
                      icon: const Icon(Icons.open_in_new),
                      tooltip: "Abrir arquivo",
                      onPressed: () async {
                        try {
                          final tempDir = await getTemporaryDirectory();
                          final file =
                              File("${tempDir.path}/${ev.arquivoNome}");
                          if (!file.existsSync()) {
                            final response =
                                await http.get(Uri.parse(ev.arquivoUrl));
                            await file.writeAsBytes(response.bodyBytes,
                                flush: true);
                          }
                          await OpenFilex.open(file.path);
                        } catch (e) {
                          if (e is AuthExpiredException) { if (context.mounted) handleApiError(context, e); return; }
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text("Erro ao abrir: $e")),
                            );
                          }
                        }
                      },
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
