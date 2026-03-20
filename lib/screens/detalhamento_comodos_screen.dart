import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;

import '../api/api.dart';
import '../utils/auth_error_handler.dart';

class DetalhamentoComodosScreen extends StatefulWidget {
  const DetalhamentoComodosScreen({super.key, required this.obraId});
  final String obraId;

  @override
  State<DetalhamentoComodosScreen> createState() =>
      _DetalhamentoComodosScreenState();
}

class _DetalhamentoComodosScreenState extends State<DetalhamentoComodosScreen> {
  final _api = ApiClient();
  late Future<Map<String, dynamic>> _future;
  bool _extraindo = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Map<String, dynamic>? _lastData;

  void _loadData() {
    _future = _api.obterDetalhamento(widget.obraId).then((data) {
      if (mounted) setState(() => _lastData = data);
      return data;
    });
  }

  /// Agrupa e conta itens iguais de todos os cômodos.
  /// Ex: {"Tomada 0.3m do piso": {"qtd": 5, "comodos": ["Garagem", "Depósito"]}}
  Map<String, Map<String, dynamic>> _agruparItens(
    List<dynamic> comodos,
    String campo,
  ) {
    final agrupados = <String, Map<String, dynamic>>{};
    for (final c in comodos) {
      final comodo = c as Map<String, dynamic>;
      final nome = comodo['nome'] as String? ?? '';
      final itens = (comodo[campo] as List<dynamic>?)?.cast<String>() ?? [];
      for (final item in itens) {
        // Normaliza: extrai quantidade e nome do item
        final match = RegExp(r'^(\d+)\s+(.+)$').firstMatch(item.trim());
        final qtd = match != null ? int.tryParse(match.group(1)!) ?? 1 : 1;
        final nomeItem = match != null ? match.group(2)!.trim() : item.trim();
        final key = nomeItem.toLowerCase();

        if (agrupados.containsKey(key)) {
          agrupados[key]!['qtd'] = (agrupados[key]!['qtd'] as int) + qtd;
          final coms = agrupados[key]!['comodos'] as List<String>;
          if (!coms.contains(nome)) coms.add(nome);
        } else {
          agrupados[key] = {
            'nome': nomeItem,
            'qtd': qtd,
            'comodos': [nome],
          };
        }
      }
    }
    return agrupados;
  }

  Future<void> _exportarExcel() async {
    final data = _lastData;
    if (data == null) return;

    final comodos = (data['comodos'] as List<dynamic>?) ?? [];
    if (comodos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nenhum dado para exportar')),
      );
      return;
    }

    final areaTotal = (data['area_total_m2'] as num?)?.toDouble() ?? 0;
    final totais = data['totais_estimados'] as Map<String, dynamic>?;
    final totalPisos = (totais?['total_pisos_m2'] as num?)?.toDouble() ?? 0;
    final totalAzulejos = (totais?['total_azulejos_m2'] as num?)?.toDouble() ?? 0;

    final wb = xlsio.Workbook();

    // ── Estilos ──
    final headerStyle = wb.styles.add('header');
    headerStyle.bold = true;
    headerStyle.backColor = '#4472C4';
    headerStyle.fontColor = '#FFFFFF';
    headerStyle.hAlign = xlsio.HAlignType.center;

    final totalStyle = wb.styles.add('total');
    totalStyle.bold = true;
    totalStyle.backColor = '#D9E2F3';

    final sectionStyle = wb.styles.add('section');
    sectionStyle.bold = true;
    sectionStyle.backColor = '#E2EFDA';

    final subHeaderStyle = wb.styles.add('subHeader');
    subHeaderStyle.bold = true;
    subHeaderStyle.backColor = '#F2F2F2';

    // ═══════════════════════════════════════════════════════════════
    // ABA 1 — Detalhamento por Cômodo
    // ═══════════════════════════════════════════════════════════════
    final sheet1 = wb.worksheets[0];
    sheet1.name = 'Por Cômodo';

