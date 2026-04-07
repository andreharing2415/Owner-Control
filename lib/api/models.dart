import "dart:convert";
import "dart:typed_data";
import "package:file_picker/file_picker.dart";
import "package:http/http.dart" as http;
import "package:http_parser/http_parser.dart";
import "package:image_picker/image_picker.dart";

import "../services/auth_service.dart";

// ignore: do_not_use_environment
const apiBaseUrl = String.fromEnvironment(
  "API_BASE_URL",
  defaultValue: "https://mestreobra-backend-530484413221.us-central1.run.app",
);

/// Exceção lançada quando o token JWT expira e não pode ser renovado.
class AuthExpiredException implements Exception {
  @override
  String toString() => 'Sessao expirada. Faca login novamente.';
}

class Obra {
  Obra({
    required this.id,
    required this.nome,
    this.localizacao,
    this.orcamento,
    this.dataInicio,
    this.dataFim,
    required this.tipo,
  });

  final String id;
  final String nome;
  final String? localizacao;
  final double? orcamento;
  final String? dataInicio;
  final String? dataFim;
  final String tipo; // "construcao" | "reforma"

  factory Obra.fromJson(Map<String, dynamic> json) {
    return Obra(
      id: json["id"] as String,
      nome: json["nome"] as String,
      localizacao: json["localizacao"] as String?,
      orcamento: (json["orcamento"] as num?)?.toDouble(),
      dataInicio: json["data_inicio"] as String?,
      dataFim: json["data_fim"] as String?,
      tipo: json["tipo"] as String? ?? "construcao",
    );
  }
}

class Etapa {
  Etapa({
    required this.id,
    required this.obraId,
    required this.nome,
    required this.ordem,
    required this.status,
    this.score,
  });

  final String id;
  final String obraId;
  final String nome;
  final int ordem;
  final String status;
  final double? score;

  factory Etapa.fromJson(Map<String, dynamic> json) {
    return Etapa(
      id: json["id"] as String,
      obraId: json["obra_id"] as String,
      nome: json["nome"] as String,
      ordem: json["ordem"] as int,
      status: json["status"] as String,
      score: (json["score"] as num?)?.toDouble(),
    );
  }
}

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
    this.origem = "padrao",
    this.comoVerificar,
    this.explicacaoLeigo,
    this.confianca,
    this.statusVerificacao,
    this.group,
  });

  final String id;
  final String etapaId;
  final String titulo;
  final String? descricao;
  final String status;
  final bool critico;
  final String? observacao;
  final String? normaReferencia;
  final String origem; // "padrao" | "ia"
  final String? comoVerificar;
  final String? explicacaoLeigo;
  final int? confianca;
  final String? statusVerificacao;
  final String? group;

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
      origem: json["origem"] as String? ?? "padrao",
      comoVerificar: json["como_verificar"] as String?,
      explicacaoLeigo: json["explicacao_leigo"] as String?,
      confianca: json["confianca"] as int?,
      statusVerificacao: json["status_verificacao"] as String?,
      group: json["group"] as String?,
    );
  }
}

class Evidencia {
  Evidencia({
    required this.id,
    required this.checklistItemId,
    this.atividadeId,
    required this.arquivoUrl,
    required this.arquivoNome,
    this.latitude,
    this.longitude,
    this.capturadoEm,
    this.mimeType,
    this.tamanhoBytes,
  });

  final String id;
  final String checklistItemId;
  final String? atividadeId;
  final String arquivoUrl;
  final String arquivoNome;
  final double? latitude;
  final double? longitude;
  final String? capturadoEm;
  final String? mimeType;
  final int? tamanhoBytes;

  factory Evidencia.fromJson(Map<String, dynamic> json) {
    return Evidencia(
      id: json["id"] as String,
      checklistItemId: json["checklist_item_id"] as String,
      atividadeId: json["atividade_id"] as String?,
      arquivoUrl: json["arquivo_url"] as String,
      arquivoNome: json["arquivo_nome"] as String,
      latitude: (json["latitude"] as num?)?.toDouble(),
      longitude: (json["longitude"] as num?)?.toDouble(),
      capturadoEm: json["capturado_em"] as String?,
      mimeType: json["mime_type"] as String?,
      tamanhoBytes: json["tamanho_bytes"] as int?,
    );
  }
}

