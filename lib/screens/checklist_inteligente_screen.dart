import 'package:flutter/material.dart';

import '../api/api.dart';
import '../utils/auth_error_handler.dart';

class ChecklistInteligenteScreen extends StatefulWidget {
  const ChecklistInteligenteScreen({super.key, required this.obra});

  final Obra obra;

  @override
  State<ChecklistInteligenteScreen> createState() =>
      _ChecklistInteligenteScreenState();
}

class _ChecklistInteligenteScreenState
    extends State<ChecklistInteligenteScreen> {
  final ApiClient _api = ApiClient();

  bool _gerando = false;
  bool _aplicando = false;
  ChecklistInteligenteResponse? _resultado;
  String? _erro;

  Future<void> _gerar() async {
    setState(() {
      _gerando = true;
      _erro = null;
    });
    try {
      final resultado =
          await _api.gerarChecklistInteligente(widget.obra.id);
      if (!mounted) return;
      setState(() {
        _resultado = resultado;
        _gerando = false;
      });
    } catch (e) {
      if (e is AuthExpiredException) { if (mounted) handleApiError(context, e); return; }
      if (!mounted) return;
      setState(() {
        _erro = e.toString();
        _gerando = false;
      });
    }
  }

  Future<void> _aplicar() async {
    if (_resultado == null) return;

    final selecionados = _resultado!.itensPorEtapa.values
        .expand((list) => list)
        .where((item) => item.selecionado)
        .toList();

    if (selecionados.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione ao menos um item.')),
      );
      return;
    }

    setState(() => _aplicando = true);
    try {
      final total = await _api.aplicarChecklistInteligente(
        obraId: widget.obra.id,
        logId: _resultado!.logId,
        itens: selecionados,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$total itens adicionados ao checklist!')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (e is AuthExpiredException) { if (mounted) handleApiError(context, e); return; }
      if (!mounted) return;
      setState(() => _aplicando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
      );
    }
  }

  int _countSelected() {
    if (_resultado == null) return 0;
    return _resultado!.itensPorEtapa.values
        .expand((list) => list)
        .where((i) => i.selecionado)
        .length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Checklist Inteligente'),
        centerTitle: false,
      ),
      bottomNavigationBar: _resultado != null
          ? _BottomApplyBar(
              aplicando: _aplicando,
              totalSelecionados: _countSelected(),
              totalItens: _resultado!.totalItens,
              onAplicar: _aplicar,
            )
          : null,
      body: _resultado == null
          ? _InitialView(
              gerando: _gerando,
              erro: _erro,
              onGerar: _gerar,
            )
          : _SugestoesView(
              resultado: _resultado!,
              onToggleItem: (item) {
                setState(() => item.selecionado = !item.selecionado);
              },
              onSelecionarTodosEtapa: (etapa, value) {
                setState(() {
                  for (final item
                      in _resultado!.itensPorEtapa[etapa] ?? []) {
                    item.selecionado = value;
                  }
                });
              },
            ),
    );
  }
}

// ─── Estado inicial ─────────────────────────────────────────────────────────

class _InitialView extends StatelessWidget {
  const _InitialView({
    required this.gerando,
    this.erro,
    required this.onGerar,
  });

