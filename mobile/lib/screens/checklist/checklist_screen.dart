import "package:flutter/material.dart";
import "package:intl/intl.dart";
import "package:provider/provider.dart";

import "../../models/checklist_item.dart";
import "../../models/etapa.dart";
import "../../providers/auth_provider.dart";
import "../../providers/subscription_provider.dart";
import "../../services/api_client.dart";
import "../subscription/paywall_screen.dart";
import "detalhe_item_screen.dart";

class ChecklistScreen extends StatefulWidget {
  const ChecklistScreen({super.key, required this.etapa, required this.api});

  final Etapa etapa;
  final ApiClient api;

  @override
  State<ChecklistScreen> createState() => _ChecklistScreenState();
}

class _ChecklistScreenState extends State<ChecklistScreen> {
  late Future<List<ChecklistItem>> _itensFuture;
  late Etapa _etapa;

  @override
  void initState() {
    super.initState();
    _etapa = widget.etapa;
    _itensFuture = widget.api.listarItens(widget.etapa.id);
  }

  Future<void> _refresh() async {
    setState(() {
      _itensFuture = widget.api.listarItens(_etapa.id);
    });
  }

  // Agrupa e ordena itens: por grupo, depois por ordem dentro do grupo.
  // Grupo "Geral" sempre por último.
  Map<String, List<ChecklistItem>> _agrupar(List<ChecklistItem> itens) {
    final map = <String, List<ChecklistItem>>{};
    for (final item in itens) {
      map.putIfAbsent(item.grupo, () => []).add(item);
    }
    for (final grupo in map.keys) {
      map[grupo]!.sort((a, b) => a.ordem.compareTo(b.ordem));
    }
    // Ordenar grupos: "Geral" por último
    final grupos = map.keys.toList()
      ..sort((a, b) {
        if (a == "Geral") return 1;
        if (b == "Geral") return -1;
        return a.compareTo(b);
      });
    return {for (final g in grupos) g: map[g]!};
  }

