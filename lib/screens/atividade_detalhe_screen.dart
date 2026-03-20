import 'package:flutter/material.dart';
import '../api/api.dart';
import '../utils/auth_error_handler.dart';
import '../widgets/atividade_detalhe/checklist_tab.dart';
import '../widgets/atividade_detalhe/servicos_tab.dart';
import '../widgets/atividade_detalhe/info_tab.dart';

class AtividadeDetalheScreen extends StatefulWidget {
  const AtividadeDetalheScreen({
    super.key,
    required this.atividade,
    this.initialTab = 0,
  });

  final AtividadeCronograma atividade;
  final int initialTab;

  @override
  State<AtividadeDetalheScreen> createState() =>
      _AtividadeDetalheScreenState();
}

class _AtividadeDetalheScreenState extends State<AtividadeDetalheScreen> {
  final ApiClient _api = ApiClient();
  final _checklistKey = GlobalKey<ChecklistTabState>();

  Future<void> _atualizarStatus() async {
    const statusLabels = {
      "pendente": "Pendente",
      "em_andamento": "Em andamento",
      "concluida": "Concluida",
    };
    final statusOptions = statusLabels.entries.toList();
    final novoStatus = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text("Atualizar status"),
        children: statusOptions.map((entry) {
          return SimpleDialogOption(
            onPressed: () => Navigator.pop(context, entry.key),
            child: Text(entry.value),
          );
        }).toList(),
      ),
    );
    if (novoStatus != null && novoStatus != widget.atividade.status) {
      try {
        await _api.atualizarAtividade(
          atividadeId: widget.atividade.id,
          status: novoStatus,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Status atualizado.")),
          );
          Navigator.pop(context, true);
        }
      } catch (e) {
        if (e is AuthExpiredException) {
          if (mounted) handleApiError(context, e);
          return;
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Erro: $e")),
          );
        }
      }
    }
  }

  Future<void> _registrarDespesa() async {
    final valorController = TextEditingController();
    final descricaoController = TextEditingController();
    final categoriaController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Lancar despesa"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: descricaoController,
                decoration: const InputDecoration(labelText: "Descricao *"),
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: valorController,
                decoration: const InputDecoration(labelText: "Valor (R\$) *"),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: categoriaController,
                decoration: const InputDecoration(labelText: "Categoria"),
                textCapitalization: TextCapitalization.words,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Lancar"),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    final valor =
        double.tryParse(valorController.text.replaceAll(",", "."));
    if (valor == null || descricaoController.text.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Valor e descricao sao obrigatorios.")),
        );
      }
      return;
    }

    try {
      final now = DateTime.now();
      final dataStr =
          "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
      await _api.lancarDespesaAtividade(
        atividadeId: widget.atividade.id,
        valor: valor,
        descricao: descricaoController.text.trim(),
        data: dataStr,
        categoria: categoriaController.text.trim().isNotEmpty
            ? categoriaController.text.trim()
            : null,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Despesa lancada com sucesso.")),
        );
      }
    } catch (e) {
      if (e is AuthExpiredException) {
        if (mounted) handleApiError(context, e);
        return;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      initialIndex: widget.initialTab,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.atividade.nome),
          bottom: const TabBar(
            tabs: [
              Tab(text: "Checklist"),
              Tab(text: "Servicos"),
              Tab(text: "Info"),
            ],
          ),
        ),
        floatingActionButton: Builder(
          builder: (context) {
            final controller = DefaultTabController.of(context);
            return ListenableBuilder(
              listenable: controller,
              builder: (context, _) {
                if (controller.index == 0) {
                  return FloatingActionButton(
                    onPressed: () =>
                        _checklistKey.currentState?.criarItem(),
                    child: const Icon(Icons.add),
                  );
                }
                return const SizedBox.shrink();
              },
            );
          },
        ),
        body: TabBarView(
          children: [
            ChecklistTab(
              key: _checklistKey,
              atividadeId: widget.atividade.id,
            ),
            ServicosTab(atividadeId: widget.atividade.id),
            InfoTab(
              atividade: widget.atividade,
              onStatusChanged: _atualizarStatus,
              onDespesaRegistrada: _registrarDespesa,
            ),
          ],
        ),
      ),
    );
  }
}
