import 'package:flutter/material.dart';
import '../../api/api.dart';
import '../../utils/auth_error_handler.dart';
import '../../utils/status_helper.dart';

class InfoTab extends StatelessWidget {
  const InfoTab({
    super.key,
    required this.atividade,
    required this.onStatusChanged,
    required this.onDespesaRegistrada,
  });

  final AtividadeCronograma atividade;
  final VoidCallback onStatusChanged;
  final VoidCallback onDespesaRegistrada;

  String _fmtDate(String? iso) {
    if (iso == null) return "—";
    return iso.split('-').reversed.join('/');
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Detalhes da atividade",
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const Divider(),
                  _InfoRow(
                    label: "Status",
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: etapaStatusColor(atividade.status)
                            .withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        atividade.status.replaceAll("_", " "),
                        style: TextStyle(
                          color: etapaStatusColor(atividade.status),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _InfoRow(
                      label: "Inicio previsto",
                      value: _fmtDate(atividade.dataInicioPrevista)),
                  const SizedBox(height: 8),
                  _InfoRow(
                      label: "Fim previsto",
                      value: _fmtDate(atividade.dataFimPrevista)),
                  const SizedBox(height: 8),
                  _InfoRow(
                      label: "Inicio real",
                      value: _fmtDate(atividade.dataInicioReal)),
                  const SizedBox(height: 8),
                  _InfoRow(
                      label: "Fim real",
                      value: _fmtDate(atividade.dataFimReal)),
                  const Divider(height: 24),
                  _InfoRow(
                    label: "Valor previsto",
                    value:
                        "R\$ ${atividade.valorPrevisto.toStringAsFixed(2)}",
                  ),
                  const SizedBox(height: 8),
                  _InfoRow(
                    label: "Valor gasto",
                    value: "R\$ ${atividade.valorGasto.toStringAsFixed(2)}",
                  ),
                  if (atividade.valorPrevisto > 0) ...[
                    const SizedBox(height: 8),
                    _InfoRow(
                      label: "Desvio",
                      value:
                          "${(((atividade.valorGasto - atividade.valorPrevisto) / atividade.valorPrevisto) * 100).toStringAsFixed(1)}%",
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onStatusChanged,
              icon: const Icon(Icons.edit),
              label: const Text("Atualizar status"),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onDespesaRegistrada,
              icon: const Icon(Icons.attach_money),
              label: const Text("Registrar despesa"),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    this.value,
    this.child,
  });

  final String label;
  final String? value;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 14, color: Colors.grey)),
        child ??
            Text(
              value ?? "—",
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w500),
            ),
      ],
    );
  }
}
