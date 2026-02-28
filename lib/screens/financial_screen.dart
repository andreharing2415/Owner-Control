import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../api/api.dart';
import 'alertas_config_screen.dart';
import 'curvas_screen.dart';
import 'lancar_despesa_screen.dart';
import 'relatorio_executivo_screen.dart';

final _brl = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$\u00a0');

class FinancialScreen extends StatefulWidget {
  const FinancialScreen({super.key});

  @override
  State<FinancialScreen> createState() => FinancialScreenState();
}

class FinancialScreenState extends State<FinancialScreen> {
  final ApiClient _api = ApiClient();

  late Future<List<Obra>> _obrasFuture;
  Obra? _obraSelecionada;
  Future<RelatorioFinanceiro>? _relatorioFuture;

  @override
  void initState() {
    super.initState();
    _obrasFuture = _api.listarObras();
  }

  /// Chamado pelo MainShell ao trocar para esta aba.
  void recarregarObras() {
    setState(() {
      _obraSelecionada = null;
      _relatorioFuture = null;
      _obrasFuture = _api.listarObras();
    });
  }

  void _selecionarObra(Obra obra) {
    setState(() {
      _obraSelecionada = obra;
      _relatorioFuture = _api.relatorioFinanceiro(obra.id);
    });
  }

  Future<void> _recarregarRelatorio() async {
    if (_obraSelecionada == null) return;
    setState(() {
      _relatorioFuture = _api.relatorioFinanceiro(_obraSelecionada!.id);
    });
  }

