class AnaliseVisual {
  AnaliseVisual({
    required this.id,
    required this.etapaId,
    required this.imagemUrl,
    this.etapaInferida,
    required this.confianca,
    required this.status,
    this.resumoGeral,
    this.avisoLegal,
    this.achados,
  });

  final String id;
  final String etapaId;
  final String imagemUrl;
  final String? etapaInferida;
  final int confianca;
  final String status;
  final String? resumoGeral;
  final String? avisoLegal;
  final List<Achado>? achados;

  factory AnaliseVisual.fromJson(Map<String, dynamic> json) {
    return AnaliseVisual(
      id: json["id"]?.toString() ?? "",
      etapaId: json["etapa_id"]?.toString() ?? "",
      imagemUrl: json["imagem_url"]?.toString() ?? "",
      etapaInferida: json["etapa_inferida"]?.toString(),
      confianca: (json["confianca"] as num?)?.toInt() ?? 0,
      status: json["status"]?.toString() ?? "concluida",
      resumoGeral: json["resumo_geral"]?.toString(),
      avisoLegal: json["aviso_legal"]?.toString(),
      achados: json["achados"] != null
          ? (json["achados"] as List<dynamic>)
              .map((e) => Achado.fromJson(e as Map<String, dynamic>))
              .toList()
          : null,
    );
  }
}

class Achado {
  Achado({
    required this.id,
    required this.analiseId,
    required this.descricao,
    required this.severidade,
    required this.acaoRecomendada,
    required this.requerEvidenciaAdicional,
    required this.requerValidacaoProfissional,
    required this.confianca,
  });

  final String id;
  final String analiseId;
  final String descricao;
  final String severidade;
  final String acaoRecomendada;
  final bool requerEvidenciaAdicional;
  final bool requerValidacaoProfissional;
  final int confianca;

  factory Achado.fromJson(Map<String, dynamic> json) {
    return Achado(
      id: json["id"]?.toString() ?? "",
      analiseId: json["analise_id"]?.toString() ?? "",
      descricao: json["descricao"]?.toString() ?? "",
      severidade: json["severidade"]?.toString() ?? "baixo",
      acaoRecomendada: json["acao_recomendada"]?.toString() ?? "",
      requerEvidenciaAdicional:
          json["requer_evidencia_adicional"] as bool? ?? false,
      requerValidacaoProfissional:
          json["requer_validacao_profissional"] as bool? ?? false,
      confianca: (json["confianca"] as num?)?.toInt() ?? 0,
    );
  }
}
