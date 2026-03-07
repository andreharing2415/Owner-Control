import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/obra.dart';
import '../../models/etapa.dart';
import '../../models/checklist_item.dart';
import '../../providers/auth_provider.dart';
import '../../providers/obra_provider.dart';
import '../../services/api_client.dart';
import '../obras/obras_screen.dart';
import '../etapas/etapas_screen.dart';
import '../normas/normas_screen.dart';
import '../financeiro/financeiro_screen.dart';
import '../documentos/documentos_screen.dart';
import '../prestadores/prestadores_screen.dart';
import '../checklist_inteligente/checklist_inteligente_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _carregando = false;
  String? _erro;
  List<Etapa> _etapas = [];
  List<ChecklistItem> _itensPendentes = [];

  ApiClient get _api => context.read<ObraAtualProvider>().api!;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final obra = context.read<ObraAtualProvider>().obraAtual;
      if (obra != null) _carregarDashboard(obra);
    });
  }

  Future<void> _carregarDashboard(Obra obra) async {
    setState(() {
      _carregando = true;
      _erro = null;
      _etapas = [];
      _itensPendentes = [];
    });
    try {
      final etapas = await _api.listarEtapas(obra.id);
      final futures =
          etapas.take(6).map((e) => _api.listarItens(e.id)).toList();
      final todosItens = await Future.wait(futures);
      final pendentes = todosItens
          .expand((lista) => lista)
          .where((item) => item.status == 'pendente')
          .toList();
      if (mounted) {
        setState(() {
          _etapas = etapas;
          _itensPendentes = pendentes;
          _carregando = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _erro = e.toString();
          _carregando = false;
        });
      }
    }
  }

  Future<void> _selecionarObra() async {
    final obraSelecionada = await Navigator.push<Obra>(
      context,
      MaterialPageRoute(
        builder: (_) => const ObrasScreen(modoSelecao: true),
      ),
    );
    if (obraSelecionada != null && mounted) {
      context.read<ObraAtualProvider>().selecionarObra(obraSelecionada);
      await _carregarDashboard(obraSelecionada);
    }
  }

  int get _etapasConcluidas =>
      _etapas.where((e) => e.status == 'concluida').length;

  double get _scoreGeral {
    if (_etapas.isEmpty) return 0.0;
    final scores =
        _etapas.where((e) => e.score != null).map((e) => e.score!).toList();
    if (scores.isEmpty) return 0.0;
    return scores.reduce((a, b) => a + b) / scores.length;
  }

  int get _itensCriticosPendentes =>
      _itensPendentes.where((i) => i.critico).length;

  @override
  Widget build(BuildContext context) {
    return Consumer<ObraAtualProvider>(
      builder: (context, provider, _) {
        final obra = provider.obraAtual;
        return Scaffold(
          appBar: AppBar(
            title: Row(
              children: [
                Image.asset('assets/images/logo_icone.png', height: 28),
                const SizedBox(width: 8),
                const Text("Mestre da Obra"),
              ],
            ),
            actions: [
              if (obra != null)
                IconButton(
                  icon: const Icon(Icons.swap_horiz),
                  tooltip: "Trocar obra",
                  onPressed: _selecionarObra,
                ),
              IconButton(
                icon: const Icon(Icons.menu_book_outlined),
                tooltip: "Normas Técnicas",
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => NormasScreen(api: _api)),
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == "logout") {
                    context.read<AuthProvider>().logout();
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    enabled: false,
                    child: Text(
                      context.read<AuthProvider>().user?.nome ?? "",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: "logout",
                    child: Row(children: [
                      Icon(Icons.logout, size: 18),
                      SizedBox(width: 8),
                      Text("Sair"),
                    ]),
                  ),
                ],
              ),
            ],
          ),
          body: obra == null ? _buildSemObra() : _buildDashboard(obra),
        );
      },
    );
  }

  Widget _buildSemObra() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/images/logo.png', width: 130),
            const SizedBox(height: 28),
            Text(
              "Bem-vindo ao Mestre da Obra",
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              "Selecione ou crie uma obra para ver o dashboard.",
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _selecionarObra,
              icon: const Icon(Icons.home_work),
              label: const Text("Selecionar Obra"),
              style: FilledButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboard(Obra obra) {
    if (_carregando) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_erro != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text("Erro:\n$_erro", textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => _carregarDashboard(obra),
                child: const Text("Tentar novamente"),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _carregarDashboard(obra),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _HeaderObra(obra: obra),
          const SizedBox(height: 14),
          _KpiRow(
            scoreGeral: _scoreGeral,
            etapasConcluidas: _etapasConcluidas,
            totalEtapas: _etapas.length,
            itensCriticosPendentes: _itensCriticosPendentes,
            totalItensPendentes: _itensPendentes.length,
          ),
          if (obra.orcamento != null) ...[
            const SizedBox(height: 14),
            _OrcamentoCard(orcamento: obra.orcamento!),
          ],
          const SizedBox(height: 14),
          _AcoesRapidasCard(
            onVerEtapas: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) =>
                      EtapasScreen(obra: obra, api: _api)),
            ).then((_) => _carregarDashboard(obra)),
            onNormas: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => NormasScreen(api: _api)),
            ),
            onTodasObras: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ObrasScreen()),
            ),
            onFinanceiro: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => FinanceiroScreen(
                      obraId: obra.id, api: _api)),
            ),
            onDocumentos: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => DocumentosScreen(
                      obraId: obra.id, api: _api)),
            ),
            onPrestadores: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => PrestadoresScreen(api: _api)),
            ),
            onChecklistIA: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => ChecklistInteligenteScreen(
                      obraId: obra.id, api: _api)),
            ),
          ),
          if (_itensPendentes.isNotEmpty) ...[
            const SizedBox(height: 14),
            _ItensPendentesCard(itens: _itensPendentes),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ─── Sub-widgets ──────────────────────────────────────────────────────────────

class _HeaderObra extends StatelessWidget {
  const _HeaderObra({required this.obra});
  final Obra obra;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor:
                  Theme.of(context).colorScheme.primaryContainer,
              child: Icon(
                Icons.home_work,
                color: Theme.of(context).colorScheme.primary,
                size: 26,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    obra.nome,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  if (obra.localizacao != null &&
                      obra.localizacao!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Row(
                        children: [
                          const Icon(Icons.location_on_outlined,
                              size: 13, color: Colors.grey),
                          const SizedBox(width: 2),
                          Expanded(
                            child: Text(
                              obra.localizacao!,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: Colors.grey[600]),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KpiRow extends StatelessWidget {
  const _KpiRow({
    required this.scoreGeral,
    required this.etapasConcluidas,
    required this.totalEtapas,
    required this.itensCriticosPendentes,
    required this.totalItensPendentes,
  });

  final double scoreGeral;
  final int etapasConcluidas;
  final int totalEtapas;
  final int itensCriticosPendentes;
  final int totalItensPendentes;

  Color _scoreColor(double s) {
    if (s >= 80) return Colors.green;
    if (s >= 50) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _KpiCard(
            icon: Icons.bar_chart,
            label: "Score Geral",
            value: "${scoreGeral.toStringAsFixed(0)}%",
            color: _scoreColor(scoreGeral),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _KpiCard(
            icon: Icons.checklist_rtl,
            label: "Etapas",
            value: "$etapasConcluidas/$totalEtapas",
            color: Colors.indigo,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _KpiCard(
            icon: Icons.pending_actions,
            label: "Pendentes",
            value: "$totalItensPendentes",
            subtitle: itensCriticosPendentes > 0
                ? "$itensCriticosPendentes críticos"
                : null,
            color: itensCriticosPendentes > 0 ? Colors.red : Colors.orange,
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
    required this.color,
    this.subtitle,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall,
              textAlign: TextAlign.center,
            ),
            if (subtitle != null)
              Text(
                subtitle!,
                style: TextStyle(
                  fontSize: 10,
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
          ],
        ),
      ),
    );
  }
}

class _OrcamentoCard extends StatelessWidget {
  const _OrcamentoCard({required this.orcamento});
  final double orcamento;

  String _formatarValor(double v) {
    final str = v.toStringAsFixed(2);
    final parts = str.split('.');
    final intPart = parts[0];
    final decPart = parts[1];
    final buffer = StringBuffer();
    for (int i = 0; i < intPart.length; i++) {
      if (i > 0 && (intPart.length - i) % 3 == 0) buffer.write('.');
      buffer.write(intPart[i]);
    }
    return 'R\$ ${buffer.toString()},$decPart';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading:
            const Icon(Icons.attach_money, color: Colors.green, size: 28),
        title: const Text("Orçamento da Obra"),
        trailing: Text(
          _formatarValor(orcamento),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: Colors.green,
          ),
        ),
      ),
    );
  }
}

class _AcoesRapidasCard extends StatelessWidget {
  const _AcoesRapidasCard({
    required this.onVerEtapas,
    required this.onNormas,
    required this.onTodasObras,
    required this.onFinanceiro,
    required this.onDocumentos,
    required this.onPrestadores,
    required this.onChecklistIA,
  });

  final VoidCallback onVerEtapas;
  final VoidCallback onNormas;
  final VoidCallback onTodasObras;
  final VoidCallback onFinanceiro;
  final VoidCallback onDocumentos;
  final VoidCallback onPrestadores;
  final VoidCallback onChecklistIA;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Ações Rápidas",
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: onVerEtapas,
                  icon: const Icon(Icons.list_alt, size: 18),
                  label: const Text("Ver Etapas"),
                ),
                OutlinedButton.icon(
                  onPressed: onFinanceiro,
                  icon: const Icon(Icons.attach_money, size: 18),
                  label: const Text("Financeiro"),
                ),
                OutlinedButton.icon(
                  onPressed: onDocumentos,
                  icon: const Icon(Icons.description, size: 18),
                  label: const Text("Documentos"),
                ),
                OutlinedButton.icon(
                  onPressed: onNormas,
                  icon: const Icon(Icons.menu_book_outlined, size: 18),
                  label: const Text("Normas"),
                ),
                OutlinedButton.icon(
                  onPressed: onPrestadores,
                  icon: const Icon(Icons.people_outline, size: 18),
                  label: const Text("Prestadores"),
                ),
                OutlinedButton.icon(
                  onPressed: onChecklistIA,
                  icon: const Icon(Icons.auto_awesome, size: 18),
                  label: const Text("Checklist IA"),
                ),
                OutlinedButton.icon(
                  onPressed: onTodasObras,
                  icon: const Icon(Icons.home_work_outlined, size: 18),
                  label: const Text("Todas as Obras"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ItensPendentesCard extends StatelessWidget {
  const _ItensPendentesCard({required this.itens});
  final List<ChecklistItem> itens;

  @override
  Widget build(BuildContext context) {
    final criticos = itens.where((i) => i.critico).toList();
    final normais = itens.where((i) => !i.critico).toList();
    final exibir = [...criticos, ...normais].take(5).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.pending_actions, size: 18),
                const SizedBox(width: 6),
                Text(
                  "Itens Pendentes",
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const Spacer(),
                if (itens.length > 5)
                  Text(
                    "+${itens.length - 5} mais",
                    style:
                        const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            ...exibir.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Icon(
                      item.critico
                          ? Icons.priority_high
                          : Icons.radio_button_unchecked,
                      size: 16,
                      color: item.critico ? Colors.red : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item.titulo,
                        style: TextStyle(
                          fontSize: 13,
                          color: item.critico ? Colors.red[700] : null,
                          fontWeight: item.critico
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