    final headers1 = [
      'Cômodo',
      'Área Líquida (m²)',
      'Piso c/ Sobra (m²)',
      'Azulejo c/ Sobra (m²)',
      'Área Molhada',
      'Itens Hidráulicos',
      'Itens Elétricos',
    ];
    for (var i = 0; i < headers1.length; i++) {
      final cell = sheet1.getRangeByIndex(1, i + 1);
      cell.setText(headers1[i]);
      cell.cellStyle = headerStyle;
    }
    for (var r = 0; r < comodos.length; r++) {
      final c = comodos[r] as Map<String, dynamic>;
      final row = r + 2;
      sheet1.getRangeByIndex(row, 1).setText(c['nome'] as String? ?? '');
      sheet1.getRangeByIndex(row, 2).setNumber((c['area_liquida_m2'] as num?)?.toDouble() ?? 0);
      sheet1.getRangeByIndex(row, 3).setNumber((c['estimativa_piso_com_sobra_m2'] as num?)?.toDouble() ?? 0);
      sheet1.getRangeByIndex(row, 4).setNumber((c['estimativa_azulejo_parede_com_sobra_m2'] as num?)?.toDouble() ?? 0);
      sheet1.getRangeByIndex(row, 5).setText((c['area_molhada'] as bool? ?? false) ? 'Sim' : 'Não');
      final hidraulicos = (c['itens_hidraulicos_e_metais'] as List<dynamic>?)?.join(', ') ?? '';
      sheet1.getRangeByIndex(row, 6).setText(hidraulicos);
      final eletricos = (c['itens_eletricos_e_iluminacao'] as List<dynamic>?)?.join(', ') ?? '';
      sheet1.getRangeByIndex(row, 7).setText(eletricos);
    }
    final totalRow1 = comodos.length + 2;
    sheet1.getRangeByIndex(totalRow1, 1)
      ..setText('TOTAL')
      ..cellStyle = totalStyle;
    sheet1.getRangeByIndex(totalRow1, 2)
      ..setNumber(areaTotal)
      ..cellStyle = totalStyle;
    sheet1.getRangeByIndex(totalRow1, 3)
      ..setNumber(totalPisos)
      ..cellStyle = totalStyle;
    sheet1.getRangeByIndex(totalRow1, 4)
      ..setNumber(totalAzulejos)
      ..cellStyle = totalStyle;
    for (var i = 1; i <= headers1.length; i++) {
      sheet1.autoFitColumn(i);
    }

    // ═══════════════════════════════════════════════════════════════
    // ABA 2 — Resumo Agrupado (para compras)
    // ═══════════════════════════════════════════════════════════════
    final sheet2 = wb.worksheets.add();
    sheet2.name = 'Resumo p/ Compras';

    final headers2 = ['Item', 'Qtd Total', 'Cômodos'];
    for (var i = 0; i < headers2.length; i++) {
      final cell = sheet2.getRangeByIndex(1, i + 1);
      cell.setText(headers2[i]);
      cell.cellStyle = headerStyle;
    }

    var row = 2;

    // Seção: Revestimentos
    sheet2.getRangeByIndex(row, 1)
      ..setText('REVESTIMENTOS')
      ..cellStyle = sectionStyle;
    sheet2.getRangeByIndex(row, 2).cellStyle = sectionStyle;
    sheet2.getRangeByIndex(row, 3).cellStyle = sectionStyle;
    row++;

    sheet2.getRangeByIndex(row, 1).setText('Piso (c/ sobra 15%)');
    sheet2.getRangeByIndex(row, 2).setNumber(totalPisos);
    sheet2.getRangeByIndex(row, 3).setText('Todos os cômodos');
    row++;

    if (totalAzulejos > 0) {
      sheet2.getRangeByIndex(row, 1).setText('Azulejo parede (c/ sobra 15%)');
      sheet2.getRangeByIndex(row, 2).setNumber(totalAzulejos);
      final comodosAzulejo = comodos
          .where((c) => ((c as Map)['area_molhada'] as bool? ?? false))
          .map((c) => (c as Map)['nome'] as String? ?? '')
          .join(', ');
      sheet2.getRangeByIndex(row, 3).setText(comodosAzulejo);
      row++;
    }
    row++; // blank row

