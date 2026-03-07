import "package:flutter/material.dart";

import "../../models/documento.dart";
import "../../services/api_client.dart";
import "detalhe_risco_screen.dart";

class AnaliseDocumentoScreen extends StatefulWidget {
  const AnaliseDocumentoScreen({
    super.key,
    required this.projetoId,
    required this.api,
  });

  final String projetoId;
  final ApiClient api;

  @override
  State<AnaliseDocumentoScreen> createState() => _AnaliseDocumentoScreenState();
}

class _AnaliseDocumentoScreenState extends State<AnaliseDocumentoScreen> {
  late Future<AnaliseDocumento> _analiseFuture;

  @override
  void initState() {
    super.initState();
    _analiseFuture = widget.api.obterAnaliseProjeto(widget.projetoId);
  }

  Future<void> _refresh() async {
    setState(() {
      _analiseFuture = widget.api.obterAnaliseProjeto(widget.projetoId);
    });
  }

  int _severidadeOrdem(String severidade) {
    switch (severidade) {
      case "alto":
        return 0;
      case "medio":
        return 1;
      case "baixo":
        return 2;
      default:
        return 3;
    }
  }

  Color _severidadeColor(String severidade) {
    switch (severidade) {
      case "alto":
        return Colors.red;
      case "medio":
        return Colors.orange;
      case "baixo":
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _severidadeLabel(String severidade) {
    switch (severidade) {
      case "alto":
        return "Alto";
      case "medio":
        return "Médio";
      case "baixo":
        return "Baixo";
      default:
        return severidade;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Análise do Documento"),
        actions: [
          IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: FutureBuilder<AnaliseDocumento>(
        future: _analiseFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Erro: ${snapshot.error}"));
          }
          final analise = snapshot.data!;
          final riscos = List<Risco>.from(analise.riscos)
            ..sort((a, b) =>
                _severidadeOrdem(a.severidade)
                    .compareTo(_severidadeOrdem(b.severidade)));

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                // Resumo geral
                if (analise.projeto.resumoGeral != null) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.summarize, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                "Resumo Geral",
                                style:
                                    Theme.of(context).textTheme.titleMedium,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(analise.projeto.resumoGeral!),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],

                // Aviso legal
                if (analise.projeto.avisoLegal != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.amber.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.warning_amber_rounded,
                            color: Colors.amber, size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Aviso Legal",
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(color: Colors.amber[800]),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                analise.projeto.avisoLegal!,
                                style: TextStyle(color: Colors.amber[900]),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Riscos header
                if (riscos.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 8),
                    child: Text(
                      "Riscos Identificados (${riscos.length})",
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ],

                // Riscos list
                ...riscos.map((risco) {
                  final color = _severidadeColor(risco.severidade);
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => DetalheRiscoScreen(risco: risco),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    _severidadeLabel(risco.severidade),
                                    style: TextStyle(
                                      color: color,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                if (risco.requerValidacaoProfissional) ...[
                                  const Icon(Icons.warning,
                                      size: 16, color: Colors.orange),
                                  const SizedBox(width: 4),
                                  Text(
                                    "Requer validação",
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.orange[700],
                                    ),
                                  ),
                                ],
                                const Spacer(),
                                Text(
                                  "${risco.confianca}%",
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(color: Colors.grey[600]),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              risco.descricao,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (risco.normaReferencia != null) ...[
                              const SizedBox(height: 6),
                              Text(
                                risco.normaReferencia!,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: Colors.grey[600]),
                              ),
                            ],
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.indigo.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                risco.traducaoLeigo,
                                style: TextStyle(
                                  color: Colors.indigo[700],
                                  fontSize: 13,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),

                if (riscos.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: [
                          Icon(Icons.verified_user,
                              size: 64, color: Colors.green[300]),
                          const SizedBox(height: 16),
                          Text(
                            "Nenhum risco identificado",
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