  Future<void> _criarItem() async {
    final tituloController = TextEditingController();
    final descricaoController = TextEditingController();
    bool critico = false;
    String grupo = "Geral";
    int ordem = 0;
    bool buscandoGrupo = false;

    final created = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: const Text("Novo item"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: tituloController,
                decoration: const InputDecoration(labelText: "Título *"),
                textCapitalization: TextCapitalization.sentences,
                onChanged: (_) async {
                  final t = tituloController.text.trim();
                  if (t.length < 5) return;
                  setLocalState(() => buscandoGrupo = true);
                  try {
                    final sugestao = await widget.api.sugerirGrupoItem(
                      etapaId: _etapa.id,
                      titulo: t,
                    );
                    setLocalState(() {
                      grupo = sugestao["grupo"] as String? ?? "Geral";
                      ordem = sugestao["ordem"] as int? ?? 0;
                      buscandoGrupo = false;
                    });
                  } catch (_) {
                    setLocalState(() => buscandoGrupo = false);
                  }
                },
              ),
              const SizedBox(height: 8),
              TextField(
                controller: descricaoController,
                decoration: const InputDecoration(labelText: "Descrição"),
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text("Grupo:", style: TextStyle(fontSize: 13)),
                  const SizedBox(width: 8),
                  buscandoGrupo
                      ? const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : Chip(
                          label: Text(grupo, style: const TextStyle(fontSize: 12)),
                          visualDensity: VisualDensity.compact,
                        ),
                ],
              ),
              StatefulBuilder(
                builder: (context, ss) => SwitchListTile(
                  title: const Text("Item crítico"),
                  subtitle: const Text("Exige evidência obrigatória"),
                  value: critico,
                  onChanged: (v) => ss(() => critico = v),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text("Cancelar")),
            ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text("Salvar")),
          ],
        ),
      ),
    );

    if (created == true && tituloController.text.trim().isNotEmpty) {
      try {
        await widget.api.criarItem(
          etapaId: _etapa.id,
          titulo: tituloController.text.trim(),
          descricao: descricaoController.text.trim(),
          critico: critico,
          grupo: grupo,
          ordem: ordem,
        );
        await _refresh();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text("Erro: $e")));
        }
      }
    }
  }

  Future<bool> _confirmarRemocao(ChecklistItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Remover item"),
        content: Text("Deseja remover \"${item.titulo}\"?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancelar"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Remover", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    return confirm == true;
  }

  Future<void> _deletarItem(ChecklistItem item) async {
    try {
      await widget.api.deletarItem(item.id);
      await _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Erro ao remover: $e")));
      }
    }
  }

  Future<void> _enriquecerTodos() async {
    final confirma = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.auto_awesome, color: Colors.blue),
        title: const Text("Enriquecer Checklist com IA?"),
        content: const Text(
          "A IA vai analisar todos os itens padrão desta etapa e preencher "
          "os 3 blocos (projeto, verificação, norma) com base nos documentos da obra.",
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Cancelar")),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("Enriquecer")),
        ],
      ),
    );
    if (confirma != true) return;

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text("Enriquecendo itens com IA..."),
          duration: Duration(seconds: 60)),
    );

    try {
      final result = await widget.api.enriquecerChecklist(_etapa.id);
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text("${result['enriquecidos']} itens enriquecidos!")),
        );
        _refresh();
      }
    } on FeatureGateException {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        PaywallScreen.show(context,
            message: "Enriqueça o checklist com IA no plano Dono da Obra");
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro: $e")),
        );
      }
    }
  }

  Future<void> _editarPrazo() async {
    DateTime? prazoPrevisto = _etapa.prazoPrevisto;
    DateTime? prazoExecutado = _etapa.prazoExecutado;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModal) => Padding(
          padding: EdgeInsets.only(
            left: 24, right: 24, top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Prazo da etapa",
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              _DatePickerRow(
                label: "Prazo previsto",
                value: prazoPrevisto,
                onChanged: (d) => setModal(() => prazoPrevisto = d),
              ),
              const SizedBox(height: 16),
              _DatePickerRow(
                label: "Data executado",
                value: prazoExecutado,
                onChanged: (d) => setModal(() => prazoExecutado = d),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    try {
                      final etapaAtualizada =
                          await widget.api.atualizarPrazoEtapa(
                        etapaId: _etapa.id,
                        prazoPrevisto: prazoPrevisto,
                        prazoExecutado: prazoExecutado,
                      );
                      if (mounted) {
                        setState(() => _etapa = etapaAtualizada);
                        Navigator.pop(context);
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("Erro: $e")));
                      }
                    }
                  },
                  child: const Text("Salvar prazo"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case "ok": return Colors.green;
      case "nao_conforme": return Colors.red;
      default: return Colors.grey;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case "ok": return "OK";
      case "nao_conforme": return "Não conforme";
      default: return "Pendente";
    }
  }

  bool get _prazoPendente =>
      _etapa.prazoPrevisto != null &&
      _etapa.prazoPrevisto!.isBefore(DateTime.now()) &&
      _etapa.prazoExecutado == null;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat("dd/MM/yy");
    final prazoLabel = _etapa.prazoPrevisto != null
        ? fmt.format(_etapa.prazoPrevisto!)
        : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(_etapa.nome),
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_awesome),
            tooltip: "Enriquecer todos com IA",
            onPressed: _enriquecerTodos,
          ),
          IconButton(
            onPressed: _editarPrazo,
            icon: Badge(
              isLabelVisible: _prazoPendente,
              child: const Icon(Icons.calendar_today_outlined),
            ),
            tooltip: prazoLabel != null
                ? "Prazo: $prazoLabel"
                : "Definir prazo",
          ),
          IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh)),
        ],
      ),
      floatingActionButton: Builder(
        builder: (context) {
          final sub = context.watch<SubscriptionProvider>();
          final user = context.read<AuthProvider>().user;
          final isConvidado = user?.isConvidado ?? false;
          // Convidado pode criar, Dono pode criar, Free não pode
          final canCreate = isConvidado || sub.canCreateChecklistItems;
          if (!canCreate) {
            return FloatingActionButton(
              onPressed: () => PaywallScreen.show(context,
                  message: "Crie itens no checklist com o plano Dono da Obra"),
              backgroundColor: Colors.grey,
              child: const Icon(Icons.lock),
            );
          }
          return FloatingActionButton(
            onPressed: _criarItem,
            child: const Icon(Icons.add),
          );
        },
      ),
      body: FutureBuilder<List<ChecklistItem>>(
        future: _itensFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 12),
                  Text("Erro: ${snapshot.error}", textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _refresh,
                    child: const Text("Tentar novamente"),
                  ),
                ],
              ),
            );
          }
          final itens = snapshot.data ?? [];
          if (itens.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.checklist, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text("Nenhum item no checklist",
                      style: Theme.of(context).textTheme.titleMedium),
                ],
              ),
            );
          }
          final grupos = _agrupar(itens);
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
              children: [
                for (final entry in grupos.entries) ...[
                  _GrupoHeader(
                    nome: entry.key,
                    itens: entry.value,
                  ),
                  const SizedBox(height: 4),
                  for (final item in entry.value)
                    Builder(
                      builder: (context) {
                        final sub = context.read<SubscriptionProvider>();
                        final canDelete = sub.isDono;
                        return _ItemCard(
                          item: item,
                          statusColor: _statusColor(item.status),
                          statusLabel: _statusLabel(item.status),
                          canDelete: canDelete,
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => DetalheItemScreen(
                                  item: item,
                                  api: widget.api,
                                  etapaNome: _etapa.nome,
                                ),
                              ),
                            );
                            await _refresh();
                          },
                          onDelete: canDelete
                              ? () async {
                                  if (await _confirmarRemocao(item)) {
                                    await _deletarItem(item);
                                  }
                                }
                              : null,
                        );
                      },
                    ),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─── Widgets auxiliares ──────────────────────────────────────────────────────

