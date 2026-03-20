import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

class PdfViewerScreen extends StatefulWidget {
  const PdfViewerScreen({super.key, required this.url, this.titulo});
  final String url;
  final String? titulo;

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  final _pdfViewerController = PdfViewerController();
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void dispose() {
    _pdfViewerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text(widget.titulo ?? 'Visualizar PDF'),
        actions: [
          IconButton(
            icon: const Icon(Icons.zoom_in),
            onPressed: () => _pdfViewerController.zoomLevel += 0.5,
          ),
          IconButton(
            icon: const Icon(Icons.zoom_out),
            onPressed: () {
              if (_pdfViewerController.zoomLevel > 1.0) {
                _pdfViewerController.zoomLevel -= 0.5;
              }
            },
          ),
        ],
      ),
      body: SfPdfViewer.network(
        widget.url,
        controller: _pdfViewerController,
        canShowScrollHead: true,
        canShowScrollStatus: true,
        onDocumentLoadFailed: (details) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao carregar PDF: ${details.description}'),
            ),
          );
        },
      ),
    );
  }
}
