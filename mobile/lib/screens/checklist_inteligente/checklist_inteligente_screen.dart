import "dart:async";

import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "../../models/auth.dart";
import "../../providers/auth_provider.dart";
import "../../providers/subscription_provider.dart";
import "../../services/api_client.dart";
import "../subscription/paywall_screen.dart";

class ChecklistInteligenteScreen extends StatefulWidget {
  const ChecklistInteligenteScreen({
    super.key,
    required this.obraId,
    required this.api,
    this.autoStart = false,
  });

  final String obraId;
  final ApiClient api;
  final bool autoStart;

  @override
  State<ChecklistInteligenteScreen> createState() =>
      _ChecklistInteligenteScreenState();
}

class _ChecklistInteligenteScreenState
    extends State<ChecklistInteligenteScreen> {
  // Job state
  ChecklistInteligenteLog? _log;
  List<ChecklistGeracaoItemModel> _itens = [];
  bool _loading = false;
  String? _erro;

  // History
  List<ChecklistInteligenteLog>? _historico;
  bool _loadingHistorico = true;
  String? _erroHistorico;

  // Selection for apply
  final Set<String> _itensSelecionados = {};

  // Polling
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _carregarHistorico();
    if (widget.autoStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _iniciar());
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _carregarHistorico() async {
    setState(() {
      _loadingHistorico = true;
      _erroHistorico = null;
    });
    try {
      final historico =
          await widget.api.historicoChecklistInteligente(widget.obraId);
      if (mounted) {
        setState(() {
          _historico = historico;
          _loadingHistorico = false;
        });
        // If there's an active job, resume polling
        final ativo = historico.where((l) => l.isProcessando).firstOrNull;
        if (ativo != null) {
          _log = ativo;
          _iniciarPolling(ativo.id);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingHistorico = false;
          _erroHistorico =
              "Não foi possível carregar o histórico. Verifique sua conexão.";
        });
      }
    }
  }

  Future<void> _iniciar() async {
    setState(() {
      _loading = true;
      _erro = null;
      _itens = [];
      _itensSelecionados.clear();
    });

    try {
      final log =
          await widget.api.iniciarChecklistInteligente(widget.obraId);
      if (mounted) {
        setState(() {
          _log = log;
          _loading = false;
        });
        _iniciarPolling(log.id);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _erro = e.toString().replaceFirst(RegExp(r'^[\w]*Exception:\s*'), "");
        });
      }
    }
  }

  void _iniciarPolling(String logId) {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _poll(logId);
    });
    // First poll immediately
    _poll(logId);
  }

  Future<void> _poll(String logId) async {
    try {
      final status =
          await widget.api.statusChecklistInteligente(widget.obraId, logId);
      if (!mounted) return;

      setState(() {
        _log = status.log;
        _itens = status.itens;
      });

      if (status.log.isConcluido || status.log.isErro) {
        _pollTimer?.cancel();
        if (status.log.isConcluido) {
          // Auto-select all items
          _itensSelecionados.addAll(status.itens.map((i) => i.id));
        }
        if (status.log.isErro) {
          setState(() {
            _erro = status.log.erroDetalhe ?? "Erro durante processamento";
          });
        }
        // Refresh history
        _carregarHistorico();
      }
    } catch (e) {
      // Don't stop polling on transient errors
    }
  }

  Future<void> _aplicar() async {
    final selecionados = _itens
        .where((i) => _itensSelecionados.contains(i.id))
        .map((i) => i.toJsonForApply())
        .toList();

    if (selecionados.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Selecione ao menos um item.")),
      );
      return;
    }
    try {
      await widget.api
          .aplicarChecklistInteligente(widget.obraId, selecionados);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text("${selecionados.length} itens aplicados ao checklist.")),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro ao aplicar: $e")),
        );
      }
    }
  }

  void _verDetalhesJob(ChecklistInteligenteLog job) async {
    try {
      final status =
          await widget.api.statusChecklistInteligente(widget.obraId, job.id);
      if (mounted) {
        setState(() {
          _log = status.log;
          _itens = status.itens;
          _erro = null;
          if (status.log.isConcluido) {
            _itensSelecionados.addAll(status.itens.map((i) => i.id));
          }
        });
        if (status.log.isProcessando) {
          _iniciarPolling(job.id);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro ao carregar detalhes: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = context.read<AuthProvider>().user;
    final isConvidado = user?.isConvidado ?? false;

    // Convidado: completely blocked
    if (isConvidado) {
      return Scaffold(
        appBar: AppBar(title: const Text("Checklist Inteligente")),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                Text("Recurso indisponível",
                    style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(
                  "O Checklist Inteligente está disponível apenas para o proprietário da obra.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Checklist Inteligente"),
        actions: [
          if (_log != null && _log!.isConcluido && _itens.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilledButton.icon(
                onPressed: _aplicar,
                icon: const Icon(Icons.check),
                label: const Text("Aplicar"),
              ),
            ),
        ],
      ),
      body: _log != null
          ? _buildJobView(theme)
          : _buildMainView(theme),
    );
  }

  Widget _buildMainView(ThemeData theme) {
    final sub = context.watch<SubscriptionProvider>();
    final lifetimeLimit = sub.checklistInteligenteLifetimeLimit;
    final used = sub.checklistInteligenteUsed;
    final reachedLimit = lifetimeLimit != null && used >= lifetimeLimit;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Hero section
        Center(
          child: Column(
            children: [
              Icon(Icons.auto_awesome,
                  size: 64, color: theme.colorScheme.primary),
              const SizedBox(height: 16),
              Text("Checklist Inteligente",
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(
                "A IA analisa os projetos PDF da sua obra e gera um checklist "
                "personalizado com base nas normas técnicas aplicáveis.",
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: Colors.grey[600]),
              ),
              // Lifetime usage counter for free plan
              if (lifetimeLimit != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: reachedLimit
                        ? Colors.red.withValues(alpha: 0.1)
                        : Colors.blue.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        reachedLimit ? Icons.block : Icons.bar_chart,
                        size: 16,
                        color: reachedLimit ? Colors.red : Colors.blue,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        "$used/$lifetimeLimit geração(ões) usada(s)",
                        style: TextStyle(
                          fontSize: 12,
                          color: reachedLimit ? Colors.red : Colors.blue[700],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: Colors.blue.withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.info_outline,
                        size: 16, color: Colors.blue[700]),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        "O processamento continua mesmo que você saia desta tela.",
                        style: TextStyle(
                            fontSize: 12, color: Colors.blue[800]),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              reachedLimit
                  ? FilledButton.icon(
                      onPressed: () => PaywallScreen.show(context,
                          message:
                              "Você atingiu o limite de gerações do plano gratuito"),
                      icon: const Icon(Icons.lock),
                      label: const Text("Limite atingido — Assinar"),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.grey,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 32, vertical: 16),
                      ),
                    )
                  : FilledButton.icon(
                      onPressed: _loading ? null : _iniciar,
                      icon: _loading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.auto_awesome),
                      label: Text(
                          _loading ? "Iniciando..." : "Gerar Checklist com IA"),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 32, vertical: 16),
                      ),
                    ),
            ],
          ),
        ),

        if (_erro != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(_erro!, style: const TextStyle(color: Colors.red))),
              ],
            ),
          ),
        ],

        // History
        if (_loadingHistorico) ...[
          const SizedBox(height: 32),
          const Center(child: CircularProgressIndicator()),
        ] else if (_erroHistorico != null) ...[
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border:
                  Border.all(color: Colors.orange.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.wifi_off, color: Colors.orange[700], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _erroHistorico!,
                        style: TextStyle(color: Colors.orange[800], fontSize: 13),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _carregarHistorico,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text("Tentar novamente"),
                  ),
                ),
              ],
            ),
          ),
        ] else if (_historico != null && _historico!.isNotEmpty) ...[
          const SizedBox(height: 32),
          Text("Histórico de Gerações",
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ..._historico!.map((job) => _buildHistoricoCard(theme, job)),
        ],
      ],
    );
  }

  Widget _buildHistoricoCard(ThemeData theme, ChecklistInteligenteLog job) {
    final Color statusColor;
    final IconData statusIcon;
    final String statusLabel;

    if (job.isProcessando) {
      statusColor = Colors.blue;
      statusIcon = Icons.hourglass_top;
      statusLabel = "Processando";
    } else if (job.isConcluido) {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
      statusLabel = "Concluído";
    } else {
      statusColor = Colors.red;
      statusIcon = Icons.error;
      statusLabel = "Erro";
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _verDetalhesJob(job),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(statusIcon, size: 18, color: statusColor),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    "${job.totalDocsAnalisados} doc(s)",
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_right, size: 20),
                ],
              ),
              if (job.isProcessando && job.totalPaginas > 0) ...[
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: job.paginasProcessadas / job.totalPaginas,
                ),
                const SizedBox(height: 4),
                Text(
                  "Página ${job.paginasProcessadas} de ${job.totalPaginas}",
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
              if (job.isConcluido) ...[
                const SizedBox(height: 6),
                Text(
                  "${job.totalItensSugeridos} itens sugeridos · ${job.totalItensAplicados} aplicados",
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: Colors.grey[600]),
                ),
              ],
              if (job.caracteristicasIdentificadas != null &&
                  job.caracteristicasIdentificadas!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: job.caracteristicasIdentificadas!
                      .take(5)
                      .map((c) => Chip(
                            label: Text(c, style: const TextStyle(fontSize: 10)),
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                          ))
                      .toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildJobView(ThemeData theme) {
    final log = _log!;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Back to list
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () {
              _pollTimer?.cancel();
              setState(() {
                _log = null;
                _itens = [];
                _erro = null;
              });
              _carregarHistorico();
            },
            icon: const Icon(Icons.arrow_back, size: 18),
            label: const Text("Voltar ao histórico"),
          ),
        ),
        const SizedBox(height: 8),

        // Status + progress
        _buildStepper(theme, log),
        const SizedBox(height: 16),

        // Page progress bar
        if (log.isProcessando && log.totalPaginas > 0) ...[
          LinearProgressIndicator(
            value: log.paginasProcessadas / log.totalPaginas,
          ),
          const SizedBox(height: 4),
          Text(
            "Página ${log.paginasProcessadas} de ${log.totalPaginas}",
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 16),
        ],

        // Características chips
        if (log.caracteristicasIdentificadas != null &&
            log.caracteristicasIdentificadas!.isNotEmpty) ...[
          Text("Características identificadas:",
              style: theme.textTheme.titleSmall),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: log.caracteristicasIdentificadas!
                .map((c) => Chip(
                      avatar: Icon(Icons.check_circle,
                          size: 16, color: theme.colorScheme.primary),
                      label: Text(c, style: const TextStyle(fontSize: 12)),
                      visualDensity: VisualDensity.compact,
                    ))
                .toList(),
          ),
          const SizedBox(height: 16),
        ],

        // Resumo
        if (log.resumoGeral != null && log.resumoGeral!.isNotEmpty)
          Card(
            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(children: [
                    Icon(Icons.auto_awesome, size: 18),
                    SizedBox(width: 6),
                    Text("Resumo da Análise",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ]),
                  const SizedBox(height: 8),
                  Text(log.resumoGeral!),
                ],
              ),
            ),
          ),

        // Aviso legal
        if (log.avisoLegal != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.1),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_outlined,
                    size: 16, color: Colors.amber),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(log.avisoLegal!,
                        style: const TextStyle(fontSize: 12))),
              ],
            ),
          ),
        ],

        // Error
        if (log.isErro && log.erroDetalhe != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.error_outline,
                        color: Colors.red, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(log.erroDetalhe!,
                            style: const TextStyle(color: Colors.red))),
                  ],
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: _iniciar,
                  child: const Text("Tentar novamente"),
                ),
              ],
            ),
          ),
        ],

        // Items list
        if (_itens.isNotEmpty) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Text("${_itens.length} itens sugeridos",
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15)),
              const Spacer(),
              if (log.isConcluido)
                TextButton(
                  onPressed: () {
                    setState(() {
                      if (_itensSelecionados.length == _itens.length) {
                        _itensSelecionados.clear();
                      } else {
                        _itensSelecionados.addAll(_itens.map((i) => i.id));
                      }
                    });
                  },
                  child: Text(_itensSelecionados.length == _itens.length
                      ? "Desmarcar todos"
                      : "Selecionar todos"),
                ),
            ],
          ),
          const SizedBox(height: 6),
          ...List.generate(_itens.length, _buildItemTile),
          const SizedBox(height: 24),
        ],
      ],
    );
  }

  Widget _buildItemTile(int i) {
    final item = _itens[i];

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: [
          CheckboxListTile(
            value: _itensSelecionados.contains(item.id),
            onChanged: _log?.isConcluido == true
                ? (v) {
                    setState(() {
                      if (v == true) {
                        _itensSelecionados.add(item.id);
                      } else {
                        _itensSelecionados.remove(item.id);
                      }
                    });
                  }
                : null,
            title: Row(
              children: [
                Expanded(
                    child: Text(item.titulo,
                        style: const TextStyle(fontSize: 14))),
                if (item.critico)
                  Container(
                    margin: const EdgeInsets.only(left: 4),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text("Crítico",
                        style: TextStyle(color: Colors.red, fontSize: 10)),
                  ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.etapaNome,
                    style: const TextStyle(fontSize: 11)),
                if (item.normaReferencia != null)
                  Text(item.normaReferencia!,
                      style:
                          const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
            dense: true,
            controlAffinity: ListTileControlAffinity.leading,
          ),
          if (item.medidasMinimas != null || item.explicacaoLeigo.isNotEmpty)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.05),
                border:
                    Border.all(color: Colors.blue.withValues(alpha: 0.15)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (item.comoVerificar.isNotEmpty) ...[
                    Row(
                      children: [
                        Icon(Icons.visibility, size: 14, color: Colors.green[700]),
                        const SizedBox(width: 4),
                        Text("Como verificar",
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.green[700])),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(item.comoVerificar,
                        style: const TextStyle(fontSize: 12)),
                    const SizedBox(height: 6),
                  ],
                  if (item.medidasMinimas != null) ...[
                    const Row(
                      children: [
                        Icon(Icons.straighten, size: 14, color: Colors.blue),
                        SizedBox(width: 4),
                        Text("Medidas mínimas",
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue)),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(item.medidasMinimas!,
                        style: const TextStyle(fontSize: 12)),
                    if (item.explicacaoLeigo.isNotEmpty)
                      const SizedBox(height: 6),
                  ],
                  if (item.explicacaoLeigo.isNotEmpty) ...[
                    Row(
                      children: [
                        Icon(Icons.lightbulb_outline,
                            size: 14, color: Colors.amber[700]),
                        const SizedBox(width: 4),
                        Text("Por que é importante",
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.amber[700])),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(item.explicacaoLeigo,
                        style: const TextStyle(fontSize: 12)),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStepper(ThemeData theme, ChecklistInteligenteLog log) {
    final int currentStep;
    if (log.isProcessando) {
      if (log.paginasProcessadas == 0) {
        currentStep = 1;
      } else if (log.totalItensSugeridos == 0) {
        currentStep = 2;
      } else {
        currentStep = 3;
      }
    } else if (log.isConcluido) {
      currentStep = 4;
    } else {
      currentStep = 0;
    }

    const steps = [
      (icon: Icons.description, label: "Extraindo PDFs"),
      (icon: Icons.search, label: "Analisando projeto"),
      (icon: Icons.checklist, label: "Gerando checklist"),
      (icon: Icons.check_circle, label: "Concluído"),
    ];

    return Row(
      children: List.generate(steps.length, (i) {
        final step = steps[i];
        final stepNum = i + 1;
        final isActive = currentStep == stepNum;
        final isDone = currentStep > stepNum;

        return Expanded(
          child: Column(
            children: [
              Row(
                children: [
                  if (i > 0)
                    Expanded(
                      child: Container(
                        height: 2,
                        color: isDone ? Colors.green : Colors.grey[300],
                      ),
                    ),
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDone
                          ? Colors.green
                          : isActive
                              ? theme.colorScheme.primary
                              : Colors.grey[200],
                    ),
                    child: isDone
                        ? const Icon(Icons.check,
                            size: 18, color: Colors.white)
                        : isActive
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Icon(step.icon,
                                size: 16, color: Colors.grey[400]),
                  ),
                  if (i < steps.length - 1)
                    Expanded(
                      child: Container(
                        height: 2,
                        color: isDone ? Colors.green : Colors.grey[300],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                step.label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  color: isActive ? theme.colorScheme.primary : Colors.grey,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      }),
    );
  }
}
