import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../api/api.dart';
import '../utils/auth_error_handler.dart';
import '../utils/status_helper.dart';

class DetalheItemScreen extends StatefulWidget {
  const DetalheItemScreen({super.key, required this.item});
  final ChecklistItem item;

  @override
  State<DetalheItemScreen> createState() => _DetalheItemScreenState();
}

class _DetalheItemScreenState extends State<DetalheItemScreen> {
  late ChecklistItem _item;
  final _obsController = TextEditingController();
  final _api = ApiClient();
  bool _savingObs = false;
  bool _savingStatus = false;
  int _evidenciasVersion = 0;

  @override
  void initState() {
    super.initState();
    _item = widget.item;
    _obsController.text = _item.observacao ?? '';
  }

  @override
  void dispose() {
    _obsController.dispose();
    super.dispose();
  }

  Future<void> _atualizarStatus(String novoStatus) async {
    if (_item.status == novoStatus) return;
    setState(() => _savingStatus = true);
    try {
      final updated = await _api.atualizarItem(
        itemId: _item.id,
        status: novoStatus,
      );
      setState(() => _item = updated);
    } catch (e) {
      if (mounted) handleApiError(context, e);
    } finally {
      if (mounted) setState(() => _savingStatus = false);
    }
  }

  Future<void> _salvarObservacao() async {
    setState(() => _savingObs = true);
    try {
      final updated = await _api.atualizarItem(
        itemId: _item.id,
        observacao: _obsController.text.trim(),
      );
      setState(() => _item = updated);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Observação salva!')),
        );
      }
    } catch (e) {
      if (mounted) handleApiError(context, e);
    } finally {
      if (mounted) setState(() => _savingObs = false);
    }
  }

  Future<void> _adicionarEvidencia() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Câmera'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Galeria'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    final picker = ImagePicker();
    final image = await picker.pickImage(source: source, imageQuality: 80);
    if (image == null || !mounted) return;

    try {
      await _api.uploadEvidenciaImagem(itemId: _item.id, image: image);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Evidência enviada!')),
        );
        setState(() => _evidenciasVersion++);
      }
    } catch (e) {
      if (mounted) handleApiError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalhe do Item'),
        actions: [
          IconButton(
            icon: const Icon(Icons.camera_alt_outlined),
            tooltip: 'Adicionar evidência',
            onPressed: _adicionarEvidencia,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ─── Título e badges ──────────────────────────────────────
          Text(_item.titulo, style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              _badge(_statusLabel(_item.status), _statusColor(_item.status)),
              if (_item.critico)
                _badge('CRÍTICO', Colors.red),
              if (_item.origem == 'ia')
                _badge('IA', cs.tertiary),
              if (_item.group != null)
                _badge(_item.group!, cs.secondary),
            ],
          ),

          // ─── Descrição ────────────────────────────────────────────
          if (_item.descricao != null && _item.descricao!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Descrição', style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(_item.descricao!, style: theme.textTheme.bodyMedium),
          ],

          // ─── Como verificar (IA) ──────────────────────────────────
          if (_item.comoVerificar != null && _item.comoVerificar!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Card(
              color: cs.secondaryContainer.withValues(alpha: 0.3),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(Icons.lightbulb_outline, size: 18, color: cs.secondary),
                      const SizedBox(width: 6),
                      Text('Como verificar', style: theme.textTheme.titleSmall),
                    ]),
                    const SizedBox(height: 6),
                    Text(_item.comoVerificar!, style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),
            ),
          ],

          // ─── Explicação leigo ─────────────────────────────────────
          if (_item.explicacaoLeigo != null && _item.explicacaoLeigo!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Card(
              color: cs.primaryContainer.withValues(alpha: 0.3),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(Icons.translate, size: 18, color: cs.primary),
                      const SizedBox(width: 6),
                      Text('Em termos simples', style: theme.textTheme.titleSmall),
                    ]),
                    const SizedBox(height: 6),
                    Text(_item.explicacaoLeigo!, style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),
            ),
          ],

          // ─── Norma referência ─────────────────────────────────────
          if (_item.normaReferencia != null && _item.normaReferencia!.isNotEmpty) ...[
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.gavel),
              title: const Text('Norma de referência'),
              subtitle: Text(_item.normaReferencia!),
              contentPadding: EdgeInsets.zero,
            ),
          ],

          // ─── Confiança IA ─────────────────────────────────────────
          if (_item.confianca != null) ...[
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.auto_awesome, size: 16),
              const SizedBox(width: 6),
              Text('Confiança IA: ${_item.confianca}%',
                style: theme.textTheme.bodySmall),
            ]),
          ],

          const Divider(height: 32),

          // ─── Status ───────────────────────────────────────────────
          Text('Status', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          if (_savingStatus)
            const Center(child: CircularProgressIndicator())
          else
            Row(
              children: [
                _StatusButton(
                  label: 'Pendente',
                  icon: Icons.hourglass_empty,
                  color: Colors.grey,
                  selected: _item.status == 'pendente',
                  onTap: () => _atualizarStatus('pendente'),
                ),
                const SizedBox(width: 8),
                _StatusButton(
                  label: 'Conforme',
                  icon: Icons.check_circle_outline,
                  color: Colors.green,
                  selected: _item.status == 'ok',
                  onTap: () => _atualizarStatus('ok'),
                ),
                const SizedBox(width: 8),
                _StatusButton(
                  label: 'Não conforme',
                  icon: Icons.error_outline,
                  color: Colors.red,
                  selected: _item.status == 'nao_conforme',
                  onTap: () => _atualizarStatus('nao_conforme'),
                ),
              ],
            ),

          const Divider(height: 32),

          // ─── Observação ───────────────────────────────────────────
          Text('Observação', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          TextField(
            controller: _obsController,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Adicione uma observação...',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.tonalIcon(
              onPressed: _savingObs ? null : _salvarObservacao,
              icon: _savingObs
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: const Text('Salvar'),
            ),
          ),

          const Divider(height: 32),

          // ─── Evidências ───────────────────────────────────────────
          Text('Evidências', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          _EvidenciasGrid(key: ValueKey(_evidenciasVersion), itemId: _item.id),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }

  String _statusLabel(String status) => checklistStatusLabel(status);

  Color _statusColor(String status) => checklistStatusColor(status);
}

