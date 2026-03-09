import "package:flutter/material.dart";

import "../../models/documento.dart";
import "../../services/api_client.dart";

class RegistrarVerificacaoScreen extends StatefulWidget {
  const RegistrarVerificacaoScreen({
    super.key,
    required this.risco,
    required this.api,
  });

  final Risco risco;
  final ApiClient api;

  @override
  State<RegistrarVerificacaoScreen> createState() =>
      _RegistrarVerificacaoScreenState();
}

class _RegistrarVerificacaoScreenState
    extends State<RegistrarVerificacaoScreen> {
  final _valorMedidoController = TextEditingController();
  String _status = "conforme";
  bool _enviando = false;

  @override
  void dispose() {
    _valorMedidoController.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    setState(() => _enviando = true);
    try {
      final riscoAtualizado = await widget.api.registrarVerificacaoRisco(
        riscoId: widget.risco.id,
        valorMedido: _valorMedidoController.text.isNotEmpty
            ? _valorMedidoController.text
            : null,
        status: _status,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Verificação registrada com sucesso!")),
        );
        Navigator.pop(context, riscoAtualizado);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final verificacoes = widget.risco.verificacoes ?? [];
    final dadoProjeto = widget.risco.dadoProjeto;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Registrar Verificação"),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Resumo do que verificar
          if (dadoProjeto != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.teal.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: Colors.teal.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.architecture,
                          size: 18, color: Colors.teal[700]),
                      const SizedBox(width: 8),
                      Text(
                        "Referência do Projeto",
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: Colors.teal[700],
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (dadoProjeto["descricao"] != null)
                    Text(
                      dadoProjeto["descricao"],
                      style:
                          TextStyle(color: Colors.teal[900], fontSize: 14),
                    ),
                  if (dadoProjeto["valor_referencia"] != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      "Valor de referência: ${dadoProjeto["valor_referencia"]}",
                      style: TextStyle(
                        color: Colors.teal[800],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Checklist de verificações
          if (verificacoes.isNotEmpty) ...[
            Text(
              "O que verificar:",
              style: theme.textTheme.titleSmall
                  ?.copyWith(color: Colors.grey[700]),
            ),
            const SizedBox(height: 8),
            ...verificacoes.map((v) {
              final iconMap = {
                "medicao": Icons.straighten,
                "visual": Icons.visibility,
                "documento": Icons.description,
              };
              final tipo = v["tipo"] ?? "visual";
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(iconMap[tipo] ?? Icons.check,
                          size: 20, color: Colors.blue[600]),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              v["instrucao"] ?? "",
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            if (v["como_medir"] != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                v["como_medir"]!,
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 16),
          ],

          const Divider(),
          const SizedBox(height: 16),

          // Formulário
          Text(
            "Sua verificação",
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 16),

          // Valor medido (opcional)
          TextField(
            controller: _valorMedidoController,
            decoration: const InputDecoration(
              labelText: "Valor medido (opcional)",
              hintText: "Ex: 15cm, 2.5m, etc.",
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.straighten),
            ),
          ),
          const SizedBox(height: 20),

          // Status
          Text(
            "Resultado da sua verificação:",
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 10),

          _buildStatusOption(
            value: "conforme",
            icon: Icons.check_circle,
            color: Colors.green,
            label: "Conforme",
            description: "Está de acordo com o projeto",
          ),
          const SizedBox(height: 8),
          _buildStatusOption(
            value: "divergente",
            icon: Icons.error,
            color: Colors.red,
            label: "Divergente",
            description: "Algo está diferente do projeto",
          ),
          const SizedBox(height: 8),
          _buildStatusOption(
            value: "duvida",
            icon: Icons.help,
            color: Colors.amber,
            label: "Dúvida",
            description: "Não tenho certeza, preciso de ajuda",
          ),
          const SizedBox(height: 24),

          // Botão enviar
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              onPressed: _enviando ? null : _enviar,
              icon: _enviando
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send),
              label: Text(_enviando ? "Enviando..." : "Registrar Verificação"),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildStatusOption({
    required String value,
    required IconData icon,
    required Color color,
    required String label,
    required String description,
  }) {
    final selected = _status == value;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => setState(() => _status = value),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.12)
              : Colors.grey.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? color.withValues(alpha: 0.5)
                : Colors.grey.withValues(alpha: 0.2),
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: selected ? color : Colors.grey, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: selected ? color : Colors.grey[800],
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    description,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check_circle, color: color, size: 24),
          ],
        ),
      ),
    );
  }
}
