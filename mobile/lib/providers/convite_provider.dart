import "package:flutter/foundation.dart";

import "../models/convite.dart";
import "../services/api_client.dart";

class ConviteProvider extends ChangeNotifier {
  ConviteProvider({required this.api});

  final ApiClient api;

  // ─── Convites da obra (visão do Dono) ─────────────────────────────────────

  List<ObraConvite> _convites = [];
  bool _loadingConvites = false;
  String? _erroConvites;

  List<ObraConvite> get convites => _convites;
  bool get loadingConvites => _loadingConvites;
  String? get erroConvites => _erroConvites;

  int get convitesAtivos =>
      _convites.where((c) => c.isPendente || c.isAceito).length;

  Future<void> carregarConvites(String obraId) async {
    _loadingConvites = true;
    _erroConvites = null;
    notifyListeners();
    try {
      _convites = await api.listarConvites(obraId);
    } catch (e) {
      _erroConvites = e.toString();
    }
    _loadingConvites = false;
    notifyListeners();
  }

  Future<void> criarConvite({
    required String obraId,
    required String email,
    required String papel,
  }) async {
    final convite = await api.criarConvite(
      obraId: obraId,
      email: email,
      papel: papel,
    );
    _convites.add(convite);
    notifyListeners();
  }

  Future<void> removerConvite(String conviteId) async {
    await api.removerConvite(conviteId);
    _convites.removeWhere((c) => c.id == conviteId);
    notifyListeners();
  }

  // ─── Obras convidadas (visão do Convidado) ────────────────────────────────

  List<ObraConvidada> _obrasConvidadas = [];
  bool _loadingObras = false;

  List<ObraConvidada> get obrasConvidadas => _obrasConvidadas;
  bool get loadingObras => _loadingObras;

  String? _erroObras;
  String? get erroObras => _erroObras;

  Future<void> carregarObrasConvidadas() async {
    _loadingObras = true;
    _erroObras = null;
    notifyListeners();
    try {
      _obrasConvidadas = await api.listarObrasConvidadas();
    } catch (e) {
      _erroObras = e.toString();
    }
    _loadingObras = false;
    notifyListeners();
  }

  // ─── Comentários em etapas ────────────────────────────────────────────────

  List<EtapaComentario> _comentarios = [];
  bool _loadingComentarios = false;

  List<EtapaComentario> get comentarios => _comentarios;
  bool get loadingComentarios => _loadingComentarios;

  String? _erroComentarios;
  String? get erroComentarios => _erroComentarios;

  Future<void> carregarComentarios(String etapaId) async {
    _loadingComentarios = true;
    _erroComentarios = null;
    notifyListeners();
    try {
      _comentarios = await api.listarComentarios(etapaId);
    } catch (e) {
      _erroComentarios = e.toString();
    }
    _loadingComentarios = false;
    notifyListeners();
  }

  Future<void> criarComentario({
    required String etapaId,
    required String texto,
  }) async {
    final comentario = await api.criarComentario(
      etapaId: etapaId,
      texto: texto,
    );
    _comentarios.insert(0, comentario);
    notifyListeners();
  }

  void clear() {
    _convites = [];
    _obrasConvidadas = [];
    _comentarios = [];
    notifyListeners();
  }
}
