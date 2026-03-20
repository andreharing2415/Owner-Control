import 'package:flutter/material.dart';
import '../../api/api.dart';

class StepCronograma extends StatelessWidget {
  const StepCronograma({
    super.key,
    required this.cronograma,
    required this.gerando,
    required this.onRegenerar,
    required this.onAceitar,
  });

  final CronogramaResponse? cronograma;
  final bool gerando;
  final VoidCallback onRegenerar;
  final VoidCallback onAceitar;

  @override
  Widget build(BuildContext context) {
    if (gerando || cronograma == null) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text("Gerando cronograma..."),
            SizedBox(height: 8),
            Text(
              "Isso pode levar alguns segundos.",
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    final atividades = cronograma!.atividades;

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: atividades.length,
            itemBuilder: (context, index) {
              final l1 = atividades[index];
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 14,
                            child: Text(
                              "${l1.ordem}",
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              l1.nome,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (l1.subAtividades.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        ...l1.subAtividades.map((l2) {
                          return Padding(
                            padding: const EdgeInsets.only(left: 36, top: 4),
                            child: Row(
                              children: [
                                Icon(Icons.subdirectory_arrow_right,
                                    size: 16, color: Colors.grey[400]),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    l2.nome,
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onRegenerar,
                  child: const Text("Regenerar"),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: onAceitar,
                  child: const Text("Aceitar"),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
