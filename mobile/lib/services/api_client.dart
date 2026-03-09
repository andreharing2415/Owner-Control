import "dart:convert";
import "dart:io" show File;
import "dart:typed_data";
import "package:file_picker/file_picker.dart";
import "package:http/http.dart" as http;
import "package:http_parser/http_parser.dart";
import "package:image_picker/image_picker.dart";

import "../models/auth.dart";
import "../models/checklist_item.dart";
import "../models/documento.dart";
import "../models/etapa.dart";
import "../models/evidencia.dart";
import "../models/financeiro.dart";
import "../models/norma.dart";
import "../models/obra.dart";
import "../models/prestador.dart";
import "../models/visual_ai.dart";

const apiBaseUrl = String.fromEnvironment(
  "API_BASE_URL",
  defaultValue: "https://mestreobra-backend-530484413221.us-central1.run.app",
);

class ApiClient {
  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  String? _accessToken;
  String? _refreshToken;

  bool get isAuthenticated => _accessToken != null;

  void setTokens({required String access, required String refresh}) {
    _accessToken = access;
    _refreshToken = refresh;
  }

  void clearTokens() {
    _accessToken = null;
    _refreshToken = null;
  }

  Uri _uri(String path) => Uri.parse("$apiBaseUrl$path");

  Map<String, String> get _headers => {
        "Content-Type": "application/json",
        if (_accessToken != null) "Authorization": "Bearer $_accessToken",
      };

  Map<String, String> get _authHeaders => {
        if (_accessToken != null) "Authorization": "Bearer $_accessToken",
      };

  Future<http.Response> _get(String path) async {
    final response = await _client.get(_uri(path), headers: _authHeaders);
    if (response.statusCode == 401 && _refreshToken != null) {
      final refreshed = await _tryRefresh();
      if (refreshed) {
        return _client.get(_uri(path), headers: _authHeaders);
      }
    }
    return response;
  }

  Future<http.Response> _post(String path, {Object? body}) async {
    final response = await _client.post(
      _uri(path),
      headers: _headers,
      body: body != null ? jsonEncode(body) : null,
    );
    if (response.statusCode == 401 && _refreshToken != null) {
      final refreshed = await _tryRefresh();
      if (refreshed) {
        return _client.post(
          _uri(path),
          headers: _headers,
          body: body != null ? jsonEncode(body) : null,
        );
      }
    }
    return response;
  }

  Future<http.Response> _patch(String path, {Object? body}) async {
    final response = await _client.patch(
      _uri(path),
      headers: _headers,
      body: body != null ? jsonEncode(body) : null,
    );
    if (response.statusCode == 401 && _refreshToken != null) {
      final refreshed = await _tryRefresh();
      if (refreshed) {
        return _client.patch(
          _uri(path),
          headers: _headers,
          body: body != null ? jsonEncode(body) : null,
        );
      }
    }
    return response;
  }

  Future<http.Response> _put(String path, {Object? body}) async {
    final response = await _client.put(
      _uri(path),
      headers: _headers,
      body: body != null ? jsonEncode(body) : null,
    );
    if (response.statusCode == 401 && _refreshToken != null) {
      final refreshed = await _tryRefresh();
      if (refreshed) {
        return _client.put(
          _uri(path),
          headers: _headers,
          body: body != null ? jsonEncode(body) : null,
        );
      }
    }
    return response;
  }

  Future<http.Response> _delete(String path) async {
    final response = await _client.delete(_uri(path), headers: _authHeaders);
    if (response.statusCode == 401 && _refreshToken != null) {
      final refreshed = await _tryRefresh();
      if (refreshed) {
        return _client.delete(_uri(path), headers: _authHeaders);
      }
    }
    return response;
  }