    // Seção: Itens Elétricos agrupados
    final eletricosAgrupados = _agruparItens(comodos, 'itens_eletricos_e_iluminacao');
    if (eletricosAgrupados.isNotEmpty) {
      sheet2.getRangeByIndex(row, 1)
        ..setText('ELÉTRICA / ILUMINAÇÃO')
        ..cellStyle = sectionStyle;
      sheet2.getRangeByIndex(row, 2).cellStyle = sectionStyle;
      sheet2.getRangeByIndex(row, 3).cellStyle = sectionStyle;
      row++;

      final sortedEletricos = eletricosAgrupados.values.toList()
        ..sort((a, b) => (b['qtd'] as int).compareTo(a['qtd'] as int));
      for (final item in sortedEletricos) {
        sheet2.getRangeByIndex(row, 1).setText(item['nome'] as String);
        sheet2.getRangeByIndex(row, 2).setNumber((item['qtd'] as int).toDouble());
        sheet2.getRangeByIndex(row, 3).setText((item['comodos'] as List<String>).join(', '));
        row++;
      }
      row++; // blank row
    }

    // Seção: Itens Hidráulicos agrupados
    final hidraulicosAgrupados = _agruparItens(comodos, 'itens_hidraulicos_e_metais');
    if (hidraulicosAgrupados.isNotEmpty) {
      sheet2.getRangeByIndex(row, 1)
        ..setText('HIDRÁULICA / METAIS')
        ..cellStyle = sectionStyle;
      sheet2.getRangeByIndex(row, 2).cellStyle = sectionStyle;
      sheet2.getRangeByIndex(row, 3).cellStyle = sectionStyle;
      row++;

      final sortedHidraulicos = hidraulicosAgrupados.values.toList()
        ..sort((a, b) => (b['qtd'] as int).compareTo(a['qtd'] as int));
      for (final item in sortedHidraulicos) {
        sheet2.getRangeByIndex(row, 1).setText(item['nome'] as String);
        sheet2.getRangeByIndex(row, 2).setNumber((item['qtd'] as int).toDouble());
        sheet2.getRangeByIndex(row, 3).setText((item['comodos'] as List<String>).join(', '));
        row++;
      }
    }

    for (var i = 1; i <= headers2.length; i++) {
      sheet2.autoFitColumn(i);
    }

    // Save and share
    final bytes = wb.saveAsStream();
    wb.dispose();

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/quantitativo_obra.xlsx');
    await file.writeAsBytes(bytes, flush: true);

