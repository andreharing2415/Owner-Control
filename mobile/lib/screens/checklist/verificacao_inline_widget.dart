import "package:flutter/material.dart";

import "../../models/checklist_item.dart";
import "../../services/api_client.dart";

class VerificacaoInlineWidget extends StatefulWidget {
  const VerificacaoInlineWidget({
    super.key,
    required this.item,
    required this.api,
    required this.onVerificado,
  });

  final ChecklistItem item;
  final ApiClient api;
  final ValueChanged<ChecklistItem> onVerificado;

  @override
  State<VerificacaoInlineWidget> createState() =>
      _VerificacaoInlineWidgetState();
}

class _VerificacaoInlineWidgetState extends State<VerificacaoInlineWidget> {
  final _valorController = TextEditingController();
  String _status = "conforme";
  bool _salvando = false;

  @override
  void dispose() {
    _valorController.dispose();
    super.dispose();
  }

  Future<void> _registrar() async {
    setState(() => _salvando = true);
    try {
      final atualizado = await widget.api.verificarChecklistItem(
        itemId: widget.item.id,
        valorMedido: _valorController.text.trim(),
        status: _status,
      );
      widget.onVerificado(atualizado);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Verificação registrada.")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Erro: $e")));
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dp = widget.item.dadoProjeto;
    final valorRef = dp?["valor_referencia"] as String?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (valorRef != null) ...[
          Text("Referência do projeto: $valorRef",
              style: TextStyle(fontSize: 13, color: Colors.grey[700])),
          const SizedBox(height: 12),
        ],
        TextField(
          controller: _valorController,
          decoration: const InputDecoration(
            labelText: "Valor medido",
            hintText: "Ex: 15cm, 2.5m, etc.",
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        _VerificacaoOption(
          label: "Conforme",
          subtitle: "Está de acordo com o projeto",
          icon: Icons.check_circle_outline,
          color: Colors.green,
          selected: _status == "conforme",
          onTap: () => setState(() => _status = "conforme"),
        ),
        const SizedBox(height: 6),
        _VerificacaoOption(
          label: "Divergente",
          subtitle: "Algo está diferente do projeto",
          icon: Icons.error_outline,
          color: Colors.red,
          selected: _status == "divergente",
          onTap: () => setState(() => _status = "divergente"),
        ),
        const SizedBox(height: 6),
        _VerificacaoOption(
          label: "Dúvida",
          subtitle: "Não tenho certeza, preciso de ajuda",
          icon: Icons.help_outline,
          color: Colors.orange,
          selected: _status == "duvida",
          onTap: () => setState(() => _status = "duvida"),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _salvando ? null : _registrar,
            child: _salvando
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Text("Registrar Verificação"),
          ),
        ),
      ],
    );
  }
}

class _VerificacaoOption extends StatelessWidget {
  const _VerificacaoOption({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.12)
              : Colors.grey.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? color : Colors.grey.withValues(alpha: 0.3),
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: selected ? color : Colors.grey, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                        fontWeight:
                            selected ? FontWeight.bold : FontWeight.w500,
                        color: selected ? color : null,
                      )),
                  Text(subtitle,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
