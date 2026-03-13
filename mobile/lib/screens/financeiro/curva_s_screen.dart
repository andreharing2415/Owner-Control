import "dart:math" as math;

import "package:flutter/foundation.dart" show listEquals;
import "package:flutter/material.dart";

import "../../models/financeiro.dart";
import "../../services/api_client.dart";

class CurvaSScreen extends StatefulWidget {
  const CurvaSScreen({
    super.key,
    required this.obraId,
    required this.api,
  });

  final String obraId;
  final ApiClient api;

  @override
  State<CurvaSScreen> createState() => _CurvaSScreenState();
}

class _CurvaSScreenState extends State<CurvaSScreen> {
  late Future<RelatorioFinanceiro> _relatorioFuture;

  @override
  void initState() {
    super.initState();
    _relatorioFuture = widget.api.relatorioFinanceiro(widget.obraId);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Curva S"),
      ),
      body: FutureBuilder<RelatorioFinanceiro>(
        future: _relatorioFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Erro: ${snapshot.error}"));
          }
          final relatorio = snapshot.data!;
          if (relatorio.curvaS.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.show_chart, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    "Sem dados para exibir a curva S",
                    style: theme.textTheme.titleMedium,
                  ),
                ],
              ),
            );
          }
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _LegendItem(color: Colors.blue, label: "Previsto"),
                    const SizedBox(width: 24),
                    _LegendItem(color: Colors.orange, label: "Realizado"),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return CustomPaint(
                        size: Size(constraints.maxWidth, constraints.maxHeight),
                        painter: _CurvaSPainter(
                          pontos: relatorio.curvaS,
                          theme: theme,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 4,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _CurvaSPainter extends CustomPainter {
  _CurvaSPainter({required this.pontos, required this.theme});

  final List<CurvaSPonto> pontos;
  final ThemeData theme;

  @override
  void paint(Canvas canvas, Size size) {
    if (pontos.isEmpty) return;

    const leftPadding = 60.0;
    const bottomPadding = 40.0;
    const topPadding = 16.0;
    const rightPadding = 16.0;

    final chartWidth = size.width - leftPadding - rightPadding;
    final chartHeight = size.height - bottomPadding - topPadding;

    final maxValue = pontos.fold<double>(0, (max, p) {
      final pMax = math.max(p.previsto, p.realizado);
      return math.max(max, pMax);
    });

    final yMax = maxValue > 0 ? maxValue * 1.1 : 100.0;

    // Draw axes
    final axisPaint = Paint()
      ..color = theme.colorScheme.outline.withValues(alpha: 0.3)
      ..strokeWidth = 1;

    // Y axis
    canvas.drawLine(
      Offset(leftPadding, topPadding),
      Offset(leftPadding, size.height - bottomPadding),
      axisPaint,
    );
    // X axis
    canvas.drawLine(
      Offset(leftPadding, size.height - bottomPadding),
      Offset(size.width - rightPadding, size.height - bottomPadding),
      axisPaint,
    );

    // Draw Y grid lines and labels
    const ySteps = 5;
    final textColor = theme.colorScheme.onSurface.withValues(alpha: 0.6);
    for (var i = 0; i <= ySteps; i++) {
      final y = topPadding + chartHeight * (1 - i / ySteps);
      final value = yMax * i / ySteps;

      // Grid line
      final gridPaint = Paint()
        ..color = theme.colorScheme.outline.withValues(alpha: 0.1)
        ..strokeWidth = 1;
      canvas.drawLine(
        Offset(leftPadding, y),
        Offset(size.width - rightPadding, y),
        gridPaint,
      );

      // Label
      final label = _formatCompact(value);
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(color: textColor, fontSize: 10),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(leftPadding - tp.width - 6, y - tp.height / 2));
    }

    // Draw X labels (show a subset to avoid overlap)
    final labelStep = math.max(1, pontos.length ~/ 6);
    for (var i = 0; i < pontos.length; i += labelStep) {
      final x = leftPadding + chartWidth * i / (pontos.length - 1);
      final label = _formatDateLabel(pontos[i].data);
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(color: textColor, fontSize: 10),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(x - tp.width / 2, size.height - bottomPadding + 8),
      );
    }

    // Draw lines
    _drawLine(
      canvas,
      pontos.map((p) => p.previsto).toList(),
      yMax,
      leftPadding,
      topPadding,
      chartWidth,
      chartHeight,
      Colors.blue,
    );
    _drawLine(
      canvas,
      pontos.map((p) => p.realizado).toList(),
      yMax,
      leftPadding,
      topPadding,
      chartWidth,
      chartHeight,
      Colors.orange,
    );
  }

  void _drawLine(
    Canvas canvas,
    List<double> values,
    double yMax,
    double leftPadding,
    double topPadding,
    double chartWidth,
    double chartHeight,
    Color color,
  ) {
    if (values.length < 2) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..color = color.withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;

    final path = Path();
    final fillPath = Path();

    for (var i = 0; i < values.length; i++) {
      final x = leftPadding + chartWidth * i / (values.length - 1);
      final y = topPadding + chartHeight * (1 - values[i] / yMax);
      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, topPadding + chartHeight);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    // Close fill path
    final lastX =
        leftPadding + chartWidth * (values.length - 1) / (values.length - 1);
    fillPath.lineTo(lastX, topPadding + chartHeight);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);

    // Draw dots
    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    for (var i = 0; i < values.length; i++) {
      final x = leftPadding + chartWidth * i / (values.length - 1);
      final y = topPadding + chartHeight * (1 - values[i] / yMax);
      canvas.drawCircle(Offset(x, y), 3, dotPaint);
    }
  }

  String _formatCompact(double value) {
    if (value >= 1000000) {
      return "R\$${(value / 1000000).toStringAsFixed(1)}M";
    }
    if (value >= 1000) {
      return "R\$${(value / 1000).toStringAsFixed(0)}k";
    }
    return "R\$${value.toStringAsFixed(0)}";
  }

  String _formatDateLabel(String label) {
    // Etapa names may be long — truncate to fit
    if (label.length > 12) {
      return "${label.substring(0, 10)}…";
    }
    return label;
  }

  @override
  bool shouldRepaint(covariant _CurvaSPainter oldDelegate) {
    return !listEquals(oldDelegate.pontos, pontos);
  }
}