class _GrupoHeader extends StatelessWidget {
  const _GrupoHeader({required this.nome, required this.itens});

  final String nome;
  final List<ChecklistItem> itens;

  @override
  Widget build(BuildContext context) {
    final concluidos = itens.where((i) => i.status == "ok").length;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            nome,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 8),
          Text(
            "$concluidos/${itens.length}",
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          const Expanded(child: Divider(indent: 8)),
        ],
      ),
    );
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({
    required this.item,
    required this.statusColor,
    required this.statusLabel,
    required this.onTap,
    this.onDelete,
    this.canDelete = true,
  });

  final ChecklistItem item;
  final Color statusColor;
  final String statusLabel;
  final VoidCallback onTap;
  final VoidCallback? onDelete;
  final bool canDelete;

  @override
  Widget build(BuildContext context) {
    final card = Card(
      margin: const EdgeInsets.only(bottom: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.titulo,
                        style: const TextStyle(fontWeight: FontWeight.w500)),
                    if (item.descricao != null && item.descricao!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          item.descricao!,
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey[600]),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        fontSize: 11,
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  // Severity badge
                  if (item.severidade != null) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _severidadeColor(item.severidade!)
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        item.severidade!.toUpperCase(),
                        style: TextStyle(
                          color: _severidadeColor(item.severidade!),
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                  // Critical badge
                  if (item.critico) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        "Crítico",
                        style: TextStyle(color: Colors.red, fontSize: 10),
                      ),
                    ),
                  ],
                  // AI enriched icon
                  if (item.isEnriquecido) ...[
                    const SizedBox(height: 4),
                    Icon(Icons.auto_awesome,
                        size: 14, color: Colors.amber[700]),
                  ],
                ],
              ),
              if (canDelete)
                PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == "remover") onDelete?.call();
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: "remover",
                      child: Row(children: [
                        Icon(Icons.delete_outline, size: 18, color: Colors.red),
                        SizedBox(width: 8),
                        Text("Remover", style: TextStyle(color: Colors.red)),
                      ]),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );

    if (!canDelete) return card;

    return Dismissible(
      key: Key(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        onDelete?.call();
        return false;
      },
      child: card,
    );
  }

}

Color _severidadeColor(String severidade) {
  switch (severidade) {
    case "alto":
      return Colors.red;
    case "medio":
      return Colors.orange;
    case "baixo":
      return Colors.green;
    default:
      return Colors.grey;
  }
}

class _DatePickerRow extends StatelessWidget {
  const _DatePickerRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat("dd/MM/yyyy");
    return Row(
      children: [
        Expanded(
          child: Text(
            value != null ? "$label: ${fmt.format(value!)}" : label,
            style: const TextStyle(fontSize: 14),
          ),
        ),
        TextButton(
          onPressed: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: value ?? DateTime.now(),
              firstDate: DateTime(2020),
              lastDate: DateTime(2035),
            );
            if (picked != null) onChanged(picked);
          },
          child: Text(value != null ? "Alterar" : "Selecionar"),
        ),
        if (value != null)
          IconButton(
            icon: const Icon(Icons.clear, size: 18),
            onPressed: () => onChanged(null),
          ),
      ],
    );
  }
}
