import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../api/api.dart';
import 'etapas_screen.dart';
import 'prestadores_screen.dart';

final _brl = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$\u00a0');

// ─── Dados consolidados de uma obra para o dashboard ─────────────────────────

class _DashboardData {
  _DashboardData({
    required this.obra,
    required this.etapas,
    required this.relatorio,
    required this.totalProjetos,
  });

  final Obra obra;
  final List<Etapa> etapas;
  final RelatorioFinanceiro relatorio;
  final int totalProjetos;

  int get etapasConcluidas =>
      etapas.where((e) => e.status == 'concluida').length;

  int get totalEtapas => etapas.length;

  double get progressoPercent =>
      totalEtapas > 0 ? (etapasConcluidas / totalEtapas) : 0.0;

  Etapa? get proximaEtapa =>
      etapas.where((e) => e.status != 'concluida').firstOrNull;
}

// ─── HomeScreen ───────────────────────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  final ApiClient _api = ApiClient();

  late Future<List<Obra>> _obrasFuture;
  Obra? _obraSelecionada;
  Future<_DashboardData>? _dashFuture;

  @override
  void initState() {
    super.initState();
    _obrasFuture = _api.listarObras();
  }

  /// Chamado pelo MainShell ao trocar para esta aba.
  void recarregarObras() {
    setState(() {
      _obraSelecionada = null;
      _dashFuture = null;
      _obrasFuture = _api.listarObras();
    });
  }

  void _selecionarObra(Obra obra) {
    setState(() {
      _obraSelecionada = obra;
      _dashFuture = _carregarDashboard(obra);
    });
  }

  Future<_DashboardData> _carregarDashboard(Obra obra) async {
    final results = await Future.wait([
      _api.listarEtapas(obra.id),
      _api.relatorioFinanceiro(obra.id),
      _api.listarProjetos(obra.id),
    ]);
    return _DashboardData(
      obra: obra,
      etapas: results[0] as List<Etapa>,
      relatorio: results[1] as RelatorioFinanceiro,
      totalProjetos: (results[2] as List<ProjetoDoc>).length,
    );
  }

  Future<void> _recarregar() async {
    setState(() {
      _obrasFuture = _api.listarObras();
      if (_obraSelecionada != null) {
        _dashFuture = _carregarDashboard(_obraSelecionada!);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mestre da Obra'),
        centerTitle: false,
      ),
      body: FutureBuilder<List<Obra>>(
        future: _obrasFuture,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return _ErroView(mensagem: '${snap.error}', onRetry: _recarregar);
          }
          final obras = snap.data ?? [];
          if (obras.isEmpty) {
            return const _SemObrasView();
          }
          if (_obraSelecionada == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _selecionarObra(obras.first);
            });
          }
          return RefreshIndicator(
            onRefresh: _recarregar,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (obras.length > 1) ...[
                  _ObraSelector(
                    obras: obras,
                    selecionada: _obraSelecionada,
                    onSelect: _selecionarObra,
                  ),
                  const SizedBox(height: 12),
                ],
                if (_dashFuture != null)
                  FutureBuilder<_DashboardData>(
                    future: _dashFuture,
                    builder: (context, ds) {
                      if (ds.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(48),
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }
                      if (ds.hasError) {
                        return _ErroView(
                          mensagem: '${ds.error}',
                          onRetry: _recarregar,
                        );
                      }
                      final data = ds.data!;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _ObraCard(data: data),
                          const SizedBox(height: 14),
                          _KpiRow(data: data),
                          const SizedBox(height: 14),
                          _PrestadoresCard(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    const PrestadoresScreen(),
                              ),
                            ).then((_) => _recarregar()),
                          ),
                          if (data.proximaEtapa != null) ...[
                            const SizedBox(height: 14),
                            _ProximaEtapaCard(
                              etapa: data.proximaEtapa!,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      EtapasScreen(obra: data.obra),
                                ),
                              ).then((_) => _recarregar()),
                            ),
                          ],
                          if (data.relatorio.alerta) ...[
                            const SizedBox(height: 14),
                            _AlertaFinanceiro(relatorio: data.relatorio),
                          ],
                          const SizedBox(height: 24),
                        ],
                      );
                    },
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─── Seletor de obra ──────────────────────────────────────────────────────────

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
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: obras.map((obra) {
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(obra.nome, overflow: TextOverflow.ellipsis),
              selected: selecionada?.id == obra.id,
              onSelected: (_) => onSelect(obra),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─── Card principal da obra ───────────────────────────────────────────────────

class _ObraCard extends StatelessWidget {
  const _ObraCard({required this.data});
  final _DashboardData data;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final obra = data.obra;
    final pct = data.progressoPercent;

    String? periodoStr;
    if (obra.dataInicio != null || obra.dataFim != null) {
      final ini = obra.dataInicio != null
          ? _formatMesAno(obra.dataInicio!)
          : '?';
      final fim = obra.dataFim != null ? _formatMesAno(obra.dataFim!) : '?';
      periodoStr = '$ini → $fim';
    }

    return Card(
      elevation: 0,
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.home_work_rounded,
                    color: scheme.onPrimaryContainer, size: 20),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    obra.nome,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: scheme.onPrimaryContainer,
                        ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _ProgressoBadge(pct: pct, scheme: scheme),
              ],
            ),
            if (obra.localizacao != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.location_on_outlined,
                      size: 13,
                      color: scheme.onPrimaryContainer.withValues(alpha: 0.7)),
                  const SizedBox(width: 3),
                  Text(
                    obra.localizacao!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onPrimaryContainer
                              .withValues(alpha: 0.7),
                        ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${(pct * 100).round()}% concluído',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: scheme.onPrimaryContainer,
                    fontSize: 13,
                  ),
                ),
                if (periodoStr != null)
                  Text(
                    periodoStr,
                    style: TextStyle(
                      fontSize: 11,
                      color:
                          scheme.onPrimaryContainer.withValues(alpha: 0.7),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 8,
                backgroundColor:
                    scheme.onPrimaryContainer.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation<Color>(
                    scheme.onPrimaryContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatMesAno(String iso) {
    try {
      return DateFormat('MMM/yy', 'pt_BR').format(DateTime.parse(iso));
    } catch (_) {
      return iso;
    }
  }
}

class _ProgressoBadge extends StatelessWidget {
  const _ProgressoBadge({required this.pct, required this.scheme});
  final double pct;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: scheme.onPrimaryContainer.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        pct >= 1.0 ? 'Concluída' : 'Em andamento',
        style: TextStyle(
          fontSize: 11,
          color: scheme.onPrimaryContainer,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ─── KPI Row ──────────────────────────────────────────────────────────────────

class _KpiRow extends StatelessWidget {
  const _KpiRow({required this.data});
  final _DashboardData data;

  @override
  Widget build(BuildContext context) {
    final rel = data.relatorio;
    final orcPct = rel.totalPrevisto > 0
        ? (rel.totalGasto / rel.totalPrevisto * 100).round()
        : 0;

    return Row(
      children: [
        Expanded(
          child: _KpiCard(
            icon: Icons.account_balance_wallet_outlined,
            label: 'Orçamento',
            value: '$orcPct%',
            subtitle: 'utilizado',
            color: rel.alerta
                ? Colors.red
                : (orcPct > 75 ? Colors.orange : Colors.green),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _KpiCard(
            icon: Icons.checklist_rtl_outlined,
            label: 'Etapas',
            value: '${data.etapasConcluidas}/${data.totalEtapas}',
            subtitle: 'concluídas',
            color: Colors.indigo,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _KpiCard(
            icon: Icons.picture_as_pdf_outlined,
            label: 'Projetos',
            value: '${data.totalProjetos}',
            subtitle: 'enviados',
            color: data.totalProjetos > 0 ? Colors.indigo : Colors.grey,
          ),
        ),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.subtitle,
    required this.color,
  });
  final IconData icon;
  final String label;
  final String value;
  final String subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall,
              textAlign: TextAlign.center,
            ),
            Text(
              subtitle,
              style:
                  TextStyle(fontSize: 10, color: color.withValues(alpha: 0.8)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Prestadores card ─────────────────────────────────────────────────────

class _PrestadoresCard extends StatelessWidget {
  const _PrestadoresCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      clipBehavior: Clip.hardEdge,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.indigo.withValues(alpha: 0.10),
          child:
              const Icon(Icons.people_outline, color: Colors.indigo, size: 20),
        ),
        title: const Text(
          'Prestadores e Fornecedores',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: const Text(
          'Gerencie e avalie seus prestadores',
          style: TextStyle(fontSize: 12),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

// ─── Próxima etapa ────────────────────────────────────────────────────────────

class _ProximaEtapaCard extends StatelessWidget {
  const _ProximaEtapaCard({required this.etapa, required this.onTap});
  final Etapa etapa;
  final VoidCallback onTap;

  String get _statusLabel => switch (etapa.status) {
        'em_andamento' => 'Em andamento',
        'concluida' => 'Concluída',
        _ => 'Pendente',
      };

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.indigo,
          child: Text(
            '${etapa.ordem}',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          etapa.nome,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          _statusLabel,
          style: const TextStyle(fontSize: 12),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

// ─── Alerta financeiro ────────────────────────────────────────────────────────

class _AlertaFinanceiro extends StatelessWidget {
  const _AlertaFinanceiro({required this.relatorio});
  final RelatorioFinanceiro relatorio;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.08),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Desvio orçamentário de '
              '${relatorio.desvioPercentual.toStringAsFixed(1)}% '
              '(acima do limite de ${relatorio.threshold.toStringAsFixed(0)}%). '
              'Total gasto: ${_brl.format(relatorio.totalGasto)}.',
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Estados vazios e erro ────────────────────────────────────────────────────

class _SemObrasView extends StatelessWidget {
  const _SemObrasView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.home_work_outlined, size: 64, color: Colors.grey),
          SizedBox(height: 12),
          Text(
            'Nenhuma obra cadastrada.',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          SizedBox(height: 6),
          Text(
            'Acesse "Obra" no menu para criar sua primeira obra.',
            style: TextStyle(color: Colors.grey, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ErroView extends StatelessWidget {
  const _ErroView({required this.mensagem, required this.onRetry});
  final String mensagem;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 8),
          Text(mensagem,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton(
              onPressed: onRetry, child: const Text('Tentar novamente')),
        ],
      ),
    );
  }
}
