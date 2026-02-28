import 'package:flutter/foundation.dart';

import '../api/api.dart';
import '../services/auth_service.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

/// Provider de autenticação — gerencia estado de login/logout.
class AuthProvider extends ChangeNotifier {
  AuthStatus _status = AuthStatus.unknown;
  Map<String, dynamic>? _user;

  AuthStatus get status => _status;
  Map<String, dynamic>? get user => _user;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  String get userName => _user?['nome'] as String? ?? 'Proprietario';
  String get userEmail => _user?['email'] as String? ?? '';

  // ─── Checar auth ao iniciar o app ─────────────────────────────────────────

  Future<void> checkAuth() async {
    final auth = AuthService.instance;
    if (auth.isLoggedIn) {
      final valid = await auth.validateToken();
      if (valid) {
        _user = auth.cachedUser;
        _status = AuthStatus.authenticated;
      } else {
        await auth.clear();
        _status = AuthStatus.unauthenticated;
      }
    } else {
      _status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  // ─── Login ────────────────────────────────────────────────────────────────

  Future<void> login({required String email, required String password}) async {
    final api = ApiClient();
    final result = await api.login(email: email, password: password);
    await AuthService.instance.saveTokens(
      accessToken: result['access_token'] as String,
      refreshToken: result['refresh_token'] as String,
      user: result['user'] as Map<String, dynamic>,
    );
    _user = result['user'] as Map<String, dynamic>;
    _status = AuthStatus.authenticated;
    notifyListeners();
  }

  // ─── Register ─────────────────────────────────────────────────────────────

  Future<void> register({
    required String nome,
    required String email,
    required String telefone,
    required String password,
  }) async {
    final api = ApiClient();
    final result = await api.register(
      nome: nome,
      email: email,
      telefone: telefone,
      password: password,
    );
    await AuthService.instance.saveTokens(
      accessToken: result['access_token'] as String,
      refreshToken: result['refresh_token'] as String,
      user: result['user'] as Map<String, dynamic>,
    );
    _user = result['user'] as Map<String, dynamic>;
    _status = AuthStatus.authenticated;
    notifyListeners();
  }

  // ─── Logout ───────────────────────────────────────────────────────────────

  Future<void> logout() async {
    await AuthService.instance.clear();
    _user = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }
}
