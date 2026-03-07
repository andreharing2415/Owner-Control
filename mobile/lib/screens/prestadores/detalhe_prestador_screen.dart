import "package:flutter/material.dart";
import "package:url_launcher/url_launcher.dart";

import "../../models/prestador.dart";
import "../../services/api_client.dart";

class DetalhePrestadorScreen extends StatefulWidget {
  const DetalhePrestadorScreen({
    super.key,
    required this.prestadorId,
    required this.api,
  });

  final String prestadorId;
  final ApiClient api;

  @override
  State<DetalhePrestadorScreen> createState() => _DetalhePrestadorScreenState();
}

class _DetalhePrestadorScreenState extends State<DetalhePrestadorScreen> {
  late Future<Map<String, dynamic>> _prestadorFuture;

  @override
  void initState() {
    super.initState();
    _prestadorFuture = widget.api.obterPrestador(widget.prestadorId);
  }

  Future<void> _refresh() async {
    setState(() {
      _prestadorFuture = widget.api.obterPrestador(widget.prestadorId);
    });
  }

  Future<void> _ligar(String telefone) async {
    final uri = Uri(scheme: "tel", path: telefone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _enviarEmail(String email) async {
    final uri = Uri(scheme: "mailto", path: email);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _adicionarAvaliacao(Prestador prestador) async {
    final bool isServico = prestador.categoria == "prestador_servico";
    int notaQualidadeServico = 3;
    int notaCumprimentoPrazos = 3;
    int notaFidelidadeProjeto = 3;
    int notaPrazoEntrega = 3;
    int notaQualidadeMaterial = 3;
    final comentarioController = TextEditingController();

    final created = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text("Nova Avaliacao"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isServico) ...[
                    const Text("Qualidade do Servico"),
                    _StarSelector(
                      value: notaQualidadeServico,
                      onChanged: (v) =>
                          setDialogState(() => notaQualidadeServico = v),
                    ),
                    const SizedBox(height: 12),
                    const Text("Cumprimento de Prazos"),
                    _StarSelector(
                      value: notaCumprimentoPrazos,
                      onChanged: (v) =>
                          setDialogState(() => notaCumprimentoPrazos = v),
                    ),
                    const SizedBox(height: 12),
                    const Text("Fidelidade ao Projeto"),
                    _StarSelector(
                      value: notaFidelidadeProjeto,
                      onChanged: (v) =>
                          setDialogState(() => notaFidelidadeProjeto = v),
                    ),
                  ] else ...[
                    const Text("Prazo de Entrega"),
                    _StarSelector(
                      value: notaPrazoEntrega,
                      onChanged: (v) =>
                          setDialogState(() => notaPrazoEntrega = v),
                    ),
                    const SizedBox(height: 12),
                    const Text("Qualidade do Material"),
                    _StarSelector(
                      value: notaQualidadeMaterial,
                      onChanged: (v) =>
                          setDialogState(() => notaQualidadeMaterial = v),
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextField(
                    controller: comentarioController,
                    decoration:
                        const InputDecoration(labelText: "Comentario"),
                    textCapitalization: TextCapitalization.sentences,
                    maxLines: 3,
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
                child: const Text("Salvar"),
              ),
            ],
          );
        },
      ),
    );

    if (created == true) {
      try {
        final notas = <String, dynamic>{
          if (isServico) ...{
            "nota_qualidade_servico": notaQualidadeServico,
            "nota_cumprimento_prazos": notaCumprimentoPrazos,
            "nota_fidelidade_projeto": notaFidelidadeProjeto,
          } else ...{
            "nota_prazo_entrega": notaPrazoEntrega,
            "nota_qualidade_material": notaQualidadeMaterial,
          },
          if (comentarioController.text.trim().isNotEmpty)
            "comentario": comentarioController.text.trim(),
        };
        await widget.api.criarAvaliacao(
          prestadorId: widget.prestadorId,
          notas: notas,
        );
        await _refresh();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Avaliacao salva com sucesso.")),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Erro ao salvar avaliacao: $e")),
          );
        }
      }
    }
  }

  Widget _buildStarsDisplay(double? value) {
    final v = value ?? 0.0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        if (v >= i + 1) {
          return const Icon(Icons.star, size: 18, color: Colors.amber);
        } else if (v > i) {
          return const Icon(Icons.star_half, size: 18, color: Colors.amber);
        }
        return Icon(Icons.star_border, size: 18, color: Colors.grey[400]);
      }),
    );
  }

  Widget _buildRatingRow(String label, double? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          _buildStarsDisplay(value),
          const SizedBox(width: 8),
          SizedBox(
            width: 30,
            child: Text(
              value != null ? value.toStringAsFixed(1) : "-",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvaliacaoStars(int? nota) {
    final v = nota ?? 0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        return Icon(
          i < v ? Icons.star : Icons.star_border,
          size: 14,
          color: i < v ? Colors.amber : Colors.grey[400],
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Detalhe do Prestador"),
        actions: [
          IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _prestadorFuture,
        builder: (context, prestadorSnap) {
          if (prestadorSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (prestadorSnap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 48, color: Colors.red),
                    const SizedBox(height: 12),
                    Text("Erro: ${prestadorSnap.error}",
                        textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    ElevatedButton(
                        onPressed: _refresh,
                        child: const Text("Tentar novamente")),
                  ],
                ),
              ),
            );
          }

          final data = prestadorSnap.data!;
          final prestadorData = data["prestador"] as Map<String, dynamic>? ?? data;
          final prestador = Prestador.fromJson(prestadorData);
          final medias = data["medias"] as Map<String, dynamic>? ?? {};
          final avaliacoes = (data["avaliacoes"] as List<dynamic>? ?? [])
              .map((e) => Avaliacao.fromJson(e as Map<String, dynamic>))
              .toList();

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Info card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 28,
                              backgroundColor: colorScheme.primaryContainer,
                              child: Icon(
                                prestador.categoria == "materiais"
                                    ? Icons.inventory_2
                                    : Icons.engineering,
                                size: 28,
                                color: colorScheme.primary,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    prestador.nome,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge,
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: colorScheme.secondaryContainer,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      prestador.categoria == "prestador_servico"
                                          ? "Prestador de Servico"
                                          : "Fornecedor de Materiais",
                                      style: TextStyle(
                                        fontSize: 12,
                                        color:
                                            colorScheme.onSecondaryContainer,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _infoRow(Icons.category, prestador.subcategoria),
                        if (prestador.regiao != null)
                          _infoRow(Icons.location_on_outlined,
                              prestador.regiao!),
                        if (prestador.telefone != null)
                          InkWell(
                            onTap: () => _ligar(prestador.telefone!),
                            child: _infoRow(
                              Icons.phone,
                              prestador.telefone!,
                              linkColor: colorScheme.primary,
                            ),
                          ),
                        if (prestador.email != null)
                          InkWell(
                            onTap: () => _enviarEmail(prestador.email!),
                            child: _infoRow(
                              Icons.email_outlined,
                              prestador.email!,
                              linkColor: colorScheme.primary,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Average ratings card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Medias de Avaliacao",
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        if (prestador.categoria == "prestador_servico") ...[
                          _buildRatingRow(
                            "Qualidade do Servico",
                            (medias["nota_qualidade_servico"] as num?)
                                ?.toDouble(),
                          ),
                          _buildRatingRow(
                            "Cumprimento de Prazos",
                            (medias["nota_cumprimento_prazos"] as num?)
                                ?.toDouble(),
                          ),
                          _buildRatingRow(
                            "Fidelidade ao Projeto",
                            (medias["nota_fidelidade_projeto"] as num?)
                                ?.toDouble(),
                          ),
                        ] else ...[
                          _buildRatingRow(
                            "Prazo de Entrega",
                            (medias["nota_prazo_entrega"] as num?)
                                ?.toDouble(),
                          ),
                          _buildRatingRow(
                            "Qualidade do Material",
                            (medias["nota_qualidade_material"] as num?)
                                ?.toDouble(),
                          ),
                        ],
                        const Divider(),
                        _buildRatingRow("Media Geral",
                            prestador.mediaGeral),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Avaliacoes section
                Row(
                  children: [
                    Expanded(
                      child: Text("Avaliacoes",
                          style: Theme.of(context).textTheme.titleMedium),
                    ),
                    FilledButton.icon(
                      onPressed: () => _adicionarAvaliacao(prestador),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text("Avaliar"),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                if (avaliacoes.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.rate_review_outlined,
                                size: 48, color: Colors.grey[400]),
                            const SizedBox(height: 8),
                            const Text("Nenhuma avaliacao ainda"),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  ...avaliacoes.map((a) {
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (prestador.categoria ==
                                "prestador_servico") ...[
                              _avaliacaoNotaRow("Qualidade",
                                  a.notaQualidadeServico),
                              _avaliacaoNotaRow(
                                  "Prazos", a.notaCumprimentoPrazos),
                              _avaliacaoNotaRow("Fidelidade",
                                  a.notaFidelidadeProjeto),
                            ] else ...[
                              _avaliacaoNotaRow(
                                  "Prazo Entrega", a.notaPrazoEntrega),
                              _avaliacaoNotaRow("Qualidade Material",
                                  a.notaQualidadeMaterial),
                            ],
                            if (a.comentario != null &&
                                a.comentario!.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: colorScheme.surfaceContainerHighest
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  a.comentario!,
                                  style: const TextStyle(
                                      fontStyle: FontStyle.italic),
                                ),
                              ),
                            ],
                            if (a.createdAt != null) ...[
                              const SizedBox(height: 4),
                              Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  a.createdAt!.substring(0, 10),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _infoRow(IconData icon, String text, {Color? linkColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: linkColor ?? Colors.grey[600]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: linkColor != null
                  ? TextStyle(
                      color: linkColor,
                      decoration: TextDecoration.underline,
                    )
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _avaliacaoNotaRow(String label, int? nota) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(width: 130, child: Text(label, style: const TextStyle(fontSize: 13))),
          _buildAvaliacaoStars(nota),
        ],
      ),
    );
  }
}

class _StarSelector extends StatelessWidget {
  const _StarSelector({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final starIndex = i + 1;
        return IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          icon: Icon(
            starIndex <= value ? Icons.star : Icons.star_border,
            color: starIndex <= value ? Colors.amber : Colors.grey[400],
          ),
          onPressed: () => onChanged(starIndex),
        );
      }),
    );
  }
}
