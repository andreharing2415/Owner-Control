import "dart:convert";
import "dart:io" show File;
import "dart:typed_data";
import "package:file_picker/file_picker.dart";
import "package:http/http.dart" as http;
import "package:http_parser/http_parser.dart";
import "package:image_picker/image_picker.dart";

// 10.0.2.2 é o alias do localhost no emulador Android.
// No web (Chrome) usamos localhost diretamente.
// ignore: do_not_use_environment
const bool _kIsWeb = bool.fromEnvironment('dart.library.html');

const apiBaseUrl = String.fromEnvironment(
  "API_BASE_URL",
  defaultValue: "http://localhost:8000",
);

class Obra {
  Obra({
    required this.id,
    required this.nome,
    this.localizacao,
    this.orcamento,
  });

  final String id;
  final String nome;
  final String? localizacao;
  final double? orcamento;

  factory Obra.fromJson(Map<String, dynamic> json) {
    return Obra(
      id: json["id"] as String,
      nome: json["nome"] as String,
      localizacao: json["localizacao"] as String?,
      orcamento: (json["orcamento"] as num?)?.toDouble(),
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
  });

  final String id;
  final String etapaId;
  final String titulo;
  final String? descricao;
  final String status;
  final bool critico;
  final String? observacao;

  factory ChecklistItem.fromJson(Map<String, dynamic> json) {
    return ChecklistItem(
      id: json["id"] as String,
      etapaId: json["etapa_id"] as String,
      titulo: json["titulo"] as String,
      descricao: json["descricao"] as String?,
      status: json["status"] as String? ?? "pendente",
      critico: json["critico"] as bool? ?? false,
      observacao: json["observacao"] as String?,
    );
  }
}

class Evidencia {
  Evidencia({
    required this.id,
    required this.checklistItemId,
    required this.arquivoUrl,
    required this.arquivoNome,
    this.mimeType,
    this.tamanhoBytes,
  });

  final String id;
  final String checklistItemId;
  final String arquivoUrl;
  final String arquivoNome;
  final String? mimeType;
  final int? tamanhoBytes;

