import "package:flutter/material.dart";

import "../../models/visual_ai.dart";
import "../../services/api_client.dart";
import "../../utils/theme_helpers.dart";

class DetalheAchadoScreen extends StatefulWidget {
  const DetalheAchadoScreen({
    super.key,
    required this.analiseId,
    required this.api,
  });

  final String analiseId;
  final ApiClient api;

  @override
  State<DetalheAchadoScreen> createState() => _DetalheAchadoScreenState();
}

class _DetalheAchadoScreenState extends State<DetalheAchadoScreen> {
  late Future<AnaliseVisual> _analiseFuture;

  @override
  void initState() {
    super.initState();
    _analiseFuture = widget.api.obterAnaliseVisual(widget.analiseId);
  }

  Future<void> _refresh() async {
    setState(() {
      _analiseFuture = widget.api.obterAnaliseVisual(widget.analiseId);
    });
  }

  Color _severidadeColor(String s) => severidadeColor(s);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Detalhe da analise"),
        actions: [
          IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: FutureBuilder<AnaliseVisual>(
        future: _analiseFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Erro: ${snapshot.error}"));
          }
          final analise = snapshot.data!;
          return _buildContent(analise);
        },
      ),
    );
  }

  Widget _buildContent(AnaliseVisual analise) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Image
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            analise.imagemUrl,
            width: double.infinity,
            height: 220,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Container(
              width: double.infinity,
              height: 220,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.broken_image, size: 48),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Etapa inferida + confianca
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (analise.etapaInferida != null) ...[
                  Text("Etapa inferida",
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      )),
                  const SizedBox(height: 4),
                  Text(analise.etapaInferida!,
                      style: theme.textTheme.titleMedium),
                  const SizedBox(height: 16),
                ],
                Text("Confianca",
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    )),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: LinearProgressIndicator(
                        value: analise.confianca / 100,
                        minHeight: 10,
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text("${analise.confianca}%",
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        )),
                  ],
                ),
              ],
            ),
          ),
        ),

        // Resumo geral
        if (analise.resumoGeral != null) ...[
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Resumo geral",
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      )),
                  const SizedBox(height: 8),
                  Text(analise.resumoGeral!,
                      style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
          ),
        ],

        // Aviso legal
        if (analise.avisoLegal != null) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border:
                  Border.all(color: Colors.amber.withValues(alpha: 0.5)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.warning_amber_rounded,
                    color: Colors.amber, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    analise.avisoLegal!,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        ],

        // Achados
        if (analise.achados != null && analise.achados!.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text("Achados (${analise.achados!.length})",
              style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          ...analise.achados!.map((achado) => _buildAchadoCard(achado)),
        ],
      ],
    );
  }

  Widget _buildAchadoCard(Achado achado) {
    final theme = Theme.of(context);
    final sevColor = _severidadeColor(achado.severidade);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: descricao + severidade badge
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(achado.descricao,
                      style: theme.textTheme.titleSmall),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: sevColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    achado.severidade,
                    style: TextStyle(
                      color: sevColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Acao recomendada
            Text("Acao recomendada",
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                )),
            const SizedBox(height: 4),
            Text(achado.acaoRecomendada),
            const SizedBox(height: 12),

            // Confianca
            Row(
              children: [
                Text("Confianca: ",
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    )),
                Text("${achado.confianca}%",
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    )),
              ],
            ),

            // Flags
            if (achado.requerValidacaoProfissional ||
                achado.requerEvidenciaAdicional) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              if (achado.requerValidacaoProfissional)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Icon(Icons.engineering,
                          size: 18,
                          color: theme.colorScheme.error),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "Requer validacao de profissional habilitado",
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.error,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (achado.requerEvidenciaAdicional)
                Row(
                  children: [
                    Icon(Icons.camera_alt,
                        size: 18, color: Colors.orange[700]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Evidencia adicional necessaria",
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.orange[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ],
        ),
      ),
    );
  }
}
