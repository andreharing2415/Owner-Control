class ObraConvite {
  ObraConvite({
    required this.id,
    required this.obraId,
    required this.email,
    required this.papel,
    required this.status,
    this.convidadoNome,
    required this.createdAt,
    this.acceptedAt,
  });

  final String id;
  final String obraId;
  final String email;
  final String papel;
  final String status;
  final String? convidadoNome;
  final String createdAt;
  final String? acceptedAt;

  bool get isPendente => status == "pendente";
  bool get isAceito => status == "aceito";

  factory ObraConvite.fromJson(Map<String, dynamic> json) {
    return ObraConvite(
      id: json["id"] as String,
      obraId: json["obra_id"] as String,
      email: json["email"] as String,
      papel: json["papel"] as String,
      status: json["status"] as String,
      convidadoNome: json["convidado_nome"] as String?,
      createdAt: json["created_at"] as String? ?? "",
      acceptedAt: json["accepted_at"] as String?,
    );
  }
}

class ObraConvidada {
  ObraConvidada({
    required this.obraId,
    required this.obraNome,
    required this.donoNome,
    required this.papel,
    required this.conviteId,
  });

  final String obraId;
  final String obraNome;
  final String donoNome;
  final String papel;
  final String conviteId;

  factory ObraConvidada.fromJson(Map<String, dynamic> json) {
    return ObraConvidada(
      obraId: json["obra_id"] as String,
      obraNome: json["obra_nome"] as String,
      donoNome: json["dono_nome"] as String,
      papel: json["papel"] as String,
      conviteId: json["convite_id"] as String,
    );
  }
}

class EtapaComentario {
  EtapaComentario({
    required this.id,
    required this.etapaId,
    required this.userId,
    this.userNome = "",
    required this.texto,
    required this.createdAt,
  });

  final String id;
  final String etapaId;
  final String userId;
  final String userNome;
  final String texto;
  final String createdAt;

  factory EtapaComentario.fromJson(Map<String, dynamic> json) {
    return EtapaComentario(
      id: json["id"] as String,
      etapaId: json["etapa_id"] as String,
      userId: json["user_id"] as String,
      userNome: json["user_nome"] as String? ?? "",
      texto: json["texto"] as String,
      createdAt: json["created_at"] as String? ?? "",
    );
  }
}
