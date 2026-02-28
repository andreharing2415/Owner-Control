import 'package:flutter/material.dart';

import '../api/api.dart';
import 'detalhe_achado_screen.dart';

class AchadosScreen extends StatelessWidget {
  const AchadosScreen({super.key, required this.resultado});

  final AnaliseVisualComAchados resultado;

  @override
  Widget build(BuildContext context) {
    final analise = resultado.analise;
    final achados = resultado.achados;

    final altoCount = achados.where((a) => a.severidade == 'alto').length;
    final medioCount = achados.where((a) => a.severidade == 'medio').length;
    final baixoCount = achados.where((a) => a.severidade == 'baixo').length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Achados da Análise'),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          // Resumo da análise
          _ResumoCard(analise: analise),
          const SizedBox(height: 16),

          // Contadores de severidade
          Row(
            children: [
              _SeveridadeChip(
                  label: 'Alto', count: altoCount, color: Colors.red),
              const SizedBox(width: 8),
              _SeveridadeChip(
                  label: 'Médio', count: medioCount, color: Colors.orange),
              const SizedBox(width: 8),
              _SeveridadeChip(
                  label: 'Baixo', count: baixoCount, color: Colors.green),
            ],
          ),
          const SizedBox(height: 16),

          if (achados.isEmpty) ...[
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Column(
                  children: [
                    Icon(Icons.check_circle_outline,
                        size: 56, color: Colors.green),
                    SizedBox(height: 8),
                    Text(
                      'Nenhum achado identificado.',
                      style: TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'A IA não identificou problemas visíveis nesta foto.',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            const Text(
              'Achados identificados',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 10),
            ...achados.map(
              (a) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _AchadoCard(
                  achado: a,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DetalheAchadoScreen(achado: a),
                    ),
                  ),
                ),
              ),
            ),
          ],

          // Aviso legal
          if (analise.avisoLegal != null) ...[
            const SizedBox(height: 8),
            _AvisoLegalCard(texto: analise.avisoLegal!),
          ],
        ],
      ),
    );
  }
}

// ─── Resumo da análise ────────────────────────────────────────────────────────

class _ResumoCard extends StatelessWidget {
  const _ResumoCard({required this.analise});

  final AnaliseVisual analise;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.camera_enhance_outlined,
                    size: 18, color: Colors.indigo),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    analise.imagemNome,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (analise.etapaInferida != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text('Etapa identificada: ',
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                  Expanded(
                    child: Text(
                      '${analise.etapaInferida} (${analise.confianca}% confiança)',
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ],
            if (analise.resumoGeral != null) ...[
              const SizedBox(height: 10),
              Text(
                analise.resumoGeral!,
                style: const TextStyle(fontSize: 13),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Chip de severidade ───────────────────────────────────────────────────────

class _SeveridadeChip extends StatelessWidget {
  const _SeveridadeChip({
    required this.label,
    required this.count,
    required this.color,
  });

  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$count',
            style: TextStyle(
                fontWeight: FontWeight.bold, color: color, fontSize: 13),
          ),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(color: color, fontSize: 12)),
        ],
      ),
    );
  }
}

// ─── Card de achado ───────────────────────────────────────────────────────────

class _AchadoCard extends StatelessWidget {
  const _AchadoCard({required this.achado, required this.onTap});

  final Achado achado;
  final VoidCallback onTap;

  (Color, IconData, String) get _severidadeStyle =>
      switch (achado.severidade) {
        'alto' => (Colors.red, Icons.warning_amber_rounded, 'Alto'),
        'medio' => (Colors.orange, Icons.info_outline, 'Médio'),
        _ => (Colors.green, Icons.check_circle_outline, 'Baixo'),
      };

  @override
  Widget build(BuildContext context) {
    final (color, icon, label) = _severidadeStyle;

    return Card(
      elevation: 0,
      clipBehavior: Clip.hardEdge,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 16, color: color),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                          fontSize: 11,
                          color: color,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${achado.confianca}% confiança',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right,
                      size: 16, color: Colors.grey),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                achado.descricao,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w500),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Text(
                achado.acaoRecomendada,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (achado.requerValidacaoProfissional) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.engineering_outlined,
                        size: 12, color: Colors.red[700]),
                    const SizedBox(width: 4),
                    Text(
                      'Requer validação profissional',
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.red[700],
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Aviso legal ──────────────────────────────────────────────────────────────

class _AvisoLegalCard extends StatelessWidget {
  const _AvisoLegalCard({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.gavel_outlined, size: 16, color: Colors.amber),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              texto,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }
}