  Future<bool> _tryRefresh() async {
    try {
      final resp = await _client.post(
        _uri("/api/auth/refresh"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"refresh_token": _refreshToken}),
      );
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        _accessToken = data["access_token"] as String;
        _refreshToken = data["refresh_token"] as String;
        return true;
      }
    } catch (_) {}
    clearTokens();
    return false;
  }

  // ─── Auth ──────────────────────────────────────────────────────────────────

  Future<AuthTokens> register({
    required String email,
    required String password,
    required String nome,
    String? telefone,
  }) async {
    final response = await _client.post(
      _uri("/api/auth/register"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "email": email,
        "password": password,
        "nome": nome,
        if (telefone != null && telefone.isNotEmpty) "telefone": telefone,
      }),
    );
    if (response.statusCode != 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      throw Exception(body["detail"] ?? "Erro ao registrar");
    }
    final tokens = AuthTokens.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
    setTokens(access: tokens.accessToken, refresh: tokens.refreshToken);
    return tokens;
  }

  Future<AuthTokens> login({
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
      throw Exception(body["detail"] ?? "Credenciais inválidas");
    }
    final tokens = AuthTokens.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
    setTokens(access: tokens.accessToken, refresh: tokens.refreshToken);
    return tokens;
  }

  Future<User> getMe() async {
    final response = await _get("/api/auth/me");
    if (response.statusCode != 200) {
      throw Exception("Erro ao obter usuário");
    }
    return User.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<GoogleAuthResult> loginWithGoogle(String idToken) async {
    final response = await _client.post(
      _uri("/api/auth/google"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"id_token": idToken}),
    );
    if (response.statusCode != 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      throw Exception(body["detail"] ?? "Erro ao autenticar com Google");
    }
    return GoogleAuthResult.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<User> updateProfile({String? nome, String? telefone}) async {
    final body = <String, dynamic>{};
    if (nome != null) body["nome"] = nome;
    if (telefone != null) body["telefone"] = telefone;
    final response = await _patch("/api/auth/me", body: body);
    if (response.statusCode != 200) {
      final b = jsonDecode(response.body) as Map<String, dynamic>;
      throw Exception(b["detail"] ?? "Erro ao atualizar perfil");
    }
    return User.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  // ─── Obras ─────────────────────────────────────────────────────────────────

  Future<List<Obra>> listarObras() async {
    final response = await _get("/api/obras");
    if (response.statusCode != 200) {
      throw Exception("Erro ao listar obras");
    }
    final data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((item) => Obra.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<Obra> criarObra({
    required String nome,
    String? localizacao,
    double? orcamento,
  }) async {
    final response = await _post("/api/obras", body: {
      "nome": nome,
      if (localizacao != null && localizacao.isNotEmpty)
        "localizacao": localizacao,
      if (orcamento != null) "orcamento": orcamento,
    });
    if (response.statusCode != 200) {
      throw Exception("Erro ao criar obra");
    }
    return Obra.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<List<Etapa>> listarEtapas(String obraId) async {
    final response = await _get("/api/obras/$obraId");
    if (response.statusCode != 200) {
      throw Exception("Erro ao buscar obra");
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final etapasJson = data["etapas"] as List<dynamic>;
    return etapasJson
        .map((item) => Etapa.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<Etapa> atualizarStatusEtapa({
    required String etapaId,
    required String status,
  }) async {
    final response = await _patch(
      "/api/etapas/$etapaId/status",
      body: {"status": status},
    );
    if (response.statusCode != 200) {
      throw Exception("Erro ao atualizar status da etapa");
    }
    return Etapa.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  // ─── Checklist ─────────────────────────────────────────────────────────────

  Future<List<ChecklistItem>> listarItens(String etapaId) async {
    final response = await _get("/api/etapas/$etapaId/checklist-items");
    if (response.statusCode != 200) {
      throw Exception("Erro ao listar checklist");
    }
    final data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((item) => ChecklistItem.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<ChecklistItem> criarItem({
    required String etapaId,
    required String titulo,
    String? descricao,
    bool critico = false,
    String grupo = "Geral",
    int ordem = 0,
  }) async {
    final response = await _post(
      "/api/etapas/$etapaId/checklist-items",
      body: {
        "titulo": titulo,
        if (descricao != null && descricao.isNotEmpty) "descricao": descricao,
        "critico": critico,
        "status": "pendente",
        "grupo": grupo,
        "ordem": ordem,
      },
    );
    if (response.statusCode != 200) {
      throw Exception("Erro ao criar item");
    }
    return ChecklistItem.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<ChecklistItem> atualizarItem({
    required String itemId,
    String? titulo,
    String? descricao,
    String? status,
    bool? critico,
    String? observacao,
    String? grupo,
  }) async {
    final response = await _patch(
      "/api/checklist-items/$itemId",
      body: {
        if (titulo != null) "titulo": titulo,
        if (descricao != null) "descricao": descricao,
        if (status != null) "status": status,
        if (critico != null) "critico": critico,
        if (observacao != null) "observacao": observacao,
        if (grupo != null) "grupo": grupo,
      },
    );
    if (response.statusCode != 200) {
      throw Exception("Erro ao atualizar item");
    }
    return ChecklistItem.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> deletarItem(String itemId) async {
    final response = await _delete("/api/checklist-items/$itemId");
    if (response.statusCode != 204) {
      throw Exception("Erro ao remover item");
    }
  }

  Future<double> calcularScore(String etapaId) async {
    final response = await _get("/api/etapas/$etapaId/score");
    if (response.statusCode != 200) {
      throw Exception("Erro ao calcular score");
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return (data["score"] as num?)?.toDouble() ?? 0.0;
  }

  Future<Etapa> atualizarPrazoEtapa({
    required String etapaId,
    DateTime? prazoPrevisto,
    DateTime? prazoExecutado,
  }) async {
    final body = <String, dynamic>{};
    if (prazoPrevisto != null) {
      body["prazo_previsto"] = prazoPrevisto.toIso8601String().split("T").first;
    }
    if (prazoExecutado != null) {
      body["prazo_executado"] = prazoExecutado.toIso8601String().split("T").first;
    }
    final response = await _patch("/api/etapas/$etapaId/prazo", body: body);
    if (response.statusCode != 200) {
      throw Exception("Erro ao atualizar prazo da etapa");
    }
    return Etapa.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<List<String>> listarNormasChecklist(String etapaId) async {
    final response = await _get("/api/etapas/$etapaId/checklist-normas");
    if (response.statusCode != 200) {
      throw Exception("Erro ao carregar normas do checklist");
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return (data["normas"] as List<dynamic>).cast<String>();
  }

  Future<Map<String, dynamic>> sugerirGrupoItem({
    required String etapaId,
    required String titulo,
  }) async {
    final response = await _post(
      "/api/etapas/$etapaId/checklist-items/sugerir-grupo",
      body: {"titulo": titulo},
    );
    if (response.statusCode != 200) {
      throw Exception("Erro ao sugerir grupo");
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  // ─── Evidências ────────────────────────────────────────────────────────────

  Future<List<Evidencia>> listarEvidencias(String itemId) async {
    final response = await _get("/api/checklist-items/$itemId/evidencias");
    if (response.statusCode != 200) {
      throw Exception("Erro ao listar evidências");
    }
    final data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((item) => Evidencia.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> uploadEvidencia({
    required String itemId,
    required PlatformFile file,
  }) async {
    final request = http.MultipartRequest(
        "POST", _uri("/api/checklist-items/$itemId/evidencias"));
    if (_accessToken != null) {
      request.headers["Authorization"] = "Bearer $_accessToken";
    }
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
      throw Exception("Plataforma não suporta leitura deste arquivo.");
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
    final request = http.MultipartRequest(
        "POST", _uri("/api/checklist-items/$itemId/evidencias"));
    if (_accessToken != null) {
      request.headers["Authorization"] = "Bearer $_accessToken";
    }
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
    final response = await _get("/api/obras/$obraId/export-pdf");
    if (response.statusCode != 200) {
      throw Exception("Erro ao exportar PDF");
    }
    return response.bodyBytes;
  }

  // ─── Normas ────────────────────────────────────────────────────────────────

  Future<NormaBuscarResponse> buscarNormas({
    required String etapaNome,
    String? disciplina,
    String? localizacao,
    String? obraTipo,
  }) async {
    final response = await _post("/api/normas/buscar", body: {
      "etapa_nome": etapaNome,
      if (disciplina != null) "disciplina": disciplina,
      if (localizacao != null) "localizacao": localizacao,
      if (obraTipo != null) "obra_tipo": obraTipo,
    });
    if (response.statusCode != 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      throw Exception(body["detail"] ?? "Erro na pesquisa de normas");
    }
    return NormaBuscarResponse.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<List<NormaLogResumido>> listarHistoricoNormas() async {
    final response = await _get("/api/normas/historico");
    if (response.statusCode != 200) {
      throw Exception("Erro ao carregar histórico");
    }
    final data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((item) =>
            NormaLogResumido.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<EtapaNormaInfo>> listarEtapasNormas() async {
    final response = await _get("/api/normas/etapas");
    if (response.statusCode != 200) {
      throw Exception("Erro ao carregar etapas");
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final etapas = data["etapas"] as List<dynamic>;
    return etapas
        .map((item) => EtapaNormaInfo.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  // ─── Financeiro ────────────────────────────────────────────────────────────

  Future<List<OrcamentoEtapa>> listarOrcamento(String obraId) async {
    final response = await _get("/api/obras/$obraId/orcamento");
    if (response.statusCode != 200) {
      throw Exception("Erro ao carregar orçamento");
    }
    final data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((e) => OrcamentoEtapa.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> salvarOrcamento(
      String obraId, List<Map<String, dynamic>> itens) async {
    final response = await _post(
      "/api/obras/$obraId/orcamento",
      body: {"itens": itens},
    );
    if (response.statusCode != 200) {
      throw Exception("Erro ao salvar orçamento");
    }
  }

  Future<List<Despesa>> listarDespesas(String obraId) async {
    final response = await _get("/api/obras/$obraId/despesas");
    if (response.statusCode != 200) {
      throw Exception("Erro ao listar despesas");
    }
    final data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((e) => Despesa.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Despesa> criarDespesa({
    required String obraId,
    String? etapaId,
    required double valor,
    required String descricao,
    required String data,
    String? categoria,
  }) async {
    final response = await _post("/api/obras/$obraId/despesas", body: {
      "valor": valor,
      "descricao": descricao,
      "data": data,
      if (etapaId != null) "etapa_id": etapaId,
      if (categoria != null) "categoria": categoria,
    });
    if (response.statusCode != 200) {
      throw Exception("Erro ao lançar despesa");
    }
    return Despesa.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<RelatorioFinanceiro> relatorioFinanceiro(String obraId) async {
    final response = await _get("/api/obras/$obraId/relatorio-financeiro");
    if (response.statusCode != 200) {
      throw Exception("Erro ao carregar relatório financeiro");
    }
    return RelatorioFinanceiro.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<AlertaConfig> obterAlertaConfig(String obraId) async {
    final response = await _get("/api/obras/$obraId/alertas");
    if (response.statusCode != 200) {
      throw Exception("Erro ao carregar configuração de alertas");
    }
    return AlertaConfig.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> salvarAlertaConfig({
    required String obraId,
    required double percentualDesvioThreshold,
    required bool notificacaoAtiva,
  }) async {
    final response = await _put("/api/obras/$obraId/alertas", body: {
      "percentual_desvio_threshold": percentualDesvioThreshold,
      "notificacao_ativa": notificacaoAtiva,
    });
    if (response.statusCode != 200) {
      throw Exception("Erro ao salvar alertas");
    }
  }

  // ─── Document AI ───────────────────────────────────────────────────────────

  Future<List<ProjetoDoc>> listarProjetos(String obraId) async {
    final response = await _get("/api/obras/$obraId/projetos");
    if (response.statusCode != 200) {
      throw Exception("Erro ao listar projetos");
    }
    final data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((e) => ProjetoDoc.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ProjetoDoc> uploadProjeto({
    required String obraId,
    PlatformFile? file,
    List<int>? bytes,
    String? fileName,
  }) async {
    final request =
        http.MultipartRequest("POST", _uri("/api/obras/$obraId/projetos"));
    if (_accessToken != null) {
      request.headers["Authorization"] = "Bearer $_accessToken";
    }
    final http.MultipartFile multipartFile;
    if (bytes != null) {
      multipartFile = http.MultipartFile.fromBytes(
        "file",
        bytes,
        filename: fileName ?? "documento.pdf",
        contentType: MediaType("application", "pdf"),
      );
    } else if (file != null && file.bytes != null) {
      multipartFile = http.MultipartFile.fromBytes(
        "file",
        file.bytes!,
        filename: file.name,
        contentType: MediaType("application", "pdf"),
      );
    } else if (file != null && file.path != null) {
      final f = File(file.path!);
      multipartFile = http.MultipartFile(
        "file",
        f.openRead(),
        await f.length(),
        filename: file.name,
        contentType: MediaType("application", "pdf"),
      );
    } else {
      throw Exception("Não foi possível ler o arquivo.");
    }
    request.files.add(multipartFile);
    final streamResp = await request.send();
    final resp = await http.Response.fromStream(streamResp);
    if (resp.statusCode != 200) {
      throw Exception("Erro ao enviar projeto");
    }
    return ProjetoDoc.fromJson(
        jsonDecode(resp.body) as Map<String, dynamic>);
  }

  Future<ProjetoDoc> obterProjeto(String projetoId) async {
    final response = await _get("/api/projetos/$projetoId");
    if (response.statusCode != 200) {
      throw Exception("Erro ao obter projeto");
    }
    return ProjetoDoc.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> deletarProjeto(String projetoId) async {
    final response = await _delete("/api/projetos/$projetoId");
    if (response.statusCode != 200) {
      String detail = "Erro ao remover projeto";
      try {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        detail = body["detail"] as String? ?? detail;
      } catch (_) {}
      throw Exception(detail);
    }
  }

  Future<void> analisarProjeto(String projetoId) async {
    final response = await _post("/api/projetos/$projetoId/analisar");
    if (response.statusCode != 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      throw Exception(body["detail"] ?? "Erro ao analisar projeto");
    }
  }

  Future<AnaliseDocumento> obterAnaliseProjeto(String projetoId) async {
    final response = await _get("/api/projetos/$projetoId/analise");
    if (response.statusCode != 200) {
      throw Exception("Erro ao obter análise");
    }
    return AnaliseDocumento.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  // ─── Visual AI ─────────────────────────────────────────────────────────────

  Future<AnaliseVisual> enviarAnaliseVisual({
    required String etapaId,
    required XFile image,
  }) async {
    final bytes = await image.readAsBytes();
    final request = http.MultipartRequest(
        "POST", _uri("/api/etapas/$etapaId/analise-visual"));
    if (_accessToken != null) {
      request.headers["Authorization"] = "Bearer $_accessToken";
    }
    final ext = image.path.split(".").last.toLowerCase();
    request.files.add(http.MultipartFile.fromBytes(
      "file",
      bytes,
      filename: image.name,
      contentType: _inferContentTypeFromExtension(ext),
    ));
    final streamResp = await request.send();
    final resp = await http.Response.fromStream(streamResp);
    if (resp.statusCode != 200) {
      throw Exception("Erro ao enviar análise visual");
    }
    return AnaliseVisual.fromJson(
        jsonDecode(resp.body) as Map<String, dynamic>);
  }

  Future<List<AnaliseVisual>> listarAnalisesVisuais(String etapaId) async {
    final response = await _get("/api/etapas/$etapaId/analises-visuais");
    if (response.statusCode != 200) {
      throw Exception("Erro ao listar análises visuais");
    }
    final data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((e) => AnaliseVisual.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<AnaliseVisual> obterAnaliseVisual(String analiseId) async {
    final response = await _get("/api/analises-visuais/$analiseId");
    if (response.statusCode != 200) {
      throw Exception("Erro ao obter análise visual");
    }
    return AnaliseVisual.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  // ─── Prestadores ───────────────────────────────────────────────────────────

  Future<List<Prestador>> listarPrestadores({
    String? categoria,
    String? subcategoria,
    String? regiao,
    String? busca,
  }) async {
    final params = <String, String>{};
    if (categoria != null) params["categoria"] = categoria;
    if (subcategoria != null) params["subcategoria"] = subcategoria;
    if (regiao != null) params["regiao"] = regiao;
    if (busca != null) params["busca"] = busca;
    final uri = _uri("/api/prestadores").replace(queryParameters: params);
    final response =
        await _client.get(uri, headers: _authHeaders);
    if (response.statusCode != 200) {
      throw Exception("Erro ao listar prestadores");
    }
    final data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((e) => Prestador.fromJson(e as Map<String, dynamic>))
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
    final response = await _post("/api/prestadores", body: {
      "nome": nome,
      "categoria": categoria,
      "subcategoria": subcategoria,
      if (regiao != null) "regiao": regiao,
      if (telefone != null) "telefone": telefone,
      if (email != null) "email": email,
    });
    if (response.statusCode != 200) {
      throw Exception("Erro ao criar prestador");
    }
    return Prestador.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> obterPrestador(String prestadorId) async {
    final response = await _get("/api/prestadores/$prestadorId");
    if (response.statusCode != 200) {
      throw Exception("Erro ao obter prestador");
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<List<Avaliacao>> listarAvaliacoes(String prestadorId) async {
    final response =
        await _get("/api/prestadores/$prestadorId/avaliacoes");
    if (response.statusCode != 200) {
      throw Exception("Erro ao listar avaliações");
    }
    final data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((e) => Avaliacao.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> criarAvaliacao({
    required String prestadorId,
    required Map<String, dynamic> notas,
  }) async {
    final response = await _post(
      "/api/prestadores/$prestadorId/avaliacoes",
      body: notas,
    );
    if (response.statusCode != 200) {
      throw Exception("Erro ao criar avaliação");
    }
  }

  Future<Map<String, List<String>>> listarSubcategorias() async {
    final response = await _get("/api/prestadores/subcategorias");
    if (response.statusCode != 200) {
      throw Exception("Erro ao listar subcategorias");
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data.map((k, v) =>
        MapEntry(k, (v as List<dynamic>).cast<String>()));
  }

  // ─── Checklist Inteligente ─────────────────────────────────────────────────

  /// Streams SSE events from the checklist inteligente endpoint.
  /// Each event is a Map with an "event" key (step, page, caracteristica, itens, error, done).
  Stream<Map<String, dynamic>> streamChecklistInteligente(String obraId) async* {
    final request = http.Request(
      "GET",
      _uri("/api/obras/$obraId/checklist-inteligente/stream"),
    );
    request.headers.addAll(_authHeaders);

    final streamedResponse = await _client.send(request);

    if (streamedResponse.statusCode != 200) {
      final body = await streamedResponse.stream.bytesToString();
      try {
        final parsed = jsonDecode(body) as Map<String, dynamic>;
        throw Exception(parsed["detail"] ?? "Erro ao gerar checklist");
      } catch (e) {
        if (e is Exception && e.toString().contains("Erro ao gerar")) rethrow;
        throw Exception("Erro ao gerar checklist (HTTP ${streamedResponse.statusCode})");
      }
    }

    // Parse SSE format: "data: {...}\n\n"
    String buffer = "";
    await for (final chunk in streamedResponse.stream.transform(const Utf8Decoder())) {
      buffer += chunk;
      while (buffer.contains("\n\n")) {
        final idx = buffer.indexOf("\n\n");
        final block = buffer.substring(0, idx).trim();
        buffer = buffer.substring(idx + 2);

        for (final line in block.split("\n")) {
          if (line.startsWith("data: ")) {
            final jsonStr = line.substring(6);
            try {
              yield jsonDecode(jsonStr) as Map<String, dynamic>;
            } catch (_) {
              // skip malformed JSON
            }
          }
        }
      }
    }
  }

  /// Starts background checklist processing. Returns the log with its ID.
  Future<ChecklistInteligenteLog> iniciarChecklistInteligente(
      String obraId) async {
    final response = await _post(
      "/api/obras/$obraId/checklist-inteligente/iniciar",
    );
    if (response.statusCode != 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      throw Exception(body["detail"] ?? "Erro ao iniciar checklist");
    }
    return ChecklistInteligenteLog.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  /// Polls the status of a checklist generation job.
  Future<ChecklistGeracaoStatus> statusChecklistInteligente(
      String obraId, String logId) async {
    final response = await _get(
      "/api/obras/$obraId/checklist-inteligente/$logId/status",
    );
    if (response.statusCode != 200) {
      throw Exception("Erro ao consultar status");
    }
    return ChecklistGeracaoStatus.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> aplicarChecklistInteligente(
      String obraId, List<Map<String, dynamic>> itens) async {
    final response = await _post(
      "/api/obras/$obraId/checklist-inteligente/aplicar",
      body: {"itens": itens},
    );
    if (response.statusCode != 200) {
      throw Exception("Erro ao aplicar checklist");
    }
  }

  Future<List<ChecklistInteligenteLog>> historicoChecklistInteligente(
      String obraId) async {
    final response =
        await _get("/api/obras/$obraId/checklist-inteligente/historico");
    if (response.statusCode != 200) {
      throw Exception("Erro ao carregar histórico");
    }
    final data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((e) =>
            ChecklistInteligenteLog.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ─── Utils ─────────────────────────────────────────────────────────────────

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
}
