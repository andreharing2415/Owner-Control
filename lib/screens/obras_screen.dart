import 'package:flutter/material.dart';
import '../api/api.dart';
import 'etapas_screen.dart';
import '../utils/auth_error_handler.dart';

class ObrasScreen extends StatefulWidget {
  const ObrasScreen({super.key, this.modoSelecao = false});

  final bool modoSelecao;

  @override
  State<ObrasScreen> createState() => _ObrasScreenState();
}

class _ObrasScreenState extends State<ObrasScreen> {
  final ApiClient _api = ApiClient();
  late Future<List<Obra>> _obrasFuture;

  @override
  void initState() {
    super.initState();
    _obrasFuture = _api.listarObras();
  }

  Future<void> _refresh() async {
    setState(() {
      _obrasFuture = _api.listarObras();
    });
  }

  Future<void> _criarObra() async {
    final nomeController = TextEditingController();
    final localController = TextEditingController();
    final orcamentoController = TextEditingController();
    DateTime? dataInicio;
    DateTime? dataFim;

    final created = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          String fmtDate(DateTime? d) =>
              d == null ? "Não definida" : "${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}";

          return AlertDialog(
            title: const Text("Nova Obra"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nomeController,
                    decoration: const InputDecoration(labelText: "Nome da obra *"),
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: localController,
                    decoration: const InputDecoration(labelText: "Localização"),
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: orcamentoController,
                    decoration: const InputDecoration(labelText: "Orçamento (R\$)"),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                  const SizedBox(height: 12),
                  const Text("Datas da obra", style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.calendar_today, size: 16),
                          label: Text("Início\n${fmtDate(dataInicio)}", textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)),
                          onPressed: () async {
                            final d = await showDatePicker(
                              context: context,
                              initialDate: dataInicio ?? DateTime.now(),
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100),
                              helpText: "Data de início",
                            );
                            if (d != null) setDialogState(() => dataInicio = d);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.event, size: 16),
                          label: Text("Previsão fim\n${fmtDate(dataFim)}", textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)),
                          onPressed: () async {
                            final d = await showDatePicker(
                              context: context,
                              initialDate: dataFim ?? (dataInicio ?? DateTime.now()).add(const Duration(days: 180)),
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100),
                              helpText: "Previsão de término",
                            );
                            if (d != null) setDialogState(() => dataFim = d);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancelar")),
              ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text("Criar")),
            ],
          );
        },
      ),
    );

    if (created == true && nomeController.text.trim().isNotEmpty) {
      try {
        final orcamento = double.tryParse(orcamentoController.text.replaceAll(",", "."));
        String? fmtIso(DateTime? d) => d == null ? null : "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";
        await _api.criarObra(
          nome: nomeController.text.trim(),
          localizacao: localController.text.trim(),
          orcamento: orcamento,
          dataInicio: fmtIso(dataInicio),
          dataFim: fmtIso(dataFim),
        );
        await _refresh();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Obra criada com etapas e checklists padrão.")),
          );
        }
      } catch (e) {
        if (e is AuthExpiredException) { if (mounted) handleApiError(context, e); return; }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Erro ao criar obra: $e")),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Obras"),
        actions: [
          IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _criarObra,
        icon: const Icon(Icons.add),
        label: const Text("Nova Obra"),
      ),
      body: FutureBuilder<List<Obra>>(
        future: _obrasFuture,
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
                  Text("Erro ao carregar obras:\n${snapshot.error}", textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  ElevatedButton(onPressed: _refresh, child: const Text("Tentar novamente")),
                ],
              ),
            );
          }
          final obras = snapshot.data ?? [];
          if (obras.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.home_work_outlined, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text("Nenhuma obra cadastrada", style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  const Text("Toque em 'Nova Obra' para começar."),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: obras.length,
              itemBuilder: (context, index) {
                final obra = obras[index];
                String subtitulo = obra.localizacao ?? "Localização não informada";
                if (obra.dataInicio != null || obra.dataFim != null) {
                  final partes = [
                    if (obra.dataInicio != null) "Início: ${obra.dataInicio!.split('-').reversed.join('/')}",
                    if (obra.dataFim != null) "Fim: ${obra.dataFim!.split('-').reversed.join('/')}",
                  ];
                  subtitulo += "\n${partes.join('  ·  ')}";
                }
                return Card(
                  child: ListTile(
                    isThreeLine: obra.dataInicio != null || obra.dataFim != null,
                    leading: const CircleAvatar(child: Icon(Icons.home_work)),
                    title: Text(obra.nome, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(subtitulo),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      if (widget.modoSelecao) {
                        Navigator.pop(context, obra);
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => EtapasScreen(obra: obra)),
                        );
                      }
                    },
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
