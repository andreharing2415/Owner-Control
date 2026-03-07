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
    this.totalPaginas = 0,
    this.paginasProcessadas = 0,
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
  final int totalPaginas;
  final int paginasProcessadas;

  bool get isProcessando => status == "processando";
  bool get isConcluido => status == "concluido";
  bool get isErro => status == "erro";

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
      totalPaginas: json["total_paginas"] as int? ?? 0,
      paginasProcessadas: json["paginas_processadas"] as int? ?? 0,
    );
  }
}

class ChecklistGeracaoItemModel {
  ChecklistGeracaoItemModel({
    required this.id,
    required this.logId,
    required this.etapaNome,
    required this.titulo,
    required this.descricao,
    this.normaReferencia,
    this.critico = false,
    this.riscoNivel = "baixo",
    this.requerValidacaoProfissional = false,
    this.confianca = 0,
    this.comoVerificar = "",
    this.medidasMinimas,
    this.explicacaoLeigo = "",
    this.caracteristicaOrigem = "",
  });

  final String id;
  final String logId;
  final String etapaNome;
  final String titulo;
  final String descricao;
  final String? normaReferencia;
  final bool critico;
  final String riscoNivel;
  final bool requerValidacaoProfissional;
  final int confianca;
  final String comoVerificar;
  final String? medidasMinimas;
  final String explicacaoLeigo;
  final String caracteristicaOrigem;

  factory ChecklistGeracaoItemModel.fromJson(Map<String, dynamic> json) {
    return ChecklistGeracaoItemModel(
      id: json["id"] as String,
      logId: json["log_id"] as String,
      etapaNome: json["etapa_nome"] as String,
      titulo: json["titulo"] as String,
      descricao: json["descricao"] as String,
      normaReferencia: json["norma_referencia"] as String?,
      critico: json["critico"] as bool? ?? false,
      riscoNivel: json["risco_nivel"] as String? ?? "baixo",
      requerValidacaoProfissional:
          json["requer_validacao_profissional"] as bool? ?? false,
      confianca: (json["confianca"] as num?)?.toInt() ?? 0,
      comoVerificar: json["como_verificar"] as String? ?? "",
      medidasMinimas: json["medidas_minimas"] as String?,
      explicacaoLeigo: json["explicacao_leigo"] as String? ?? "",
      caracteristicaOrigem: json["caracteristica_origem"] as String? ?? "",
    );
  }

  Map<String, dynamic> toJsonForApply() => {
        "etapa_nome": etapaNome,
        "titulo": titulo,
        "descricao": descricao,
        "norma_referencia": normaReferencia,
        "critico": critico,
      };
}

class ChecklistGeracaoStatus {
  ChecklistGeracaoStatus({
    required this.log,
    required this.itens,
  });

  final ChecklistInteligenteLog log;
  final List<ChecklistGeracaoItemModel> itens;

  factory ChecklistGeracaoStatus.fromJson(Map<String, dynamic> json) {
    return ChecklistGeracaoStatus(
      log: ChecklistInteligenteLog.fromJson(
          json["log"] as Map<String, dynamic>? ?? json),
      itens: (json["itens"] as List<dynamic>?)
              ?.map((e) =>
                  ChecklistGeracaoItemModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}
