class Obra {
  Obra({
    required this.id,
    required this.nome,
    this.localizacao,
    this.orcamento,
    this.areaM2,
  });

  final String id;
  final String nome;
  final String? localizacao;
  final double? orcamento;
  final double? areaM2;

  factory Obra.fromJson(Map<String, dynamic> json) {
    return Obra(
      id: json["id"] as String,
      nome: json["nome"] as String,
      localizacao: json["localizacao"] as String?,
      orcamento: (json["orcamento"] as num?)?.toDouble(),
      areaM2: (json["area_m2"] as num?)?.toDouble(),
    );
  }
}
