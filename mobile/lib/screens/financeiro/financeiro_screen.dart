import "package:flutter/material.dart";

import "../../models/financeiro.dart";
import "../../services/api_client.dart";
import "alertas_config_screen.dart";
import "curva_s_screen.dart";
import "lancar_despesa_screen.dart";

class FinanceiroScreen extends StatefulWidget {
  const FinanceiroScreen({
    super.key,
    required this.obraId,
    required this.api,
  });

  final String obraId;
  final ApiClient api;

  @override
  State<FinanceiroScreen> createState() => _FinanceiroScreenState();
}

class _FinanceiroScreenState extends State<FinanceiroScreen> {
  late Future<RelatorioFinanceiro> _relatorioFuture;

  @override
  void initState() {
    super.initState();
    _relatorioFuture = widget.api.relatorioFinanceiro(widget.obraId);
  }

  Future<void> _refresh() async {
    setState(() {
      _relatorioFuture = widget.api.relatorioFinanceiro(widget.obraId);
    });
  }

  String _formatCurrency(double value) {
    final parts = value.toStringAsFixed(2).split(".");
    final intPart = parts[0];
    final decPart = parts[1];
    final negative = intPart.startsWith("-");
    final digits = negative ? intPart.substring(1) : intPart;
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) {
        buffer.write(".");
      }
      buffer.write(digits[i]);
    }
    final formatted = "R\$ ${negative ? "-" : ""}$buffer,$decPart";
    return formatted;
  }

  Color _desvioColor(double desvio) {
    final abs = desvio.abs();
    if (abs < 10) return Colors.green;
    if (abs < 20) return Colors.orange;
    return Colors.red;
  }

  Future<void> _abrirLancarDespesa() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => LancarDespesaScreen(
          obraId: widget.obraId,
          api: widget.api,
        ),
      ),
    );
    if (result == true) {
      await _refresh();
    }
  }

  void _abrirCurvaS() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CurvaSScreen(
          obraId: widget.obraId,
          api: widget.api,
        ),
      ),
    );
  }

  void _abrirAlertasConfig() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AlertasConfigScreen(
          obraId: widget.obraId,
          api: widget.api,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Financeiro"),
        actions: [
          IconButton(
            onPressed: _abrirCurvaS,
            icon: const Icon(Icons.show_chart),
            tooltip: "Curva S",
          ),
          IconButton(
            onPressed: _abrirAlertasConfig,
            icon: const Icon(Icons.notifications_active),
            tooltip: "Alertas",
          ),
          IconButton(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _abrirLancarDespesa,
        icon: const Icon(Icons.add),
        label: const Text("Despesa"),
      ),
      body: FutureBuilder<RelatorioFinanceiro>(
        future: _relatorioFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Erro: ${snapshot.error}"));
          }
          final relatorio = snapshot.data!;
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildResumoCard(relatorio, colorScheme),
                const SizedBox(height: 16),
                Text(
                  "Por Etapa",
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                ...relatorio.porEtapa.map(
                  (etapa) => _buildEtapaCard(etapa, relatorio, colorScheme),
                ),
                if (relatorio.porEtapa.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.account_balance_wallet,
                              size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            "Nenhuma etapa com orcamento",
                            style: theme.textTheme.titleMedium,
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 80),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildResumoCard(
      RelatorioFinanceiro relatorio, ColorScheme colorScheme) {
    final desvioColor = _desvioColor(relatorio.desvioPercentual);

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.account_balance_wallet, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  "Resumo do Orcamento",
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Previsto",
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatCurrency(relatorio.totalPrevisto),
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(color: Colors.blue),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Realizado",
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatCurrency(relatorio.totalRealizado),
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(color: desvioColor),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: desvioColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    "Desvio: ${relatorio.desvioPercentual.toStringAsFixed(1)}%",
                    style: TextStyle(
                      color: desvioColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: relatorio.totalPrevisto > 0
                    ? (relatorio.totalRealizado / relatorio.totalPrevisto)
                        .clamp(0.0, 1.5)
                    : 0,
                minHeight: 8,
                backgroundColor: Colors.grey.withValues(alpha: 0.15),
                color: desvioColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEtapaCard(EtapaFinanceiro etapa,
      RelatorioFinanceiro relatorio, ColorScheme colorScheme) {
    final desvioColor = _desvioColor(etapa.desvioPercentual);
    final progresso = etapa.previsto > 0
        ? (etapa.realizado / etapa.previsto).clamp(0.0, 1.5)
        : 0.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    etapa.etapaNome,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: desvioColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    "${etapa.desvioPercentual.toStringAsFixed(1)}%",
                    style: TextStyle(
                      color: desvioColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    "Prev: ${_formatCurrency(etapa.previsto)}",
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Colors.blue),
                  ),
                ),
                Expanded(
                  child: Text(
                    "Real: ${_formatCurrency(etapa.realizado)}",
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: desvioColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progresso,
                minHeight: 6,
                backgroundColor: Colors.grey.withValues(alpha: 0.15),
                color: desvioColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
