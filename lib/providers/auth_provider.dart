import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:local_auth/local_auth.dart';

import '../api/api.dart';
import '../services/auth_service.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

/// Provider de autenticação — gerencia estado de login/logout.
class AuthProvider extends ChangeNotifier {
  AuthStatus _status = AuthStatus.unknown;
  Map<String, dynamic>? _user;
  bool _isNewUser = false;

  AuthStatus get status => _status;
  Map<String, dynamic>? get user => _user;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  bool get isNewUser => _isNewUser;
  String get userName => _user?['nome'] as String? ?? 'Proprietario';
  String get userEmail => _user?['email'] as String? ?? '';

  void clearNewUserFlag() {
    _isNewUser = false;
    notifyListeners();
  }

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

  // ─── Google Sign-In ──────────────────────────────────────────────────────

  Future<void> loginWithGoogle() async {
    final googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);
    final account = await googleSignIn.signIn();
    if (account == null) return; // usuário cancelou

    final auth = await account.authentication;
    final idToken = auth.idToken;
    if (idToken == null) throw Exception('Erro ao obter token do Google');

    final api = ApiClient();
    final result = await api.loginWithGoogle(idToken: idToken);

    await AuthService.instance.saveTokens(
      accessToken: result['access_token'] as String,
      refreshToken: result['refresh_token'] as String,
      user: result['user'] as Map<String, dynamic>,
    );
    _user = result['user'] as Map<String, dynamic>;
    _isNewUser = result['is_new_user'] as bool? ?? false;
    _status = AuthStatus.authenticated;
    notifyListeners();
  }

  // ─── Atualizar perfil ──────────────────────────────────────────────────

  Future<void> updateProfile({String? nome, String? telefone}) async {
    final api = ApiClient();
    final updatedUser = await api.updateProfile(nome: nome, telefone: telefone);
    _user = updatedUser;
    await AuthService.instance.updateCachedUser(updatedUser);
    notifyListeners();
  }

  // ─── Biometria ─────────────────────────────────────────────────────────────

  final _localAuth = LocalAuthentication();

  Future<bool> isBiometricsAvailable() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();
      return canCheck && isSupported;
    } catch (_) {
      return false;
    }
  }

  Future<bool> isBiometricsEnabled() =>
      AuthService.instance.isBiometricsEnabled();

  Future<bool> wasBiometricsPrompted() =>
      AuthService.instance.wasBiometricsPrompted();

  Future<void> markBiometricsPrompted() =>
      AuthService.instance.markBiometricsPrompted();

  Future<void> setBiometricsEnabled(bool enabled) async {
    await AuthService.instance.setBiometricsEnabled(enabled);
    notifyListeners();
  }

  Future<void> loginWithBiometrics() async {
    final authenticated = await _localAuth.authenticate(
      localizedReason: 'Use sua biometria para entrar',
      options: const AuthenticationOptions(
        stickyAuth: true,
        biometricOnly: true,
      ),
    );
    if (!authenticated) throw Exception('Autenticação biométrica cancelada');

    // Reutiliza o token salvo no secure storage
    final auth = AuthService.instance;
    if (!auth.isLoggedIn) throw Exception('Nenhuma sessão salva');

    final valid = await auth.validateToken();
    if (!valid) throw Exception('Sessão expirada. Faça login novamente.');

    _user = auth.cachedUser;
    _status = AuthStatus.authenticated;
    notifyListeners();
  }

  // ─── Logout ───────────────────────────────────────────────────────────────

  Future<void> logout() async {
    await AuthService.instance.clear();
    _user = null;
    _isNewUser = false;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }
}
