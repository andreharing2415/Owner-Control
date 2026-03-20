import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../api/api.dart';
import '../utils/auth_error_handler.dart';

class OrcamentoEditScreen extends StatefulWidget {
  const OrcamentoEditScreen({super.key, required this.obraId});
  final String obraId;

  @override
  State<OrcamentoEditScreen> createState() => _OrcamentoEditScreenState();
}

class _OrcamentoEditScreenState extends State<OrcamentoEditScreen> {
  final _api = ApiClient();
  final _currencyFormat = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
  bool _loading = true;
  bool _saving = false;
  String? _error;

  List<Etapa> _etapas = [];
  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final etapas = await _api.listarEtapas(widget.obraId);
      final orcamentos = await _api.consultarOrcamento(widget.obraId);

      final map = <String, double>{};
      for (final o in orcamentos) {
        map[o.etapaId] = o.valorPrevisto;
      }

      for (final e in etapas) {
        final val = map[e.id] ?? 0;
        _controllers[e.id] = TextEditingController(
          text: val > 0 ? val.toStringAsFixed(2) : '',
        );
      }

      setState(() {
        _etapas = etapas;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = '$e'.replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  double get _total {
    double sum = 0;
    for (final e in _etapas) {
      final text = _controllers[e.id]?.text.replaceAll(',', '.') ?? '';
      sum += double.tryParse(text) ?? 0;
    }
    return sum;
  }

  Future<void> _salvar() async {
    setState(() => _saving = true);
    try {
      final itens = <OrcamentoEtapaCreate>[];
      for (final e in _etapas) {
        final text = _controllers[e.id]?.text.replaceAll(',', '.') ?? '';
        final valor = double.tryParse(text) ?? 0;
        if (valor > 0) {
          itens.add(OrcamentoEtapaCreate(etapaId: e.id, valorPrevisto: valor));
        }
      }
      await _api.registrarOrcamento(obraId: widget.obraId, itens: itens);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Orçamento salvo com sucesso!')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) handleApiError(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Orçamento por Etapa'),
        actions: [
          TextButton.icon(
            onPressed: _saving ? null : _salvar,
            icon: _saving
                ? const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save),
            label: const Text('Salvar'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : Column(
                  children: [
                    // Total
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Total Previsto',
                              style: theme.textTheme.titleSmall),
                          Text(
                            _currencyFormat.format(_total),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Lista de etapas
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: _etapas.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (ctx, i) {
                          final etapa = _etapas[i];
                          return Card(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    etapa.nome,
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: _controllers[etapa.id],
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                            decimal: true),
                                    inputFormatters: [
                                      FilteringTextInputFormatter.allow(
                                          RegExp(r'[\d.,]')),
                                    ],
                                    decoration: const InputDecoration(
                                      labelText: 'Valor Previsto (R\$)',
                                      border: OutlineInputBorder(),
                                      prefixText: 'R\$ ',
                                    ),
                                    onChanged: (_) => setState(() {}),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }
}
