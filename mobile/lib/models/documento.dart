import "dart:convert";

class ProjetoDoc {
  ProjetoDoc({
    required this.id,
    required this.obraId,
    required this.arquivoUrl,
    required this.arquivoNome,
    required this.status,
    this.resumoGeral,
    this.avisoLegal,
  });

  final String id;
  final String obraId;
  final String arquivoUrl;
  final String arquivoNome;
  final String status;
  final String? resumoGeral;
  final String? avisoLegal;

  factory ProjetoDoc.fromJson(Map<String, dynamic> json) {
    return ProjetoDoc(
      id: json["id"] as String,
      obraId: json["obra_id"] as String,
      arquivoUrl: json["arquivo_url"] as String,
      arquivoNome: json["arquivo_nome"] as String,
      status: json["status"] as String,
      resumoGeral: json["resumo_geral"] as String?,
      avisoLegal: json["aviso_legal"] as String?,
    );
  }
}

class Risco {
  Risco({
    required this.id,
    required this.projetoId,
    required this.descricao,
    required this.severidade,
    this.normaReferencia,
    required this.traducaoLeigo,
    required this.requerValidacaoProfissional,
    required this.confianca,
    this.normaUrl,
    this.acaoProprietario,
    this.perguntasParaProfissional,
    this.documentosAExigir,
  });

  final String id;
  final String projetoId;
  final String descricao;
  final String severidade;
  final String? normaReferencia;
  final String traducaoLeigo;
  final bool requerValidacaoProfissional;
  final int confianca;
  final String? normaUrl;
  final String? acaoProprietario;
  final List<Map<String, String>>? perguntasParaProfissional;
  final List<String>? documentosAExigir;

  factory Risco.fromJson(Map<String, dynamic> json) {
    List<Map<String, String>>? parsePerguntas(dynamic raw) {
      if (raw == null) return null;
      if (raw is String) {
        try {
          final parsed = jsonDecode(raw);
          if (parsed is List) {
            return parsed
                .map((e) => Map<String, String>.from(e as Map))
                .toList();
          }
        } catch (_) {}
        return null;
      }
      if (raw is List) {
        return raw.map((e) => Map<String, String>.from(e as Map)).toList();
      }
      return null;
    }

    List<String>? parseDocs(dynamic raw) {
      if (raw == null) return null;
      if (raw is String) {
        try {
          final parsed = jsonDecode(raw);
          if (parsed is List) {
            return parsed.map((e) => e.toString()).toList();
          }
        } catch (_) {}
        return null;
      }
      if (raw is List) {
        return raw.map((e) => e.toString()).toList();
      }
      return null;
    }

    return Risco(
      id: json["id"] as String,
      projetoId: json["projeto_id"] as String,
      descricao: json["descricao"] as String,
      severidade: json["severidade"] as String,
      normaReferencia: json["norma_referencia"] as String?,
      traducaoLeigo: json["traducao_leigo"] as String,
      requerValidacaoProfissional:
          json["requer_validacao_profissional"] as bool? ?? false,
      confianca: (json["confianca"] as num?)?.toInt() ?? 0,
      normaUrl: json["norma_url"] as String?,
      acaoProprietario: json["acao_proprietario"] as String?,
      perguntasParaProfissional:
          parsePerguntas(json["perguntas_para_profissional"]),
      documentosAExigir: parseDocs(json["documentos_a_exigir"]),
    );
  }
}

class AnaliseDocumento {
  AnaliseDocumento({
    required this.projeto,
    required this.riscos,
  });

  final ProjetoDoc projeto;
  final List<Risco> riscos;

  factory AnaliseDocumento.fromJson(Map<String, dynamic> json) {
    return AnaliseDocumento(
      projeto: ProjetoDoc.fromJson(json["projeto"] as Map<String, dynamic>),
      riscos: (json["riscos"] as List<dynamic>)
          .map((e) => Risco.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
