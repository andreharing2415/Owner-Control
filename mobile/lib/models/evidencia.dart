class Evidencia {
  Evidencia({
    required this.id,
    required this.checklistItemId,
    required this.arquivoUrl,
    required this.arquivoNome,
    this.mimeType,
    this.tamanhoBytes,
  });

  final String id;
  final String checklistItemId;
  final String arquivoUrl;
  final String arquivoNome;
  final String? mimeType;
  final int? tamanhoBytes;

  factory Evidencia.fromJson(Map<String, dynamic> json) {
    return Evidencia(
      id: json["id"] as String,
      checklistItemId: json["checklist_item_id"] as String,
      arquivoUrl: json["arquivo_url"] as String,
      arquivoNome: json["arquivo_nome"] as String,
      mimeType: json["mime_type"] as String?,
      tamanhoBytes: json["tamanho_bytes"] as int?,
    );
  }
}
