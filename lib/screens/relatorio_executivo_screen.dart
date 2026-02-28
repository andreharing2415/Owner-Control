import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../api/api.dart';
import '../utils/auth_error_handler.dart';

class RelatorioExecutivoScreen extends StatefulWidget {
  const RelatorioExecutivoScreen({super.key, required this.obra});

  final Obra obra;

  @override
  State<RelatorioExecutivoScreen> createState() =>
      _RelatorioExecutivoScreenState();
}

class _RelatorioExecutivoScreenState
    extends State<RelatorioExecutivoScreen> {
  final ApiClient _api = ApiClient();
  final _brl = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$\u00a0');

  late Future<(RelatorioFinanceiro, List<Despesa>)> _dataFuture;
  bool _exportando = false;

  @override
  void initState() {
    super.initState();
    _dataFuture = _carregarDados();
  }

  Future<(RelatorioFinanceiro, List<Despesa>)> _carregarDados() async {
    final results = await Future.wait([
      _api.relatorioFinanceiro(widget.obra.id),
      _api.listarDespesas(widget.obra.id),
    ]);
    return (
      results[0] as RelatorioFinanceiro,
      results[1] as List<Despesa>,
    );
  }

  Future<void> _exportarPdf() async {
    setState(() => _exportando = true);
    try {
      final bytes = await _api.exportarPdf(widget.obra.id);
      final dir = await getTemporaryDirectory();
      final file =
          File('${dir.path}/relatorio-${widget.obra.id}.pdf');
      await file.writeAsBytes(bytes);
      await OpenFilex.open(file.path);
    } catch (e) {
      if (e is AuthExpiredException) { if (mounted) handleApiError(context, e); return; }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao exportar PDF: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _exportando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Relatório Executivo'),
        centerTitle: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton.icon(
              onPressed: _exportando ? null : _exportarPdf,
              icon: _exportando
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.picture_as_pdf_outlined, size: 18),
              label: const Text('PDF'),
            ),
          ),
        ],
      ),
      body: FutureBuilder<(RelatorioFinanceiro, List<Despesa>)>(
        future: _dataFuture,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline,
                      size: 48, color: Colors.red),
                  const SizedBox(height: 8),
                  Text('${snap.error}'),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () =>
                        setState(() => _dataFuture = _carregarDados()),
                    child: const Text('Tentar novamente'),
                  ),
                ],
              ),
            );
          }

          final (relatorio, despesas) = snap.data!;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
            children: [
              // ─── Cabeçalho da obra ─────────────────────────────────
              _ObraHeader(obra: widget.obra),
              const SizedBox(height: 16),

              // ─── Resumo financeiro ─────────────────────────────────
              _ResumoCard(relatorio: relatorio, brl: _brl),
              const SizedBox(height: 24),

              // ─── Orçamento por etapa ───────────────────────────────
              const Text(
                'Orçamento por Etapa',
                style:
                    TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(height: 10),
              if (relatorio.porEtapa.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('Nenhum orçamento registrado.',
                      style: TextStyle(color: Colors.grey)),
                )
              else
                ...relatorio.porEtapa.map(
                  (e) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _EtapaCard(etapa: e, brl: _brl),
                  ),
                ),

              const SizedBox(height: 24),

              // ─── Despesas ──────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Despesas Lançadas',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  Text(
                    '${despesas.length} registro${despesas.length != 1 ? 's' : ''}',
                    style: const TextStyle(
                        fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              if (despesas.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Text(
                      'Nenhuma despesa lançada.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                )
              else
                ...despesas.map(
                  (d) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: _DespesaRow(despesa: d, brl: _brl),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

// ─── Cabeçalho da obra ────────────────────────────────────────────────────────

class _ObraHeader extends StatelessWidget {
  const _ObraHeader({required this.obra});
  final Obra obra;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.indigo.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.home_work_outlined,
              color: Colors.indigo, size: 26),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                obra.nome,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 17),
              ),
              if (obra.localizacao != null)
                Text(
                  obra.localizacao!,
                  style: const TextStyle(
                      color: Colors.grey, fontSize: 12),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Resumo financeiro ────────────────────────────────────────────────────────

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
    final pct = relatorio.totalPrevisto > 0
        ? (relatorio.totalGasto / relatorio.totalPrevisto).clamp(0.0, 2.0)
        : 0.0;

    return Card(
      elevation: 0,
      color: Theme.of(context)
          .colorScheme
          .surfaceContainerHighest
          .withValues(alpha: 0.4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _Metrica(
                  label: 'Total Previsto',
                  valor: brl.format(relatorio.totalPrevisto),
                  color: Colors.indigo,
                ),
                _Metrica(
                  label: 'Total Gasto',
                  valor: brl.format(relatorio.totalGasto),
                  color: color,
                  align: CrossAxisAlignment.end,
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 8,
                backgroundColor: Colors.grey.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Desvio: ${desvio >= 0 ? '+' : ''}${desvio.toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: color,
                    fontSize: 13,
                  ),
                ),
                Text(
                  'Limite: ${relatorio.threshold.toStringAsFixed(0)}%',
                  style: const TextStyle(
                      fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
            if (relatorio.alerta) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      size: 14, color: Colors.red),
                  const SizedBox(width: 4),
                  Text(
                    'Desvio acima do limite (${relatorio.threshold.toStringAsFixed(0)}%)',
                    style: const TextStyle(
                      color: Colors.red,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Card de etapa ────────────────────────────────────────────────────────────

class _EtapaCard extends StatelessWidget {
  const _EtapaCard({required this.etapa, required this.brl});
  final EtapaFinanceiroItem etapa;
  final NumberFormat brl;

  Color _barColor() {
    if (etapa.alerta) return Colors.red;
    if (etapa.desvioPercentual > 0) return Colors.orange;
    return Colors.indigo;
  }

  @override
  Widget build(BuildContext context) {
    final barColor = _barColor();
    final pct = etapa.valorPrevisto > 0
        ? (etapa.valorGasto / etapa.valorPrevisto).clamp(0.0, 2.0)
        : 0.0;

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    etapa.etapaNome,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (etapa.alerta)
                  const Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Icon(Icons.warning_amber_rounded,
                        size: 14, color: Colors.red),
                  ),
                const SizedBox(width: 4),
                Text(
                  '${etapa.desvioPercentual >= 0 ? '+' : ''}${etapa.desvioPercentual.toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: barColor,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 5,
                backgroundColor: Colors.grey.withValues(alpha: 0.12),
                valueColor: AlwaysStoppedAnimation<Color>(barColor),
              ),
            ),
            const SizedBox(height: 5),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Gasto: ${brl.format(etapa.valorGasto)}',
                    style: const TextStyle(
                        fontSize: 11, color: Colors.grey)),
                Text('Previsto: ${brl.format(etapa.valorPrevisto)}',
                    style: const TextStyle(
                        fontSize: 11, color: Colors.grey)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Row de despesa ───────────────────────────────────────────────────────────

class _DespesaRow extends StatelessWidget {
  const _DespesaRow({required this.despesa, required this.brl});
  final Despesa despesa;
  final NumberFormat brl;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: ListTile(
        dense: true,
        leading:
            const Icon(Icons.receipt_long_outlined, size: 20, color: Colors.grey),
        title: Text(
          despesa.descricao,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          despesa.data,
          style: const TextStyle(fontSize: 11),
        ),
        trailing: Text(
          brl.format(despesa.valor),
          style: const TextStyle(
              fontWeight: FontWeight.bold, fontSize: 13),
        ),
      ),
    );
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

class _Metrica extends StatelessWidget {
  const _Metrica({
    required this.label,
    required this.valor,
    required this.color,
    this.align = CrossAxisAlignment.start,
  });
  final String label;
  final String valor;
  final Color color;
  final CrossAxisAlignment align;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: align,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 11, color: Colors.grey)),
        Text(
          valor,
          style: TextStyle(
              fontWeight: FontWeight.bold, fontSize: 16, color: color),
        ),
      ],
    );
  }
}
