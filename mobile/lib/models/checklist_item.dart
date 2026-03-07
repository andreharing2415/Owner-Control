class ChecklistItem {
  ChecklistItem({
    required this.id,
    required this.etapaId,
    required this.titulo,
    this.descricao,
    required this.status,
    required this.critico,
    this.observacao,
  });

  final String id;
  final String etapaId;
  final String titulo;
  final String? descricao;
  final String status;
  final bool critico;
  final String? observacao;

  factory ChecklistItem.fromJson(Map<String, dynamic> json) {
    return ChecklistItem(
      id: json["id"] as String,
      etapaId: json["etapa_id"] as String,
      titulo: json["titulo"] as String,
      descricao: json["descricao"] as String?,
      status: json["status"] as String? ?? "pendente",
      critico: json["critico"] as bool? ?? false,
      observacao: json["observacao"] as String?,
    );
  }
}
