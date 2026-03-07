class NormaResultado {
  NormaResultado({
    required this.id,
    required this.titulo,
    required this.fonteNome,
    this.fonteUrl,
    required this.fonteTipo,
    this.versao,
    this.dataNorma,
    this.trechoRelevante,
    required this.traducaoLeigo,
    required this.nivelConfianca,
    this.riscoNivel,
    required this.requerValidacaoProfissional,
  });

  final String id;
  final String titulo;
  final String fonteNome;
  final String? fonteUrl;
  final String fonteTipo;
  final String? versao;
  final String? dataNorma;
  final String? trechoRelevante;
  final String traducaoLeigo;
  final int nivelConfianca;
  final String? riscoNivel;
  final bool requerValidacaoProfissional;

  factory NormaResultado.fromJson(Map<String, dynamic> json) {
    return NormaResultado(
      id: json["id"] as String,
      titulo: json["titulo"] as String,
      fonteNome: json["fonte_nome"] as String,
      fonteUrl: json["fonte_url"] as String?,
      fonteTipo: json["fonte_tipo"] as String? ?? "secundaria",
      versao: json["versao"] as String?,
      dataNorma: json["data_norma"] as String?,
      trechoRelevante: json["trecho_relevante"] as String?,
      traducaoLeigo: json["traducao_leigo"] as String,
      nivelConfianca: (json["nivel_confianca"] as num?)?.toInt() ?? 0,
      riscoNivel: json["risco_nivel"] as String?,
      requerValidacaoProfissional:
          json["requer_validacao_profissional"] as bool? ?? false,
    );
  }
}

class ChecklistDinamicoItem {
  ChecklistDinamicoItem({
    required this.item,
    required this.critico,
    this.normaReferencia,
  });

  final String item;
  final bool critico;
  final String? normaReferencia;

  factory ChecklistDinamicoItem.fromJson(Map<String, dynamic> json) {
    return ChecklistDinamicoItem(
      item: json["item"] as String,
      critico: json["critico"] as bool? ?? false,
      normaReferencia: json["norma_referencia"] as String?,
    );
  }
}

class NormaBuscarResponse {
  NormaBuscarResponse({
    required this.logId,
    required this.etapaNome,
    required this.resumoGeral,
    required this.avisoLegal,
    required this.dataConsulta,
    required this.normas,
    required this.checklistDinamico,
  });

  final String logId;
  final String etapaNome;
  final String resumoGeral;
  final String avisoLegal;
  final String dataConsulta;
  final List<NormaResultado> normas;
  final List<ChecklistDinamicoItem> checklistDinamico;

  factory NormaBuscarResponse.fromJson(Map<String, dynamic> json) {
    return NormaBuscarResponse(
      logId: json["log_id"] as String,
      etapaNome: json["etapa_nome"] as String,
      resumoGeral: json["resumo_geral"] as String,
      avisoLegal: json["aviso_legal"] as String,
      dataConsulta: json["data_consulta"] as String,
      normas: (json["normas"] as List<dynamic>)
          .map((item) =>
              NormaResultado.fromJson(item as Map<String, dynamic>))
          .toList(),
      checklistDinamico: (json["checklist_dinamico"] as List<dynamic>)
          .map((item) =>
              ChecklistDinamicoItem.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class NormaLogResumido {
  NormaLogResumido({
    required this.id,
    required this.etapaNome,
    this.disciplina,
    this.localizacao,
    required this.dataConsulta,
    required this.totalNormas,
  });

  final String id;
  final String etapaNome;
  final String? disciplina;
  final String? localizacao;
  final String dataConsulta;
  final int totalNormas;

  factory NormaLogResumido.fromJson(Map<String, dynamic> json) {
    final resultados = json["resultados"] as List<dynamic>? ?? [];
    return NormaLogResumido(
      id: json["id"] as String,
      etapaNome: json["etapa_nome"] as String,
      disciplina: json["disciplina"] as String?,
      localizacao: json["localizacao"] as String?,
      dataConsulta: json["data_consulta"] as String,
      totalNormas: resultados.length,
    );
  }
}

class EtapaNormaInfo {
  EtapaNormaInfo({required this.nome, required this.keywords});

  final String nome;
  final List<String> keywords;

  factory EtapaNormaInfo.fromJson(Map<String, dynamic> json) {
    return EtapaNormaInfo(
      nome: json["nome"] as String,
      keywords: (json["keywords"] as List<dynamic>).cast<String>(),
    );
  }
}