class RdoDiario {
  RdoDiario({
    required this.id,
    required this.obraId,
    required this.dataReferencia,
    required this.clima,
    required this.maoObraTotal,
    required this.atividadesExecutadas,
    this.observacoes,
    required this.fotosUrls,
    required this.publicado,
    this.publicadoEm,
  });

  final String id;
  final String obraId;
  final String dataReferencia;
  final String clima;
  final int maoObraTotal;
  final String atividadesExecutadas;
  final String? observacoes;
  final List<String> fotosUrls;
  final bool publicado;
  final String? publicadoEm;

  factory RdoDiario.fromJson(Map<String, dynamic> json) {
    return RdoDiario(
      id: json["id"] as String,
      obraId: json["obra_id"] as String,
      dataReferencia: json["data_referencia"] as String,
      clima: json["clima"] as String,
      maoObraTotal: (json["mao_obra_total"] as num?)?.toInt() ?? 0,
      atividadesExecutadas: json["atividades_executadas"] as String,
      observacoes: json["observacoes"] as String?,
      fotosUrls: (json["fotos_urls"] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      publicado: json["publicado"] as bool? ?? false,
      publicadoEm: json["publicado_em"] as String?,
    );
  }
}

// ─── Modelos de Normas ────────────────────────────────────────────────────────

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
  final String fonteTipo; // "oficial" | "secundaria"
  final String? versao;
  final String? dataNorma;
  final String? trechoRelevante;
  final String traducaoLeigo;
  final int nivelConfianca; // 0–100
  final String? riscoNivel; // "alto" | "medio" | "baixo" | null
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
          .map((item) => NormaResultado.fromJson(item as Map<String, dynamic>))
          .toList(),
      checklistDinamico: (json["checklist_dinamico"] as List<dynamic>)
          .map((item) => ChecklistDinamicoItem.fromJson(item as Map<String, dynamic>))
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

// ─── Modelos Financeiros ──────────────────────────────────────────────────────

class OrcamentoEtapa {
  OrcamentoEtapa({
    required this.id,
    required this.obraId,
    required this.etapaId,
    required this.valorPrevisto,
  });

  final String id;
  final String obraId;
  final String etapaId;
  final double valorPrevisto;

  factory OrcamentoEtapa.fromJson(Map<String, dynamic> json) {
    return OrcamentoEtapa(
      id: json["id"] as String,
      obraId: json["obra_id"] as String,
      etapaId: json["etapa_id"] as String,
      valorPrevisto: (json["valor_previsto"] as num).toDouble(),
    );
  }
}

class OrcamentoEtapaCreate {
  OrcamentoEtapaCreate({required this.etapaId, required this.valorPrevisto});
  final String etapaId;
  final double valorPrevisto;

  Map<String, dynamic> toJson() => {
        "etapa_id": etapaId,
        "valor_previsto": valorPrevisto,
      };
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
  final String data; // "YYYY-MM-DD"
  final String? categoria;
  final String? comprovanteUrl;

  factory Despesa.fromJson(Map<String, dynamic> json) {
    return Despesa(
      id: json["id"] as String,
      obraId: json["obra_id"] as String,
      etapaId: json["etapa_id"] as String?,
      valor: (json["valor"] as num).toDouble(),
      descricao: json["descricao"] as String,
      data: json["data"] as String,
      categoria: json["categoria"] as String?,
      comprovanteUrl: json["comprovante_url"] as String?,
    );
  }
}

class DespesaCreate {
  DespesaCreate({
    this.etapaId,
    required this.valor,
    required this.descricao,
    required this.data,
    this.categoria,
  });

  final String? etapaId;
  final double valor;
  final String descricao;
  final String data; // "YYYY-MM-DD"
  final String? categoria;