  factory Evidencia.fromJson(Map<String, dynamic> json) {
    return Evidencia(
      id: json["id"] as String,
      checklistItemId: json["checklist_item_id"] as String,
      arquivoUrl: json["arquivo_url"] as String,
      arquivoNome: json["arquivo_nome"] as String,
      mimeType: json["mime_type"] as String?,
      tamanhoBytes: json["tamanho_bytes"] as int?,
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

// ─── ApiClient ────────────────────────────────────────────────────────────────

class ApiClient {
  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Uri _uri(String path) => Uri.parse("$apiBaseUrl$path");

  Future<List<Obra>> listarObras() async {
    final response = await _client.get(_uri("/api/obras"));
    if (response.statusCode != 200) {
      throw Exception("Erro ao listar obras");
    }
    final data = jsonDecode(response.body) as List<dynamic>;
    return data.map((item) => Obra.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<Obra> criarObra({
    required String nome,
    String? localizacao,
    double? orcamento,
  }) async {
    final payload = {
      "nome": nome,
      if (localizacao != null && localizacao.isNotEmpty) "localizacao": localizacao,
      if (orcamento != null) "orcamento": orcamento,
    };
    final response = await _client.post(
      _uri("/api/obras"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(payload),
    );
    if (response.statusCode != 200) {
      throw Exception("Erro ao criar obra");
    }
    return Obra.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<List<Etapa>> listarEtapas(String obraId) async {
    final response = await _client.get(_uri("/api/obras/$obraId"));
    if (response.statusCode != 200) {
      throw Exception("Erro ao buscar obra");
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final etapasJson = data["etapas"] as List<dynamic>;
    return etapasJson.map((item) => Etapa.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<Etapa> atualizarStatusEtapa({
    required String etapaId,
    required String status,
  }) async {
    final response = await _client.patch(
      _uri("/api/etapas/$etapaId/status"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"status": status}),
    );
    if (response.statusCode != 200) {
      throw Exception("Erro ao atualizar status da etapa");
    }
    return Etapa.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<List<ChecklistItem>> listarItens(String etapaId) async {
    final response = await _client.get(_uri("/api/etapas/$etapaId/checklist-items"));
    if (response.statusCode != 200) {
      throw Exception("Erro ao listar checklist");
    }
    final data = jsonDecode(response.body) as List<dynamic>;
    return data.map((item) => ChecklistItem.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<ChecklistItem> criarItem({
    required String etapaId,
    required String titulo,
    String? descricao,
    bool critico = false,
  }) async {
    final payload = {
      "titulo": titulo,
      if (descricao != null && descricao.isNotEmpty) "descricao": descricao,
      "critico": critico,
      "status": "pendente",
    };
    final response = await _client.post(
      _uri("/api/etapas/$etapaId/checklist-items"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(payload),
    );
    if (response.statusCode != 200) {
      throw Exception("Erro ao criar item");
    }
    return ChecklistItem.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<ChecklistItem> atualizarItem({
    required String itemId,
    String? titulo,
    String? descricao,
    String? status,
    bool? critico,
    String? observacao,
  }) async {
    final payload = {
      if (titulo != null) "titulo": titulo,
      if (descricao != null) "descricao": descricao,
      if (status != null) "status": status,
      if (critico != null) "critico": critico,
      if (observacao != null) "observacao": observacao,
    };
    final response = await _client.patch(
      _uri("/api/checklist-items/$itemId"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(payload),
    );
    if (response.statusCode != 200) {
      throw Exception("Erro ao atualizar item");
    }
    return ChecklistItem.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<double> calcularScore(String etapaId) async {
    final response = await _client.get(_uri("/api/etapas/$etapaId/score"));
    if (response.statusCode != 200) {
      throw Exception("Erro ao calcular score");
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return (data["score"] as num?)?.toDouble() ?? 0.0;
  }

  Future<List<Evidencia>> listarEvidencias(String itemId) async {
    final response = await _client.get(_uri("/api/checklist-items/$itemId/evidencias"));
    if (response.statusCode != 200) {
      throw Exception("Erro ao listar evidências");
    }
    final data = jsonDecode(response.body) as List<dynamic>;
    return data.map((item) => Evidencia.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<void> uploadEvidencia({
    required String itemId,
    required PlatformFile file,
  }) async {
    final request = http.MultipartRequest("POST", _uri("/api/checklist-items/$itemId/evidencias"));
    final contentType = _inferContentTypeFromExtension(file.extension);
    final http.MultipartFile multipartFile;
    if (file.readStream != null) {
      multipartFile = http.MultipartFile(
        "file",
        http.ByteStream(file.readStream!),
        file.size,
        filename: file.name,
        contentType: contentType,
      );
    } else if (file.path != null) {
      final f = File(file.path!);
      final length = file.size > 0 ? file.size : await f.length();
      multipartFile = http.MultipartFile(
        "file",
        f.openRead(),
        length,
        filename: file.name,
        contentType: contentType,
      );
    } else if (file.bytes != null) {
      multipartFile = http.MultipartFile.fromBytes(
        "file",
        file.bytes!,
        filename: file.name,
        contentType: contentType,
      );
    } else {
      throw Exception("Plataforma não suporta leitura deste arquivo; tente outra opção.");
    }
    request.files.add(multipartFile);
    final response = await request.send();
    if (response.statusCode != 200) {
      throw Exception("Erro ao enviar evidencia");
    }
  }

  Future<void> uploadEvidenciaImagem({
    required String itemId,
    required XFile image,
  }) async {
    final bytes = await image.readAsBytes();
    final request = http.MultipartRequest("POST", _uri("/api/checklist-items/$itemId/evidencias"));
    final ext = image.path.split(".").last.toLowerCase();
    final multipartFile = http.MultipartFile.fromBytes(
      "file",
      bytes,
      filename: image.name,
      contentType: _inferContentTypeFromExtension(ext),
    );
    request.files.add(multipartFile);
    final response = await request.send();
    if (response.statusCode != 200) {
      throw Exception("Erro ao enviar imagem");
    }
  }

  Future<Uint8List> exportarPdf(String obraId) async {
    final response = await _client.get(_uri("/api/obras/$obraId/export-pdf"));
    if (response.statusCode != 200) {
      throw Exception("Erro ao exportar PDF");
    }
    return response.bodyBytes;
  }

  MediaType? _inferContentTypeFromExtension(String? ext) {
    if (ext == null) return null;
    switch (ext.toLowerCase()) {
      case "jpg":
      case "jpeg":
        return MediaType("image", "jpeg");
      case "png":
        return MediaType("image", "png");
      case "pdf":
        return MediaType("application", "pdf");
      default:
        return null;
    }
  }

  // ─── Fase 2 — Normas ────────────────────────────────────────────────────────

  Future<NormaBuscarResponse> buscarNormas({
    required String etapaNome,
    String? disciplina,
    String? localizacao,
    String? obraTipo,
  }) async {
    final payload = {
      "etapa_nome": etapaNome,
      if (disciplina != null) "disciplina": disciplina,
      if (localizacao != null) "localizacao": localizacao,
      if (obraTipo != null) "obra_tipo": obraTipo,
    };
    final response = await _client.post(
      _uri("/api/normas/buscar"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(payload),
    );
    if (response.statusCode != 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      throw Exception(body["detail"] ?? "Erro na pesquisa de normas");
    }
    return NormaBuscarResponse.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<List<NormaLogResumido>> listarHistoricoNormas() async {
    final response = await _client.get(_uri("/api/normas/historico"));
    if (response.statusCode != 200) {
      throw Exception("Erro ao carregar histórico");
    }
    final data = jsonDecode(response.body) as List<dynamic>;
    return data.map((item) => NormaLogResumido.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<List<EtapaNormaInfo>> listarEtapasNormas() async {
    final response = await _client.get(_uri("/api/normas/etapas"));
    if (response.statusCode != 200) {
      throw Exception("Erro ao carregar etapas");
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final etapas = data["etapas"] as List<dynamic>;
    return etapas.map((item) => EtapaNormaInfo.fromJson(item as Map<String, dynamic>)).toList();
  }
}
