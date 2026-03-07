class AuthTokens {
  AuthTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.tokenType,
  });

  final String accessToken;
  final String refreshToken;
  final String tokenType;

  factory AuthTokens.fromJson(Map<String, dynamic> json) {
    return AuthTokens(
      accessToken: json["access_token"] as String,
      refreshToken: json["refresh_token"] as String,
      tokenType: json["token_type"] as String? ?? "bearer",
    );
  }
}

class User {
  User({
    required this.id,
    required this.email,
    required this.nome,
    this.telefone,
    required this.role,
  });

  final String id;
  final String email;
  final String nome;
  final String? telefone;
  final String role;

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json["id"] as String,
      email: json["email"] as String,
      nome: json["nome"] as String,
      telefone: json["telefone"] as String?,
      role: json["role"] as String? ?? "owner",
    );
  }
}

class ChecklistInteligenteLog {
  ChecklistInteligenteLog({
    required this.id,
    required this.obraId,
    required this.status,
    required this.totalDocsAnalisados,
    this.caracteristicasIdentificadas,
    required this.totalItensSugeridos,
    required this.totalItensAplicados,
    this.resumoGeral,
    this.avisoLegal,
    this.erroDetalhe,
  });

  final String id;
  final String obraId;
  final String status;
  final int totalDocsAnalisados;
  final List<String>? caracteristicasIdentificadas;
  final int totalItensSugeridos;
  final int totalItensAplicados;
  final String? resumoGeral;
  final String? avisoLegal;
  final String? erroDetalhe;

  factory ChecklistInteligenteLog.fromJson(Map<String, dynamic> json) {
    List<String>? caract;
    if (json["caracteristicas_identificadas"] != null) {
      final raw = json["caracteristicas_identificadas"];
      if (raw is List) {
        caract = raw.cast<String>();
      }
    }
    return ChecklistInteligenteLog(
      id: json["id"] as String,
      obraId: json["obra_id"] as String,
      status: json["status"] as String,
      totalDocsAnalisados: json["total_docs_analisados"] as int? ?? 0,
      caracteristicasIdentificadas: caract,
      totalItensSugeridos: json["total_itens_sugeridos"] as int? ?? 0,
      totalItensAplicados: json["total_itens_aplicados"] as int? ?? 0,
      resumoGeral: json["resumo_geral"] as String?,
      avisoLegal: json["aviso_legal"] as String?,
      erroDetalhe: json["erro_detalhe"] as String?,
    );
  }
}
