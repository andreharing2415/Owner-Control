import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../api/api.dart';

class CurvaSScreen extends StatelessWidget {
  const CurvaSScreen({super.key, required this.relatorio});

  final RelatorioFinanceiro relatorio;

  String _formatY(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}K';
    return v.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    final brl = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$\u00a0');
    final porEtapa = relatorio.porEtapa;

    double maxY = 0;
    for (final e in porEtapa) {
      if (e.valorPrevisto > maxY) maxY = e.valorPrevisto;
      if (e.valorGasto > maxY) maxY = e.valorGasto;
    }
    maxY = maxY > 0 ? maxY * 1.25 : 1000;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Curva de Gastos'),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Resumo ───────────────────────────────────────────────
            _ResumoCard(relatorio: relatorio, brl: brl),
            const SizedBox(height: 24),

            // ─── Gráfico ──────────────────────────────────────────────
            const Text(
              'Previsto × Realizado por Etapa',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _LegendaDot(color: Colors.indigo.shade300, label: 'Previsto'),
                const SizedBox(width: 16),
                _LegendaDot(color: Colors.orange, label: 'Realizado'),
                const SizedBox(width: 16),
                _LegendaDot(color: Colors.red, label: 'Alerta'),
              ],
            ),
            const SizedBox(height: 16),

            if (porEtapa.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Text(
                    'Nenhum orçamento registrado por etapa.',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else
              SizedBox(
                height: 280,
                child: BarChart(
                  BarChartData(
                    maxY: maxY,
                    barGroups: porEtapa.asMap().entries.map((entry) {
                      final i = entry.key;
                      final e = entry.value;
                      return BarChartGroupData(
                        x: i,
                        barsSpace: 4,
                        barRods: [
                          BarChartRodData(
                            toY: e.valorPrevisto,
                            color: Colors.indigo.shade300,
                            width: 14,
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(4)),
                          ),
                          BarChartRodData(
                            toY: e.valorGasto,
                            color: e.alerta ? Colors.red : Colors.orange,
                            width: 14,
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(4)),
                          ),
                        ],
                      );
                    }).toList(),
                    titlesData: FlTitlesData(
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 28,
                          getTitlesWidget: (value, meta) {
                            final i = value.toInt();
                            if (i < 0 || i >= porEtapa.length) {
                              return const SizedBox.shrink();
                            }
                            return Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                'E${i + 1}',
                                style: const TextStyle(fontSize: 11),
                              ),
                            );
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 54,
                          getTitlesWidget: (value, meta) {
                            if (value == meta.max) {
                              return const SizedBox.shrink();
                            }
                            return Text(
                              _formatY(value),
                              style: const TextStyle(
                                  fontSize: 10, color: Colors.grey),
                            );
                          },
                        ),
                      ),
                      topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                    ),
                    borderData: FlBorderData(show: false),
                    gridData: const FlGridData(show: true),
                  ),
                ),
              ),

            const SizedBox(height: 24),

            // ─── Legenda das etapas ────────────────────────────────────
            const Text(
              'Etapas',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 8),
            ...porEtapa.asMap().entries.map((entry) {
              final i = entry.key;
              final e = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.indigo.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'E${i + 1}',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.indigo,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        e.etapaNome,
                        style: const TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (e.alerta)
                      const Icon(Icons.warning_amber_rounded,
                          size: 14, color: Colors.red),
                    const SizedBox(width: 4),
                    Text(
                      brl.format(e.valorGasto),
                      style: const TextStyle(
                          fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

// ─── Resumo ────────────────────────────────────────────────────────────────────

class _ResumoCard extends StatelessWidget {
  const _ResumoCard({required this.relatorio, required this.brl});
  final RelatorioFinanceiro relatorio;
  final NumberFormat brl;

  @override
  Widget build(BuildContext context) {
    final desvio = relatorio.desvioPercentual;
    final color = relatorio.alerta
        ? Colors.red
        : desvio > 0
            ? Colors.orange
            : Colors.green;

    return Card(
      elevation: 0,
      color:
          Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _MetricaItem(
              label: 'Total Previsto',
              valor: brl.format(relatorio.totalPrevisto),
              color: Colors.indigo,
            ),
            _MetricaItem(
              label: 'Total Gasto',
              valor: brl.format(relatorio.totalGasto),
              color: color,
            ),
            _MetricaItem(
              label: 'Desvio',
              valor:
                  '${desvio >= 0 ? '+' : ''}${desvio.toStringAsFixed(1)}%',
              color: color,
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricaItem extends StatelessWidget {
  const _MetricaItem(
      {required this.label, required this.valor, required this.color});
  final String label;
  final String valor;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          valor,
          style: TextStyle(
              fontWeight: FontWeight.bold, fontSize: 15, color: color),
        ),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }
}

class _LegendaDot extends StatelessWidget {
  const _LegendaDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration:
              BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }
}
