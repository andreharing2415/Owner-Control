import "package:flutter/material.dart";

class DetalhamentoComodosScreen extends StatelessWidget {
  const DetalhamentoComodosScreen({super.key, required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final comodos = (data["comodos"] as List<dynamic>?) ?? [];
    final areaTotal = data["area_total_m2"] as num?;
    final fonteDoc = data["fonte_doc_nome"] as String?;
    final totais = data["totais_estimados"] as Map<String, dynamic>?;
    final resumo = data["resumo_projeto"] as String?;
    final peDireito = data["pe_direito_utilizado"] as String?;

    final totalPisos = (totais?["total_pisos_m2"] as num?) ?? 0;
    final totalAzulejos = (totais?["total_azulejos_m2"] as num?) ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Quantitativo da Obra"),
      ),
      body: comodos.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.home_work_outlined, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text("Nenhum cômodo extraído",
                      style: theme.textTheme.titleMedium),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                // Resumo do projeto
                if (resumo != null) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: theme.colorScheme.primaryContainer,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.description_outlined,
                            color: theme.colorScheme.primary, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(resumo,
                              style: theme.textTheme.bodyMedium),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Info row: fonte + pé-direito
                Wrap(
                  spacing: 16,
                  runSpacing: 4,
                  children: [
                    if (fonteDoc != null)
                      _InfoChip(
                        icon: Icons.insert_drive_file_outlined,
                        label: fonteDoc,
                      ),
                    if (peDireito != null)
                      _InfoChip(
                        icon: Icons.height,
                        label: "Pé-direito: $peDireito",
                      ),
                  ],
                ),
                const SizedBox(height: 16),

                // Totais cards
                Row(
                  children: [
                    _TotalCard(
                      icon: Icons.square_foot,
                      color: Colors.indigo,
                      value: areaTotal != null
                          ? "${areaTotal.toStringAsFixed(1)} m²"
                          : "—",
                      label: "Área Total",
                    ),
                    const SizedBox(width: 8),
                    _TotalCard(
                      icon: Icons.grid_view_rounded,
                      color: Colors.blue,
                      value: "${totalPisos.toStringAsFixed(1)} m²",
                      label: "Pisos (c/ sobra)",
                    ),
                    const SizedBox(width: 8),
                    _TotalCard(
                      icon: Icons.wallpaper_rounded,
                      color: Colors.teal,
                      value: "${totalAzulejos.toStringAsFixed(1)} m²",
                      label: "Azulejos (c/ sobra)",
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Section title
                Text("Detalhamento por Cômodo",
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    )),
                const SizedBox(height: 8),

                // Room cards
                ...comodos.asMap().entries.map((entry) {
                  final c = entry.value as Map<String, dynamic>;
                  return _ComodoCard(comodo: c);
                }),
              ],
            ),
    );
  }
}

// ─── Info Chip ──────────────────────────────────────────────────────────────

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey[500]),
        const SizedBox(width: 4),
        Flexible(
          child: Text(label,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}

// ─── Total Card ─────────────────────────────────────────────────────────────

class _TotalCard extends StatelessWidget {
  const _TotalCard({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });
  final IconData icon;
  final Color color;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: color,
                  )),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(label,
                  style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                  textAlign: TextAlign.center),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Comodo Card ────────────────────────────────────────────────────────────

class _ComodoCard extends StatelessWidget {
  const _ComodoCard({required this.comodo});
  final Map<String, dynamic> comodo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nome = comodo["nome"] as String? ?? "—";
    final areaLiquida = (comodo["area_liquida_m2"] ?? comodo["area_m2"]) as num?;
    final pisoCobra = comodo["estimativa_piso_com_sobra_m2"] as num?;
    final isMolhada = comodo["area_molhada"] == true;
    final azulejo = comodo["estimativa_azulejo_parede_com_sobra_m2"] as num?;
    final itensHidraulicos =
        (comodo["itens_hidraulicos_e_metais"] as List<dynamic>?)
                ?.cast<String>() ??
            [];
    final itensEletricos =
        (comodo["itens_eletricos_e_iluminacao"] as List<dynamic>?)
                ?.cast<String>() ??
            [];

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            color: isMolhada
                ? Colors.blue.withValues(alpha: 0.08)
                : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            child: Row(
              children: [
                Icon(
                  isMolhada ? Icons.water_drop_rounded : Icons.meeting_room_outlined,
                  size: 20,
                  color: isMolhada ? Colors.blue : theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(nome,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      )),
                ),
                if (isMolhada)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text("Área molhada",
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue)),
                  ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Metrics row
                Row(
                  children: [
                    if (areaLiquida != null)
                      _MetricTile(
                        label: "Área",
                        value: "${areaLiquida.toStringAsFixed(1)} m²",
                        icon: Icons.crop_square,
                      ),
                    if (pisoCobra != null) ...[
                      const SizedBox(width: 16),
                      _MetricTile(
                        label: "Piso",
                        value: "${pisoCobra.toStringAsFixed(1)} m²",
                        icon: Icons.grid_view_rounded,
                      ),
                    ],
                    if (isMolhada && azulejo != null && azulejo > 0) ...[
                      const SizedBox(width: 16),
                      _MetricTile(
                        label: "Azulejo",
                        value: "${azulejo.toStringAsFixed(1)} m²",
                        icon: Icons.wallpaper_rounded,
                      ),
                    ],
                  ],
                ),

                // Hydraulic items
                if (itensHidraulicos.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _ItemSection(
                    icon: Icons.plumbing,
                    color: Colors.blue,
                    title: "Hidráulica & Metais",
                    items: itensHidraulicos,
                  ),
                ],

                // Electrical items
                if (itensEletricos.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _ItemSection(
                    icon: Icons.electrical_services,
                    color: Colors.amber.shade700,
                    title: "Elétrica & Iluminação",
                    items: itensEletricos,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Metric Tile ────────────────────────────────────────────────────────────

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.icon,
  });
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: Colors.grey[500]),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(fontSize: 11, color: Colors.grey[500])),
          ],
        ),
        const SizedBox(height: 2),
        Text(value,
            style: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

// ─── Item Section ───────────────────────────────────────────────────────────

class _ItemSection extends StatelessWidget {
  const _ItemSection({
    required this.icon,
    required this.color,
    required this.title,
    required this.items,
  });
  final IconData icon;
  final Color color;
  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 6),
            Text(title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                )),
          ],
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: items
              .map((item) => Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: color.withValues(alpha: 0.15)),
                    ),
                    child: Text(item,
                        style: TextStyle(fontSize: 11, color: Colors.grey[700])),
                  ))
              .toList(),
        ),
      ],
    );
  }
}
