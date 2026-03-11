import "dart:async";

import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "../../models/documento.dart";
import "../../providers/auth_provider.dart";
import "../../providers/subscription_provider.dart";
import "../../services/api_client.dart";
import "pdf_viewer_screen.dart";
import "riscos_review_screen.dart";
import "../checklist_inteligente/checklist_inteligente_screen.dart";

import "dart:io";
import "package:file_picker/file_picker.dart";

class DocumentosScreen extends StatefulWidget {
  const DocumentosScreen({
    super.key,
    required this.obraId,
    required this.api,
  });

  final String obraId;
  final ApiClient api;

  @override
  State<DocumentosScreen> createState() => _DocumentosScreenState();
}

class _DocumentosScreenState extends State<DocumentosScreen> {
  late Future<List<ProjetoDoc>> _projetosFuture;
  bool _uploading = false;
  int _riscosPendentes = 0;

  @override
  void initState() {
    super.initState();
    _projetosFuture = widget.api.listarProjetos(widget.obraId);
    _checkRiscosPendentes();
  }

  Future<void> _checkRiscosPendentes() async {
    try {
      final result = await widget.api.listarRiscosPendentes(widget.obraId);
      if (mounted) {
        setState(() => _riscosPendentes = result["total"] as int);
      }
    } catch (_) {}
  }

  Future<void> _refresh() async {
    setState(() {
      _projetosFuture = widget.api.listarProjetos(widget.obraId);
    });
    _checkRiscosPendentes();
  }

  Future<void> _uploadPdf() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      if (result == null || result.files.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Nenhum arquivo selecionado.")),
          );
        }
        return;
      }
      setState(() => _uploading = true);
      final file = result.files.first;
      final bytes = file.bytes ?? await File(file.path!).readAsBytes();
      await widget.api.uploadProjeto(
        obraId: widget.obraId,
        bytes: bytes,
        fileName: file.name,
      );
      await _refresh();
      if (mounted) _perguntarChecklistInteligente();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro ao enviar projeto: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _perguntarChecklistInteligente() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.auto_awesome, color: Colors.blue),
        title: const Text("Atualizar Checklist?"),
        content: const Text(
          "Deseja gerar ou atualizar o checklist inteligente com base nos "
          "documentos do projeto? A IA analisará os PDFs e sugerirá itens "
          "de verificação com normas técnicas aplicáveis.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Depois"),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChecklistInteligenteScreen(
                    obraId: widget.obraId,
                    api: widget.api,
                    autoStart: true,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.auto_awesome),
            label: const Text("Gerar Checklist"),
          ),
        ],
      ),
    );
  }

  Future<void> _analisarProjeto(ProjetoDoc projeto) async {
    try {
      await widget.api.analisarProjeto(projeto.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Análise iniciada. Aguarde o processamento.")),
        );
      }
      await _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro ao iniciar análise: $e")),
        );
      }
    }
  }

  Future<void> _deletarProjeto(ProjetoDoc projeto) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Remover documento"),
        content: Text("Deseja remover \"${projeto.arquivoNome}\"?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancelar"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("Remover"),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await widget.api.deletarProjeto(projeto.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Documento removido.")),
        );
      }
      await _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro ao remover: $e")),
        );
      }
    }
  }

  void _onTapProjeto(ProjetoDoc projeto) {
    switch (projeto.status) {
      case "concluido":
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Análise concluída. Verifique o checklist.")),
        );
      case "pendente":
        _analisarProjeto(projeto);
      case "processando":
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Análise em andamento. Aguarde a conclusão.")),
        );
      case "erro":
        _analisarProjeto(projeto);  // Retry analysis on error
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case "concluido":
        return Colors.green;
      case "processando":
        return Colors.blue;
      case "erro":
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case "concluido":
        return "Concluído";
      case "processando":
        return "Processando";
      case "erro":
        return "Erro";
      default:
        return "Pendente";
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case "concluido":
        return Icons.check_circle;
      case "processando":
        return Icons.hourglass_top;
      case "erro":
        return Icons.error;
      default:
        return Icons.schedule;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Documentos"),
        actions: [
          IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh)),
          IconButton(
            icon: const Icon(Icons.auto_awesome),
            tooltip: "Checklist IA",
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChecklistInteligenteScreen(
                    obraId: widget.obraId, api: widget.api),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: Builder(
        builder: (context) {
          final user = context.read<AuthProvider>().user;
          if (user != null && user.isConvidado) return const SizedBox.shrink();
          return FloatingActionButton.extended(
            onPressed: _uploading ? null : _uploadPdf,
            icon: _uploading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.upload_file),
            label: Text(_uploading ? "Enviando..." : "Upload PDF"),
          );
        },
      ),
      body: FutureBuilder<List<ProjetoDoc>>(
        future: _projetosFuture,
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
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 12),
                    Text("Erro: ${snapshot.error}", textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _refresh,
                      child: const Text("Tentar novamente"),
                    ),
                  ],
                ),
              ),
            );
          }
          final projetos = snapshot.data ?? [];
          if (projetos.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.description, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    "Nenhum documento enviado",
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Envie um PDF de projeto para análise",
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: projetos.length + (_riscosPendentes > 0 ? 1 : 0),
              itemBuilder: (context, index) {
                if (_riscosPendentes > 0 && index == 0) {
                  return Card(
                    color: Colors.orange.shade50,
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: const Icon(Icons.warning_amber, color: Colors.orange),
                      title: Text("$_riscosPendentes riscos identificados"),
                      subtitle: const Text("Adicionar ao checklist das etapas?"),
                      trailing: FilledButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => RiscosReviewScreen(
                              api: widget.api,
                              obraId: widget.obraId,
                            ),
                          ),
                        ).then((_) => _refresh()),
                        child: const Text("Revisar"),
                      ),
                    ),
                  );
                }
                final projetoIndex = _riscosPendentes > 0 ? index - 1 : index;
                final projeto = projetos[projetoIndex];
                final statusColor = _statusColor(projeto.status);
                return Card(
                  child: ListTile(
                    leading: Icon(Icons.picture_as_pdf,
                        color: Colors.red[400], size: 36),
                    title: Text(
                      projeto.arquivoNome,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Row(
                      children: [
                        Icon(_statusIcon(projeto.status),
                            size: 14, color: statusColor),
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _statusLabel(projeto.status),
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PdfViewerScreen(
                                projetoId: projeto.id,
                                fileName: projeto.arquivoNome,
                                api: widget.api,
                              ),
                            ),
                          ),
                          child: const Padding(
                            padding: EdgeInsets.all(8),
                            child: Icon(Icons.visibility, size: 22),
                          ),
                        ),
                        if (context.read<SubscriptionProvider>().canDeleteDoc)
                          GestureDetector(
                            onTap: () => _deletarProjeto(projeto),
                            child: const Padding(
                              padding: EdgeInsets.all(8),
                              child: Icon(Icons.delete_outline, color: Colors.red, size: 22),
                            ),
                          ),
                        if (projeto.status == "concluido")
                          const Icon(Icons.chevron_right),
                      ],
                    ),
                    onTap: () => _onTapProjeto(projeto),
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
