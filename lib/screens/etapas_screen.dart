import 'dart:io';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import '../api/api.dart';
import 'checklist_inteligente_screen.dart';
import 'checklist_screen.dart';
import 'normas_screen.dart';
import 'visual_ai_screen.dart';
import '../utils/auth_error_handler.dart';

const _statusEtapaLabels = {
  "pendente": "Pendente",
  "em_andamento": "Em andamento",
  "concluida": "Concluída",
};

class EtapasScreen extends StatefulWidget {
  const EtapasScreen({super.key, required this.obra});

  final Obra obra;

  @override
  State<EtapasScreen> createState() => _EtapasScreenState();
}

class _EtapasScreenState extends State<EtapasScreen> {
  final ApiClient _api = ApiClient();
  late Future<List<Etapa>> _etapasFuture;
  bool _exportando = false;

  @override
  void initState() {
    super.initState();
    _etapasFuture = _api.listarEtapas(widget.obra.id);
  }

  Future<void> _refresh() async {
    setState(() {
      _etapasFuture = _api.listarEtapas(widget.obra.id);
    });
  }

  Future<void> _exportarPdf() async {
    setState(() => _exportando = true);
    try {
      final bytes = await _api.exportarPdf(widget.obra.id);
      final tempDir = await getTemporaryDirectory();
      final file = File("${tempDir.path}/obra-${widget.obra.id}.pdf");
      await file.writeAsBytes(bytes, flush: true);
      await OpenFilex.open(file.path);
    } catch (e) {
      if (e is AuthExpiredException) { if (mounted) handleApiError(context, e); return; }
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Erro ao exportar: $e")));
      }
    } finally {
      if (mounted) setState(() => _exportando = false);
    }
  }

  Future<void> _atualizarStatus(Etapa etapa) async {
    final statusOptions = _statusEtapaLabels.entries.toList();
    final novoStatus = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text("Status: ${etapa.nome}"),
        children: statusOptions.map((entry) {
          return SimpleDialogOption(
            onPressed: () => Navigator.pop(context, entry.key),
            child: Text(entry.value),
          );
        }).toList(),
      ),
    );
    if (novoStatus != null && novoStatus != etapa.status) {
      try {
        await _api.atualizarStatusEtapa(
            etapaId: etapa.id, status: novoStatus);
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

  Color _statusColor(String status) {
    switch (status) {
      case "concluida":
        return Colors.green;
      case "em_andamento":
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.obra.nome),
        actions: [
          IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh)),
          IconButton(
            icon: const Icon(Icons.auto_awesome),
            tooltip: "Checklist Inteligente",
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    ChecklistInteligenteScreen(obra: widget.obra),
              ),
            ).then((result) {
              if (result == true) _refresh();
            }),
          ),
          IconButton(
            icon: const Icon(Icons.menu_book_outlined),
            tooltip: "Biblioteca Normativa",
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NormasScreen()),
            ),
          ),
          _exportando
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                      width: 24,
                      height: 24,
                      child:
                          CircularProgressIndicator(strokeWidth: 2)),
                )
              : IconButton(
                  onPressed: _exportarPdf,
                  icon: const Icon(Icons.picture_as_pdf),
                  tooltip: "Exportar PDF"),
        ],
      ),
      body: FutureBuilder<List<Etapa>>(
        future: _etapasFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Erro: ${snapshot.error}"));
          }
          final etapas = snapshot.data ?? [];
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: etapas.length,
              itemBuilder: (context, index) {
                final etapa = etapas[index];
                final scoreStr = etapa.score != null
                    ? "${etapa.score!.toStringAsFixed(0)}%"
                    : "—";
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                          _statusColor(etapa.status).withValues(alpha: 0.15),
                      child: Text(
                        "${etapa.ordem}",
                        style: TextStyle(
                          color: _statusColor(etapa.status),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(etapa.nome,
                        style:
                            const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _statusColor(etapa.status)
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _statusEtapaLabels[etapa.status] ?? etapa.status,
                            style: TextStyle(
                                color: _statusColor(etapa.status),
                                fontSize: 12),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text("Score: $scoreStr",
                            style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                    trailing: PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert),
                      onSelected: (value) {
                        if (value == "checklist") {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    ChecklistScreen(etapa: etapa)),
                          ).then((_) => _refresh());
                        } else if (value == "status") {
                          _atualizarStatus(etapa);
                        } else if (value == "normas") {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  NormasScreen(etapaInicial: etapa.nome),
                            ),
                          );
                        } else if (value == "visual_ai") {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  VisualAIScreen(etapa: etapa),
                            ),
                          );
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                            value: "checklist",
                            child: Text("Ver checklist")),
                        const PopupMenuItem(
                            value: "status",
                            child: Text("Atualizar status")),
                        const PopupMenuItem(
                          value: "normas",
                          child: Row(
                            children: [
                              Icon(Icons.menu_book_outlined, size: 18),
                              SizedBox(width: 8),
                              Text("Normas aplicáveis"),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: "visual_ai",
                          child: Row(
                            children: [
                              Icon(Icons.camera_enhance_outlined, size: 18),
                              SizedBox(width: 8),
                              Text("Análise Visual (IA)"),
                            ],
                          ),
                        ),
                      ],
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                ChecklistScreen(etapa: etapa)),
                      ).then((_) => _refresh());
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