  final bool gerando;
  final String? erro;
  final VoidCallback onGerar;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.auto_awesome,
              size: 56,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 20),
            Text(
              'Checklist Inteligente',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              'A IA vai analisar os documentos do seu projeto e sugerir '
              'itens de checklist personalizados com as normas técnicas '
              'aplicáveis, em linguagem simples.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Funcionalidades como piscina, ar condicionado, elevador, '
              'painéis solares e outras serão identificadas automaticamente.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 12,
                height: 1.5,
              ),
            ),
            if (erro != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 16, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        erro!,
                        style:
                            const TextStyle(fontSize: 12, color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: gerando ? null : onGerar,
              icon: gerando
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.auto_awesome, size: 18),
              label: Text(gerando
                  ? 'Analisando documentos...'
                  : 'Gerar Checklist Inteligente'),
            ),
            if (gerando) ...[
              const SizedBox(height: 12),
              Text(
                'Isso pode levar até 1 minuto dependendo\nda quantidade de documentos.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Vista de sugestões ─────────────────────────────────────────────────────

class _SugestoesView extends StatelessWidget {
  const _SugestoesView({
    required this.resultado,
    required this.onToggleItem,
    required this.onSelecionarTodosEtapa,
  });

  final ChecklistInteligenteResponse resultado;
  final void Function(ItemChecklistSugerido) onToggleItem;
  final void Function(String etapa, bool value) onSelecionarTodosEtapa;

  @override
  Widget build(BuildContext context) {
    final etapas = resultado.itensPorEtapa.keys.toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      children: [
        // Resumo do projeto
        Card(
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.auto_awesome,
                        size: 18,
                        color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 6),
                    Text(
                      'Resumo do Projeto',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  resultado.resumoProjeto,
                  style: const TextStyle(fontSize: 13, height: 1.5),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Características identificadas
        if (resultado.caracteristicas.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'Características identificadas',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
          ),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: resultado.caracteristicas
                .map((c) => _CaracteristicaChip(caracteristica: c))
                .toList(),
          ),
          const SizedBox(height: 16),
        ],

        // Itens agrupados por etapa
        ...etapas.map((etapa) {
          final itens = resultado.itensPorEtapa[etapa]!;
          final todosSelecionados = itens.every((i) => i.selecionado);
          final algunsSelecionados = itens.any((i) => i.selecionado);

          return _EtapaSection(
            etapaNome: etapa,
            itens: itens,
            todosSelecionados: todosSelecionados,
            algunsSelecionados: algunsSelecionados,
            onToggleItem: onToggleItem,
            onSelecionarTodos: (value) =>
                onSelecionarTodosEtapa(etapa, value),
          );
        }),

        // Aviso legal
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.amber.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline,
                  size: 14, color: Colors.amber),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  resultado.avisoLegal,
                  style: const TextStyle(fontSize: 11),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Seção de uma etapa ─────────────────────────────────────────────────────

class _EtapaSection extends StatelessWidget {
  const _EtapaSection({
    required this.etapaNome,
    required this.itens,
    required this.todosSelecionados,
    required this.algunsSelecionados,
    required this.onToggleItem,
    required this.onSelecionarTodos,
  });

  final String etapaNome;
  final List<ItemChecklistSugerido> itens;
  final bool todosSelecionados;
  final bool algunsSelecionados;
  final void Function(ItemChecklistSugerido) onToggleItem;
  final void Function(bool) onSelecionarTodos;

  @override
  Widget build(BuildContext context) {
    final selecionados = itens.where((i) => i.selecionado).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Row(
          children: [
            Checkbox(
              value: todosSelecionados
                  ? true
                  : (algunsSelecionados ? null : false),
              tristate: true,
              onChanged: (value) =>
                  onSelecionarTodos(value == true || value == null),
            ),
            Expanded(
              child: Text(
                etapaNome,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$selecionados/${itens.length}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ...itens.map(
            (item) => _ItemSugeridoTile(item: item, onToggle: onToggleItem)),
        const SizedBox(height: 8),
      ],
    );
  }
}

// ─── Tile de item sugerido ──────────────────────────────────────────────────

class _ItemSugeridoTile extends StatefulWidget {
  const _ItemSugeridoTile({
    required this.item,
    required this.onToggle,
  });

  final ItemChecklistSugerido item;
  final void Function(ItemChecklistSugerido) onToggle;

  @override
  State<_ItemSugeridoTile> createState() => _ItemSugeridoTileState();
}

class _ItemSugeridoTileState extends State<_ItemSugeridoTile> {
  bool _expanded = false;

  (Color, String) get _riscoStyle => switch (widget.item.riscoNivel) {
        'alto' => (Colors.red, 'Alto'),
        'medio' => (Colors.orange, 'Médio'),
        _ => (Colors.green, 'Baixo'),
      };

  @override
  Widget build(BuildContext context) {
    final (riscoColor, riscoLabel) = _riscoStyle;
    final item = widget.item;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 6),
      color: item.selecionado ? null : Colors.grey.withValues(alpha: 0.06),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => _expanded = !_expanded),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 12, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(
                    value: item.selecionado,
                    onChanged: (_) => widget.onToggle(item),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 6),
                        Text(
                          item.titulo,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: item.selecionado
                                ? null
                                : Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            // Badge de risco
                            _MiniChip(
                              label: riscoLabel,
                              color: riscoColor,
                            ),
                            // Badge de critico
                            if (item.critico)
                              const _MiniChip(
                                label: 'Crítico',
                                color: Colors.red,
                              ),
                            // Badge de validacao profissional
                            if (item.requerValidacaoProfissional)
                              const _MiniChip(
                                label: 'Validar c/ profissional',
                                color: Colors.deepPurple,
                              ),
                            // Norma referencia
                            if (item.normaReferencia != null &&
                                item.normaReferencia!.isNotEmpty)
                              _MiniChip(
                                label: item.normaReferencia!,
                                color: Colors.blueGrey,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _expanded
                        ? Icons.expand_less
                        : Icons.expand_more,
                    size: 20,
                    color: Colors.grey,
                  ),
                ],
              ),
              // Detalhes expandidos
              if (_expanded) ...[
                const Divider(height: 16),
                Padding(
                  padding: const EdgeInsets.only(left: 48, right: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.descricao,
                        style: const TextStyle(
                            fontSize: 12, height: 1.5),
                      ),
                      if (item.comoVerificar.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Row(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.search,
                                size: 14,
                                color: Theme.of(context)
                                    .colorScheme
                                    .primary),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'Como verificar: ${item.comoVerificar}',
                                style: TextStyle(
                                  fontSize: 12,
                                  height: 1.5,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 6),
                      Text(
                        'Confiança: ${item.confianca}%',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Chip de característica ─────────────────────────────────────────────────

class _CaracteristicaChip extends StatelessWidget {
  const _CaracteristicaChip({required this.caracteristica});

  final CaracteristicaIdentificada caracteristica;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: caracteristica.descricaoNoProjeto,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Theme.of(context)
              .colorScheme
              .primary
              .withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Theme.of(context)
                .colorScheme
                .primary
                .withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              caracteristica.nomeLegivel,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '${caracteristica.confianca}%',
              style: TextStyle(
                fontSize: 10,
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Mini chip (risco, norma, crítico) ──────────────────────────────────────

class _MiniChip extends StatelessWidget {
  const _MiniChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ─── Barra inferior de aplicação ────────────────────────────────────────────

class _BottomApplyBar extends StatelessWidget {
  const _BottomApplyBar({
    required this.aplicando,
    required this.totalSelecionados,
    required this.totalItens,
    required this.onAplicar,
  });

  final bool aplicando;
  final int totalSelecionados;
  final int totalItens;
  final VoidCallback onAplicar;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Text(
                '$totalSelecionados de $totalItens itens selecionados',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
              ),
            ),
            FilledButton.icon(
              onPressed:
                  (aplicando || totalSelecionados == 0) ? null : onAplicar,
              icon: aplicando
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.check, size: 18),
              label: Text(aplicando
                  ? 'Aplicando...'
                  : 'Aplicar $totalSelecionados itens'),
            ),
          ],
        ),
      ),
    );
  }
}
