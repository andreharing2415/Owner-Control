import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../api/api.dart';
import '../utils/auth_error_handler.dart';

class LancarDespesaScreen extends StatefulWidget {
  const LancarDespesaScreen({
    super.key,
    required this.obra,
    required this.etapas,
  });

  final Obra obra;
  final List<Etapa> etapas;

  @override
  State<LancarDespesaScreen> createState() => _LancarDespesaScreenState();
}

class _LancarDespesaScreenState extends State<LancarDespesaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _valorCtrl = TextEditingController();
  final _descricaoCtrl = TextEditingController();
  final ApiClient _api = ApiClient();

  Etapa? _etapaSelecionada;
  String? _categoria;
  DateTime _data = DateTime.now();
  bool _salvando = false;

  static const _categorias = [
    'Material',
    'Mão de obra',
    'Equipamento',
    'Projeto',
    'Licença / Taxa',
    'Outros',
  ];

  Future<void> _selecionarData() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _data,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _data = picked);
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _salvando = true);
    try {
      final valor = double.parse(
        _valorCtrl.text.replaceAll('.', '').replaceAll(',', '.'),
      );
      await _api.lancarDespesa(
        obraId: widget.obra.id,
        despesa: DespesaCreate(
          etapaId: _etapaSelecionada?.id,
          valor: valor,
          descricao: _descricaoCtrl.text.trim(),
          data: DateFormat('yyyy-MM-dd').format(_data),
          categoria: _categoria,
        ),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (e is AuthExpiredException) { if (mounted) handleApiError(context, e); return; }
      if (!mounted) return;
      setState(() => _salvando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  void dispose() {
    _valorCtrl.dispose();
    _descricaoCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel = DateFormat('dd/MM/yyyy').format(_data);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lançar Despesa'),
        centerTitle: false,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Obra (read-only info)
            Card(
              elevation: 0,
              child: ListTile(
                leading: const Icon(Icons.home_work_outlined),
                title: Text(widget.obra.nome),
                subtitle: Text(widget.obra.localizacao ?? 'Sem localização'),
              ),
            ),
            const SizedBox(height: 16),

            // Valor
            TextFormField(
              controller: _valorCtrl,
              decoration: const InputDecoration(
                labelText: 'Valor (R\$) *',
                border: OutlineInputBorder(),
                prefixText: 'R\$ ',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Informe o valor';
                final parsed = double.tryParse(
                  v.replaceAll('.', '').replaceAll(',', '.'),
                );
                if (parsed == null || parsed <= 0) return 'Valor inválido';
                return null;
              },
            ),
            const SizedBox(height: 14),

            // Descrição
            TextFormField(
              controller: _descricaoCtrl,
              decoration: const InputDecoration(
                labelText: 'Descrição *',
                border: OutlineInputBorder(),
                hintText: 'Ex: Compra de cimento, mão de obra fundação...',
              ),
              maxLines: 2,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Informe a descrição' : null,
            ),
            const SizedBox(height: 14),

            // Data
            InkWell(
              onTap: _selecionarData,
              borderRadius: BorderRadius.circular(4),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Data *',
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.calendar_today_outlined),
                ),
                child: Text(dateLabel),
              ),
            ),
            const SizedBox(height: 14),

            // Etapa (opcional)
            DropdownButtonFormField<Etapa?>(
              initialValue: _etapaSelecionada,
              decoration: const InputDecoration(
                labelText: 'Etapa (opcional)',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<Etapa?>(
                  value: null,
                  child: Text('Sem etapa específica'),
                ),
                ...widget.etapas.map(
                  (e) => DropdownMenuItem<Etapa?>(
                    value: e,
                    child: Text(e.nome, overflow: TextOverflow.ellipsis),
                  ),
                ),
              ],
              onChanged: (e) => setState(() => _etapaSelecionada = e),
            ),
            const SizedBox(height: 14),

            // Categoria (opcional)
            DropdownButtonFormField<String?>(
              initialValue: _categoria,
              decoration: const InputDecoration(
                labelText: 'Categoria (opcional)',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Sem categoria'),
                ),
                ..._categorias.map(
                  (c) => DropdownMenuItem<String?>(
                    value: c,
                    child: Text(c),
                  ),
                ),
              ],
              onChanged: (c) => setState(() => _categoria = c),
            ),
            const SizedBox(height: 28),

            FilledButton.icon(
              onPressed: _salvando ? null : _salvar,
              icon: _salvando
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
              label: Text(_salvando ? 'Salvando...' : 'Lançar Despesa'),
            ),
          ],
        ),
      ),
    );
  }
}
