import "dart:convert";
import "dart:typed_data";
import "package:file_picker/file_picker.dart";
import "package:http/http.dart" as http;
import "package:http_parser/http_parser.dart";
import "package:image_picker/image_picker.dart";

import "../models/subscription_purchase.dart";
import "../services/auth_service.dart";
import "models.dart";

class ApiClient {
  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// Timeout padrão para requisições normais (SEC-10).
  static const _defaultTimeout = Duration(seconds: 30);
  /// Timeout estendido para operações longas (análise IA, upload).
  static const _longTimeout = Duration(minutes: 5);

  /// PERF-07v2: Deduplicação de requests GET em andamento.
  /// Se um GET idêntico já está em voo, reutiliza o Future.
  static final Map<String, Future<http.Response>> _inflightGets = {};

  Uri _uri(String path) => Uri.parse("$apiBaseUrl$path");

  /// Headers padrão — inclui Bearer token automaticamente se disponível.
  Map<String, String> _headers({bool json = true}) {
    final h = <String, String>{};
    if (json) h['Content-Type'] = 'application/json';
    final token = AuthService.instance.accessToken;
    if (token != null) h['Authorization'] = 'Bearer $token';
    return h;
  }

  /// Executa [request] e, se receber 401, tenta refresh e repete uma vez.
  /// Se o refresh falhar, lança [AuthExpiredException].
  Future<http.Response> _withAuth(
    Future<http.Response> Function() request, {
    Duration timeout = _defaultTimeout,
  }) async {
    final response = await request().timeout(timeout);
    if (response.statusCode != 401) return response;

    // Tenta renovar o token
    final refreshed = await AuthService.instance.refreshAccessToken();
    if (!refreshed) throw AuthExpiredException();

    // Repete a request com o novo token
    return request().timeout(timeout);
  }

  /// PERF-07v2: GET com deduplicação — reutiliza Future se request idêntico em voo.
  Future<http.Response> _deduplicatedGet(
    String path, {
    Duration timeout = _defaultTimeout,
  }) {
    if (_inflightGets.containsKey(path)) {
      return _inflightGets[path]!;
    }
    final future = _withAuth(
      () => _client.get(_uri(path), headers: _headers(json: false)),
      timeout: timeout,
    ).whenComplete(() => _inflightGets.remove(path));
    _inflightGets[path] = future;
    return future;
  }

  /// Versão auth-aware para multipart requests.
  Future<http.StreamedResponse> _withAuthMultipart(
    Future<http.StreamedResponse> Function() request,
  ) async {
    final response = await request();
    if (response.statusCode != 401) return response;

    final refreshed = await AuthService.instance.refreshAccessToken();
    if (!refreshed) throw AuthExpiredException();

    return request();
  }

