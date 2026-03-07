class Prestador {
  Prestador({
    required this.id,
    required this.nome,
    required this.categoria,
    required this.subcategoria,
    this.regiao,
    this.telefone,
    this.email,
    this.mediaGeral,
  });

  final String id;
  final String nome;
  final String categoria;
  final String subcategoria;
  final String? regiao;
  final String? telefone;
  final String? email;
  final double? mediaGeral;

  factory Prestador.fromJson(Map<String, dynamic> json) {
    return Prestador(
      id: json["id"] as String,
      nome: json["nome"] as String,
      categoria: json["categoria"] as String,
      subcategoria: json["subcategoria"] as String,
      regiao: json["regiao"] as String?,
      telefone: json["telefone"] as String?,
      email: json["email"] as String?,
      mediaGeral: (json["nota_geral"] as num?)?.toDouble(),
    );
  }
}

class Avaliacao {
  Avaliacao({
    required this.id,
    required this.prestadorId,
    this.notaQualidadeServico,
    this.notaCumprimentoPrazos,
    this.notaFidelidadeProjeto,
    this.notaPrazoEntrega,
    this.notaQualidadeMaterial,
    this.comentario,
    this.createdAt,
  });

  final String id;
  final String prestadorId;
  final int? notaQualidadeServico;
  final int? notaCumprimentoPrazos;
  final int? notaFidelidadeProjeto;
  final int? notaPrazoEntrega;
  final int? notaQualidadeMaterial;
  final String? comentario;
  final String? createdAt;

  factory Avaliacao.fromJson(Map<String, dynamic> json) {
    return Avaliacao(
      id: json["id"] as String,
      prestadorId: json["prestador_id"] as String,
      notaQualidadeServico: json["nota_qualidade_servico"] as int?,
      notaCumprimentoPrazos: json["nota_cumprimento_prazos"] as int?,
      notaFidelidadeProjeto: json["nota_fidelidade_projeto"] as int?,
      notaPrazoEntrega: json["nota_prazo_entrega"] as int?,
      notaQualidadeMaterial: json["nota_qualidade_material"] as int?,
      comentario: json["comentario"] as String?,
      createdAt: json["created_at"] as String?,
    );
  }
}

class Subcategoria {
  Subcategoria({required this.categoria, required this.subcategorias});

  final String categoria;
  final List<String> subcategorias;
}
