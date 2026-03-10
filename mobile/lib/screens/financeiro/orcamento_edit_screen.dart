import "package:flutter/material.dart";
import "package:flutter/services.dart";

import "../../models/etapa.dart";
import "../../models/financeiro.dart";
import "../../services/api_client.dart";

class OrcamentoEditScreen extends StatefulWidget {
  const OrcamentoEditScreen({
    super.key,
    required this.obraId,
    required this.api,
  });

  final String obraId;
  final ApiClient api;

  @override
  State<OrcamentoEditScreen> createState() => _OrcamentoEditScreenState();
}

class _OrcamentoEditScreenState extends State<OrcamentoEditScreen> {
  bool _loading = true;
  bool _saving = false;
  String? _error;
  List<Etapa> _etapas = [];
  // ignore: unused_field — kept for potential future use
  Map<String, OrcamentoEtapa> _orcamentos = {};
  final Map<String, TextEditingController> _previstoControllers = {};
  final Map<String, TextEditingController> _realizadoControllers = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    for (final c in _previstoControllers.values) {
      c.dispose();
    }
    for (final c in _realizadoControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final etapas = await widget.api.listarEtapas(widget.obraId);
      final orcamentos = await widget.api.listarOrcamento(widget.obraId);
      final orcMap = <String, OrcamentoEtapa>{};
      for (final o in orcamentos) {
        orcMap[o.etapaId] = o;
      }
      setState(() {
        _etapas = etapas;
        _orcamentos = orcMap;
        for (final etapa in etapas) {
          final orc = orcMap[etapa.id];
          _previstoControllers[etapa.id] = TextEditingController(
            text: orc != null && orc.valorPrevisto > 0
                ? orc.valorPrevisto.toStringAsFixed(2)
                : "",
          );
          _realizadoControllers[etapa.id] = TextEditingController(
            text: orc?.valorRealizado != null
                ? orc!.valorRealizado!.toStringAsFixed(2)
                : "",
          );
        }
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _salvar() async {
    setState(() => _saving = true);
    try {
      final itens = <Map<String, dynamic>>[];
      for (final etapa in _etapas) {
        final prevText =
            _previstoControllers[etapa.id]?.text.replaceAll(",", ".") ?? "";
        final realText =
            _realizadoControllers[etapa.id]?.text.replaceAll(",", ".") ?? "";
        final previsto = double.tryParse(prevText) ?? 0.0;
        final realizado = realText.isEmpty ? null : double.tryParse(realText);
        itens.add({
          "etapa_id": etapa.id,
          "valor_previsto": previsto,
          if (realizado != null) "valor_realizado": realizado,
        });
      }
      await widget.api.salvarOrcamento(widget.obraId, itens);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Orçamento salvo com sucesso")),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro ao salvar: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Editar Orçamento"),
        actions: [
          TextButton.icon(
            onPressed: _saving ? null : _salvar,
            icon: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save),
            label: const Text("Salvar"),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text("Erro: $_error"));
    }
    if (_etapas.isEmpty) {
      return const Center(child: Text("Nenhuma etapa encontrada"));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _etapas.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final etapa = _etapas[index];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  etapa.nome,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _previstoControllers[etapa.id],
                        decoration: const InputDecoration(
                          labelText: "Previsto (R\$)",
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r"[\d.,]")),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _realizadoControllers[etapa.id],
                        decoration: const InputDecoration(
                          labelText: "Realizado (R\$)",
                          border: OutlineInputBorder(),
                          isDense: true,
                          hintText: "Auto (despesas)",
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r"[\d.,]")),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