  Map<String, dynamic> toJson() => {
        if (etapaId != null) "etapa_id": etapaId,
        "valor": valor,
        "descricao": descricao,
        "data": data,
        if (categoria != null) "categoria": categoria,
      };
}

class EtapaFinanceiroItem {
  EtapaFinanceiroItem({
    required this.etapaId,
    required this.etapaNome,
    required this.valorPrevisto,
    required this.valorGasto,
    required this.desvioPercentual,
    required this.alerta,
  });

  final String etapaId;
  final String etapaNome;
  final double valorPrevisto;
  final double valorGasto;
  final double desvioPercentual;
  final bool alerta;

  factory EtapaFinanceiroItem.fromJson(Map<String, dynamic> json) {
    return EtapaFinanceiroItem(
      etapaId: json["etapa_id"] as String,
      etapaNome: json["etapa_nome"] as String,
      valorPrevisto: (json["valor_previsto"] as num).toDouble(),
      valorGasto: (json["valor_gasto"] as num).toDouble(),
      desvioPercentual: (json["desvio_percentual"] as num).toDouble(),
      alerta: json["alerta"] as bool? ?? false,
    );
  }
}

class RelatorioFinanceiro {
  RelatorioFinanceiro({
    required this.obraId,
    required this.totalPrevisto,
    required this.totalGasto,
    required this.desvioPercentual,
    required this.alerta,
    required this.threshold,
    required this.porEtapa,
  });

  final String obraId;
  final double totalPrevisto;
  final double totalGasto;
  final double desvioPercentual;
  final bool alerta;
  final double threshold;
  final List<EtapaFinanceiroItem> porEtapa;

  factory RelatorioFinanceiro.fromJson(Map<String, dynamic> json) {
    return RelatorioFinanceiro(
      obraId: json["obra_id"] as String,
      totalPrevisto: (json["total_previsto"] as num).toDouble(),
      totalGasto: (json["total_gasto"] as num).toDouble(),
      desvioPercentual: (json["desvio_percentual"] as num).toDouble(),
      alerta: json["alerta"] as bool? ?? false,
      threshold: (json["threshold"] as num?)?.toDouble() ?? 10.0,
      porEtapa: (json["por_etapa"] as List<dynamic>)
          .map((e) => EtapaFinanceiroItem.fromJson(e as Map<String, dynamic>))
          .toList(),
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
          (json["percentual_desvio_threshold"] as num).toDouble(),
      notificacaoAtiva: json["notificacao_ativa"] as bool? ?? true,
    );
  }
}

// ─── Modelos — Fase 3 — Document AI ──────────────────────────────────────────

class ProjetoDoc {
  ProjetoDoc({
    required this.id,
    required this.obraId,
    required this.arquivoUrl,
    required this.arquivoNome,
    required this.status,
    this.erroDetalhe,
    this.resumoGeral,
    this.avisoLegal,
    required this.createdAt,
  });

  final String id;
  final String obraId;
  final String arquivoUrl;
  final String arquivoNome;
  final String status; // pendente | processando | concluido | erro
  final String? erroDetalhe;
  final String? resumoGeral;
  final String? avisoLegal;
  final String createdAt;

  factory ProjetoDoc.fromJson(Map<String, dynamic> json) {
    return ProjetoDoc(
      id: json["id"] as String,
      obraId: json["obra_id"] as String,
      arquivoUrl: json["arquivo_url"] as String,
      arquivoNome: json["arquivo_nome"] as String,
      status: json["status"] as String? ?? "pendente",
      erroDetalhe: json["erro_detalhe"] as String?,
      resumoGeral: json["resumo_geral"] as String?,
      avisoLegal: json["aviso_legal"] as String?,
      createdAt: json["created_at"] as String,
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
  });

  final String id;
  final String projetoId;
  final String descricao;
  final String severidade; // "alto" | "medio" | "baixo"
  final String? normaReferencia;
  final String traducaoLeigo;
  final bool requerValidacaoProfissional;
  final int confianca; // 0–100