    if (mounted) {
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Quantitativo da Obra',
      );
    }
  }

  /// Mostra diálogo para informar o pé-direito antes de extrair.
  Future<void> _pedirPeDireitoEExtrair() async {
    final controller = TextEditingController(text: '2,70');
    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Altura do pé-direito'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Informe a altura do pé-direito para calcular corretamente a quantidade de azulejos nas áreas molhadas.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Pé-direito (metros)',
                hintText: '2,70',
                suffixText: 'm',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final text = controller.text.replaceAll(',', '.');
              final value = double.tryParse(text);
              if (value != null && value > 0 && value <= 10) {
                Navigator.pop(ctx, value);
              }
            },
            child: const Text('Extrair'),
          ),
        ],
      ),
    );
    if (result == null) return;
    await _extrair(peDireito: result);
  }

  Future<void> _extrair({double peDireito = 2.70}) async {
    setState(() => _extraindo = true);
    try {
      await _api.extrairDetalhamento(widget.obraId, peDireito: peDireito);
      if (mounted) {
        setState(() => _loadData());
      }
    } catch (e) {
      if (mounted) handleApiError(context, e);
    } finally {
      if (mounted) setState(() => _extraindo = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nf = NumberFormat('#,##0.00', 'pt_BR');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quantitativo da Obra'),
        actions: [
          IconButton(
            onPressed: _lastData != null ? _exportarExcel : null,
            icon: const Icon(Icons.table_chart_outlined),
            tooltip: 'Exportar Excel',
          ),
          IconButton(
            onPressed: _extraindo ? null : _pedirPeDireitoEExtrair,
            icon: _extraindo
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            tooltip: 'Extrair do PDF',
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.square_foot, size: 56, color: Colors.grey[400]),
                  const SizedBox(height: 12),
                  const Text('Nenhum detalhamento disponível'),
                  const SizedBox(height: 12),
                  FilledButton.tonalIcon(
                    onPressed: _extraindo ? null : _pedirPeDireitoEExtrair,
                    icon: const Icon(Icons.auto_awesome),
                    label: const Text('Extrair do projeto'),
                  ),
                ],
              ),
            );
          }
          final data = snap.data!;
          _lastData = data;
          final comodos = (data['comodos'] as List<dynamic>?) ?? [];
          final areaTotal = (data['area_total_m2'] as num?)?.toDouble() ?? 0;
          final fonte = data['fonte_doc_nome'] as String?;
          final totais = data['totais_estimados'] as Map<String, dynamic>?;
          final totalPisos = (totais?['total_pisos_m2'] as num?)?.toDouble() ?? 0;
          final totalAzulejos = (totais?['total_azulejos_m2'] as num?)?.toDouble() ?? 0;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Fonte
              if (fonte != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.description_outlined, size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Fonte: $fonte',
                          style: theme.textTheme.bodySmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),

              // Cards de resumo
              Row(
                children: [
                  _MetricCard(
                    label: 'Área total',
                    value: '${nf.format(areaTotal)} m²',
                    icon: Icons.straighten,
                    color: Colors.blue,
                  ),
                  const SizedBox(width: 8),
                  _MetricCard(
                    label: 'Pisos',
                    value: '${nf.format(totalPisos)} m²',
                    icon: Icons.grid_on,
                    color: Colors.teal,
                  ),
                  const SizedBox(width: 8),
                  _MetricCard(
                    label: 'Azulejos',
                    value: '${nf.format(totalAzulejos)} m²',
                    icon: Icons.dashboard_outlined,
                    color: Colors.indigo,
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Lista de cômodos
              Text(
                'Detalhamento por Cômodo',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),

              if (comodos.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Column(
                    children: [
                      Icon(Icons.room_preferences_outlined, size: 56, color: Colors.grey[400]),
                      const SizedBox(height: 12),
                      Text(
                        'Nenhum cômodo encontrado',
                        style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Analise os documentos do projeto para identificar\ncômodos, medidas e calcular quantitativos.',
                        style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[500]),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: _extraindo ? null : _pedirPeDireitoEExtrair,
                        icon: _extraindo
                            ? const SizedBox(
                                width: 18, height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.auto_awesome),
                        label: Text(_extraindo ? 'Analisando documentos...' : 'Identificar Cômodos e Medidas'),
                      ),
                    ],
                  ),
                )
              else
                ...comodos.map((c) {
                  final comodo = c as Map<String, dynamic>;
                  return _ComodoCard(comodo: comodo, nf: nf);
                }),
            ],
          );
        },
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        elevation: 0,
        color: color.withValues(alpha: 0.08),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
                textAlign: TextAlign.center,
              ),
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ComodoCard extends StatelessWidget {
  const _ComodoCard({required this.comodo, required this.nf});
  final Map<String, dynamic> comodo;
  final NumberFormat nf;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nome = comodo['nome'] as String? ?? 'Cômodo';
    final area = (comodo['area_liquida_m2'] as num?)?.toDouble() ?? 0;
    final piso = (comodo['estimativa_piso_com_sobra_m2'] as num?)?.toDouble();
    final azulejo = (comodo['estimativa_azulejo_parede_com_sobra_m2'] as num?)?.toDouble();
    final areaMolhada = comodo['area_molhada'] as bool? ?? false;
    final hidraulicos = (comodo['itens_hidraulicos_e_metais'] as List<dynamic>?)?.cast<String>() ?? [];
    final eletricos = (comodo['itens_eletricos_e_iluminacao'] as List<dynamic>?)?.cast<String>() ?? [];

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    nome,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (areaMolhada)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Área molhada',
                      style: TextStyle(fontSize: 10, color: Colors.blue),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text('Área: ${nf.format(area)} m²', style: theme.textTheme.bodySmall),
            if (piso != null)
              Text('Piso (c/ sobra): ${nf.format(piso)} m²', style: theme.textTheme.bodySmall),
            if (azulejo != null)
              Text('Azulejo (c/ sobra): ${nf.format(azulejo)} m²', style: theme.textTheme.bodySmall),
            if (hidraulicos.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: hidraulicos.map((h) => Chip(
                  label: Text(h, style: const TextStyle(fontSize: 10)),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                  avatar: const Icon(Icons.water_drop, size: 14),
                )).toList(),
              ),
            ],
            if (eletricos.isNotEmpty) ...[
              const SizedBox(height: 4),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: eletricos.map((e) => Chip(
                  label: Text(e, style: const TextStyle(fontSize: 10)),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                  avatar: const Icon(Icons.electrical_services, size: 14),
                )).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
