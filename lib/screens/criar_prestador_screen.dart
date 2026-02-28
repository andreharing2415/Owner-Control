import 'package:flutter/material.dart';

import '../api/api.dart';
import 'prestadores_screen.dart' show subcategoriaLabels;
import '../utils/auth_error_handler.dart';

class CriarPrestadorScreen extends StatefulWidget {
  const CriarPrestadorScreen({super.key});

  @override
  State<CriarPrestadorScreen> createState() => _CriarPrestadorScreenState();
}

class _CriarPrestadorScreenState extends State<CriarPrestadorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nomeCtrl = TextEditingController();
  final _regiaoCtrl = TextEditingController();
  final _telefoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final ApiClient _api = ApiClient();

  String? _categoria;
  String? _subcategoria;
  Map<String, List<String>>? _subcategorias;
  bool _carregando = true;
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    _carregarSubcategorias();
  }

  Future<void> _carregarSubcategorias() async {
    try {
      final data = await _api.listarSubcategorias();
      if (mounted) {
        setState(() {
          _subcategorias = data;
          _carregando = false;
        });
      }
    } catch (e) {
      if (e is AuthExpiredException) { if (mounted) handleApiError(context, e); return; }
      if (mounted) {
        setState(() => _carregando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar subcategorias: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _regiaoCtrl.dispose();
    _telefoneCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _salvando = true);
    try {
      await _api.criarPrestador(
        nome: _nomeCtrl.text.trim(),
        categoria: _categoria!,
        subcategoria: _subcategoria!,
        regiao: _regiaoCtrl.text.trim().isNotEmpty
            ? _regiaoCtrl.text.trim()
            : null,
        telefone: _telefoneCtrl.text.trim().isNotEmpty
            ? _telefoneCtrl.text.trim()
            : null,
        email: _emailCtrl.text.trim().isNotEmpty
            ? _emailCtrl.text.trim()
            : null,
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
  Widget build(BuildContext context) {
    if (_carregando) {
      return Scaffold(
        appBar: AppBar(title: const Text('Cadastrar Prestador')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final subcatList = _categoria != null
        ? (_subcategorias?[_categoria] ?? <String>[])
        : <String>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cadastrar Prestador'),
        centerTitle: false,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Nome *
            TextFormField(
              controller: _nomeCtrl,
              decoration: const InputDecoration(
                labelText: 'Nome *',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Informe o nome' : null,
            ),
            const SizedBox(height: 14),

            // Categoria *
            DropdownButtonFormField<String>(
              initialValue: _categoria,
              decoration: const InputDecoration(
                labelText: 'Categoria *',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'prestador_servico',
                  child: Text('Prestador de Serviço'),
                ),
                DropdownMenuItem(
                  value: 'materiais',
                  child: Text('Fornecedor de Materiais'),
                ),
              ],
              onChanged: (val) {
                setState(() {
                  _categoria = val;
                  _subcategoria = null;
                });
              },
              validator: (v) => v == null ? 'Selecione a categoria' : null,
            ),
            const SizedBox(height: 14),

            // Subcategoria *
            DropdownButtonFormField<String>(
              key: ValueKey(_categoria),
              initialValue: _subcategoria,
              decoration: const InputDecoration(
                labelText: 'Subcategoria *',
                border: OutlineInputBorder(),
              ),
              items: subcatList
                  .map((sub) => DropdownMenuItem(
                        value: sub,
                        child: Text(subcategoriaLabels[sub] ?? sub),
                      ))
                  .toList(),
              onChanged: (val) => setState(() => _subcategoria = val),
              validator: (v) => v == null ? 'Selecione a subcategoria' : null,
            ),
            const SizedBox(height: 14),

            // Região
            TextFormField(
              controller: _regiaoCtrl,
              decoration: const InputDecoration(
                labelText: 'Região',
                border: OutlineInputBorder(),
                hintText: 'Ex: São Paulo - SP',
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 14),

            // Telefone
            TextFormField(
              controller: _telefoneCtrl,
              decoration: const InputDecoration(
                labelText: 'Telefone',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 14),

            // Email
            TextFormField(
              controller: _emailCtrl,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 28),

            // Submit
            FilledButton.icon(
              onPressed: _salvando ? null : _salvar,
              icon: _salvando
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
              label: Text(_salvando ? 'Salvando...' : 'Cadastrar'),
            ),
          ],
        ),
      ),
    );
  }
}
