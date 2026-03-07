import "package:flutter/material.dart";
import "package:url_launcher/url_launcher.dart";

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

  Future<void> _abrirNormaUrl(BuildContext context) async {
    if (risco.normaUrl == null) return;
    final uri = Uri.tryParse(risco.normaUrl!);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Não foi possível abrir o link.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _severidadeColor(risco.severidade);
    final theme = Theme.of(context);

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
            style: theme.textTheme.titleSmall?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          const SizedBox(height: 6),
          Text(
            risco.descricao,
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 20),

          // Norma referencia
          if (risco.normaReferencia != null) ...[
            Text(
              "Norma de Referência",
              style: theme.textTheme.titleSmall?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 6),
            Card(
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: risco.normaUrl != null
                    ? () => _abrirNormaUrl(context)
                    : null,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Icon(Icons.gavel, size: 20, color: Colors.blueGrey),
                      const SizedBox(width: 10),
                      Expanded(child: Text(risco.normaReferencia!)),
                      if (risco.normaUrl != null)
                        const Icon(Icons.open_in_new,
                            size: 16, color: Colors.blue),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Traducao leigo
          Text(
            "Explicação Simplificada",
            style: theme.textTheme.titleSmall?.copyWith(
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

          // Acao do proprietario
          if (risco.acaoProprietario != null) ...[
            _buildSection(
              context,
              icon: Icons.task_alt,
              iconColor: Colors.green,
              title: "O que você deve fazer",
              bgColor: Colors.green.withValues(alpha: 0.08),
              borderColor: Colors.green.withValues(alpha: 0.3),
              child: Text(
                risco.acaoProprietario!,
                style: TextStyle(
                  color: Colors.green[900],
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Perguntas para profissional
          if (risco.perguntasParaProfissional != null &&
              risco.perguntasParaProfissional!.isNotEmpty) ...[
            _buildSection(
              context,
              icon: Icons.help_outline,
              iconColor: Colors.blue,
              title: "Pergunte ao seu engenheiro",
              bgColor: Colors.blue.withValues(alpha: 0.08),
              borderColor: Colors.blue.withValues(alpha: 0.3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: risco.perguntasParaProfissional!.map((perg) {
                  final pergunta = perg["pergunta"] ?? "";
                  final respostaEsperada = perg["resposta_esperada"] ?? "";
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.chat_bubble_outline,
                                size: 16, color: Colors.blue[700]),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                pergunta,
                                style: TextStyle(
                                  color: Colors.blue[900],
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (respostaEsperada.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Padding(
                            padding: const EdgeInsets.only(left: 24),
                            child: Text(
                              "Resposta esperada: $respostaEsperada",
                              style: TextStyle(
                                color: Colors.blue[700],
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Documentos a exigir
          if (risco.documentosAExigir != null &&
              risco.documentosAExigir!.isNotEmpty) ...[
            _buildSection(
              context,
              icon: Icons.description,
              iconColor: Colors.purple,
              title: "Documentos a exigir",
              bgColor: Colors.purple.withValues(alpha: 0.08),
              borderColor: Colors.purple.withValues(alpha: 0.3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: risco.documentosAExigir!
                    .map((doc) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.article_outlined,
                                  size: 16, color: Colors.purple[600]),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  doc,
                                  style: TextStyle(
                                    color: Colors.purple[900],
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ))
                    .toList(),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Confianca
          Text(
            "Confiança da Análise",
            style: theme.textTheme.titleSmall?.copyWith(
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
                style: theme.textTheme.titleMedium?.copyWith(
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
                              theme.textTheme.titleSmall?.copyWith(
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

  Widget _buildSection(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required Color bgColor,
    required Color borderColor,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: iconColor),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: iconColor,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
