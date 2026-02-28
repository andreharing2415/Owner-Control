import 'package:flutter/material.dart';

import '../api/api.dart';

class DetalheAchadoScreen extends StatelessWidget {
  const DetalheAchadoScreen({super.key, required this.achado});

  final Achado achado;

  (Color, IconData, String) get _severidadeStyle =>
      switch (achado.severidade) {
        'alto' => (Colors.red, Icons.warning_amber_rounded, 'Alto'),
        'medio' => (Colors.orange, Icons.info_outline, 'Médio'),
        _ => (Colors.green, Icons.check_circle_outline, 'Baixo'),
      };

  @override
  Widget build(BuildContext context) {
    final (color, icon, label) = _severidadeStyle;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalhe do Achado'),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Badge de severidade
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: color.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 16, color: color),
                    const SizedBox(width: 6),
                    Text(
                      'Severidade $label',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: color,
                          fontSize: 13),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              _ConfiancaChip(confianca: achado.confianca),
            ],
          ),
          const SizedBox(height: 16),

          // Descrição
          _Secao(
            titulo: 'Descrição do Achado',
            icon: Icons.search_outlined,
            child: Text(
              achado.descricao,
              style: const TextStyle(fontSize: 14, height: 1.5),
            ),
          ),
          const SizedBox(height: 14),

          // Ação recomendada
          _Secao(
            titulo: 'Ação Recomendada',
            icon: Icons.task_alt_outlined,
            child: Text(
              achado.acaoRecomendada,
              style: const TextStyle(fontSize: 14, height: 1.5),
            ),
          ),
          const SizedBox(height: 14),

          // Alertas
          if (achado.requerValidacaoProfissional ||
              achado.requerEvidenciaAdicional) ...[
            _Secao(
              titulo: 'Atenção',
              icon: Icons.notifications_active_outlined,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (achado.requerValidacaoProfissional)
                    _AlertaItem(
                      icon: Icons.engineering_outlined,
                      color: Colors.red,
                      texto:
                          'Este achado requer validação por engenheiro ou arquiteto habilitado antes de tomar qualquer decisão.',
                    ),
                  if (achado.requerEvidenciaAdicional) ...[
                    if (achado.requerValidacaoProfissional)
                      const SizedBox(height: 8),
                    _AlertaItem(
                      icon: Icons.add_a_photo_outlined,
                      color: Colors.orange,
                      texto:
                          'Recomenda-se registrar evidências adicionais (mais fotos ou documentos) para melhor avaliação.',
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          // Aviso legal
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.gavel_outlined,
                    size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Esta análise é informativa e NÃO substitui vistoria técnica de engenheiro ou arquiteto habilitado. '
                    'Confiança da IA: ${achado.confianca}%.',
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Chip de confiança ────────────────────────────────────────────────────────

class _ConfiancaChip extends StatelessWidget {
  const _ConfiancaChip({required this.confianca});

  final int confianca;

  Color get _color {
    if (confianca >= 70) return Colors.green;
    if (confianca >= 40) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _color.withValues(alpha: 0.3)),
      ),
      child: Text(
        '$confianca% confiança',
        style: TextStyle(
            fontSize: 11, color: _color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ─── Seção com título ─────────────────────────────────────────────────────────

class _Secao extends StatelessWidget {
  const _Secao({
    required this.titulo,
    required this.icon,
    required this.child,
  });

  final String titulo;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: Colors.indigo),
            const SizedBox(width: 6),
            Text(
              titulo,
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Colors.indigo),
            ),
          ],
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

// ─── Item de alerta ───────────────────────────────────────────────────────────

class _AlertaItem extends StatelessWidget {
  const _AlertaItem({
    required this.icon,
    required this.color,
    required this.texto,
  });

  final IconData icon;
  final Color color;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            texto,
            style: TextStyle(fontSize: 13, color: color, height: 1.4),
          ),
        ),
      ],
    );
  }
}
