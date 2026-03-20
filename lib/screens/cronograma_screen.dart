import 'dart:io';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;
import '../api/api.dart';
import '../utils/auth_error_handler.dart';
import '../utils/status_helper.dart';
import 'atividade_detalhe_screen.dart';
import 'detalhamento_comodos_screen.dart';

const _statusLabels = {
  "pendente": "Pendente",
  "em_andamento": "Em andamento",
  "concluida": "Concluida",
};

class CronogramaScreen extends StatefulWidget {
  const CronogramaScreen({super.key, required this.obra});

  final Obra obra;

  @override
  State<CronogramaScreen> createState() => _CronogramaScreenState();
}

class _CronogramaScreenState extends State<CronogramaScreen> {
  final ApiClient _api = ApiClient();
  late Future<CronogramaResponse> _cronogramaFuture;
  bool _exportando = false;

  @override
  void initState() {
    super.initState();
    _cronogramaFuture = _api.listarCronograma(widget.obra.id);
  }

  Future<void> _refresh() async {
    setState(() {
      _cronogramaFuture = _api.listarCronograma(widget.obra.id);
    });
  }

  Future<void> _exportarPdf() async {
    setState(() => _exportando = true);
    try {
      final bytes = await _api.exportarPdf(widget.obra.id);
      final tempDir = await getTemporaryDirectory();
      final file =
          File("${tempDir.path}/cronograma-${widget.obra.id}.pdf");
      await file.writeAsBytes(bytes, flush: true);
      await OpenFilex.open(file.path);
    } catch (e) {
      if (e is AuthExpiredException) {
        if (mounted) handleApiError(context, e);
        return;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro ao exportar: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _exportando = false);
    }
  }

