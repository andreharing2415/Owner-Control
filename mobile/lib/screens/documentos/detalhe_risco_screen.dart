import "package:flutter/material.dart";

import "../../models/documento.dart";

class DetalheRiscoScreen extends StatelessWidget {
  const DetalheRiscoScreen({super.key, required this.risco});

  final Risco risco;

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
    final color = _severidadeColor(risco.severidade);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Detalhe do Risco"),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Severidade badge
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.shield, size: 16, color: color),
                    const SizedBox(width: 6),
                    Text(
                      _severidadeLabel(risco.severidade),
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              if (risco.requerValidacaoProfissional)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.warning,
                          size: 16, color: Colors.orange),
                      const SizedBox(width: 6),
                      Text(
                        "Requer validação profissional",
                        style: TextStyle(
                          color: Colors.orange[800],
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),

          // Descricao
          Text(
            "Descrição",
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          const SizedBox(height: 6),
          Text(
            risco.descricao,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 20),

          // Norma referencia
          if (risco.normaReferencia != null) ...[
            Text(
              "Norma de Referência",
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 6),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.gavel, size: 20, color: Colors.blueGrey),
                    const SizedBox(width: 10),
                    Expanded(child: Text(risco.normaReferencia!)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Traducao leigo
          Text(
            "Explicação Simplificada",
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.indigo.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              risco.traducaoLeigo,
              style: TextStyle(
                color: Colors.indigo[700],
                fontSize: 15,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Confianca
          Text(
            "Confiança da Análise",
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: risco.confianca / 100,
                    minHeight: 12,
                    backgroundColor: Colors.grey.withValues(alpha: 0.15),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      risco.confianca >= 80
                          ? Colors.green
                          : risco.confianca >= 50
                              ? Colors.orange
                              : Colors.red,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                "${risco.confianca}%",
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Validacao profissional
          if (risco.requerValidacaoProfissional) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.orange.withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.engineering,
                      color: Colors.orange, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Validação Profissional Necessária",
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    color: Colors.orange[800],
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Este risco deve ser avaliado por um profissional "
                          "habilitado antes de tomar qualquer decisão.",
                          style: TextStyle(color: Colors.orange[900]),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
