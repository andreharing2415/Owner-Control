class OrcamentoEtapa {
  OrcamentoEtapa({
    required this.id,
    required this.obraId,
    required this.etapaId,
    required this.valorPrevisto,
    this.valorRealizado,
    this.etapaNome,
  });

  final String id;
  final String obraId;
  final String etapaId;
  final double valorPrevisto;
  final double? valorRealizado;
  final String? etapaNome;

  factory OrcamentoEtapa.fromJson(Map<String, dynamic> json) {
    return OrcamentoEtapa(
      id: json["id"] as String,
      obraId: json["obra_id"] as String,
      etapaId: json["etapa_id"] as String,
      valorPrevisto: (json["valor_previsto"] as num?)?.toDouble() ?? 0.0,
      valorRealizado: (json["valor_realizado"] as num?)?.toDouble(),
      etapaNome: json["etapa_nome"] as String?,
    );
  }
}

class Despesa {
  Despesa({
    required this.id,
    required this.obraId,
    this.etapaId,
    required this.valor,
    required this.descricao,
    required this.data,
    this.categoria,
    this.comprovanteUrl,
  });

  final String id;
  final String obraId;
  final String? etapaId;
  final double valor;
  final String descricao;
  final String data;
  final String? categoria;
  final String? comprovanteUrl;

  factory Despesa.fromJson(Map<String, dynamic> json) {
    return Despesa(
      id: json["id"] as String,
      obraId: json["obra_id"] as String,
      etapaId: json["etapa_id"] as String?,
      valor: (json["valor"] as num?)?.toDouble() ?? 0.0,
      descricao: json["descricao"] as String,
      data: json["data"] as String,
      categoria: json["categoria"] as String?,
      comprovanteUrl: json["comprovante_url"] as String?,
    );
  }
}

class AlertaConfig {
  AlertaConfig({
    required this.id,
    required this.obraId,
    required this.percentualDesvioThreshold,
    required this.notificacaoAtiva,
  });

  final String id;
  final String obraId;
  final double percentualDesvioThreshold;
  final bool notificacaoAtiva;

  factory AlertaConfig.fromJson(Map<String, dynamic> json) {
    return AlertaConfig(
      id: json["id"] as String,
      obraId: json["obra_id"] as String,
      percentualDesvioThreshold:
          (json["percentual_desvio_threshold"] as num?)?.toDouble() ?? 10.0,
      notificacaoAtiva: json["notificacao_ativa"] as bool,
    );
  }
}

class RelatorioFinanceiro {
  RelatorioFinanceiro({
    required this.totalPrevisto,
    required this.totalRealizado,
    required this.desvioPercentual,
    this.curvaS = const [],
    required this.porEtapa,
  });

  final double totalPrevisto;
  final double totalRealizado;
  final double desvioPercentual;
  final List<CurvaSPonto> curvaS;
  final List<EtapaFinanceiro> porEtapa;

  factory RelatorioFinanceiro.fromJson(Map<String, dynamic> json) {
    return RelatorioFinanceiro(
      totalPrevisto: (json["total_previsto"] as num?)?.toDouble() ?? 0.0,
      totalRealizado: (json["total_gasto"] as num?)?.toDouble() ?? 0.0,
      desvioPercentual: (json["desvio_percentual"] as num?)?.toDouble() ?? 0.0,
      curvaS: (json["curva_s"] as List<dynamic>?)
              ?.map((e) => CurvaSPonto.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      porEtapa: (json["por_etapa"] as List<dynamic>?)
              ?.map((e) => EtapaFinanceiro.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class CurvaSPonto {
  CurvaSPonto({
    required this.data,
    required this.previsto,
    required this.realizado,
  });

  final String data;
  final double previsto;
  final double realizado;

  factory CurvaSPonto.fromJson(Map<String, dynamic> json) {
    return CurvaSPonto(
      data: json["data"] as String,
      previsto: (json["previsto"] as num?)?.toDouble() ?? 0.0,
      realizado: (json["realizado"] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class EtapaFinanceiro {
  EtapaFinanceiro({
    required this.etapaId,
    required this.etapaNome,
    required this.previsto,
    required this.realizado,
    required this.desvioPercentual,
  });

  final String etapaId;
  final String etapaNome;
  final double previsto;
  final double realizado;
  final double desvioPercentual;

  factory EtapaFinanceiro.fromJson(Map<String, dynamic> json) {
    return EtapaFinanceiro(
      etapaId: json["etapa_id"] as String,
      etapaNome: json["etapa_nome"] as String,
      previsto: (json["valor_previsto"] as num?)?.toDouble() ?? 0.0,
      realizado: (json["valor_gasto"] as num?)?.toDouble() ?? 0.0,
      desvioPercentual: (json["desvio_percentual"] as num?)?.toDouble() ?? 0.0,
    );
  }
}
