import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../api/api.dart';
import '../providers/tab_refresh_notifier.dart';
import 'document_analysis_screen.dart';
import '../utils/auth_error_handler.dart';
import '../widgets/ad_banner_widget.dart';

class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key, this.refreshNotifier});
  final TabRefreshNotifier? refreshNotifier;

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  final ApiClient _api = ApiClient();

  late Future<List<Obra>> _obrasFuture;
  Obra? _obraSelecionada;
  Future<List<ProjetoDoc>>? _projetosFuture;
  bool _enviando = false;

  @override
  void initState() {
    super.initState();
    _obrasFuture = _api.listarObras();
    widget.refreshNotifier?.addListener(_onRefreshRequested);
  }

  @override
  void dispose() {
    widget.refreshNotifier?.removeListener(_onRefreshRequested);
    super.dispose();
  }

  void _onRefreshRequested() {
    setState(() {
      _obraSelecionada = null;
      _projetosFuture = null;
      _obrasFuture = _api.listarObras();
    });
  }

  void _selecionarObra(Obra obra) {
    setState(() {
      _obraSelecionada = obra;
      _projetosFuture = _api.listarProjetos(obra.id);
    });
  }

  Future<void> _recarregar() async {
    if (_obraSelecionada == null) return;
    setState(() {
      _projetosFuture = _api.listarProjetos(_obraSelecionada!.id);
    });
  }

  Future<void> _uploadProjeto() async {
    if (_obraSelecionada == null) return;

    try {
      await FilePicker.platform.clearTemporaryFiles();
    } catch (_) {}

    FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: true,
        withData: true,
      );
    } on Exception catch (e) {
      debugPrint('[Upload] pickFiles falhou: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao selecionar arquivo: $e')),
        );
      }
      return;
    }
    if (result == null || result.files.isEmpty) return;
    // Filter PDF only and read bytes from path
    final files = <PlatformFile>[];
    for (final f in result.files) {
      if (!f.name.toLowerCase().endsWith('.pdf')) continue;
      if (f.bytes != null && f.bytes!.isNotEmpty) {
        files.add(f);
      } else if (f.path != null) {
        try {
          final bytes = await File(f.path!).readAsBytes();
          files.add(PlatformFile(
            name: f.name,
            size: bytes.length,
            bytes: bytes,
          ));
        } catch (e) {
          debugPrint('[Upload] falha ao ler ${f.name}: $e');
        }
      }
    }
    if (files.isEmpty) return;

    setState(() => _enviando = true);
    try {
      for (final file in files) {
        await _api.uploadProjeto(obraId: _obraSelecionada!.id, file: file);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${files.length} arquivo(s) enviado(s)!')),
        );
        _recarregar();
      }
    } catch (e) {
      if (e is AuthExpiredException) { if (mounted) handleApiError(context, e); return; }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao enviar: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  Future<void> _deletarProjeto(ProjetoDoc projeto) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remover documento'),
        content: Text('Deseja remover "${projeto.arquivoNome}"?\n\nEssa ação não pode ser desfeita.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remover', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await _api.deletarProjeto(projeto.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Documento removido.')),
        );
        _recarregar();
      }
    } catch (e) {
      if (e is AuthExpiredException) { if (mounted) handleApiError(context, e); return; }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao remover: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _analisarPendentes() async {
    if (_obraSelecionada == null) return;
    setState(() => _enviando = true);
    try {
      final projetos = await _api.listarProjetos(_obraSelecionada!.id);
      final pendentes = projetos.where((p) => p.status == "pendente").toList();
      if (pendentes.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Nenhum documento pendente para analisar.')),
          );
        }
        return;
      }
      for (final p in pendentes) {
        await _api.dispararAnalise(p.id);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${pendentes.length} documento(s) analisado(s)!')),
        );
        _recarregar();
      }
    } catch (e) {
      if (e is AuthExpiredException) { if (mounted) handleApiError(context, e); return; }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao analisar: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Projetos'),
        centerTitle: false,
        actions: [
          if (_obraSelecionada != null)
            IconButton(
              onPressed: _enviando ? null : _analisarPendentes,
              icon: const Icon(Icons.auto_awesome),
              tooltip: 'Analisar pendentes',
            ),
        ],
      ),
      floatingActionButton: _obraSelecionada != null
          ? FloatingActionButton.extended(
              heroTag: "fab_documents",
              onPressed: _enviando ? null : _uploadProjeto,
              icon: _enviando
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.upload_file_outlined),
              label: Text(_enviando ? 'Enviando...' : 'Enviar PDF'),
            )
          : null,
      body: FutureBuilder<List<Obra>>(
        future: _obrasFuture,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 8),
                  Text('${snap.error}'),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () =>
                        setState(() => _obrasFuture = _api.listarObras()),
                    child: const Text('Tentar novamente'),
                  ),
                ],
              ),
            );
          }
          final obras = snap.data ?? [];
          if (obras.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.folder_open_outlined,
                      size: 56, color: Colors.grey),
                  SizedBox(height: 8),
                  Text('Nenhuma obra cadastrada.',
                      style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }
          if (_obraSelecionada == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _selecionarObra(obras.first);
            });
          }
          return Column(
            children: [
              _ObraSelector(
                obras: obras,
                selecionada: _obraSelecionada,
                onSelect: _selecionarObra,
              ),
              const AdBannerWidget(),
              Expanded(
                child: _ProjetosView(
                  future: _projetosFuture,
                  onRefresh: _recarregar,
                  onDelete: _deletarProjeto,
                  onTap: (p) => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DocumentAnalysisScreen(
                        projeto: p,
                        obra: _obraSelecionada,
                      ),
                    ),
                  ).then((_) => _recarregar()),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─── Seletor de Obra ─────────────────────────────────────────────────────────

class _ObraSelector extends StatelessWidget {
  const _ObraSelector({
    required this.obras,
    required this.selecionada,
    required this.onSelect,
  });

  final List<Obra> obras;
  final Obra? selecionada;
  final void Function(Obra) onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: obras.map((obra) {
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(obra.nome, overflow: TextOverflow.ellipsis),
              selected: selecionada?.id == obra.id,
              onSelected: (_) => onSelect(obra),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─── Lista de Projetos ────────────────────────────────────────────────────────

class _ProjetosView extends StatelessWidget {
  const _ProjetosView({
    required this.future,
    required this.onRefresh,
    required this.onTap,
    required this.onDelete,
  });

  final Future<List<ProjetoDoc>>? future;
  final Future<void> Function() onRefresh;
  final void Function(ProjetoDoc) onTap;
  final void Function(ProjetoDoc) onDelete;

  @override
  Widget build(BuildContext context) {
    if (future == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return FutureBuilder<List<ProjetoDoc>>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(
            child: Text('Erro: ${snap.error}',
                style: const TextStyle(color: Colors.red)),
          );
        }
        final projetos = snap.data ?? [];
        if (projetos.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.picture_as_pdf_outlined,
                    size: 56, color: Colors.grey[400]),
                const SizedBox(height: 12),
                const Text(
                  'Nenhum projeto enviado.',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Envie um PDF para análise de riscos por IA.',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: onRefresh,
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            itemCount: projetos.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (_, i) =>
                _ProjetoTile(projeto: projetos[i], onTap: onTap, onDelete: onDelete),
          ),
        );
      },
    );
  }
}

// ─── Tile de Projeto ──────────────────────────────────────────────────────────

class _ProjetoTile extends StatelessWidget {
  const _ProjetoTile({required this.projeto, required this.onTap, required this.onDelete});

  final ProjetoDoc projeto;
  final void Function(ProjetoDoc) onTap;
  final void Function(ProjetoDoc) onDelete;

  (String, Color, IconData) get _statusStyle => switch (projeto.status) {
        'concluido' =>
          ('Análise pronta', Colors.green, Icons.check_circle_outline),
        'processando' =>
          ('Analisando...', Colors.blue, Icons.hourglass_top_outlined),
        'erro' => ('Erro na análise', Colors.red, Icons.error_outline),
        _ => ('Aguardando análise', Colors.orange, Icons.schedule_outlined),
      };

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return DateFormat('dd/MM/yyyy').format(dt);
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    final (statusLabel, statusColor, statusIcon) = _statusStyle;

    return Card(
      elevation: 0,
      clipBehavior: Clip.hardEdge,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.indigo.withValues(alpha: 0.10),
          child: const Icon(Icons.picture_as_pdf_outlined,
              color: Colors.indigo, size: 20),
        ),
        title: Text(
          projeto.arquivoNome,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          _formatDate(projeto.createdAt),
          style: const TextStyle(fontSize: 11),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(statusIcon, size: 14, color: statusColor),
            const SizedBox(width: 4),
            Text(
              statusLabel,
              style: TextStyle(
                fontSize: 11,
                color: statusColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            PopupMenuButton<String>(
              iconSize: 18,
              padding: EdgeInsets.zero,
              onSelected: (v) {
                if (v == 'delete') onDelete(projeto);
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'delete',
                  child: Row(children: [
                    Icon(Icons.delete_outline, size: 18, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Remover', style: TextStyle(color: Colors.red)),
                  ]),
                ),
              ],
            ),
          ],
        ),
        onTap: () => onTap(projeto),
      ),
    );
  }
}
