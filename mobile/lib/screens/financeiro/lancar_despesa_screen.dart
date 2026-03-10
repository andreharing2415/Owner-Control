import "package:flutter/material.dart";
import "package:flutter/services.dart";

import "../../models/etapa.dart";
import "../../services/api_client.dart";

class LancarDespesaScreen extends StatefulWidget {
  const LancarDespesaScreen({
    super.key,
    required this.obraId,
    required this.api,
    this.etapaId,
    this.etapaNome,
  });

  final String obraId;
  final ApiClient api;
  final String? etapaId;
  final String? etapaNome;

  @override
  State<LancarDespesaScreen> createState() => _LancarDespesaScreenState();
}

class _LancarDespesaScreenState extends State<LancarDespesaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _valorController = TextEditingController();
  final _descricaoController = TextEditingController();
  final _categoriaController = TextEditingController();

  DateTime _dataSelecionada = DateTime.now();
  String? _etapaIdSelecionada;
  List<Etapa> _etapas = [];
  bool _carregando = false;
  bool _carregandoEtapas = true;

  @override
  void initState() {
    super.initState();
    _etapaIdSelecionada = widget.etapaId;
    _carregarEtapas();
  }

  @override
  void dispose() {
    _valorController.dispose();
    _descricaoController.dispose();
    _categoriaController.dispose();
    super.dispose();
  }

  Future<void> _carregarEtapas() async {
    try {
      final etapas = await widget.api.listarEtapas(widget.obraId);
      if (mounted) {
        setState(() {
          _etapas = etapas;
          _carregandoEtapas = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _carregandoEtapas = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Erro ao carregar etapas: $e")));
      }
    }
  }

  Future<void> _selecionarData() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dataSelecionada,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() => _dataSelecionada = picked);
    }
  }

  String _formatDate(DateTime date) {
    final d = date.day.toString().padLeft(2, "0");
    final m = date.month.toString().padLeft(2, "0");
    return "$d/$m/${date.year}";
  }

  String _formatDateIso(DateTime date) {
    final d = date.day.toString().padLeft(2, "0");
    final m = date.month.toString().padLeft(2, "0");
    return "${date.year}-$m-$d";
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;

    final valorText = _valorController.text
        .replaceAll(".", "")
        .replaceAll(",", ".")
        .trim();
    final valor = double.tryParse(valorText);
    if (valor == null || valor <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Valor invalido")),
      );
      return;
    }

    setState(() => _carregando = true);
    try {
      await widget.api.criarDespesa(
        obraId: widget.obraId,
        valor: valor,
        descricao: _descricaoController.text.trim(),
        data: _formatDateIso(_dataSelecionada),
        etapaId: _etapaIdSelecionada,
        categoria: _categoriaController.text.trim().isNotEmpty
            ? _categoriaController.text.trim()
            : null,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Despesa lancada com sucesso")),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _carregando = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Erro: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Lancar Despesa"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _valorController,
                decoration: const InputDecoration(
                  labelText: "Valor (R\$) *",
                  prefixText: "R\$ ",
                  border: OutlineInputBorder(),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r"[\d.,]")),
                ],
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return "Informe o valor";
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descricaoController,
                decoration: const InputDecoration(
                  labelText: "Descricao *",
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.sentences,
                maxLines: 2,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return "Informe a descricao";
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: _selecionarData,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: "Data",
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.calendar_today),
                  ),
                  child: Text(_formatDate(_dataSelecionada)),
                ),
              ),
              const SizedBox(height: 16),
              _carregandoEtapas
                  ? const Center(child: CircularProgressIndicator())
                  : DropdownButtonFormField<String>(
                      initialValue: _etapaIdSelecionada,
                      decoration: const InputDecoration(
                        labelText: "Etapa",
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text("Nenhuma (geral)"),
                        ),
                        ..._etapas.map(
                          (etapa) => DropdownMenuItem<String>(
                            value: etapa.id,
                            child: Text(etapa.nome),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() => _etapaIdSelecionada = value);
                      },
                    ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _categoriaController,
                decoration: const InputDecoration(
                  labelText: "Categoria",
                  border: OutlineInputBorder(),
                  hintText: "Ex: Material, Mao de obra, Equipamento",
                ),
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _carregando ? null : _salvar,
                icon: _carregando
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: Text(_carregando ? "Salvando..." : "Salvar Despesa"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