  factory Risco.fromJson(Map<String, dynamic> json) {
    return Risco(
      id: json["id"] as String,
      projetoId: json["projeto_id"] as String,
      descricao: json["descricao"] as String? ?? "",
      severidade: json["severidade"] as String? ?? "baixo",
      normaReferencia: json["norma_referencia"] as String?,
      traducaoLeigo: json["traducao_leigo"] as String? ?? "",
      requerValidacaoProfissional:
          json["requer_validacao_profissional"] as bool? ?? false,
      confianca: (json["confianca"] as num?)?.toInt() ?? 0,
    );
  }
}

class ProjetoAnalise {
  ProjetoAnalise({
    required this.projeto,
    required this.riscos,
  });

  final ProjetoDoc projeto;
  final List<Risco> riscos;

  factory ProjetoAnalise.fromJson(Map<String, dynamic> json) {
    return ProjetoAnalise(
      projeto: ProjetoDoc.fromJson(json["projeto"] as Map<String, dynamic>),
      riscos: (json["riscos"] as List<dynamic>)
          .map((r) => Risco.fromJson(r as Map<String, dynamic>))
          .toList(),
    );
  }
}

// ─── Modelos — Fase 4 — Visual AI ─────────────────────────────────────────────

class AnaliseVisual {
  AnaliseVisual({
    required this.id,
    required this.etapaId,
    required this.imagemUrl,
    required this.imagemNome,
    this.etapaInferida,
    required this.confianca,
    required this.status,
    this.resumoGeral,
    this.avisoLegal,
    required this.createdAt,
  });

  final String id;
  final String etapaId;
  final String imagemUrl;
  final String imagemNome;
  final String? etapaInferida;
  final int confianca; // 0–100
  final String status; // processando | concluida | erro
  final String? resumoGeral;
  final String? avisoLegal;
  final String createdAt;