  // ─── Auth ─────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final response = await _client.post(
      _uri("/api/auth/login"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"email": email, "password": password}),
    );
    if (response.statusCode != 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      throw Exception(body["detail"] ?? "Erro ao fazer login");
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> loginWithGoogle({
    required String idToken,
  }) async {
    final response = await _client.post(
      _uri("/api/auth/google"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"id_token": idToken}),
    );
    if (response.statusCode != 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      throw Exception(body["detail"] ?? "Erro ao fazer login com Google");
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateProfile({
    String? nome,
    String? telefone,
  }) async {
    final payload = <String, dynamic>{
      "nome": ?nome,
      "telefone": ?telefone,
    };
    final response = await _withAuth(() => _client.patch(
      _uri("/api/auth/me"),
      headers: _headers(),
      body: jsonEncode(payload),
    ));
    if (response.statusCode != 200) {
      throw Exception("Erro ao atualizar perfil");
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> register({
    required String nome,
    required String email,
    required String telefone,
    required String password,
  }) async {
    final response = await _client.post(
      _uri("/api/auth/register"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "nome": nome,
        "email": email,
        "telefone": telefone,
        "password": password,
      }),
    );
    if (response.statusCode == 409) {
      throw Exception("Este email ja esta cadastrado");
    }
    if (response.statusCode != 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      throw Exception(body["detail"] ?? "Erro ao criar conta");
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  // ─── Obras ────────────────────────────────────────────────────────────────

  Future<List<Obra>> listarObras() async {
    final response = await _deduplicatedGet("/api/obras");
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
    String? dataInicio,
    String? dataFim,
    String tipo = "construcao",
  }) async {
    final payload = <String, dynamic>{
      "nome": nome,
      if (localizacao != null && localizacao.isNotEmpty) "localizacao": localizacao,
      "orcamento": ?orcamento,
      "data_inicio": ?dataInicio,
      "data_fim": ?dataFim,
      "tipo": tipo,
    };
    final response = await _withAuth(() => _client.post(
      _uri("/api/obras"),
      headers: _headers(),
      body: jsonEncode(payload),
    ));
    if (response.statusCode != 200) {
      throw Exception("Erro ao criar obra");
    }
    return Obra.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  /// Remove uma obra e todos os dados associados.
  Future<void> deletarObra(String obraId) async {
    final response = await _withAuth(() => _client.delete(
      _uri("/api/obras/$obraId"),
      headers: _headers(json: false),
    ));
    if (response.statusCode != 200) {
      try {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        throw Exception(body["detail"] ?? "Erro ao remover obra");
      } on FormatException {
        throw Exception("Erro ao remover obra (status ${response.statusCode})");
      }
    }
  }

  Future<void> registrarDeviceToken({
    required String obraId,
    required String token,
    required String platform,
  }) async {
    final response = await _withAuth(() => _client.post(
      _uri("/api/obras/$obraId/device-tokens"),
      headers: _headers(),
      body: jsonEncode({"token": token, "platform": platform}),
    ));
    if (response.statusCode != 200) {
      throw Exception("Erro ao registrar device token");
    }
  }

  Future<void> removerDeviceToken({
    required String obraId,
    required String token,
  }) async {
    final response = await _withAuth(() => _client.delete(
      _uri("/api/obras/$obraId/device-tokens/$token"),
      headers: _headers(json: false),
    ));
    if (response.statusCode != 204) {
      throw Exception("Erro ao remover device token");
    }
  }

  Future<List<Etapa>> listarEtapas(String obraId) async {
    final response = await _deduplicatedGet("/api/obras/$obraId");
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
    final response = await _withAuth(() => _client.patch(
      _uri("/api/etapas/$etapaId/status"),
      headers: _headers(),
      body: jsonEncode({"status": status}),
    ));
    if (response.statusCode != 200) {
      throw Exception("Erro ao atualizar status da etapa");
    }
    return Etapa.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<List<ChecklistItem>> listarItens(String etapaId) async {
    final response = await _withAuth(() => _client.get(_uri("/api/etapas/$etapaId/checklist-items"), headers: _headers(json: false)));
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
    final response = await _withAuth(() => _client.post(
      _uri("/api/etapas/$etapaId/checklist-items"),
      headers: _headers(),
      body: jsonEncode(payload),
    ));
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
    final payload = <String, dynamic>{
      "titulo": ?titulo,
      "descricao": ?descricao,
      "status": ?status,
      "critico": ?critico,
      "observacao": ?observacao,
    };
    final response = await _withAuth(() => _client.patch(
      _uri("/api/checklist-items/$itemId"),
      headers: _headers(),
      body: jsonEncode(payload),
    ));
    if (response.statusCode != 200) {
      throw Exception("Erro ao atualizar item");
    }
    return ChecklistItem.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<double> calcularScore(String etapaId) async {
    final response = await _withAuth(() => _client.get(_uri("/api/etapas/$etapaId/score"), headers: _headers(json: false)));
    if (response.statusCode != 200) {
      throw Exception("Erro ao calcular score");
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return (data["score"] as num?)?.toDouble() ?? 0.0;
  }

  Future<List<Evidencia>> listarEvidencias(String itemId) async {
    final response = await _withAuth(() => _client.get(_uri("/api/checklist-items/$itemId/evidencias"), headers: _headers(json: false)));
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
    final response = await _withAuthMultipart(() {
      final request = http.MultipartRequest("POST", _uri("/api/checklist-items/$itemId/evidencias"));
      request.headers.addAll(_headers(json: false));
      request.files.add(_buildMultipartFile(file, _inferContentTypeFromExtension(file.extension)));
      return request.send();
    });
    if (response.statusCode != 200) {
      throw Exception("Erro ao enviar evidencia");
    }
  }

  Future<void> uploadEvidenciaImagem({
    required String itemId,
    required XFile image,
  }) async {
    return uploadEvidenciaImagemComMeta(itemId: itemId, image: image);
  }

  Future<void> uploadEvidenciaImagemComMeta({
    required String itemId,
    required XFile image,
    String? atividadeId,
    double? latitude,
    double? longitude,
    DateTime? capturadoEm,
  }) async {
    final bytes = await image.readAsBytes();
    final ext = image.path.split(".").last.toLowerCase();
    final response = await _withAuthMultipart(() {
      final request = http.MultipartRequest("POST", _uri("/api/checklist-items/$itemId/evidencias"));
      request.headers.addAll(_headers(json: false));
      if (atividadeId != null) {
        request.fields["atividade_id"] = atividadeId;
      }
      if (latitude != null) {
        request.fields["latitude"] = latitude.toString();
      }
      if (longitude != null) {
        request.fields["longitude"] = longitude.toString();
      }
      if (capturadoEm != null) {
        request.fields["capturado_em"] = capturadoEm.toUtc().toIso8601String();
      }
      request.files.add(http.MultipartFile.fromBytes(
        "file",
        bytes,
        filename: image.name,
        contentType: _inferContentTypeFromExtension(ext),
      ));
      return request.send();
    });
    if (response.statusCode != 200) {
      throw Exception("Erro ao enviar imagem");
    }
  }

  Future<Uint8List> exportarPdf(String obraId) async {
    final response = await _withAuth(() => _client.get(_uri("/api/obras/$obraId/export-pdf"), headers: _headers(json: false)));
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

  /// Builds a MultipartFile from a PlatformFile, using bytes (web) or readStream (mobile/desktop).
  http.MultipartFile _buildMultipartFile(PlatformFile file, MediaType? contentType) {
    if (file.bytes != null) {
      return http.MultipartFile.fromBytes(
        "file",
        file.bytes!,
        filename: file.name,
        contentType: contentType,
      );
    }
    return http.MultipartFile(
      "file",
      http.ByteStream(file.readStream!),
      file.size,
      filename: file.name,
      contentType: contentType,
    );
  }

  // ─── Fase 2 — Normas ────────────────────────────────────────────────────────

  Future<NormaBuscarResponse> buscarNormas({
    required String etapaNome,
    String? disciplina,
    String? localizacao,
    String? obraTipo,
  }) async {
    final payload = <String, dynamic>{
      "etapa_nome": etapaNome,
      "disciplina": ?disciplina,
      "localizacao": ?localizacao,
      "obra_tipo": ?obraTipo,
    };
    final response = await _withAuth(() => _client.post(
      _uri("/api/normas/buscar"),
      headers: _headers(),
      body: jsonEncode(payload),
    ));
    if (response.statusCode != 200) {
      try {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        throw Exception(body["detail"] ?? "Erro na pesquisa de normas");
      } on FormatException {
        throw Exception("Erro na pesquisa de normas (status ${response.statusCode})");
      }
    }
    return NormaBuscarResponse.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<List<NormaLogResumido>> listarHistoricoNormas() async {
    final response = await _withAuth(() => _client.get(_uri("/api/normas/historico"), headers: _headers(json: false)));
    if (response.statusCode != 200) {
      throw Exception("Erro ao carregar histórico");
    }
    final data = jsonDecode(response.body) as List<dynamic>;
    return data.map((item) => NormaLogResumido.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<List<EtapaNormaInfo>> listarEtapasNormas() async {
    final response = await _withAuth(() => _client.get(_uri("/api/normas/etapas"), headers: _headers(json: false)));
    if (response.statusCode != 200) {
      throw Exception("Erro ao carregar etapas");
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final etapas = data["etapas"] as List<dynamic>;
    return etapas.map((item) => EtapaNormaInfo.fromJson(item as Map<String, dynamic>)).toList();
  }

  // ─── Fase 2 — Governança Financeira ────────────────────────────────────────

  Future<List<OrcamentoEtapa>> registrarOrcamento({
    required String obraId,
    required List<OrcamentoEtapaCreate> itens,
  }) async {
    final payload = itens.map((i) => i.toJson()).toList();
    final response = await _withAuth(() => _client.post(
      _uri("/api/obras/$obraId/orcamento"),
      headers: _headers(),
      body: jsonEncode(payload),
    ));
    if (response.statusCode != 200) {
      throw Exception("Erro ao registrar orçamento");
    }
    final data = jsonDecode(response.body) as List<dynamic>;
    return data.map((item) => OrcamentoEtapa.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<List<OrcamentoEtapa>> consultarOrcamento(String obraId) async {
    final response = await _withAuth(() => _client.get(_uri("/api/obras/$obraId/orcamento"), headers: _headers(json: false)));
    if (response.statusCode != 200) {
      throw Exception("Erro ao consultar orçamento");
    }
    final data = jsonDecode(response.body) as List<dynamic>;
    return data.map((item) => OrcamentoEtapa.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<Despesa> lancarDespesa({
    required String obraId,
    required DespesaCreate despesa,
  }) async {
    final response = await _withAuth(() => _client.post(
      _uri("/api/obras/$obraId/despesas"),
      headers: _headers(),
      body: jsonEncode(despesa.toJson()),
    ));
    if (response.statusCode != 200) {
      throw Exception("Erro ao lançar despesa");
    }
    return Despesa.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<List<Despesa>> listarDespesas(String obraId) async {
    final response = await _withAuth(() => _client.get(_uri("/api/obras/$obraId/despesas"), headers: _headers(json: false)));
    if (response.statusCode != 200) {
      throw Exception("Erro ao listar despesas");
    }
    final data = jsonDecode(response.body) as List<dynamic>;
    return data.map((item) => Despesa.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<RelatorioFinanceiro> relatorioFinanceiro(String obraId) async {
    final response = await _deduplicatedGet("/api/obras/$obraId/relatorio-financeiro");
    if (response.statusCode != 200) {
      throw Exception("Erro ao carregar relatório financeiro");
    }
    return RelatorioFinanceiro.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<AlertaConfig> configurarAlertas({
    required String obraId,
    double? percentualDesvioThreshold,
    bool? notificacaoAtiva,
  }) async {
    final payload = <String, dynamic>{
      "percentual_desvio_threshold": ?percentualDesvioThreshold,
      "notificacao_ativa": ?notificacaoAtiva,
    };
    final response = await _withAuth(() => _client.put(
      _uri("/api/obras/$obraId/alertas"),
      headers: _headers(),
      body: jsonEncode(payload),
    ));
    if (response.statusCode != 200) {
      throw Exception("Erro ao configurar alertas");
    }
    return AlertaConfig.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  // ─── Fase 3 — Document AI ───────────────────────────────────────────────────

  Future<ProjetoDoc> uploadProjeto({
    required String obraId,
    required PlatformFile file,
  }) async {
    if (file.size == 0) {
      throw Exception("Arquivo vazio (0 bytes). Selecione um PDF válido.");
    }
    final response = await _withAuthMultipart(() {
      final request = http.MultipartRequest("POST", _uri("/api/obras/$obraId/projetos"));
      request.headers.addAll(_headers(json: false));
      request.files.add(_buildMultipartFile(file, MediaType("application", "pdf")));
      return request.send();
    });
    final body = await response.stream.bytesToString();
    if (response.statusCode != 200) {
      String detail = "Erro ao enviar projeto";
      try {
        final json = jsonDecode(body) as Map<String, dynamic>;
        detail = (json["detail"] as String?) ?? detail;
      } catch (_) {}
      throw Exception(detail);
    }
    return ProjetoDoc.fromJson(jsonDecode(body) as Map<String, dynamic>);
  }

  Future<List<ProjetoDoc>> listarProjetos(String obraId) async {
    final response = await _deduplicatedGet("/api/obras/$obraId/projetos");
    if (response.statusCode != 200) {
      throw Exception("Erro ao listar projetos");
    }
    final data = jsonDecode(response.body) as List<dynamic>;
    return data.map((item) => ProjetoDoc.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<ProjetoDoc> obterProjeto(String projetoId) async {
    final response = await _withAuth(() => _client.get(_uri("/api/projetos/$projetoId"), headers: _headers(json: false)));
    if (response.statusCode != 200) {
      throw Exception("Erro ao obter projeto");
    }
    return ProjetoDoc.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  /// Remove um projeto PDF e seus riscos associados.
  Future<void> deletarProjeto(String projetoId) async {
    final response = await _withAuth(() => _client.delete(
      _uri("/api/projetos/$projetoId"),
      headers: _headers(json: false),
    ));
    if (response.statusCode != 200) {
      try {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        throw Exception(body["detail"] ?? "Erro ao remover projeto");
      } on FormatException {
        throw Exception("Erro ao remover projeto (status ${response.statusCode})");
      }
    }
  }

  /// Dispara a análise em background (retorna 202).
  Future<void> dispararAnalise(String projetoId) async {
    final response = await _withAuth(() => _client.post(
      _uri("/api/projetos/$projetoId/analisar"),
      headers: _headers(),
    ));
    if (response.statusCode != 202 && response.statusCode != 200) {
      try {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        throw Exception(body["detail"] ?? "Erro ao analisar projeto");
      } on FormatException {
        throw Exception("Erro ao analisar projeto (status ${response.statusCode})");
      }
    }
  }

  /// Polling: consulta o status atual do projeto até concluir ou dar erro.
  /// Retorna o ProjetoDoc final.
  Future<ProjetoDoc> aguardarAnalise(
    String projetoId, {
    Duration intervalo = const Duration(seconds: 5),
    Duration timeout = const Duration(minutes: 10),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      final projeto = await obterProjeto(projetoId);
      if (projeto.status == "concluido" || projeto.status == "erro") {
        return projeto;
      }
      await Future.delayed(intervalo);
    }
    throw Exception("Timeout aguardando análise do projeto");
  }

  Future<ProjetoAnalise> obterAnalise(String projetoId) async {
    final response = await _withAuth(() => _client.get(_uri("/api/projetos/$projetoId/analise"), headers: _headers(json: false)));
    if (response.statusCode != 200) {
      throw Exception("Erro ao obter análise");
    }
    return ProjetoAnalise.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  // ─── Fase 4 — Visual AI ─────────────────────────────────────────────────────

  Future<AnaliseVisualComAchados> analisarImagemEtapa({
    required String etapaId,
    required XFile image,
  }) async {
    final bytes = await image.readAsBytes();
    final ext = image.path.split(".").last.toLowerCase();
    final response = await _withAuthMultipart(() {
      final request = http.MultipartRequest(
        "POST",
        _uri("/api/etapas/$etapaId/analise-visual"),
      );
      request.headers.addAll(_headers(json: false));
      request.files.add(http.MultipartFile.fromBytes(
        "file",
        bytes,
        filename: image.name,
        contentType: _inferContentTypeFromExtension(ext),
      ));
      return request.send();
    });
    final body = await response.stream.bytesToString();
    if (response.statusCode != 200) {
      try {
        final decoded = jsonDecode(body) as Map<String, dynamic>;
        throw Exception(decoded["detail"] ?? "Erro na análise visual");
      } on FormatException {
        throw Exception("Erro na análise visual (status ${response.statusCode})");
      }
    }
    return AnaliseVisualComAchados.fromJson(
      jsonDecode(body) as Map<String, dynamic>,
    );
  }

  Future<List<AnaliseVisual>> listarAnalisesVisuais(String etapaId) async {
    final response =
        await _withAuth(() => _client.get(_uri("/api/etapas/$etapaId/analises-visuais"), headers: _headers(json: false)));
    if (response.statusCode != 200) {
      throw Exception("Erro ao listar análises visuais");
    }
    final data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((item) => AnaliseVisual.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<AnaliseVisualComAchados> obterAnaliseVisual(String analiseId) async {
    final response =
        await _withAuth(() => _client.get(_uri("/api/analises-visuais/$analiseId"), headers: _headers(json: false)));
    if (response.statusCode != 200) {
      throw Exception("Erro ao obter análise visual");
    }
    return AnaliseVisualComAchados.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  // ─── Fase 5 — Prestadores e Fornecedores ──────────────────────────────────

  Future<List<Prestador>> listarPrestadores({
    String? categoria,
    String? subcategoria,
    String? regiao,
    String? q,
  }) async {
    final params = <String, String>{};
    if (categoria != null) params['categoria'] = categoria;
    if (subcategoria != null) params['subcategoria'] = subcategoria;
    if (regiao != null && regiao.isNotEmpty) params['regiao'] = regiao;
    if (q != null && q.isNotEmpty) params['q'] = q;
    final uri = Uri.parse("$apiBaseUrl/api/prestadores")
        .replace(queryParameters: params.isNotEmpty ? params : null);
    final response = await _withAuth(() => _client.get(uri, headers: _headers(json: false)));
    if (response.statusCode != 200) {
      throw Exception("Erro ao listar prestadores");
    }
    final data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((item) => Prestador.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<Prestador> criarPrestador({
    required String nome,
    required String categoria,
    required String subcategoria,
    String? regiao,
    String? telefone,
    String? email,
  }) async {
    final payload = <String, dynamic>{
      "nome": nome,
      "categoria": categoria,
      "subcategoria": subcategoria,
    };
    if (regiao != null && regiao.isNotEmpty) payload["regiao"] = regiao;
    if (telefone != null && telefone.isNotEmpty) payload["telefone"] = telefone;
    if (email != null && email.isNotEmpty) payload["email"] = email;

    final response = await _withAuth(() => _client.post(
      _uri("/api/prestadores"),
      headers: _headers(),
      body: jsonEncode(payload),
    ));
    if (response.statusCode != 200) {
      throw Exception("Erro ao cadastrar prestador");
    }
    return Prestador.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<PrestadorDetalhe> obterPrestador(String prestadorId) async {
    final response =
        await _withAuth(() => _client.get(_uri("/api/prestadores/$prestadorId"), headers: _headers(json: false)));
    if (response.statusCode != 200) {
      throw Exception("Erro ao obter prestador");
    }
    return PrestadorDetalhe.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<AvaliacaoPrestador> criarAvaliacao({
    required String prestadorId,
    int? notaQualidadeServico,
    int? notaCumprimentoPrazos,
    int? notaFidelidadeProjeto,
    int? notaPrazoEntrega,
    int? notaQualidadeMaterial,
    String? comentario,
  }) async {
    final payload = <String, dynamic>{};
    if (notaQualidadeServico != null) {
      payload["nota_qualidade_servico"] = notaQualidadeServico;
    }
    if (notaCumprimentoPrazos != null) {
      payload["nota_cumprimento_prazos"] = notaCumprimentoPrazos;
    }
    if (notaFidelidadeProjeto != null) {
      payload["nota_fidelidade_projeto"] = notaFidelidadeProjeto;
    }
    if (notaPrazoEntrega != null) {
      payload["nota_prazo_entrega"] = notaPrazoEntrega;
    }
    if (notaQualidadeMaterial != null) {
      payload["nota_qualidade_material"] = notaQualidadeMaterial;
    }
    if (comentario != null && comentario.isNotEmpty) {
      payload["comentario"] = comentario;
    }

    final response = await _withAuth(() => _client.post(
      _uri("/api/prestadores/$prestadorId/avaliacoes"),
      headers: _headers(),
      body: jsonEncode(payload),
    ));
    if (response.statusCode != 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      throw Exception(body["detail"] ?? "Erro ao registrar avaliação");
    }
    return AvaliacaoPrestador.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<Map<String, List<String>>> listarSubcategorias() async {
    final response =
        await _withAuth(() => _client.get(_uri("/api/prestadores/subcategorias"), headers: _headers(json: false)));
    if (response.statusCode != 200) {
      throw Exception("Erro ao listar subcategorias");
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data.map(
      (k, v) => MapEntry(k, (v as List<dynamic>).cast<String>()),
    );
  }

  // ─── Fase 6 — Checklist Inteligente ──────────────────────────────────────

  Future<ChecklistInteligenteResponse> gerarChecklistInteligente(
      String obraId) async {
    final response = await _withAuth(() => _client.post(
      _uri("/api/obras/$obraId/checklist-inteligente"),
      headers: _headers(),
    ));
    if (response.statusCode != 200) {
      try {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        throw Exception(body["detail"] ?? "Erro ao gerar checklist inteligente");
      } on FormatException {
        throw Exception("Erro ao gerar checklist inteligente (status ${response.statusCode})");
      }
    }
    return ChecklistInteligenteResponse.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<int> aplicarChecklistInteligente({
    required String obraId,
    required String logId,
    required List<ItemChecklistSugerido> itens,
  }) async {
    final payload = {
      "log_id": logId,
      "itens": itens.map((i) => i.toApplyJson()).toList(),
    };
    final response = await _withAuth(() => _client.post(
      _uri("/api/obras/$obraId/checklist-inteligente/aplicar"),
      headers: _headers(),
      body: jsonEncode(payload),
    ));
    if (response.statusCode != 200) {
      try {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        throw Exception(body["detail"] ?? "Erro ao aplicar itens");
      } on FormatException {
        throw Exception("Erro ao aplicar itens (status ${response.statusCode})");
      }
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data["total_aplicados"] as int;
  }

  // ─── Cronograma ──────────────────────────────────────────────────────────

  Future<IdentificarProjetosResponse> identificarTiposProjeto(String obraId) async {
    final response = await _withAuth(() => _client.post(
      _uri("/api/obras/$obraId/identificar-projetos"),
      headers: _headers(),
    ));
    if (response.statusCode != 200) {
      try {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        throw Exception(body["detail"] ?? "Erro ao identificar projetos");
      } on FormatException {
        throw Exception("Erro ao identificar projetos (status ${response.statusCode})");
      }
    }
    return IdentificarProjetosResponse.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<CronogramaResponse> gerarCronograma({
    required String obraId,
    required List<String> tiposProjeto,
  }) async {
    final response = await _withAuth(() => _client.post(
      _uri("/api/obras/$obraId/cronograma/gerar"),
      headers: _headers(),
      body: jsonEncode({"tipos_projeto": tiposProjeto}),
    ));
    if (response.statusCode != 200) {
      try {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        throw Exception(body["detail"] ?? "Erro ao gerar cronograma");
      } on FormatException {
        throw Exception("Erro ao gerar cronograma (status ${response.statusCode})");
      }
    }
    return CronogramaResponse.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<CronogramaResponse> listarCronograma(String obraId) async {
    final response = await _withAuth(() => _client.get(
      _uri("/api/obras/$obraId/cronograma"),
      headers: _headers(json: false),
    ));
    if (response.statusCode != 200) {
      throw Exception("Erro ao listar cronograma");
    }
    return CronogramaResponse.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<List<Evidencia>> listarEvidenciasAtividade(String atividadeId) async {
    final response = await _withAuth(() => _client.get(
      _uri("/api/cronograma/$atividadeId/evidencias"),
      headers: _headers(json: false),
    ));
    if (response.statusCode != 200) {
      throw Exception("Erro ao listar evidências da atividade");
    }
    final data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((item) => Evidencia.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<Map<String, dynamic>> verificarAlertasCronograma(String obraId) async {
    final response = await _withAuth(() => _client.post(
      _uri("/api/obras/$obraId/cronograma/alertas/verificar"),
      headers: _headers(),
      body: jsonEncode({}),
    ));
    if (response.statusCode != 200) {
      throw Exception("Erro ao verificar alertas de cronograma");
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<RdoDiario> criarRdo({
    required String obraId,
    required String dataReferencia,
    required String clima,
    required int maoObraTotal,
    required String atividadesExecutadas,
    String? observacoes,
    List<String> fotosUrls = const [],
  }) async {
    final response = await _withAuth(() => _client.post(
      _uri("/api/obras/$obraId/rdo"),
      headers: _headers(),
      body: jsonEncode({
        "data_referencia": dataReferencia,
        "clima": clima,
        "mao_obra_total": maoObraTotal,
        "atividades_executadas": atividadesExecutadas,
        "observacoes": observacoes,
        "fotos_urls": fotosUrls,
      }),
    ));
    if (response.statusCode != 200) {
      throw Exception("Erro ao criar RDO");
    }
    return RdoDiario.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<List<RdoDiario>> listarRdos(String obraId) async {
    final response = await _withAuth(() => _client.get(
      _uri("/api/obras/$obraId/rdo"),
      headers: _headers(json: false),
    ));
    if (response.statusCode != 200) {
      throw Exception("Erro ao listar RDOs");
    }
    final data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((item) => RdoDiario.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<RdoDiario> publicarRdo(String rdoId) async {
    final response = await _withAuth(() => _client.post(
      _uri("/api/rdo/$rdoId/publicar"),
      headers: _headers(),
      body: jsonEncode({}),
    ));
    if (response.statusCode != 200) {
      throw Exception("Erro ao publicar RDO");
    }
    return RdoDiario.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<AtividadeCronograma> atualizarAtividade({
    required String atividadeId,
    String? status,
    String? dataInicioReal,
    String? dataFimReal,
    double? valorPrevisto,
    double? valorGasto,
  }) async {
    final payload = <String, dynamic>{
      "status": ?status,
      "data_inicio_real": ?dataInicioReal,
      "data_fim_real": ?dataFimReal,
      "valor_previsto": ?valorPrevisto,
      "valor_gasto": ?valorGasto,
    };
    final response = await _withAuth(() => _client.patch(
      _uri("/api/cronograma/$atividadeId"),
      headers: _headers(),
      body: jsonEncode(payload),
    ));
    if (response.statusCode != 200) {
      throw Exception("Erro ao atualizar atividade");
    }
    return AtividadeCronograma.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<List<ServicoNecessario>> listarServicos(String atividadeId) async {
    final response = await _withAuth(() => _client.get(
      _uri("/api/cronograma/$atividadeId/servicos"),
      headers: _headers(json: false),
    ));
    if (response.statusCode != 200) {
      throw Exception("Erro ao listar serviços");
    }
    final data = jsonDecode(response.body) as List<dynamic>;
    return data.map((e) => ServicoNecessario.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<ServicoNecessario> vincularPrestador({
    required String servicoId,
    required String prestadorId,
  }) async {
    final response = await _withAuth(() => _client.post(
      _uri("/api/servicos/$servicoId/vincular"),
      headers: _headers(),
      body: jsonEncode({"prestador_id": prestadorId}),
    ));
    if (response.statusCode != 200) {
      throw Exception("Erro ao vincular prestador");
    }
    return ServicoNecessario.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<List<ChecklistItem>> listarChecklistAtividade(String atividadeId) async {
    final response = await _withAuth(() => _client.get(
      _uri("/api/cronograma/$atividadeId/checklist"),
      headers: _headers(json: false),
    ));
    if (response.statusCode != 200) {
      throw Exception("Erro ao listar checklist da atividade");
    }
    final data = jsonDecode(response.body) as List<dynamic>;
    return data.map((e) => ChecklistItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<ChecklistItem> criarChecklistAtividade({
    required String atividadeId,
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
    final response = await _withAuth(() => _client.post(
      _uri("/api/cronograma/$atividadeId/checklist"),
      headers: _headers(),
      body: jsonEncode(payload),
    ));
    if (response.statusCode != 200) {
      throw Exception("Erro ao criar item de checklist");
    }
    return ChecklistItem.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<Despesa> lancarDespesaAtividade({
    required String atividadeId,
    required double valor,
    required String descricao,
    required String data,
    String? categoria,
  }) async {
    final payload = <String, dynamic>{
      "valor": valor,
      "descricao": descricao,
      "data": data,
      "categoria": ?categoria,
    };
    final response = await _withAuth(() => _client.post(
      _uri("/api/cronograma/$atividadeId/despesas"),
      headers: _headers(),
      body: jsonEncode(payload),
    ));
    if (response.statusCode != 200) {
      throw Exception("Erro ao lançar despesa");
    }
    return Despesa.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  // ─── Subscription ──────────────────────────────────────────────────────────

  Future<SubscriptionInfo> getSubscription() async {
    final response = await _withAuth(() => _client.get(
      _uri("/api/subscription/me"),
      headers: _headers(json: false),
    ));
    if (response.statusCode != 200) {
      throw Exception("Erro ao carregar assinatura");
    }
    return SubscriptionInfo.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<SubscriptionInfo> syncSubscription() async {
    final response = await _withAuth(() => _client.post(
      _uri("/api/subscription/sync"),
      headers: _headers(),
      body: jsonEncode({}),
    ));
    if (response.statusCode != 200) {
      throw Exception("Erro ao sincronizar assinatura");
    }
    return SubscriptionInfo.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<String> createCheckout(String plano) async {
    final response = await _withAuth(() => _client.post(
      _uri("/api/subscription/create-checkout"),
      headers: _headers(),
      body: jsonEncode({"plan": plano}),
    ));
    if (response.statusCode != 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      throw Exception(body["detail"] ?? "Erro ao criar checkout");
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data["checkout_url"] as String;
  }

  Future<void> validarCompraNativa(NativePurchasePayload payload) async {
    final response = await _withAuth(() => _client.post(
      _uri("/api/subscription/validate-purchase"),
      headers: _headers(),
      body: jsonEncode(payload.toJson()),
    ));
    if (response.statusCode != 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      throw Exception(body["detail"] ?? "Erro ao validar compra nativa");
    }
  }

  Future<void> cancelSubscription() async {
    final response = await _withAuth(() => _client.post(
      _uri("/api/subscription/cancel-subscription"),
      headers: _headers(),
      body: jsonEncode({}),
    ));
    if (response.statusCode != 200) {
      throw Exception("Erro ao cancelar assinatura");
    }
  }

  Future<int> rewardUsage(String feature) async {
    final response = await _withAuth(() => _client.post(
      _uri("/api/subscription/reward-usage"),
      headers: _headers(),
      body: jsonEncode({"feature": feature}),
    ));
    if (response.statusCode != 200) {
      throw Exception("Erro ao registrar recompensa");
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data["bonus_granted"] as int? ?? 0;
  }

  // ─── Convites ─────────────────────────────────────────────────────────────

  Future<ObraConvite> criarConvite({
    required String obraId,
    required String email,
    required String papel,
  }) async {
    final response = await _withAuth(() => _client.post(
      _uri("/api/obras/$obraId/convites"),
      headers: _headers(),
      body: jsonEncode({"email": email, "papel": papel}),
    ));
    if (response.statusCode != 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      throw Exception(body["detail"] ?? "Erro ao criar convite");
    }
    return ObraConvite.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<List<ObraConvite>> listarConvites(String obraId) async {
    final response = await _withAuth(() => _client.get(
      _uri("/api/obras/$obraId/convites"),
      headers: _headers(json: false),
    ));
    if (response.statusCode != 200) {
      throw Exception("Erro ao listar convites");
    }
    final data = jsonDecode(response.body) as List<dynamic>;
    return data.map((e) => ObraConvite.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> removerConvite(String conviteId) async {
    final response = await _withAuth(() => _client.delete(
      _uri("/api/convites/$conviteId"),
      headers: _headers(json: false),
    ));
    if (response.statusCode != 200) {
      throw Exception("Erro ao remover convite");
    }
  }

  Future<Map<String, dynamic>> aceitarConvite({
    required String token,
    required String nome,
  }) async {
    final response = await _client.post(
      _uri("/api/convites/aceitar"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"token": token, "nome": nome}),
    );
    if (response.statusCode != 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      throw Exception(body["detail"] ?? "Erro ao aceitar convite");
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<List<ObraConvidada>> listarObrasConvidadas() async {
    final response = await _withAuth(() => _client.get(
      _uri("/api/convites/minhas-obras"),
      headers: _headers(json: false),
    ));
    if (response.statusCode != 200) {
      throw Exception("Erro ao listar obras convidadas");
    }
    final data = jsonDecode(response.body) as List<dynamic>;
    return data.map((e) => ObraConvidada.fromJson(e as Map<String, dynamic>)).toList();
  }

  // ─── Riscos Pendentes ─────────────────────────────────────────────────────

  Future<List<Risco>> listarRiscosPendentes(String obraId) async {
    final response = await _withAuth(() => _client.get(
      _uri("/api/obras/$obraId/riscos-pendentes"),
      headers: _headers(json: false),
    ));
    if (response.statusCode != 200) {
      throw Exception("Erro ao listar riscos pendentes");
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final riscos = data["riscos"] as List<dynamic>;
    return riscos.map((e) => Risco.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<int> aplicarRiscos({
    required String obraId,
    required List<String> riscoIds,
  }) async {
    final response = await _withAuth(() => _client.post(
      _uri("/api/obras/$obraId/aplicar-riscos"),
      headers: _headers(),
      body: jsonEncode({"risco_ids": riscoIds}),
    ));
    if (response.statusCode != 200) {
      throw Exception("Erro ao aplicar riscos ao checklist");
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data["criados"] as int? ?? 0;
  }

  // ─── Detalhamento por Cômodos ─────────────────────────────────────────────

  Future<Map<String, dynamic>> obterDetalhamento(String obraId) async {
    final response = await _withAuth(() => _client.get(
      _uri("/api/obras/$obraId/detalhamento"),
      headers: _headers(json: false),
    ));
    if (response.statusCode != 200) {
      throw Exception("Erro ao obter detalhamento");
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> extrairDetalhamento(String obraId, {double peDireito = 2.70}) async {
    final response = await _withAuth(() => _client.post(
      _uri("/api/obras/$obraId/extrair-detalhamento?pe_direito=$peDireito"),
      headers: _headers(),
      body: jsonEncode({}),
    ));
    if (response.statusCode != 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      throw Exception(body["detail"] ?? "Erro ao extrair detalhamento");
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  // ─── Geração Unificada — state machine (AI-06/AI-07) ─────────────────────

  /// Inicia geração unificada (cronograma + checklist) em background.
  /// Retorna imediatamente com o log para acompanhamento via polling.
  Future<GeracaoUnificadaLog> iniciarGeracaoUnificada(
    String obraId,
    List<String> tiposProjeto,
  ) async {
    final response = await _withAuth(() => _client.post(
      _uri("/api/obras/$obraId/geracao-unificada/iniciar"),
      headers: _headers(),
      body: jsonEncode({"tipos_projeto": tiposProjeto}),
    ));
    if (response.statusCode != 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      throw Exception(body["detail"] ?? "Erro ao iniciar geracao unificada");
    }
    return GeracaoUnificadaLog.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  /// Consulta o estado atual do log de geração unificada (polling).
  /// O cliente deve chamar periodicamente até [GeracaoUnificadaLog.isTerminal].
  Future<GeracaoUnificadaLog> statusGeracaoUnificada(
    String obraId,
    String logId,
  ) async {
    final response = await _withAuth(() => _client.get(
      _uri("/api/obras/$obraId/geracao-unificada/$logId/status"),
      headers: _headers(json: false),
    ));
    if (response.statusCode != 200) {
      throw Exception("Erro ao consultar status da geracao unificada");
    }
    return GeracaoUnificadaLog.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }
}
