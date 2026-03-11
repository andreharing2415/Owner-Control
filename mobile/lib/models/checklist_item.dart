import 'dart:convert';

class ChecklistItem {
  ChecklistItem({
    required this.id,
    required this.etapaId,
    required this.titulo,
    this.descricao,
    required this.status,
    required this.critico,
    this.observacao,
    this.normaReferencia,
    this.grupo = 'Geral',
    this.ordem = 0,
    this.criadoEm,
    this.origem = 'padrao',
    this.projetoDocId,
    this.projetoDocNome,
    this.comoVerificar,
    this.medidasMinimas,
    this.explicacaoLeigo,
    // 3 Camadas
    this.severidade,
    this.traducaoLeigo,
    this.dadoProjeto,
    this.verificacoes,
    this.perguntaEngenheiro,
    this.documentosAExigir,
    this.registroProprietario,
    this.resultadoCruzamento,
    this.statusVerificacao = 'pendente',
    this.confianca,
    this.requerValidacaoProfissional = false,
  });

  final String id;
  final String etapaId;
  final String titulo;
  final String? descricao;
  final String status;
  final bool critico;
  final String? observacao;
  final String? normaReferencia;
  final String grupo;
  final int ordem;
  final DateTime? criadoEm;
  final String origem;
  final String? projetoDocId;
  final String? projetoDocNome;
  final String? comoVerificar;
  final String? medidasMinimas;
  final String? explicacaoLeigo;
  // 3 Camadas
  final String? severidade;
  final String? traducaoLeigo;
  final Map<String, dynamic>? dadoProjeto;
  final List<Map<String, dynamic>>? verificacoes;
  final Map<String, dynamic>? perguntaEngenheiro;
  final List<String>? documentosAExigir;
  final Map<String, dynamic>? registroProprietario;
  final Map<String, dynamic>? resultadoCruzamento;
  final String statusVerificacao;
  final int? confianca;
  final bool requerValidacaoProfissional;

  bool get isEnriquecido => dadoProjeto != null || verificacoes != null;

  factory ChecklistItem.fromJson(Map<String, dynamic> json) {
    return ChecklistItem(
      id: json["id"] as String,
      etapaId: json["etapa_id"] as String,
      titulo: json["titulo"] as String,
      descricao: json["descricao"] as String?,
      status: json["status"] as String? ?? "pendente",
      critico: json["critico"] as bool? ?? false,
      observacao: json["observacao"] as String?,
      normaReferencia: json["norma_referencia"] as String?,
      grupo: json["grupo"] as String? ?? "Geral",
      ordem: json["ordem"] as int? ?? 0,
      criadoEm: json["created_at"] != null
          ? DateTime.tryParse(json["created_at"] as String)
          : null,
      origem: json["origem"] as String? ?? "padrao",
      projetoDocId: json["projeto_doc_id"] as String?,
      projetoDocNome: json["projeto_doc_nome"] as String?,
      comoVerificar: json["como_verificar"] as String?,
      medidasMinimas: json["medidas_minimas"] as String?,
      explicacaoLeigo: json["explicacao_leigo"] as String?,
      // 3 Camadas
      severidade: json["severidade"] as String?,
      traducaoLeigo: json["traducao_leigo"] as String?,
      dadoProjeto: _parseJsonObj(json["dado_projeto"]),
      verificacoes: _parseJsonList(json["verificacoes"]),
      perguntaEngenheiro: _parseJsonObj(json["pergunta_engenheiro"]),
      documentosAExigir: _parseStringList(json["documentos_a_exigir"]),
      registroProprietario: _parseJsonObj(json["registro_proprietario"]),
      resultadoCruzamento: _parseJsonObj(json["resultado_cruzamento"]),
      statusVerificacao: json["status_verificacao"] as String? ?? "pendente",
      confianca: json["confianca"] as int?,
      requerValidacaoProfissional:
          json["requer_validacao_profissional"] as bool? ?? false,
    );
  }

  static Map<String, dynamic>? _parseJsonObj(dynamic val) {
    if (val == null) return null;
    if (val is Map) return Map<String, dynamic>.from(val);
    if (val is String) {
      try {
        final decoded = jsonDecode(val);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }
    return null;
  }

  static List<Map<String, dynamic>>? _parseJsonList(dynamic val) {
    if (val == null) return null;
    if (val is List) {
      return val
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
    }
    if (val is String) {
      try {
        final decoded = jsonDecode(val);
        if (decoded is List) {
          return decoded
              .whereType<Map>()
              .map((m) => Map<String, dynamic>.from(m))
              .toList();
        }
      } catch (_) {}
    }
    return null;
  }

  static List<String>? _parseStringList(dynamic val) {
    if (val == null) return null;
    if (val is List) return val.map((e) => e.toString()).toList();
    if (val is String) {
      try {
        final decoded = jsonDecode(val);
        if (decoded is List) return decoded.map((e) => e.toString()).toList();
      } catch (_) {}
    }
    return null;
  }
}
