import "package:flutter/material.dart";
import "package:image_picker/image_picker.dart";
import "package:provider/provider.dart";

import "../../models/etapa.dart";
import "../../models/visual_ai.dart";
import "../../providers/auth_provider.dart";
import "../../providers/subscription_provider.dart";
import "../../services/api_client.dart";
import "../subscription/paywall_screen.dart";
import "detalhe_achado_screen.dart";

class VisualAiScreen extends StatefulWidget {
  const VisualAiScreen({super.key, required this.etapa, required this.api});

  final Etapa etapa;
  final ApiClient api;

  @override
  State<VisualAiScreen> createState() => _VisualAiScreenState();
}

class _VisualAiScreenState extends State<VisualAiScreen> {
  final ImagePicker _imagePicker = ImagePicker();
  late Future<List<AnaliseVisual>> _historicoFuture;
  AnaliseVisual? _ultimaAnalise;
  bool _enviando = false;

  @override
  void initState() {
    super.initState();
    _historicoFuture = widget.api.listarAnalisesVisuais(widget.etapa.id);
  }

  Future<void> _refresh() async {
    setState(() {
      _historicoFuture = widget.api.listarAnalisesVisuais(widget.etapa.id);
    });
  }

  Future<void> _selecionarImagem(ImageSource source) async {
    final image = await _imagePicker.pickImage(
      source: source,
      imageQuality: 85,
    );
    if (image == null) return;

    setState(() => _enviando = true);

    try {
      final analise = await widget.api.enviarAnaliseVisual(
        etapaId: widget.etapa.id,
        image: image,
      );
      setState(() {
        _ultimaAnalise = analise;
        _enviando = false;
        _historicoFuture = widget.api.listarAnalisesVisuais(widget.etapa.id);
      });
    } catch (e) {
      setState(() => _enviando = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro ao enviar analise: $e")),
        );
      }
    }
  }

  Future<void> _mostrarOpcoesFoto() async {
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text("Enviar foto para analise"),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, ImageSource.camera),
            child: const Row(children: [
              Icon(Icons.camera_alt),
              SizedBox(width: 12),
              Text("Tirar foto"),
            ]),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, ImageSource.gallery),
            child: const Row(children: [
              Icon(Icons.photo_library),
              SizedBox(width: 12),
              Text("Escolher da galeria"),
            ]),
          ),
        ],
      ),
    );

    if (source != null) {
      await _selecionarImagem(source);
    }
  }

  Color _severidadeColor(String severidade) {
    switch (severidade.toLowerCase()) {
      case "alta":
      case "critica":
        return Colors.red;
      case "media":
        return Colors.orange;
      default:
        return Colors.green;
    }
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case "concluido":
      case "concluida":
        return Colors.green;
      case "erro":
        return Colors.red;
      default:
        return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = context.read<AuthProvider>().user;
    final isConvidado = user?.isConvidado ?? false;

    // Convidado: completely blocked
    if (isConvidado) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.etapa.nome)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                Text("Recurso indisponível",
                    style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(
                  "A Análise Visual com IA está disponível apenas para o proprietário da obra.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final sub = context.watch<SubscriptionProvider>();
    final limit = sub.aiVisualMonthlyLimit;
    final used = sub.aiVisualUsed;
    final reachedLimit = limit != null && used >= limit;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.etapa.nome),
        actions: [
          IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.visibility,
                          color: theme.colorScheme.primary, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "Analise Visual com IA",
                          style: theme.textTheme.titleLarge,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Envie uma foto da etapa para receber uma analise automatica com inteligencia artificial.",
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  // Usage counter for free plan
                  if (limit != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: reachedLimit
                            ? Colors.red.withValues(alpha: 0.1)
                            : Colors.blue.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            reachedLimit ? Icons.block : Icons.bar_chart,
                            size: 16,
                            color: reachedLimit ? Colors.red : Colors.blue,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            "$used/$limit análise(s) usada(s) este mês",
                            style: TextStyle(
                              fontSize: 12,
                              color: reachedLimit
                                  ? Colors.red
                                  : Colors.blue[700],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: reachedLimit
                        ? FilledButton.icon(
                            onPressed: () => PaywallScreen.show(context,
                                message:
                                    "Você atingiu o limite de análises visuais do plano gratuito"),
                            icon: const Icon(Icons.lock),
                            label: const Text("Limite atingido — Assinar"),
                            style: FilledButton.styleFrom(
                                backgroundColor: Colors.grey),
                          )
                        : FilledButton.icon(
                            onPressed:
                                _enviando ? null : _mostrarOpcoesFoto,
                            icon: const Icon(Icons.add_a_photo),
                            label:
                                const Text("Enviar foto para analise"),
                          ),
                  ),
                ],
              ),
            ),
          ),

          // Loading state
          if (_enviando) ...[
            const SizedBox(height: 16),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text("Analisando imagem com IA..."),
                    SizedBox(height: 4),
                    Text(
                      "Isso pode levar alguns segundos.",
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // Latest analysis result
          if (_ultimaAnalise != null && !_enviando) ...[
            const SizedBox(height: 16),
            _buildResultadoCard(_ultimaAnalise!),
          ],

          // History
          const SizedBox(height: 24),
          Text("Historico de analises", style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          FutureBuilder<List<AnaliseVisual>>(
            future: _historicoFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ),
                );
              }
              if (snapshot.hasError) {
                return Center(child: Text("Erro: ${snapshot.error}"));
              }
              final analises = snapshot.data ?? [];
              if (analises.isEmpty) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Icon(Icons.image_search,
                            size: 48, color: Colors.grey[400]),
                        const SizedBox(height: 12),
                        Text(
                          "Nenhuma analise realizada ainda",
                          style: theme.textTheme.bodyLarge,
                        ),
                      ],
                    ),
                  ),
                );
              }
              return Column(
                children: analises
                    .map((a) => _buildHistoricoItem(a))
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildResultadoCard(AnaliseVisual analise) {
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: theme.colorScheme.primaryContainer,
            child: Text(
              "Resultado da analise",
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ),
          Padding(
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
                      style: theme.textTheme.titleSmall),
                  const SizedBox(height: 12),
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
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text("${analise.confianca}%",
                        style: theme.textTheme.titleSmall),
                  ],
                ),
                if (analise.resumoGeral != null) ...[
                  const SizedBox(height: 16),
                  Text("Resumo geral",
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      )),
                  const SizedBox(height: 4),
                  Text(analise.resumoGeral!),
                ],
                if (analise.achados != null &&
                    analise.achados!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  Text("Achados (${analise.achados!.length})",
                      style: theme.textTheme.titleSmall),
                  const SizedBox(height: 8),
                  ...analise.achados!.map((achado) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              margin: const EdgeInsets.only(top: 2),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: _severidadeColor(achado.severidade)
                                    .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                achado.severidade,
                                style: TextStyle(
                                  color:
                                      _severidadeColor(achado.severidade),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(child: Text(achado.descricao)),
                          ],
                        ),
                      )),
                ],
                if (analise.avisoLegal != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: Colors.amber.withValues(alpha: 0.5)),
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoricoItem(AnaliseVisual analise) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DetalheAchadoScreen(
                analiseId: analise.id,
                api: widget.api,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  analise.imagemUrl,
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    width: 56,
                    height: 56,
                    color: Colors.grey[300],
                    child: const Icon(Icons.broken_image, size: 24),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (analise.etapaInferida != null)
                      Text(
                        analise.etapaInferida!,
                        style: theme.textTheme.titleSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          "Confianca: ${analise.confianca}%",
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _statusColor(analise.status)
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            analise.status,
                            style: TextStyle(
                              color: _statusColor(analise.status),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
