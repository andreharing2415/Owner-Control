library;

import '../api/api.dart';

/// Contrato para dados detalhados da visão do dono da obra.
abstract class OwnerProgressService {
  Future<List<Etapa>> listarEtapas(String obraId);
  Future<List<ChecklistItem>> listarItens(String etapaId);
  Future<List<Evidencia>> listarEvidencias(String itemId);
}

/// Implementação concreta baseada no ApiClient.
class ApiOwnerProgressService implements OwnerProgressService {
  ApiOwnerProgressService({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  @override
  Future<List<Etapa>> listarEtapas(String obraId) => _client.listarEtapas(obraId);

  @override
  Future<List<ChecklistItem>> listarItens(String etapaId) => _client.listarItens(etapaId);

  @override
  Future<List<Evidencia>> listarEvidencias(String itemId) =>
      _client.listarEvidencias(itemId);
}