// ─── Botão de status ──────────────────────────────────────────────────────────

class _StatusButton extends StatelessWidget {
  const _StatusButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.15) : Colors.transparent,
            border: Border.all(
              color: selected ? color : Colors.grey.shade300,
              width: selected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: selected ? color : Colors.grey),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  color: selected ? color : Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Grid de evidências ───────────────────────────────────────────────────────

class _EvidenciasGrid extends StatefulWidget {
  const _EvidenciasGrid({required this.itemId});
  final String itemId;

  @override
  State<_EvidenciasGrid> createState() => _EvidenciasGridState();
}

class _EvidenciasGridState extends State<_EvidenciasGrid> {
  late Future<List<Evidencia>> _future;

  @override
  void initState() {
    super.initState();
    _future = ApiClient().listarEvidencias(widget.itemId);
  }

  @override
  void didUpdateWidget(_EvidenciasGrid old) {
    super.didUpdateWidget(old);
    _future = ApiClient().listarEvidencias(widget.itemId);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Evidencia>>(
      future: _future,
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Text('Erro ao carregar evidências');
        }
        final items = snap.data ?? [];
        if (items.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Text(
                'Nenhuma evidência anexada',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          );
        }
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: items.length,
          itemBuilder: (ctx, i) {
            final ev = items[i];
            final isImage = ev.mimeType?.startsWith('image/') ?? false;
            return ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: isImage
                  ? CachedNetworkImage(
                      imageUrl: ev.arquivoUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, _) => const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      errorWidget: (_, _, _) => _filePlaceholder(ev),
                    )
                  : _filePlaceholder(ev),
            );
          },
        );
      },
    );
  }

  Widget _filePlaceholder(Evidencia ev) {
    return Container(
      color: Colors.grey.shade200,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.insert_drive_file, size: 32, color: Colors.grey),
          const SizedBox(height: 4),
          Text(
            ev.arquivoNome,
            style: const TextStyle(fontSize: 10),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
