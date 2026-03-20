import 'package:flutter/material.dart';

class StepTipo extends StatelessWidget {
  const StepTipo({
    super.key,
    required this.tipo,
    required this.onTipoSelected,
  });

  final String tipo;
  final ValueChanged<String> onTipoSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Qual o tipo da obra?",
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Text("Selecione o tipo para personalizar o fluxo."),
          const SizedBox(height: 32),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: _TipoCard(
                    icon: Icons.construction,
                    titulo: "Construcao",
                    descricao:
                        "Obra nova com projetos, cronograma completo e gerenciamento de atividades.",
                    selecionado: tipo == "construcao",
                    onTap: () => onTipoSelected("construcao"),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _TipoCard(
                    icon: Icons.home_repair_service,
                    titulo: "Reforma",
                    descricao:
                        "Reforma ou manutencao com etapas simplificadas e checklist direto.",
                    selecionado: tipo == "reforma",
                    onTap: () => onTipoSelected("reforma"),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TipoCard extends StatelessWidget {
  const _TipoCard({
    required this.icon,
    required this.titulo,
    required this.descricao,
    required this.selecionado,
    required this.onTap,
  });

  final IconData icon;
  final String titulo;
  final String descricao;
  final bool selecionado;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: selecionado ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: selecionado
            ? BorderSide(color: Theme.of(context).colorScheme.primary, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 64, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 16),
              Text(
                titulo,
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                descricao,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
