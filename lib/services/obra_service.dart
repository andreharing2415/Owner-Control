/// Seam para operacoes de obra usadas pelo fluxo principal (dashboard/onboarding).
///
/// Isola telas e providers do cliente HTTP concreto, preparando
/// migracao gradual para Riverpod na fase 5.
library;

import '../api/api.dart';

/// Contrato de acesso para operacoes de obra do fluxo principal.
abstract class ObraService {
  /// Lista todas as obras do usuario autenticado.
  Future<List<Obra>> listarObras();

  /// Cria uma nova obra.
  Future<Obra> criarObra({
    required String nome,
    String? localizacao,
    double? orcamento,
    String? dataInicio,
    String? dataFim,
  });

  /// Lista etapas de uma obra.
  Future<List<Etapa>> listarEtapas(String obraId);

  /// Retorna relatorio financeiro consolidado de uma obra.
  Future<RelatorioFinanceiro> relatorioFinanceiro(String obraId);

  /// Lista documentos/projetos enviados para uma obra.
  Future<List<ProjetoDoc>> listarProjetos(String obraId);
}

/// Implementacao concreta que delega para [ApiClient].
class ApiObraService implements ObraService {
  ApiObraService({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  @override
  Future<List<Obra>> listarObras() => _client.listarObras();

  @override
  Future<Obra> criarObra({
    required String nome,
    String? localizacao,
    double? orcamento,
    String? dataInicio,
    String? dataFim,
  }) =>
      _client.criarObra(
        nome: nome,
        localizacao: localizacao,
        orcamento: orcamento,
        dataInicio: dataInicio,
        dataFim: dataFim,
      );

  @override
  Future<List<Etapa>> listarEtapas(String obraId) =>
      _client.listarEtapas(obraId);

  @override
  Future<RelatorioFinanceiro> relatorioFinanceiro(String obraId) =>
      _client.relatorioFinanceiro(obraId);

  @override
  Future<List<ProjetoDoc>> listarProjetos(String obraId) =>
      _client.listarProjetos(obraId);
}
