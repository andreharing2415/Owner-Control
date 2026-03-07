class Etapa {
  Etapa({
    required this.id,
    required this.obraId,
    required this.nome,
    required this.ordem,
    required this.status,
    this.score,
  });

  final String id;
  final String obraId;
  final String nome;
  final int ordem;
  final String status;
  final double? score;

  factory Etapa.fromJson(Map<String, dynamic> json) {
    return Etapa(
      id: json["id"] as String,
      obraId: json["obra_id"] as String,
      nome: json["nome"] as String,
      ordem: json["ordem"] as int,
      status: json["status"] as String,
      score: (json["score"] as num?)?.toDouble(),
    );
  }
}
