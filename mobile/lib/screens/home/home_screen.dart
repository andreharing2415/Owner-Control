import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../../models/obra.dart';
import '../../models/etapa.dart';
import '../../models/checklist_item.dart';
import '../../providers/auth_provider.dart';
import '../../providers/obra_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../services/api_client.dart';
import '../convites/convites_screen.dart';
import '../obras/obras_screen.dart';
import '../etapas/etapas_screen.dart';
import '../normas/normas_screen.dart';
import '../documentos/documentos_screen.dart';
import '../financeiro/financeiro_screen.dart';
import '../prestadores/prestadores_screen.dart';
import '../conta/minha_conta_screen.dart';
import '../subscription/paywall_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentTab = 0;
  List<GlobalKey<NavigatorState>> _navKeys =
      List.generate(4, (_) => GlobalKey<NavigatorState>());

  ApiClient get _api => context.read<ObraAtualProvider>().api!;

  void _resetNavKeys() {
    _navKeys = List.generate(4, (_) => GlobalKey<NavigatorState>());
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
      setState(() {
        _currentTab = 0;
        _resetNavKeys();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ObraAtualProvider>(
      builder: (context, provider, _) {
        final obra = provider.obraAtual;
        if (obra == null) return _buildSemObra();

        final isConvidado =
            context.read<AuthProvider>().user?.isConvidado ?? false;

        final pages = <Widget>[
          Navigator(
            key: _navKeys[0],
            onGenerateRoute: (_) => MaterialPageRoute(
              builder: (_) => _DashboardPage(
                obra: obra,
                api: _api,
                onSelectObra: _selecionarObra,
              ),
            ),
          ),
          Navigator(
            key: _navKeys[1],
            onGenerateRoute: (_) => MaterialPageRoute(
              builder: (_) => EtapasScreen(obra: obra, api: _api),
            ),
          ),
          if (!isConvidado)
            Navigator(
              key: _navKeys[2],
              onGenerateRoute: (_) => MaterialPageRoute(
                builder: (_) => DocumentosScreen(obraId: obra.id, api: _api),
              ),
            ),
          if (!isConvidado)
            Navigator(
              key: _navKeys[3],
              onGenerateRoute: (_) => MaterialPageRoute(
                builder: (_) => NormasScreen(api: _api),
              ),
            ),
        ];

        final navItems = <BottomNavigationBarItem>[
          const BottomNavigationBarItem(
              icon: Icon(Icons.home), label: 'Início'),
          const BottomNavigationBarItem(
              icon: Icon(Icons.list_alt), label: 'Etapas'),
          if (!isConvidado)
            const BottomNavigationBarItem(
                icon: Icon(Icons.description), label: 'Documentos'),
          if (!isConvidado)
            const BottomNavigationBarItem(
                icon: Icon(Icons.menu_book_outlined), label: 'Normas'),
          const BottomNavigationBarItem(
              icon: Icon(Icons.more_horiz), label: 'Mais'),
        ];

        final safeTab = _currentTab < pages.length ? _currentTab : 0;

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;
            final nav = _navKeys[safeTab].currentState;
            if (nav != null && nav.canPop()) {
              nav.pop();
            } else if (safeTab != 0) {
              setState(() => _currentTab = 0);
            }
          },
          child: Scaffold(
            body: IndexedStack(
              index: safeTab,
              children: pages,
            ),
            bottomNavigationBar: BottomNavigationBar(
              currentIndex: safeTab,
              type: BottomNavigationBarType.fixed,
              selectedFontSize: 12,
              unselectedFontSize: 11,
              onTap: (index) {
                final maisIndex = navItems.length - 1;
                if (index == maisIndex) {
                  _showMaisMenu(obra, isConvidado);
                } else if (index == safeTab) {
                  _navKeys[safeTab]
                      .currentState
                      ?.popUntil((r) => r.isFirst);
                } else {
                  setState(() => _currentTab = index);
                }
              },
              items: navItems,
            ),
          ),
        );
      },
    );
  }

  Widget _buildSemObra() {
    return Scaffold(
      appBar: AppBar(
        title:
            SvgPicture.asset('assets/images/logo_horizontal.svg', height: 28),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SvgPicture.asset('assets/images/logo.svg', width: 200),
              const SizedBox(height: 28),
              Text(
                "Seja bem-vindo",
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                "Selecione ou crie uma obra para ver o dashboard.",
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: _selecionarObra,
                icon: const Icon(Icons.home_work),
                label: const Text("Selecionar Obra"),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 32, vertical: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMaisMenu(Obra obra, bool isConvidado) {
    final sub = context.read<SubscriptionProvider>();
    final user = context.read<AuthProvider>().user;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                if (user != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 4),
                    child: Text(
                      user.nome,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.swap_horiz),
                  title: const Text("Trocar Obra"),
                  onTap: () {
                    Navigator.pop(ctx);
                    _selecionarObra();
                  },
                ),
                if (!isConvidado)
                  ListTile(
                    leading: const Icon(Icons.attach_money),
                    title: const Text("Financeiro"),
                    onTap: () {
                      Navigator.pop(ctx);
                      _navKeys[_currentTab].currentState?.push(
                        MaterialPageRoute(
                          builder: (_) =>
                              FinanceiroScreen(obraId: obra.id, api: _api),
                        ),
                      );
                    },
                  ),
                if (!isConvidado)
                  ListTile(
                    leading: const Icon(Icons.people_outline),
                    title: const Text("Convites"),
                    onTap: () {
                      Navigator.pop(ctx);
                      _navKeys[_currentTab].currentState?.push(
                        MaterialPageRoute(
                          builder: (_) => ConvitesScreen(
                              obraId: obra.id, obraNome: obra.nome),
                        ),
                      );
                    },
                  ),
                if (!isConvidado)
                  ListTile(
                    leading: const Icon(Icons.engineering),
                    title: const Text("Prestadores"),
                    onTap: () {
                      Navigator.pop(ctx);
                      _navKeys[_currentTab].currentState?.push(
                        MaterialPageRoute(
                          builder: (_) => PrestadoresScreen(api: _api),
                        ),
                      );
                    },
                  ),
                if (sub.isGratuito && !isConvidado)
                  ListTile(
                    leading: const Icon(Icons.workspace_premium,
                        color: Colors.amber),
                    title: const Text("Assinar Plano Dono"),
                    onTap: () {
                      Navigator.pop(ctx);
                      PaywallScreen.show(context);
                    },
                  ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: const Text("Minha Conta"),
                  onTap: () {
                    Navigator.pop(ctx);
                    _navKeys[_currentTab].currentState?.push(
                      MaterialPageRoute(
                        builder: (_) => const MinhaContaScreen(),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.logout),
                  title: const Text("Sair"),
                  onTap: () {
                    Navigator.pop(ctx);
                    context.read<AuthProvider>().logout();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─── Dashboard Page ──────────────────────────────────────────────────────────

class _DashboardPage extends StatefulWidget {
  const _DashboardPage({
    required this.obra,
    required this.api,
    required this.onSelectObra,
  });

  final Obra obra;
  final ApiClient api;
  final VoidCallback onSelectObra;

  @override
  State<_DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<_DashboardPage> {
  bool _carregando = false;
  String? _erro;
  List<Etapa> _etapas = [];
  List<ChecklistItem> _itensPendentes = [];

  @override
  void initState() {
    super.initState();
    _carregarDashboard();
  }

  Future<void> _carregarDashboard() async {
    setState(() {
      _carregando = true;
      _erro = null;
      _etapas = [];
      _itensPendentes = [];
    });
    try {
      final etapas = await widget.api.listarEtapas(widget.obra.id);
      final List<ChecklistItem> pendentes = [];
      for (final etapa in etapas.take(6)) {
        try {
          final itens = await widget.api.listarItens(etapa.id);
          pendentes.addAll(itens.where((item) => item.status == 'pendente'));
        } catch (_) {
          // Ignora erro individual por etapa
        }
      }
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
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            SvgPicture.asset('assets/images/logo_horizontal.svg', height: 28),
            const SizedBox(width: 8),
            Consumer<SubscriptionProvider>(
              builder: (context, sub, _) {
                final user = context.read<AuthProvider>().user;
                if (user != null && user.isConvidado) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      "Convidado",
                      style:
                          TextStyle(fontSize: 10, color: Colors.blue.shade700),
                    ),
                  );
                }
                if (sub.isDono) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.workspace_premium,
                            size: 12, color: Colors.amber.shade700),
                        const SizedBox(width: 2),
                        Text(
                          "Dono",
                          style: TextStyle(
                              fontSize: 10,
                              color: Colors.amber.shade700,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ],
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
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
                onPressed: _carregarDashboard,
                child: const Text("Tentar novamente"),
              ),
            ],
          ),
        ),
      );
    }

    final obra = widget.obra;

    return RefreshIndicator(
      onRefresh: _carregarDashboard,
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
          if (obra.orcamento != null &&
              !(context.read<AuthProvider>().user?.isConvidado ??
                  false)) ...[
            const SizedBox(height: 14),
            _OrcamentoCard(
              orcamento: obra.orcamento!,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        FinanceiroScreen(obraId: obra.id, api: widget.api)),
              ),
            ),
          ],
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
  const _OrcamentoCard({required this.orcamento, required this.onTap});
  final double orcamento;
  final VoidCallback onTap;

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
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _formatarValor(orcamento),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: Colors.green,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}

class _ItensPendentesCard extends StatelessWidget {
  const _ItensPendentesCard({required this.itens});
  final List<ChecklistItem> itens;

  @override
  Widget build(BuildContext context) {
    final ordenados = [...itens]..sort((a, b) {
        if (a.critico != b.critico) return a.critico ? -1 : 1;
        if (a.criadoEm != null && b.criadoEm != null) {
          return a.criadoEm!.compareTo(b.criadoEm!);
        }
        return 0;
      });
    final exibir = ordenados.take(5).toList();

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
