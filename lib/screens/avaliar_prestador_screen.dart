import 'package:flutter/material.dart';

import '../api/api.dart';
import 'widgets/star_rating.dart';
import '../utils/auth_error_handler.dart';

class AvaliarPrestadorScreen extends StatefulWidget {
  const AvaliarPrestadorScreen({
    super.key,
    required this.prestadorId,
    required this.categoria,
  });

  final String prestadorId;
  final String categoria;

  @override
  State<AvaliarPrestadorScreen> createState() =>
      _AvaliarPrestadorScreenState();
}

class _AvaliarPrestadorScreenState extends State<AvaliarPrestadorScreen> {
  final _comentarioCtrl = TextEditingController();
  final ApiClient _api = ApiClient();
  bool _salvando = false;

  // Prestador de serviço ratings
  int _notaQualidadeServico = 0;
  int _notaCumprimentoPrazos = 0;
  int _notaFidelidadeProjeto = 0;

  // Fornecedor de materiais ratings
  int _notaPrazoEntrega = 0;
  int _notaQualidadeMaterial = 0;

  @override
  void dispose() {
    _comentarioCtrl.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    final bool hasRating;
    if (widget.categoria == 'prestador_servico') {
      hasRating = _notaQualidadeServico > 0 ||
          _notaCumprimentoPrazos > 0 ||
          _notaFidelidadeProjeto > 0;
    } else {
      hasRating = _notaPrazoEntrega > 0 || _notaQualidadeMaterial > 0;
    }

    if (!hasRating) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Informe ao menos uma nota'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _salvando = true);
    try {
      await _api.criarAvaliacao(
        prestadorId: widget.prestadorId,
        notaQualidadeServico:
            _notaQualidadeServico > 0 ? _notaQualidadeServico : null,
        notaCumprimentoPrazos:
            _notaCumprimentoPrazos > 0 ? _notaCumprimentoPrazos : null,
        notaFidelidadeProjeto:
            _notaFidelidadeProjeto > 0 ? _notaFidelidadeProjeto : null,
        notaPrazoEntrega: _notaPrazoEntrega > 0 ? _notaPrazoEntrega : null,
        notaQualidadeMaterial:
            _notaQualidadeMaterial > 0 ? _notaQualidadeMaterial : null,
        comentario: _comentarioCtrl.text.trim().isNotEmpty
            ? _comentarioCtrl.text.trim()
            : null,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (e is AuthExpiredException) { if (mounted) handleApiError(context, e); return; }
      if (!mounted) return;
      setState(() => _salvando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isServico = widget.categoria == 'prestador_servico';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Avaliar Prestador'),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Info banner
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: scheme.primaryContainer.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: scheme.primaryContainer,
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 18, color: scheme.primary),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Avalie de 1 a 5 estrelas em cada tópico.',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Category-specific rating fields
          if (isServico) ...[
            _RatingField(
              label: 'Qualidade do Serviço',
              rating: _notaQualidadeServico,
              onChanged: (v) =>
                  setState(() => _notaQualidadeServico = v),
            ),
            const SizedBox(height: 18),
            _RatingField(
              label: 'Cumprimento de Prazos',
              rating: _notaCumprimentoPrazos,
              onChanged: (v) =>
                  setState(() => _notaCumprimentoPrazos = v),
            ),
            const SizedBox(height: 18),
            _RatingField(
              label: 'Fidelidade ao Projeto',
              rating: _notaFidelidadeProjeto,
              onChanged: (v) =>
                  setState(() => _notaFidelidadeProjeto = v),
            ),
          ] else ...[
            _RatingField(
              label: 'Prazo de Entrega',
              rating: _notaPrazoEntrega,
              onChanged: (v) => setState(() => _notaPrazoEntrega = v),
            ),
            const SizedBox(height: 18),
            _RatingField(
              label: 'Qualidade do Material',
              rating: _notaQualidadeMaterial,
              onChanged: (v) =>
                  setState(() => _notaQualidadeMaterial = v),
            ),
          ],
          const SizedBox(height: 18),

          // Comment
          TextFormField(
            controller: _comentarioCtrl,
            decoration: const InputDecoration(
              labelText: 'Comentário (opcional)',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 28),

          // Submit
          FilledButton.icon(
            onPressed: _salvando ? null : _salvar,
            icon: _salvando
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            label: Text(_salvando ? 'Salvando...' : 'Enviar Avaliação'),
          ),
        ],
      ),
    );
  }
}

// ─── Rating field ────────────────────────────────────────────────────────────

class _RatingField extends StatelessWidget {
  const _RatingField({
    required this.label,
    required this.rating,
    required this.onChanged,
  });

  final String label;
  final int rating;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        const SizedBox(height: 6),
        StarRating(rating: rating, onChanged: onChanged, size: 36),
      ],
    );
  }
}
