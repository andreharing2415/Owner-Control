class ProjetoDoc {
  ProjetoDoc({
    required this.id,
    required this.obraId,
    required this.arquivoUrl,
    required this.arquivoNome,
    required this.status,
    this.resumoGeral,
    this.avisoLegal,
  });

  final String id;
  final String obraId;
  final String arquivoUrl;
  final String arquivoNome;
  final String status;
  final String? resumoGeral;
  final String? avisoLegal;

  factory ProjetoDoc.fromJson(Map<String, dynamic> json) {
    return ProjetoDoc(
      id: json["id"] as String,
      obraId: json["obra_id"] as String,
      arquivoUrl: json["arquivo_url"] as String,
      arquivoNome: json["arquivo_nome"] as String,
      status: json["status"] as String,
      resumoGeral: json["resumo_geral"] as String?,
      avisoLegal: json["aviso_legal"] as String?,
    );
  }
}
