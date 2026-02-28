import 'dart:async';

import 'package:flutter/material.dart';

import '../api/api.dart';
import 'criar_prestador_screen.dart';
import 'detalhe_prestador_screen.dart';
import 'widgets/star_rating.dart';

// ─── Label maps ──────────────────────────────────────────────────────────────

const categoriaLabels = <String, String>{
  'prestador_servico': 'Prestador de Serviço',
  'materiais': 'Fornecedor de Materiais',
};

const subcategoriaLabels = <String, String>{
  'arquiteto': 'Arquiteto',
  'empreiteiro': 'Empreiteiro',
  'pintor': 'Pintor',
  'marcenaria': 'Marcenaria',
  'marmore_granito': 'Mármore e Granito',
  'eletricista': 'Eletricista',
  'encanador': 'Encanador',
  'serralheiro': 'Serralheiro',
  'vidraceiro': 'Vidraceiro',
  'gesseiro': 'Gesseiro',
  'loja_material': 'Loja de Material',
  'fornecedor_aco': 'Fornecedor de Aço',
  'madeira': 'Madeira',
  'tinta': 'Tinta',
  'eletro_eletronicos': 'Eletro/Eletrônicos',
  'hidraulica': 'Hidráulica',
  'ceramica': 'Cerâmica',
  'outro': 'Outro',
};

const topicoLabels = <String, String>{
  'nota_qualidade_servico': 'Qualidade do Serviço',
  'nota_cumprimento_prazos': 'Cumprimento de Prazos',
  'nota_fidelidade_projeto': 'Fidelidade ao Projeto',
  'nota_prazo_entrega': 'Prazo de Entrega',
  'nota_qualidade_material': 'Qualidade do Material',
};

// ─── PrestadoresScreen ───────────────────────────────────────────────────────

class PrestadoresScreen extends StatefulWidget {
  const PrestadoresScreen({super.key});

  @override
  State<PrestadoresScreen> createState() => _PrestadoresScreenState();
}

class _PrestadoresScreenState extends State<PrestadoresScreen> {
  final ApiClient _api = ApiClient();
  final _buscaCtrl = TextEditingController();
  Timer? _debounce;

  late Future<List<Prestador>> _prestadoresFuture;
  String? _categoriaFiltro;

  @override
  void initState() {
    super.initState();
    _prestadoresFuture = _api.listarPrestadores();
  }

  @override
  void dispose() {
    _buscaCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _recarregar() {
    setState(() {
      _prestadoresFuture = _api.listarPrestadores(
        categoria: _categoriaFiltro,
        q: _buscaCtrl.text.trim().isNotEmpty ? _buscaCtrl.text.trim() : null,
      );
    });
  }

  Future<void> _refresh() async {
    _recarregar();
  }

  void _onBuscaChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _recarregar);
  }

  void _selecionarCategoria(String? categoria) {
    setState(() {
      _categoriaFiltro = categoria;
    });
    _recarregar();
  }

  Future<void> _abrirCadastro() async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const CriarPrestadorScreen()),
    );
    if (ok == true) _recarregar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Prestadores'),
        centerTitle: false,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _abrirCadastro,
        icon: const Icon(Icons.add),
        label: const Text('Cadastrar'),
      ),
      body: Column(
        children: [
          // Category filter chips
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: const Text('Todos'),
                    selected: _categoriaFiltro == null,
                    onSelected: (_) => _selecionarCategoria(null),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: const Text('Prestadores'),
                    selected: _categoriaFiltro == 'prestador_servico',
                    onSelected: (_) =>
                        _selecionarCategoria('prestador_servico'),
                  ),
                ),
                FilterChip(
                  label: const Text('Fornecedores'),
                  selected: _categoriaFiltro == 'materiais',
                  onSelected: (_) => _selecionarCategoria('materiais'),
                ),
              ],
            ),
          ),

          // Search bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _buscaCtrl,
              decoration: InputDecoration(
                hintText: 'Buscar por nome...',
                prefixIcon: const Icon(Icons.search, size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                isDense: true,
              ),
              onChanged: _onBuscaChanged,
            ),
          ),
          const SizedBox(height: 8),

          // List
          Expanded(
            child: FutureBuilder<List<Prestador>>(
              future: _prestadoresFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline,
                            size: 48, color: Colors.red),
                        const SizedBox(height: 8),
                        Text('Erro: ${snapshot.error}',
                            style: const TextStyle(color: Colors.red),
                            textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: _recarregar,
                          child: const Text('Tentar novamente'),
                        ),
                      ],
                    ),
                  );
                }
                final prestadores = snapshot.data ?? [];
                if (prestadores.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.people_outline,
                            size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 12),
                        const Text(
                          'Nenhum prestador cadastrado.',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 16),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Toque em "Cadastrar" para adicionar.',
                          style: TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                      ],
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                    itemCount: prestadores.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final p = prestadores[index];
                      return _PrestadorTile(
                        prestador: p,
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  DetalhePrestadorScreen(prestadorId: p.id),
                            ),
                          );
                          _recarregar();
                        },
                      );
                    },
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

// ─── Tile ────────────────────────────────────────────────────────────────────

class _PrestadorTile extends StatelessWidget {
  const _PrestadorTile({required this.prestador, required this.onTap});

  final Prestador prestador;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isServico = prestador.categoria == 'prestador_servico';

    return Card(
      elevation: 0,
      clipBehavior: Clip.hardEdge,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor:
              (isServico ? Colors.indigo : Colors.teal).withValues(alpha: 0.10),
          child: Icon(
            isServico ? Icons.engineering : Icons.inventory_2_outlined,
            color: isServico ? Colors.indigo : Colors.teal,
            size: 20,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                prestador.nome,
                style: const TextStyle(fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (prestador.notaGeral != null) ...[
              const SizedBox(width: 6),
              StarRatingDisplay(rating: prestador.notaGeral!, size: 14),
              const SizedBox(width: 4),
              Text(
                prestador.notaGeral!.toStringAsFixed(1),
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ],
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: (isServico ? Colors.indigo : Colors.teal)
                        .withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    subcategoriaLabels[prestador.subcategoria] ??
                        prestador.subcategoria,
                    style: TextStyle(
                      fontSize: 11,
                      color: isServico ? Colors.indigo : Colors.teal,
                    ),
                  ),
                ),
                if (prestador.regiao != null) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.location_on_outlined,
                      size: 12, color: Colors.grey[500]),
                  const SizedBox(width: 2),
                  Expanded(
                    child: Text(
                      prestador.regiao!,
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
            if (prestador.totalAvaliacoes > 0) ...[
              const SizedBox(height: 2),
              Text(
                '${prestador.totalAvaliacoes} avaliação(ões)',
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
            ],
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
