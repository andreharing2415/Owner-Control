import "dart:async";

import "package:flutter/material.dart";

import "../../services/api_client.dart";

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
  // Stepper state
  int _currentStep = 0; // 0=idle, 1-4=steps
  String _stepLabel = "";
  int _pagesCurrent = 0;
  int _pagesTotal = 0;
  String _currentDoc = "";

  // Results
  final List<Map<String, dynamic>> _caracteristicas = [];
  final List<Map<String, dynamic>> _itens = [];
  String? _resumo;
  String? _avisoLegal;
  String? _erro;
  bool _concluido = false;

  // Selection for apply
  final Set<int> _itensSelecionados = {};

  StreamSubscription<Map<String, dynamic>>? _subscription;

  @override
  void initState() {
    super.initState();
    if (widget.autoStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _gerar());
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _gerar() {
    setState(() {
      _currentStep = 1;
      _stepLabel = "Iniciando...";
      _pagesCurrent = 0;
      _pagesTotal = 0;
      _currentDoc = "";
      _caracteristicas.clear();
      _itens.clear();
      _itensSelecionados.clear();
      _resumo = null;
      _avisoLegal = null;
      _erro = null;
      _concluido = false;
    });

    _subscription?.cancel();
    _subscription = widget.api
        .streamChecklistInteligente(widget.obraId)
        .listen(
      _onEvent,
      onError: (e) {
        if (mounted) {
          setState(() {
            _erro = e.toString().replaceFirst("Exception: ", "");
            _currentStep = 0;
          });
        }
      },
      onDone: () {
        if (mounted && !_concluido) {
          setState(() {
            _concluido = true;
            _currentStep = 4;
            _stepLabel = "Concluído!";
          });
        }
      },
    );
  }

  void _onEvent(Map<String, dynamic> data) {
    if (!mounted) return;

    final event = data["event"] as String? ?? "";

    setState(() {
      switch (event) {
        case "step":
          _currentStep = data["step"] as int? ?? _currentStep;
          _stepLabel = data["label"] as String? ?? _stepLabel;
          break;

        case "page":
          _pagesCurrent = data["current"] as int? ?? _pagesCurrent;
          _pagesTotal = data["total"] as int? ?? _pagesTotal;
          _currentDoc = data["doc"] as String? ?? _currentDoc;
          break;

        case "caracteristica":
          _caracteristicas.add(data);
          break;

        case "itens":
          final newItens = data["itens"] as List? ?? [];
          for (int j = 0; j < newItens.length; j++) {
            final item = newItens[j];
            if (item is Map<String, dynamic>) {
              _itensSelecionados.add(_itens.length);
              _itens.add(item);
            }
          }
          break;

        case "error":
          final msg = data["message"] as String? ?? "Erro desconhecido";
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg), backgroundColor: Colors.orange),
          );
          break;

        case "done":
          _concluido = true;
          _currentStep = 4;
          _resumo = data["resumo_projeto"] as String?;
          _avisoLegal = data["aviso_legal"] as String?;
          for (int i = 0; i < _itens.length; i++) {
            _itensSelecionados.add(i);
          }
          break;
      }
    });
  }

  Future<void> _aplicar() async {
    final selecionados = _itensSelecionados.map((i) => _itens[i]).toList();
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Checklist Inteligente"),
        actions: [
          if (_concluido && _itens.isNotEmpty)
            FilledButton.icon(
              onPressed: _aplicar,
              icon: const Icon(Icons.check),
              label: const Text("Aplicar"),
            ),
        ],
      ),
      body: _currentStep == 0 && _erro == null && !_concluido
          ? _buildInicio(theme)
          : _erro != null && _currentStep == 0
              ? _buildErro(theme)
              : _buildStreaming(theme),
    );
  }

  Widget _buildInicio(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome,
                size: 72, color: theme.colorScheme.primary),
            const SizedBox(height: 20),
            Text("Checklist Inteligente",
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text(
              "A IA analisa os projetos PDF da sua obra e gera um checklist "
              "personalizado com base nas normas técnicas aplicáveis.",
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _gerar,
              icon: const Icon(Icons.auto_awesome),
              label: const Text("Gerar Checklist com IA"),
              style: FilledButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErro(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text(_erro!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
                onPressed: _gerar, child: const Text("Tentar novamente")),
          ],
        ),
      ),
    );
  }

  Widget _buildStreaming(ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildStepper(theme),
        const SizedBox(height: 16),

        // Page progress bar
        if (_pagesTotal > 0 && !_concluido) ...[
          LinearProgressIndicator(
            value: _pagesTotal > 0 ? _pagesCurrent / _pagesTotal : 0,
          ),
          const SizedBox(height: 4),
          Text(
            "Página $_pagesCurrent de $_pagesTotal"
            "${_currentDoc.isNotEmpty ? ' — $_currentDoc' : ''}",
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 16),
        ],

        // Características chips
        if (_caracteristicas.isNotEmpty) ...[
          Text("Características identificadas:",
              style: theme.textTheme.titleSmall),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: _caracteristicas
                .map((c) => Chip(
                      avatar: Icon(Icons.check_circle,
                          size: 16, color: theme.colorScheme.primary),
                      label: Text("${c['nome'] ?? c['id']}",
                          style: const TextStyle(fontSize: 12)),
                      visualDensity: VisualDensity.compact,
                    ))
                .toList(),
          ),
          const SizedBox(height: 16),
        ],

        // Resumo
        if (_resumo != null && _resumo!.isNotEmpty)
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
                  Text(_resumo!),
                ],
              ),
            ),
          ),

        // Aviso legal
        if (_avisoLegal != null) ...[
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
                    child: Text(_avisoLegal!,
                        style: const TextStyle(fontSize: 12))),
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
              if (_concluido)
                TextButton(
                  onPressed: () {
                    setState(() {
                      if (_itensSelecionados.length == _itens.length) {
                        _itensSelecionados.clear();
                      } else {
                        for (int i = 0; i < _itens.length; i++) {
                          _itensSelecionados.add(i);
                        }
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
    final titulo =
        item["titulo"] as String? ?? item["item"] as String? ?? "";
    final critico = item["critico"] as bool? ?? false;
    final norma = item["norma_referencia"] as String?;
    final etapa = item["etapa_nome"] as String?;
    final medidasMinimas = item["medidas_minimas"] as String?;
    final explicacaoLeigo = item["explicacao_leigo"] as String?;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: [
          CheckboxListTile(
            value: _itensSelecionados.contains(i),
            onChanged: _concluido
                ? (v) {
                    setState(() {
                      if (v == true) {
                        _itensSelecionados.add(i);
                      } else {
                        _itensSelecionados.remove(i);
                      }
                    });
                  }
                : null,
            title: Row(
              children: [
                Expanded(
                    child:
                        Text(titulo, style: const TextStyle(fontSize: 14))),
                if (critico)
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
                if (etapa != null)
                  Text(etapa, style: const TextStyle(fontSize: 11)),
                if (norma != null)
                  Text(norma,
                      style:
                          const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
            dense: true,
            controlAffinity: ListTileControlAffinity.leading,
          ),
          if (medidasMinimas != null || explicacaoLeigo != null)
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
                  if (medidasMinimas != null) ...[
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
                    Text(medidasMinimas,
                        style: const TextStyle(fontSize: 12)),
                    if (explicacaoLeigo != null) const SizedBox(height: 6),
                  ],
                  if (explicacaoLeigo != null) ...[
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
                    Text(explicacaoLeigo,
                        style: const TextStyle(fontSize: 12)),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStepper(ThemeData theme) {
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
        final isActive = _currentStep == stepNum;
        final isDone = _currentStep > stepNum;

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
                            : Icon(step.icon, size: 16, color: Colors.grey[400]),
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
                isActive ? _stepLabel : step.label,
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
