import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../api/api.dart';
import 'avaliar_prestador_screen.dart';
import 'prestadores_screen.dart'
    show categoriaLabels, subcategoriaLabels, topicoLabels;
import 'widgets/star_rating.dart';

class DetalhePrestadorScreen extends StatefulWidget {
  const DetalhePrestadorScreen({super.key, required this.prestadorId});

  final String prestadorId;

  @override
  State<DetalhePrestadorScreen> createState() => _DetalhePrestadorScreenState();
}

class _DetalhePrestadorScreenState extends State<DetalhePrestadorScreen> {
  final ApiClient _api = ApiClient();
  late Future<PrestadorDetalhe> _detalheFuture;

  @override
  void initState() {
    super.initState();
    _detalheFuture = _api.obterPrestador(widget.prestadorId);
  }

  void _recarregar() {
    setState(() {
      _detalheFuture = _api.obterPrestador(widget.prestadorId);
    });
  }

  Future<void> _abrirAvaliacao(String categoria) async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AvaliarPrestadorScreen(
          prestadorId: widget.prestadorId,
          categoria: categoria,
        ),
      ),
    );
    if (ok == true) _recarregar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalhe do Prestador'),
        centerTitle: false,
      ),
      body: FutureBuilder<PrestadorDetalhe>(
        future: _detalheFuture,
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

          final detalhe = snapshot.data!;
          final p = detalhe.prestador;

          return Scaffold(
            floatingActionButton: FloatingActionButton.extended(
              onPressed: () => _abrirAvaliacao(p.categoria),
              icon: const Icon(Icons.star_rounded),
              label: const Text('Avaliar'),
            ),
            body: RefreshIndicator(
              onRefresh: () async => _recarregar(),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                children: [
                  _CabecalhoCard(prestador: p),
                  if (detalhe.medias.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _MediasCard(medias: detalhe.medias),
                  ],
                  const SizedBox(height: 16),
                  Text(
                    'Avaliações (${detalhe.avaliacoes.length})',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 10),
                  if (detalhe.avaliacoes.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        child: Column(
                          children: [
                            Icon(Icons.rate_review_outlined,
                                size: 48, color: Colors.grey[400]),
                            const SizedBox(height: 8),
                            const Text(
                              'Nenhuma avaliação ainda.',
                              style:
                                  TextStyle(color: Colors.grey, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ...detalhe.avaliacoes.map(
                      (a) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _AvaliacaoCard(avaliacao: a),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── Header card ─────────────────────────────────────────────────────────────

class _CabecalhoCard extends StatelessWidget {
  const _CabecalhoCard({required this.prestador});
  final Prestador prestador;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isServico = prestador.categoria == 'prestador_servico';

    return Card(
      elevation: 0,
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor:
                      scheme.onPrimaryContainer.withValues(alpha: 0.12),
                  child: Icon(
                    isServico ? Icons.engineering : Icons.inventory_2_outlined,
                    color: scheme.onPrimaryContainer,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        prestador.nome,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                          color: scheme.onPrimaryContainer,
                        ),
                      ),
                      Text(
                        subcategoriaLabels[prestador.subcategoria] ??
                            prestador.subcategoria,
                        style: TextStyle(
                          fontSize: 13,
                          color: scheme.onPrimaryContainer
                              .withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (prestador.notaGeral != null) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  StarRatingDisplay(rating: prestador.notaGeral!, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    '${prestador.notaGeral!.toStringAsFixed(1)} '
                    '(${prestador.totalAvaliacoes} avaliação(ões))',
                    style: TextStyle(
                      fontSize: 13,
                      color: scheme.onPrimaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 10),
            _InfoRow(
              icon: Icons.category_outlined,
              text: categoriaLabels[prestador.categoria] ??
                  prestador.categoria,
            ),
            if (prestador.regiao != null)
              _InfoRow(
                icon: Icons.location_on_outlined,
                text: prestador.regiao!,
              ),
            if (prestador.telefone != null)
              _InfoRow(
                icon: Icons.phone_outlined,
                text: prestador.telefone!,
              ),
            if (prestador.email != null)
              _InfoRow(
                icon: Icons.email_outlined,
                text: prestador.email!,
              ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(icon,
              size: 14,
              color: scheme.onPrimaryContainer.withValues(alpha: 0.6)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: scheme.onPrimaryContainer.withValues(alpha: 0.8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Averages card ───────────────────────────────────────────────────────────

class _MediasCard extends StatelessWidget {
  const _MediasCard({required this.medias});
  final Map<String, double> medias;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Médias por Tópico',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 12),
            ...medias.entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        topicoLabels[entry.key] ?? entry.key,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    StarRatingDisplay(rating: entry.value, size: 16),
                    const SizedBox(width: 6),
                    SizedBox(
                      width: 28,
                      child: Text(
                        entry.value.toStringAsFixed(1),
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600),
                        textAlign: TextAlign.end,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Review card ─────────────────────────────────────────────────────────────

class _AvaliacaoCard extends StatelessWidget {
  const _AvaliacaoCard({required this.avaliacao});
  final AvaliacaoPrestador avaliacao;

  @override
  Widget build(BuildContext context) {
    final notas = <String, int>{};
    if (avaliacao.notaQualidadeServico != null) {
      notas['nota_qualidade_servico'] = avaliacao.notaQualidadeServico!;
    }
    if (avaliacao.notaCumprimentoPrazos != null) {
      notas['nota_cumprimento_prazos'] = avaliacao.notaCumprimentoPrazos!;
    }
    if (avaliacao.notaFidelidadeProjeto != null) {
      notas['nota_fidelidade_projeto'] = avaliacao.notaFidelidadeProjeto!;
    }
    if (avaliacao.notaPrazoEntrega != null) {
      notas['nota_prazo_entrega'] = avaliacao.notaPrazoEntrega!;
    }
    if (avaliacao.notaQualidadeMaterial != null) {
      notas['nota_qualidade_material'] = avaliacao.notaQualidadeMaterial!;
    }

    String dataFormatada;
    try {
      final dt = DateTime.parse(avaliacao.createdAt);
      dataFormatada = DateFormat('dd/MM/yyyy').format(dt);
    } catch (_) {
      dataFormatada = avaliacao.createdAt;
    }

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.calendar_today_outlined,
                    size: 13, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Text(
                  dataFormatada,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...notas.entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        topicoLabels[entry.key] ?? entry.key,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    StarRatingDisplay(
                        rating: entry.value.toDouble(), size: 14),
                    const SizedBox(width: 4),
                    Text(
                      '${entry.value}',
                      style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
            if (avaliacao.comentario != null) ...[
              const SizedBox(height: 8),
              Text(
                avaliacao.comentario!,
                style: TextStyle(
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