  factory AnaliseVisual.fromJson(Map<String, dynamic> json) {
    return AnaliseVisual(
      id: json["id"] as String,
      etapaId: json["etapa_id"] as String,
      imagemUrl: json["imagem_url"] as String,
      imagemNome: json["imagem_nome"] as String,
      etapaInferida: json["etapa_inferida"] as String?,
      confianca: (json["confianca"] as num?)?.toInt() ?? 0,
      status: json["status"] as String? ?? "processando",
      resumoGeral: json["resumo_geral"] as String?,
      avisoLegal: json["aviso_legal"] as String?,
      createdAt: json["created_at"] as String,
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
  final String severidade; // "alto" | "medio" | "baixo"
  final String acaoRecomendada;
  final bool requerEvidenciaAdicional;
  final bool requerValidacaoProfissional;
  final int confianca; // 0–100

  factory Achado.fromJson(Map<String, dynamic> json) {
    return Achado(
      id: json["id"] as String,
      analiseId: json["analise_id"] as String,
      descricao: json["descricao"] as String? ?? "",
      severidade: json["severidade"] as String? ?? "baixo",
      acaoRecomendada: json["acao_recomendada"] as String? ?? "",
      requerEvidenciaAdicional:
          json["requer_evidencia_adicional"] as bool? ?? false,
      requerValidacaoProfissional:
          json["requer_validacao_profissional"] as bool? ?? false,
      confianca: (json["confianca"] as num?)?.toInt() ?? 0,
    );
  }
}

class AnaliseVisualComAchados {
  AnaliseVisualComAchados({
    required this.analise,
    required this.achados,
  });

  final AnaliseVisual analise;
  final List<Achado> achados;

  factory AnaliseVisualComAchados.fromJson(Map<String, dynamic> json) {
    return AnaliseVisualComAchados(
      analise: AnaliseVisual.fromJson(json["analise"] as Map<String, dynamic>),
      achados: (json["achados"] as List<dynamic>)
          .map((a) => Achado.fromJson(a as Map<String, dynamic>))
          .toList(),
    );
  }
}

// ─── Fase 5 — Prestadores e Fornecedores ─────────────────────────────────────

class Prestador {
  Prestador({
    required this.id,
    required this.nome,
    required this.categoria,
    required this.subcategoria,
    this.regiao,
    this.telefone,
    this.email,
    this.notaGeral,
    required this.totalAvaliacoes,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String nome;
  final String categoria;
  final String subcategoria;
  final String? regiao;
  final String? telefone;
  final String? email;
  final double? notaGeral;
  final int totalAvaliacoes;
  final String createdAt;
  final String updatedAt;

  factory Prestador.fromJson(Map<String, dynamic> json) {
    return Prestador(
      id: json["id"] as String,
      nome: json["nome"] as String,
      categoria: json["categoria"] as String,
      subcategoria: json["subcategoria"] as String,
      regiao: json["regiao"] as String?,
      telefone: json["telefone"] as String?,
      email: json["email"] as String?,
      notaGeral: (json["nota_geral"] as num?)?.toDouble(),
      totalAvaliacoes: json["total_avaliacoes"] as int? ?? 0,
      createdAt: json["created_at"] as String,
      updatedAt: json["updated_at"] as String,
    );
  }
}

class AvaliacaoPrestador {
  AvaliacaoPrestador({
    required this.id,
    required this.prestadorId,
    this.notaQualidadeServico,
    this.notaCumprimentoPrazos,
    this.notaFidelidadeProjeto,
    this.notaPrazoEntrega,
    this.notaQualidadeMaterial,
    this.comentario,
    required this.createdAt,
  });

  final String id;
  final String prestadorId;
  final int? notaQualidadeServico;
  final int? notaCumprimentoPrazos;
  final int? notaFidelidadeProjeto;
  final int? notaPrazoEntrega;
  final int? notaQualidadeMaterial;
  final String? comentario;
  final String createdAt;

  factory AvaliacaoPrestador.fromJson(Map<String, dynamic> json) {
    return AvaliacaoPrestador(
      id: json["id"] as String,
      prestadorId: json["prestador_id"] as String,
      notaQualidadeServico: json["nota_qualidade_servico"] as int?,
      notaCumprimentoPrazos: json["nota_cumprimento_prazos"] as int?,
      notaFidelidadeProjeto: json["nota_fidelidade_projeto"] as int?,
      notaPrazoEntrega: json["nota_prazo_entrega"] as int?,
      notaQualidadeMaterial: json["nota_qualidade_material"] as int?,
      comentario: json["comentario"] as String?,
      createdAt: json["created_at"] as String,
    );
  }
}

class PrestadorDetalhe {
  PrestadorDetalhe({
    required this.prestador,
    required this.avaliacoes,
    required this.medias,
  });

  final Prestador prestador;
  final List<AvaliacaoPrestador> avaliacoes;
  final Map<String, double> medias;

  factory PrestadorDetalhe.fromJson(Map<String, dynamic> json) {
    return PrestadorDetalhe(
      prestador:
          Prestador.fromJson(json["prestador"] as Map<String, dynamic>),
      avaliacoes: (json["avaliacoes"] as List<dynamic>)
          .map((a) =>
              AvaliacaoPrestador.fromJson(a as Map<String, dynamic>))
          .toList(),
      medias: (json["medias"] as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, (v as num).toDouble())),
    );
  }
}

// ─── Fase 6 — Checklist Inteligente ─────────────────────────────────────────

class CaracteristicaIdentificada {
  CaracteristicaIdentificada({
    required this.id,
    required this.nomeLegivel,
    required this.descricaoNoProjeto,
    required this.confianca,
  });

  final String id;
  final String nomeLegivel;
  final String descricaoNoProjeto;
  final int confianca;

  factory CaracteristicaIdentificada.fromJson(Map<String, dynamic> json) {
    return CaracteristicaIdentificada(
      id: json["id"] as String,
      nomeLegivel: json["nome_legivel"] as String,
      descricaoNoProjeto: json["descricao_no_projeto"] as String,
      confianca: (json["confianca"] as num).toInt(),
    );
  }
}

class ItemChecklistSugerido {
  ItemChecklistSugerido({
    required this.etapaNome,
    required this.titulo,
    required this.descricao,
    this.normaReferencia,
    required this.critico,
    required this.riscoNivel,
    required this.requerValidacaoProfissional,
    required this.confianca,
    required this.comoVerificar,
    required this.caracteristicaOrigem,
  });

  final String etapaNome;
  final String titulo;
  final String descricao;
  final String? normaReferencia;
  final bool critico;
  final String riscoNivel; // "alto" | "medio" | "baixo"
  final bool requerValidacaoProfissional;
  final int confianca;
  final String comoVerificar;
  final String caracteristicaOrigem;

  bool selecionado = true;

  factory ItemChecklistSugerido.fromJson(Map<String, dynamic> json) {
    return ItemChecklistSugerido(
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
      caracteristicaOrigem: json["caracteristica_origem"] as String? ?? "",
    );
  }

  Map<String, dynamic> toApplyJson() => {
        "etapa_nome": etapaNome,
        "titulo": titulo,
        "descricao": descricao,
        "norma_referencia": normaReferencia,
        "critico": critico,
      };
}

class ChecklistInteligenteResponse {
  ChecklistInteligenteResponse({
    required this.logId,
    required this.resumoProjeto,
    this.observacoesGerais,
    required this.caracteristicas,
    required this.itensPorEtapa,
    required this.totalItens,
    required this.avisoLegal,
  });

  final String logId;
  final String resumoProjeto;
  final String? observacoesGerais;
  final List<CaracteristicaIdentificada> caracteristicas;
  final Map<String, List<ItemChecklistSugerido>> itensPorEtapa;
  final int totalItens;
  final String avisoLegal;

  factory ChecklistInteligenteResponse.fromJson(Map<String, dynamic> json) {
    final rawMap = json["itens_por_etapa"] as Map<String, dynamic>;
    final itensPorEtapa = rawMap.map(
      (key, value) => MapEntry(
        key,
        (value as List<dynamic>)
            .map((i) =>
                ItemChecklistSugerido.fromJson(i as Map<String, dynamic>))
            .toList(),
      ),
    );

    return ChecklistInteligenteResponse(
      logId: json["log_id"] as String,
      resumoProjeto: json["resumo_projeto"] as String,
      observacoesGerais: json["observacoes_gerais"] as String?,
      caracteristicas: (json["caracteristicas"] as List<dynamic>)
          .map((c) =>
              CaracteristicaIdentificada.fromJson(c as Map<String, dynamic>))
          .toList(),
      itensPorEtapa: itensPorEtapa,
      totalItens: json["total_itens"] as int,
      avisoLegal: json["aviso_legal"] as String,
    );
  }
}

// ─── Geração Unificada — state machine (AI-06/AI-07) ─────────────────────────

/// Log de geração unificada (cronograma + checklist) com state machine observável.
/// O cliente faz polling via [ApiClient.statusGeracaoUnificada] a cada 2 segundos.
/// Estados: pendente → analisando → gerando → concluido | erro | cancelado
class GeracaoUnificadaLog {
  GeracaoUnificadaLog({
    required this.id,
    required this.obraId,
    required this.status,
    this.etapaAtual,
    required this.totalAtividades,
    required this.atividadesGeradas,
    required this.totalItensChecklist,
    this.erroDetalhe,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String obraId;
  final String status; // "pendente"|"analisando"|"gerando"|"concluido"|"erro"|"cancelado"
  final String? etapaAtual;
  final int totalAtividades;
  final int atividadesGeradas;
  final int totalItensChecklist;
  final String? erroDetalhe;
  final String createdAt;
  final String updatedAt;

  /// Retorna true quando o processamento terminou (sucesso, erro ou cancelamento).
  bool get isTerminal =>
      status == "concluido" || status == "erro" || status == "cancelado";

  factory GeracaoUnificadaLog.fromJson(Map<String, dynamic> json) {
    return GeracaoUnificadaLog(
      id: json["id"] as String,
      obraId: json["obra_id"] as String,
      status: json["status"] as String? ?? "pendente",
      etapaAtual: json["etapa_atual"] as String?,
      totalAtividades: json["total_atividades"] as int? ?? 0,
      atividadesGeradas: json["atividades_geradas"] as int? ?? 0,
      totalItensChecklist: json["total_itens_checklist"] as int? ?? 0,
      erroDetalhe: json["erro_detalhe"] as String?,
      createdAt: json["created_at"] as String? ?? "",
      updatedAt: json["updated_at"] as String? ?? "",
    );
  }
}

// ─── Cronograma ──────────────────────────────────────────────────────────────

class TipoProjetoIdentificado {
  TipoProjetoIdentificado({
    required this.nome,
    required this.confianca,
    this.projetoDocId,
    this.projetoDocNome,
    this.confirmado = true,
  });

  final String nome;
  final int confianca;
  final String? projetoDocId;
  final String? projetoDocNome;
  bool confirmado;

  factory TipoProjetoIdentificado.fromJson(Map<String, dynamic> json) {
    return TipoProjetoIdentificado(
      nome: json["nome"] as String,
      confianca: json["confianca"] as int? ?? 0,
      projetoDocId: json["projeto_doc_id"] as String?,
      projetoDocNome: json["projeto_doc_nome"] as String?,
    );
  }
}

class IdentificarProjetosResponse {
  IdentificarProjetosResponse({
    required this.tipos,
    required this.resumo,
    required this.avisoLegal,
  });

  final List<TipoProjetoIdentificado> tipos;
  final String resumo;
  final String avisoLegal;

  factory IdentificarProjetosResponse.fromJson(Map<String, dynamic> json) {
    return IdentificarProjetosResponse(
      tipos: (json["tipos"] as List<dynamic>)
          .map((e) => TipoProjetoIdentificado.fromJson(e as Map<String, dynamic>))
          .toList(),
      resumo: json["resumo"] as String,
      avisoLegal: json["aviso_legal"] as String,
    );
  }
}

class ServicoNecessario {
  ServicoNecessario({
    required this.id,
    required this.atividadeId,
    required this.descricao,
    required this.categoria,
    this.prestadorId,
  });

  final String id;
  final String atividadeId;
  final String descricao;
  final String categoria;
  final String? prestadorId;

  factory ServicoNecessario.fromJson(Map<String, dynamic> json) {
    return ServicoNecessario(
      id: json["id"] as String,
      atividadeId: json["atividade_id"] as String,
      descricao: json["descricao"] as String,
      categoria: json["categoria"] as String,
      prestadorId: json["prestador_id"] as String?,
    );
  }
}

class AtividadeCronograma {
  AtividadeCronograma({
    required this.id,
    required this.obraId,
    this.parentId,
    required this.nome,
    this.descricao,
    required this.ordem,
    required this.nivel,
    required this.status,
    this.dataInicioPrevista,
    this.dataFimPrevista,
    this.dataInicioReal,
    this.dataFimReal,
    required this.valorPrevisto,
    required this.valorGasto,
    this.tipoProjeto,
    this.subAtividades = const [],
    this.servicos = const [],
  });

  final String id;
  final String obraId;
  final String? parentId;
  final String nome;
  final String? descricao;
  final int ordem;
  final int nivel;
  final String status;
  final String? dataInicioPrevista;
  final String? dataFimPrevista;
  final String? dataInicioReal;
  final String? dataFimReal;
  final double valorPrevisto;
  final double valorGasto;
  final String? tipoProjeto;
  final List<AtividadeCronograma> subAtividades;
  final List<ServicoNecessario> servicos;

  factory AtividadeCronograma.fromJson(Map<String, dynamic> json) {
    return AtividadeCronograma(
      id: json["id"] as String,
      obraId: json["obra_id"] as String,
      parentId: json["parent_id"] as String?,
      nome: json["nome"] as String,
      descricao: json["descricao"] as String?,
      ordem: json["ordem"] as int? ?? 0,
      nivel: json["nivel"] as int? ?? 1,
      status: json["status"] as String? ?? "pendente",
      dataInicioPrevista: json["data_inicio_prevista"] as String?,
      dataFimPrevista: json["data_fim_prevista"] as String?,
      dataInicioReal: json["data_inicio_real"] as String?,
      dataFimReal: json["data_fim_real"] as String?,
      valorPrevisto: (json["valor_previsto"] as num?)?.toDouble() ?? 0,
      valorGasto: (json["valor_gasto"] as num?)?.toDouble() ?? 0,
      tipoProjeto: json["tipo_projeto"] as String?,
      subAtividades: (json["sub_atividades"] as List<dynamic>?)
              ?.map((e) => AtividadeCronograma.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      servicos: (json["servicos"] as List<dynamic>?)
              ?.map((e) => ServicoNecessario.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class CronogramaResponse {
  CronogramaResponse({
    required this.obraId,
    required this.totalPrevisto,
    required this.totalGasto,
    required this.desvioPercentual,
    required this.atividades,
  });

  final String obraId;
  final double totalPrevisto;
  final double totalGasto;
  final double desvioPercentual;
  final List<AtividadeCronograma> atividades;

  factory CronogramaResponse.fromJson(Map<String, dynamic> json) {
    return CronogramaResponse(
      obraId: json["obra_id"] as String,
      totalPrevisto: (json["total_previsto"] as num?)?.toDouble() ?? 0,
      totalGasto: (json["total_gasto"] as num?)?.toDouble() ?? 0,
      desvioPercentual: (json["desvio_percentual"] as num?)?.toDouble() ?? 0,
      atividades: (json["atividades"] as List<dynamic>?)
              ?.map((e) => AtividadeCronograma.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

// ─── Modelos de Subscription ─────────────────────────────────────────────────

class SubscriptionInfo {
  SubscriptionInfo({
    required this.plan,
    required this.planConfig,
    required this.usage,
    required this.obraCount,
    required this.docCount,
    required this.conviteCount,
    this.expiresAt,
    required this.status,
    required this.showAds,
    required this.canWatchRewarded,
  });

  final String plan; // "gratuito" | "essencial" | "completo"
  final Map<String, dynamic> planConfig;
  final Map<String, dynamic> usage;
  final int obraCount;
  final int docCount;
  final int conviteCount;
  final String? expiresAt;
  final String status; // "active" | "expired" | "cancelled"
  final bool showAds;
  final bool canWatchRewarded;

  bool get isGratuito => plan == 'gratuito';
  bool get isEssencial => plan == 'essencial';
  bool get isCompleto => plan == 'completo' || plan == 'dono_da_obra';

  int _configInt(String key) => (planConfig[key] as num?)?.toInt() ?? 0;
  bool _configBool(String key) => planConfig[key] as bool? ?? false;

  int get maxObras => _configInt('max_obras');
  int get maxDocUploads => _configInt('max_doc_uploads');
  bool get canDeleteDoc => _configBool('can_delete_doc');
  bool get canCreateEtapas => _configBool('can_create_etapas');
  bool get canCreateChecklistItems => _configBool('can_create_checklist_items');
  int get maxConvites => _configInt('max_convites');

  factory SubscriptionInfo.fromJson(Map<String, dynamic> json) {
    return SubscriptionInfo(
      plan: json["plan"] as String? ?? "gratuito",
      planConfig: json["plan_config"] as Map<String, dynamic>? ?? {},
      usage: json["usage"] as Map<String, dynamic>? ?? {},
      obraCount: json["obra_count"] as int? ?? 0,
      docCount: json["doc_count"] as int? ?? 0,
      conviteCount: json["convite_count"] as int? ?? 0,
      expiresAt: json["expires_at"] as String?,
      status: json["status"] as String? ?? "active",
      showAds: json["show_ads"] as bool? ?? true,
      canWatchRewarded: json["can_watch_rewarded"] as bool? ?? false,
    );
  }
}

// ─── Modelos de Convites ──────────────────────────────────────────────────────

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
  final String status; // "pendente" | "aceito" | "removido"
  final String? convidadoNome;
  final String createdAt;
  final String? acceptedAt;

  bool get isPendente => status == 'pendente';
  bool get isAceito => status == 'aceito';

  factory ObraConvite.fromJson(Map<String, dynamic> json) {
    return ObraConvite(
      id: json["id"] as String,
      obraId: json["obra_id"] as String,
      email: json["email"] as String,
      papel: json["papel"] as String,
      status: json["status"] as String,
      convidadoNome: json["convidado_nome"] as String?,
      createdAt: json["created_at"] as String,
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

// ─── ApiClient ────────────────────────────────────────────────────────────────

