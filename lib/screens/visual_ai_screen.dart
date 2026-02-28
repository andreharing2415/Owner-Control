import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../api/api.dart';
import 'achados_screen.dart';
import '../utils/auth_error_handler.dart';

class VisualAIScreen extends StatefulWidget {
  const VisualAIScreen({super.key, required this.etapa});

  final Etapa etapa;

  @override
  State<VisualAIScreen> createState() => _VisualAIScreenState();
}

class _VisualAIScreenState extends State<VisualAIScreen> {
  final ApiClient _api = ApiClient();
  final ImagePicker _picker = ImagePicker();

  Future<List<AnaliseVisual>>? _analisesFuture;
  bool _analisando = false;

  @override
  void initState() {
    super.initState();
    _carregarAnalises();
  }

  void _carregarAnalises() {
    setState(() {
      _analisesFuture = _api.listarAnalisesVisuais(widget.etapa.id);
    });
  }

  Future<void> _capturarEAnalisar(ImageSource source) async {
    final image = await _picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1920,
    );
    if (image == null) return;

    setState(() => _analisando = true);
    try {
      final resultado = await _api.analisarImagemEtapa(
        etapaId: widget.etapa.id,
        image: image,
      );
      if (!mounted) return;
      _carregarAnalises();
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AchadosScreen(resultado: resultado),
        ),
      );
    } catch (e) {
      if (e is AuthExpiredException) { if (mounted) handleApiError(context, e); return; }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro na análise: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _analisando = false);
    }
  }

  Future<void> _mostrarOpcoesFoto() async {
    await showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Tirar foto'),
              onTap: () {
                Navigator.pop(ctx);
                _capturarEAnalisar(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Escolher da galeria'),
              onTap: () {
                Navigator.pop(ctx);
                _capturarEAnalisar(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Visual AI — ${widget.etapa.nome}'),
        centerTitle: false,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _analisando ? null : _mostrarOpcoesFoto,
        icon: _analisando
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.camera_alt_outlined),
        label: Text(_analisando ? 'Analisando...' : 'Analisar foto'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InfoBanner(etapaNome: widget.etapa.nome),
          Expanded(child: _AnalisesView(future: _analisesFuture, api: _api)),
        ],
      ),
    );
  }
}

// ─── Banner informativo ───────────────────────────────────────────────────────

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.etapaNome});

  final String etapaNome;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.indigo.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.indigo.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 18, color: Colors.indigo),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Tire ou selecione uma foto da etapa "$etapaNome" '
              'e a IA identificará achados e riscos visíveis.',
              style: const TextStyle(fontSize: 12, color: Colors.indigo),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Lista de análises ────────────────────────────────────────────────────────

class _AnalisesView extends StatelessWidget {
  const _AnalisesView({required this.future, required this.api});

  final Future<List<AnaliseVisual>>? future;
  final ApiClient api;

  @override
  Widget build(BuildContext context) {
    if (future == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return FutureBuilder<List<AnaliseVisual>>(
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
        final analises = snap.data ?? [];
        if (analises.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.camera_enhance_outlined,
                    size: 64, color: Colors.grey[300]),
                const SizedBox(height: 12),
                const Text('Nenhuma análise realizada.',
                    style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 6),
                const Text(
                  'Tire uma foto da obra para a IA identificar achados.',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          itemCount: analises.length,
          separatorBuilder: (context, i) => const SizedBox(height: 8),
          itemBuilder: (_, i) => _AnaliseTile(
            analise: analises[i],
            api: api,
          ),
        );
      },
    );
  }
}

// ─── Tile de análise ──────────────────────────────────────────────────────────

class _AnaliseTile extends StatelessWidget {
  const _AnaliseTile({required this.analise, required this.api});

  final AnaliseVisual analise;
  final ApiClient api;

  (String, Color, IconData) get _statusStyle => switch (analise.status) {
        'concluida' => ('Concluída', Colors.green, Icons.check_circle_outline),
        'erro' => ('Erro', Colors.red, Icons.error_outline),
        _ => ('Processando...', Colors.blue, Icons.hourglass_top_outlined),
      };

  String _formatDate(String iso) {
    try {
      return DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(iso));
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
          child:
              const Icon(Icons.camera_enhance_outlined, color: Colors.indigo, size: 20),
        ),
        title: Text(
          analise.imagemNome,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_formatDate(analise.createdAt),
                style: const TextStyle(fontSize: 11)),
            if (analise.etapaInferida != null)
              Text(
                'Etapa: ${analise.etapaInferida} (${analise.confianca}%)',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
          ],
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
            const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
          ],
        ),
        onTap: analise.status != 'concluida'
            ? null
            : () async {
                try {
                  final resultado = await api.obterAnaliseVisual(analise.id);
                  if (context.mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AchadosScreen(resultado: resultado),
                      ),
                    );
                  }
                } catch (e) {
                  if (e is AuthExpiredException) { if (context.mounted) handleApiError(context, e); return; }
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Erro: $e')),
                    );
                  }
                }
              },
      ),
    );
  }
}
