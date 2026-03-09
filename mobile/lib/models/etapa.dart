class Etapa {
  Etapa({
    required this.id,
    required this.obraId,
    required this.nome,
    required this.ordem,
    required this.status,
    this.score,
    this.prazoPrevisto,
    this.prazoExecutado,
  });

  final String id;
  final String obraId;
  final String nome;
  final int ordem;
  final String status;
  final double? score;
  final DateTime? prazoPrevisto;
  final DateTime? prazoExecutado;

  factory Etapa.fromJson(Map<String, dynamic> json) {
    return Etapa(
      id: json["id"] as String,
      obraId: json["obra_id"] as String,
      nome: json["nome"] as String,
      ordem: json["ordem"] as int,
      status: json["status"] as String,
      score: (json["score"] as num?)?.toDouble(),
      prazoPrevisto: json["prazo_previsto"] != null
          ? DateTime.parse(json["prazo_previsto"] as String)
          : null,
      prazoExecutado: json["prazo_executado"] != null
          ? DateTime.parse(json["prazo_executado"] as String)
          : null,
    );
  }
}
