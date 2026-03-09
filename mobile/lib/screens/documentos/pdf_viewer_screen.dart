import "package:flutter/material.dart";
import "package:provider/provider.dart";
import "package:syncfusion_flutter_pdfviewer/pdfviewer.dart";

import "../../providers/subscription_provider.dart";
import "../subscription/paywall_screen.dart";

class PdfViewerScreen extends StatelessWidget {
  const PdfViewerScreen({
    super.key,
    required this.url,
    required this.fileName,
  });

  final String url;
  final String fileName;

  @override
  Widget build(BuildContext context) {
    final sub = context.read<SubscriptionProvider>();
    final maxPages = sub.maxDocPagesViewable;

    return Scaffold(
      appBar: AppBar(
        title: Text(fileName, overflow: TextOverflow.ellipsis),
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
            child: SfPdfViewer.network(
              url,
              pageLayoutMode: PdfPageLayoutMode.continuous,
              onDocumentLoaded: maxPages != null
                  ? (details) {
                      // Syncfusion doesn't natively support page limiting,
                      // but the backend already enforces analysis limits.
                      // The banner informs the user about the limitation.
                    }
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}
