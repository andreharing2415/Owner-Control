import "dart:typed_data";

import "package:flutter/material.dart";
import "package:provider/provider.dart";
import "package:syncfusion_flutter_pdfviewer/pdfviewer.dart";

import "../../providers/subscription_provider.dart";
import "../../services/api_client.dart";
import "../subscription/paywall_screen.dart";

class PdfViewerScreen extends StatefulWidget {
  const PdfViewerScreen({
    super.key,
    required this.projetoId,
    required this.fileName,
    required this.api,
  });

  final String projetoId;
  final String fileName;
  final ApiClient api;

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  late Future<List<int>> _pdfFuture;

  @override
  void initState() {
    super.initState();
    _pdfFuture = widget.api.downloadProjetoPdf(widget.projetoId);
  }

  @override
  Widget build(BuildContext context) {
    final sub = context.read<SubscriptionProvider>();
    final maxPages = sub.maxDocPagesViewable;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.fileName, overflow: TextOverflow.ellipsis),
      ),
      body: Column(
        children: [
          if (maxPages != null)
            MaterialBanner(
              content: Text(
                "Plano gratuito: visualizando até $maxPages páginas. Assine para ver o documento completo.",
              ),
              leading: const Icon(Icons.info_outline, color: Colors.amber),
              actions: [
                TextButton(
                  onPressed: () => PaywallScreen.show(context,
                      message: "Veja o documento completo"),
                  child: const Text("Assinar"),
                ),
              ],
            ),
          Expanded(
            child: FutureBuilder<List<int>>(
              future: _pdfFuture,
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
                        const SizedBox(height: 16),
                        Text("Erro ao carregar PDF:\n${snapshot.error}",
                            textAlign: TextAlign.center),
                      ],
                    ),
                  );
                }
                return SfPdfViewer.memory(
                  Uint8List.fromList(snapshot.data!),
                  pageLayoutMode: PdfPageLayoutMode.continuous,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