  Future<void> _exportarExcel(CronogramaResponse cronograma) async {
    final wb = xlsio.Workbook();
    final sheet = wb.worksheets[0];
    sheet.name = 'Cronograma';

    // Styles
    final headerStyle = wb.styles.add('header');
    headerStyle.bold = true;
    headerStyle.backColor = '#4472C4';
    headerStyle.fontColor = '#FFFFFF';
    headerStyle.hAlign = xlsio.HAlignType.center;

    final l1Style = wb.styles.add('l1');
    l1Style.bold = true;
    l1Style.backColor = '#D9E2F3';

    final totalStyle = wb.styles.add('total');
    totalStyle.bold = true;
    totalStyle.backColor = '#B4C6E7';

    // Headers
    final headers = [
      'Etapa',
      'Atividade',
      'Status',
      'Início Previsto',
      'Fim Previsto',
      'Início Real',
      'Fim Real',
      'Valor Previsto (R\$)',
      'Valor Gasto (R\$)',
    ];
    for (var i = 0; i < headers.length; i++) {
      final cell = sheet.getRangeByIndex(1, i + 1);
      cell.setText(headers[i]);
      cell.cellStyle = headerStyle;
    }

    var row = 2;
    for (final l1 in cronograma.atividades) {
      // L1 row (etapa)
      sheet.getRangeByIndex(row, 1).setText(l1.nome);
      sheet.getRangeByIndex(row, 2).setText('');
      sheet.getRangeByIndex(row, 3).setText(_statusLabels[l1.status] ?? l1.status);
      sheet.getRangeByIndex(row, 4).setText(l1.dataInicioPrevista ?? '');
      sheet.getRangeByIndex(row, 5).setText(l1.dataFimPrevista ?? '');
      sheet.getRangeByIndex(row, 6).setText(l1.dataInicioReal ?? '');
      sheet.getRangeByIndex(row, 7).setText(l1.dataFimReal ?? '');
      sheet.getRangeByIndex(row, 8).setNumber(l1.valorPrevisto);
      sheet.getRangeByIndex(row, 9).setNumber(l1.valorGasto);
      for (var c = 1; c <= headers.length; c++) {
        sheet.getRangeByIndex(row, c).cellStyle = l1Style;
      }
      row++;

      // L2 rows (sub-atividades)
      for (final l2 in l1.subAtividades) {
        sheet.getRangeByIndex(row, 1).setText('');
        sheet.getRangeByIndex(row, 2).setText(l2.nome);
        sheet.getRangeByIndex(row, 3).setText(_statusLabels[l2.status] ?? l2.status);
        sheet.getRangeByIndex(row, 4).setText(l2.dataInicioPrevista ?? '');
        sheet.getRangeByIndex(row, 5).setText(l2.dataFimPrevista ?? '');
        sheet.getRangeByIndex(row, 6).setText(l2.dataInicioReal ?? '');
        sheet.getRangeByIndex(row, 7).setText(l2.dataFimReal ?? '');
        sheet.getRangeByIndex(row, 8).setNumber(l2.valorPrevisto);
        sheet.getRangeByIndex(row, 9).setNumber(l2.valorGasto);
        row++;
      }
    }

    // Total row
    sheet.getRangeByIndex(row, 1).setText('TOTAL');
    sheet.getRangeByIndex(row, 8).setNumber(cronograma.totalPrevisto);
    sheet.getRangeByIndex(row, 9).setNumber(cronograma.totalGasto);
    for (var c = 1; c <= headers.length; c++) {
      sheet.getRangeByIndex(row, c).cellStyle = totalStyle;
    }

    // Auto-fit
    for (var i = 1; i <= headers.length; i++) {
      sheet.autoFitColumn(i);
    }

    final bytes = wb.saveAsStream();
    wb.dispose();

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/cronograma_${widget.obra.nome.replaceAll(RegExp(r'[^\w]'), '_')}.xlsx');
    await file.writeAsBytes(bytes, flush: true);

    if (mounted) {
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Cronograma - ${widget.obra.nome}',
      );
    }
  }

  Color _statusColor(String status) => etapaStatusColor(status);

  IconData _statusIcon(String status) {
    switch (status) {
      case "concluida":
        return Icons.check_circle;
      case "em_andamento":
        return Icons.timelapse;
      default:
        return Icons.radio_button_unchecked;
    }
  }

  Color _desvioColor(double desvio) {
    if (desvio <= 0) return Colors.green;
    if (desvio <= 10) return Colors.orange;
    return Colors.red;
  }

  String _fmtCurrency(double value) {
    if (value >= 1000000) {
      return "R\$ ${(value / 1000000).toStringAsFixed(1)}M";
    }
    if (value >= 1000) {
      return "R\$ ${(value / 1000).toStringAsFixed(1)}K";
    }
    return "R\$ ${value.toStringAsFixed(2)}";
  }

  Future<void> _atualizarStatusL1(AtividadeCronograma atividade) async {
    final statusOptions = _statusLabels.entries.toList();
    final novoStatus = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text("Status: ${atividade.nome}"),
        children: statusOptions.map((entry) {
          return SimpleDialogOption(
            onPressed: () => Navigator.pop(context, entry.key),
            child: Text(entry.value),
          );
        }).toList(),
      ),
    );
    if (novoStatus != null && novoStatus != atividade.status) {
      try {
        await _api.atualizarAtividade(
          atividadeId: atividade.id,
          status: novoStatus,
        );
        await _refresh();
      } catch (e) {
        if (e is AuthExpiredException) {
          if (mounted) handleApiError(context, e);
          return;
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Erro: $e")),
          );
        }
      }
    }
  }

  void _lancarDespesaDialog(CronogramaResponse cronograma) {
    // Collect all L2 activities
    final l2Atividades = <AtividadeCronograma>[];
    for (final l1 in cronograma.atividades) {
      for (final l2 in l1.subAtividades) {
        l2Atividades.add(l2);
      }
    }

    if (l2Atividades.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Nenhuma atividade disponivel.")),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text("Selecione a atividade"),
        children: l2Atividades.map((atv) {
          return SimpleDialogOption(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AtividadeDetalheScreen(
                    atividade: atv,
                    initialTab: 2,
                  ),
                ),
              ).then((_) => _refresh());
            },
            child: Text(atv.nome),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.obra.nome),
        actions: [
          IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DetalhamentoComodosScreen(
                  obraId: widget.obra.id,
                ),
              ),
            ),
            icon: const Icon(Icons.square_foot),
            tooltip: "Quantitativo",
          ),
          IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh)),
          _exportando
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : PopupMenuButton<String>(
                  icon: const Icon(Icons.file_download_outlined),
                  tooltip: "Exportar",
                  onSelected: (value) async {
                    if (value == 'pdf') {
                      _exportarPdf();
                    } else if (value == 'excel') {
                      final snap = await _cronogramaFuture;
                      _exportarExcel(snap);
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: 'pdf',
                      child: ListTile(
                        leading: Icon(Icons.picture_as_pdf, color: Colors.red),
                        title: Text('Exportar PDF'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    PopupMenuItem(
                      value: 'excel',
                      child: ListTile(
                        leading: Icon(Icons.table_chart, color: Colors.green),
                        title: Text('Exportar Excel'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
        ],
      ),
      body: FutureBuilder<CronogramaResponse>(
        future: _cronogramaFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Erro: ${snapshot.error}"));
          }
          final cronograma = snapshot.data!;
          final atividades = cronograma.atividades;

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: atividades.length + 1, // +1 for summary card
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _SummaryCard(
                      totalPrevisto: cronograma.totalPrevisto,
                      totalGasto: cronograma.totalGasto,
                      desvio: cronograma.desvioPercentual,
                      desvioColor: _desvioColor(cronograma.desvioPercentual),
                      fmtCurrency: _fmtCurrency,
                    ),
                  );
                }
                return _buildL1Tile(atividades[index - 1]);
              },
            ),
          );
        },
      ),
      floatingActionButton: FutureBuilder<CronogramaResponse>(
        future: _cronogramaFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const SizedBox.shrink();
          return FloatingActionButton.extended(
            onPressed: () => _lancarDespesaDialog(snapshot.data!),
            icon: const Icon(Icons.add),
            label: const Text("Lancar Despesa"),
          );
        },
      ),
    );
  }

  Widget _buildL1Tile(AtividadeCronograma l1) {
    return Card(
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor:
              _statusColor(l1.status).withValues(alpha: 0.15),
          child: Text(
            "${l1.ordem}",
            style: TextStyle(
              color: _statusColor(l1.status),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(l1.nome,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Row(
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color:
                    _statusColor(l1.status).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _statusLabels[l1.status] ?? l1.status,
                style: TextStyle(
                  color: _statusColor(l1.status),
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              "${_fmtCurrency(l1.valorGasto)} / ${_fmtCurrency(l1.valorPrevisto)}",
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          onSelected: (value) {
            if (value == "status") {
              _atualizarStatusL1(l1);
            } else if (value == "checklist" && l1.subAtividades.isNotEmpty) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AtividadeDetalheScreen(
                    atividade: l1.subAtividades.first,
                  ),
                ),
              ).then((_) => _refresh());
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: "status",
              child: Text("Atualizar status"),
            ),
            const PopupMenuItem(
              value: "checklist",
              child: Text("Ver checklist"),
            ),
          ],
        ),
        children: l1.subAtividades.map((l2) {
          return ListTile(
            contentPadding:
                const EdgeInsets.only(left: 72, right: 16),
            title: Text(l2.nome,
                style: const TextStyle(fontSize: 14)),
            subtitle: Text(
              _buildL2Subtitle(l2),
              style: const TextStyle(fontSize: 12),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _statusIcon(l2.status),
                  size: 20,
                  color: _statusColor(l2.status),
                ),
                if (l2.servicos.isNotEmpty) ...[
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.indigo.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      "${l2.servicos.length}",
                      style: const TextStyle(
                        color: Colors.indigo,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      AtividadeDetalheScreen(atividade: l2),
                ),
              ).then((_) => _refresh());
            },
          );
        }).toList(),
      ),
    );
  }

  String _buildL2Subtitle(AtividadeCronograma l2) {
    final parts = <String>[];
    if (l2.dataInicioPrevista != null) {
      parts.add(
          "${l2.dataInicioPrevista!.split('-').reversed.join('/')} - ${l2.dataFimPrevista?.split('-').reversed.join('/') ?? '?'}");
    }
    parts.add(
        "${_fmtCurrency(l2.valorGasto)} / ${_fmtCurrency(l2.valorPrevisto)}");
    return parts.join("  |  ");
  }
}

// ─── Summary Card ─────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.totalPrevisto,
    required this.totalGasto,
    required this.desvio,
    required this.desvioColor,
    required this.fmtCurrency,
  });

  final double totalPrevisto;
  final double totalGasto;
  final double desvio;
  final Color desvioColor;
  final String Function(double) fmtCurrency;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: desvioColor.withValues(alpha: 0.05),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _SummaryItem(
              label: "Previsto",
              value: fmtCurrency(totalPrevisto),
              color: Colors.blue,
            ),
            _SummaryItem(
              label: "Gasto",
              value: fmtCurrency(totalGasto),
              color: Colors.deepOrange,
            ),
            _SummaryItem(
              label: "Desvio",
              value: "${desvio.toStringAsFixed(1)}%",
              color: desvioColor,
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
