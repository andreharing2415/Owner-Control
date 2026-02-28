import 'package:flutter/material.dart';

import '../api/api.dart';

class DetalheRiscoScreen extends StatelessWidget {
  const DetalheRiscoScreen({super.key, required this.risco});

  final Risco risco;

  (Color, IconData, String) get _sevStyle => switch (risco.severidade) {
        'alto' => (Colors.red, Icons.warning_rounded, 'Alto'),
        'medio' => (Colors.orange, Icons.warning_amber_rounded, 'Médio'),
        _ => (Colors.green, Icons.info_outline, 'Baixo'),
      };

  @override
  Widget build(BuildContext context) {
    final (color, icon, sevLabel) = _sevStyle;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalhe do Risco'),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ─── Badge de severidade ──────────────────────────────────
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: color.withValues(alpha: 0.12),
                  child: Icon(icon, color: color, size: 32),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: color.withValues(alpha: 0.35)),
                  ),
                  child: Text(
                    'Severidade: $sevLabel',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ─── Tradução leigo (destaque) ────────────────────────────
          Card(
            elevation: 0,
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.person_outline,
                          size: 16, color: Colors.indigo),
                      SizedBox(width: 6),
                      Text(
                        'O que isso significa para você',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Colors.indigo,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    risco.traducaoLeigo,
                    style: const TextStyle(fontSize: 14, height: 1.5),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 14),

          // ─── Descrição técnica ────────────────────────────────────
          Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.engineering_outlined,
                          size: 16, color: Colors.grey),
                      SizedBox(width: 6),
                      Text(
                        'Descrição Técnica',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    risco.descricao,
                    style: const TextStyle(
                        fontSize: 13, height: 1.5, color: Colors.black87),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 14),

          // ─── Norma de referência ──────────────────────────────────
          if (risco.normaReferencia != null) ...[
            Card(
              elevation: 0,
              child: ListTile(
                leading: const Icon(Icons.menu_book_outlined,
                    color: Colors.indigo),
                title: const Text(
                  'Norma de Referência',
                  style:
                      TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                subtitle: Text(
                  risco.normaReferencia!,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],

          // ─── Nível de confiança ───────────────────────────────────
          Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Nível de Confiança da IA',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      Text(
                        '${risco.confianca}%',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _confidenceColor(risco.confianca),
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: risco.confianca / 100,
                      minHeight: 8,
                      backgroundColor:
                          Colors.grey.withValues(alpha: 0.15),
                      valueColor: AlwaysStoppedAnimation<Color>(
                          _confidenceColor(risco.confianca)),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 14),

          // ─── Alerta de validação profissional ─────────────────────
          if (risco.requerValidacaoProfissional) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: Colors.red.withValues(alpha: 0.25)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.engineering, color: Colors.red, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Validação Profissional Necessária',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                            fontSize: 13,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Este risco requer análise de engenheiro ou arquiteto habilitado antes de prosseguir com a obra.',
                          style: TextStyle(
                              fontSize: 12, color: Colors.red),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          // ─── Aviso legal ──────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border:
                  Border.all(color: Colors.amber.withValues(alpha: 0.30)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 14, color: Colors.amber),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Esta análise é informativa e NÃO substitui parecer técnico de profissional habilitado.',
                    style: TextStyle(fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _confidenceColor(int confianca) {
    if (confianca >= 75) return Colors.green;
    if (confianca >= 50) return Colors.orange;
    return Colors.red;
  }
}
