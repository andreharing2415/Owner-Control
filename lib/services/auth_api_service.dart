/// Seam para operacoes de autenticacao usadas pelo AuthProvider.
///
/// Isola o provider do cliente HTTP concreto, preparando
/// migracao gradual para Riverpod na fase 5.
library;

import '../api/api.dart';

/// Contrato de acesso para chamadas de autenticacao.
abstract class AuthApiService {
  /// Realiza login e retorna payload com tokens e dados do usuario.
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  });

  /// Registra novo usuario e retorna payload com tokens e dados do usuario.
  Future<Map<String, dynamic>> register({
    required String nome,
    required String email,
    required String telefone,
    required String password,
  });

  /// Realiza login com conta Google usando id token.
  Future<Map<String, dynamic>> loginWithGoogle({required String idToken});

  /// Atualiza perfil do usuario autenticado.
  Future<Map<String, dynamic>> updateProfile({String? nome, String? telefone});
}

/// Implementacao concreta que delega para [ApiClient].
class ApiAuthService implements AuthApiService {
  ApiAuthService({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  @override
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) =>
      _client.login(email: email, password: password);

  @override
  Future<Map<String, dynamic>> register({
    required String nome,
    required String email,
    required String telefone,
    required String password,
  }) =>
      _client.register(
        nome: nome,
        email: email,
        telefone: telefone,
        password: password,
      );

  @override
  Future<Map<String, dynamic>> loginWithGoogle({required String idToken}) =>
      _client.loginWithGoogle(idToken: idToken);

  @override
  Future<Map<String, dynamic>> updateProfile({String? nome, String? telefone}) =>
      _client.updateProfile(nome: nome, telefone: telefone);
}