  Future<void> _abrirLancarDespesa() async {
    if (_obraSelecionada == null) return;
    final etapas = await _api.listarEtapas(_obraSelecionada!.id);
    if (!mounted) return;
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => LancarDespesaScreen(
          obra: _obraSelecionada!,
          etapas: etapas,
        ),
      ),
    );
    if (ok == true) _recarregarRelatorio();
  }

  Future<void> _abrirCurvaS() async {
    if (_obraSelecionada == null || _relatorioFuture == null) return;
    final relatorio = await _relatorioFuture;
    if (!mounted || relatorio == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => CurvaSScreen(relatorio: relatorio)),
    );
  }

  Future<void> _abrirAlertasConfig() async {
    if (_obraSelecionada == null || _relatorioFuture == null) return;
    final relatorio = await _relatorioFuture;
    if (!mounted || relatorio == null) return;
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AlertasConfigScreen(
          obra: _obraSelecionada!,
          thresholdAtual: relatorio.threshold,
        ),
      ),
    );
    if (ok == true) _recarregarRelatorio();
  }

  void _abrirRelatorioExecutivo() {
    if (_obraSelecionada == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            RelatorioExecutivoScreen(obra: _obraSelecionada!),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Financeiro'),
        centerTitle: false,
        actions: [
          if (_obraSelecionada != null) ...[
            IconButton(
              tooltip: 'Curva de Gastos',
              icon: const Icon(Icons.bar_chart_outlined),
              onPressed: () => _abrirCurvaS(),
            ),
            IconButton(
              tooltip: 'Configurar Alertas',
              icon: const Icon(Icons.tune_outlined),
              onPressed: () => _abrirAlertasConfig(),
            ),
            IconButton(
              tooltip: 'Relatório Executivo',
              icon: const Icon(Icons.summarize_outlined),
              onPressed: () => _abrirRelatorioExecutivo(),
            ),
          ],
        ],
      ),
      floatingActionButton: _obraSelecionada != null
          ? FloatingActionButton.extended(
              onPressed: _abrirLancarDespesa,
              icon: const Icon(Icons.add),
              label: const Text('Lançar Despesa'),
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
                  Icon(Icons.account_balance_wallet_outlined,
                      size: 56, color: Colors.grey),
                  SizedBox(height: 8),
                  Text('Nenhuma obra cadastrada.',
                      style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }
          // Seleciona a primeira obra automaticamente na primeira carga
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
              Expanded(child: _RelatorioView(future: _relatorioFuture)),
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
          final selected = selecionada?.id == obra.id;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(
                obra.nome,
                overflow: TextOverflow.ellipsis,
              ),
              selected: selected,
              onSelected: (_) => onSelect(obra),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─── Relatório View ───────────────────────────────────────────────────────────

class _RelatorioView extends StatelessWidget {
  const _RelatorioView({required this.future});
  final Future<RelatorioFinanceiro>? future;

  @override
  Widget build(BuildContext context) {
    if (future == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return FutureBuilder<RelatorioFinanceiro>(
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
        final rel = snap.data!;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
          children: [
            _ResumoCard(relatorio: rel),
            const SizedBox(height: 16),
            const Text(
              'Por Etapa',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 10),
            if (rel.porEtapa.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'Nenhum orçamento registrado por etapa.',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else
              ...rel.porEtapa.map(
                (e) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _EtapaCard(etapa: e),
                ),
              ),
          ],
        );
      },
    );
  }
}

// ─── Resumo Total ─────────────────────────────────────────────────────────────

class _ResumoCard extends StatelessWidget {
  const _ResumoCard({required this.relatorio});
  final RelatorioFinanceiro relatorio;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final rel = relatorio;
    final desvio = rel.desvioPercentual;
    final barColor =
        desvio > rel.threshold ? Colors.red : desvio > 0 ? Colors.orange : Colors.green;
    final pct = rel.totalPrevisto > 0
        ? (rel.totalGasto / rel.totalPrevisto).clamp(0.0, 2.0)
        : 0.0;

    return Card(
      elevation: 0,
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Resumo Geral',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _Valor(label: 'Gasto', valor: rel.totalGasto),
                _Valor(
                    label: 'Previsto',
                    valor: rel.totalPrevisto,
                    align: CrossAxisAlignment.end),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Desvio: ${desvio >= 0 ? '+' : ''}${desvio.toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: barColor,
                    fontSize: 13,
                  ),
                ),
                Text(
                  'Limite alerta: ${rel.threshold.toStringAsFixed(0)}%',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 10,
                backgroundColor: Colors.grey.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation<Color>(barColor),
              ),
            ),
            if (rel.alerta) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      size: 14, color: Colors.red),
                  const SizedBox(width: 4),
                  Text(
                    'Desvio acima de ${rel.threshold.toStringAsFixed(0)}%!',
                    style: const TextStyle(
                      color: Colors.red,
                      fontSize: 12,
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

// ─── Card por Etapa ───────────────────────────────────────────────────────────

class _EtapaCard extends StatelessWidget {
  const _EtapaCard({required this.etapa});
  final EtapaFinanceiroItem etapa;

  Color _barColor(double desvio, double threshold) {
    if (desvio > threshold) return Colors.red;
    if (desvio > 0) return Colors.orange;
    return Colors.indigo;
  }

  @override
  Widget build(BuildContext context) {
    final barColor = _barColor(etapa.desvioPercentual, 10);
    final pct = etapa.valorPrevisto > 0
        ? (etapa.valorGasto / etapa.valorPrevisto).clamp(0.0, 2.0)
        : 0.0;

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    etapa.etapaNome,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (etapa.alerta)
                  const Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Icon(Icons.warning_amber_rounded,
                        size: 16, color: Colors.red),
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
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 6,
                backgroundColor: Colors.grey.withValues(alpha: 0.12),
                valueColor: AlwaysStoppedAnimation<Color>(barColor),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Gasto: ${_brl.format(etapa.valorGasto)}',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
                Text(
                  'Previsto: ${_brl.format(etapa.valorPrevisto)}',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Helper ───────────────────────────────────────────────────────────────────

class _Valor extends StatelessWidget {
  const _Valor({
    required this.label,
    required this.valor,
    this.align = CrossAxisAlignment.start,
  });

  final String label;
  final double valor;
  final CrossAxisAlignment align;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: align,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 12, color: Colors.grey)),
        Text(
          _brl.format(valor),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
      ],
    );
  }
}
