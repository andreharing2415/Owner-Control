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
      id: json["id"] as String,
      etapaId: json["etapa_id"] as String,
      imagemUrl: json["imagem_url"] as String,
      etapaInferida: json["etapa_inferida"] as String?,
      confianca: (json["confianca"] as num?)?.toInt() ?? 0,
      status: json["status"] as String,
      resumoGeral: json["resumo_geral"] as String?,
      avisoLegal: json["aviso_legal"] as String?,
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
      id: json["id"] as String,
      analiseId: json["analise_id"] as String,
      descricao: json["descricao"] as String,
      severidade: json["severidade"] as String,
      acaoRecomendada: json["acao_recomendada"] as String,
      requerEvidenciaAdicional:
          json["requer_evidencia_adicional"] as bool? ?? false,
      requerValidacaoProfissional:
          json["requer_validacao_profissional"] as bool? ?? false,
      confianca: (json["confianca"] as num?)?.toInt() ?? 0,
    );
  }
}
