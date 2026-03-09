import "package:flutter/foundation.dart";
import "package:google_sign_in/google_sign_in.dart";
import "package:local_auth/local_auth.dart";

import "../models/auth.dart";
import "../services/api_client.dart";
import "../services/revenuecat_service.dart";
import "../services/secure_storage.dart";

class AuthProvider extends ChangeNotifier {
  AuthProvider({required this.api});

  final ApiClient api;
  User? _user;
  bool _loading = true;

  User? get user => _user;
  bool get isAuthenticated => _user != null;
  bool get loading => _loading;

  final _googleSignIn = GoogleSignIn(
    scopes: ["email", "profile"],
    serverClientId: const String.fromEnvironment(
      "GOOGLE_CLIENT_ID",
      defaultValue: "530484413221-ce3hk4ahk234gq35s8tll80u8v9pbde8.apps.googleusercontent.com",
    ),
  );
  final _localAuth = LocalAuthentication();

  // ─── Init ──────────────────────────────────────────────────────────────────

  Future<void> init() async {
    _loading = true;
    notifyListeners();
    try {
      final tokens = await SecureStorage.loadTokens();
      if (tokens != null) {
        api.setTokens(access: tokens.access, refresh: tokens.refresh);
        _user = await api.getMe();
        await RevenueCatService.init(_user!.id);
      }
    } catch (_) {
      api.clearTokens();
      await SecureStorage.clearTokens();
    }
    _loading = false;
    notifyListeners();
  }

  // ─── Email / Senha ─────────────────────────────────────────────────────────

  Future<void> login({required String email, required String password}) async {
    final tokens = await api.login(email: email, password: password);
    await SecureStorage.saveTokens(tokens.accessToken, tokens.refreshToken);
    api.setTokens(access: tokens.accessToken, refresh: tokens.refreshToken);
    _user = await api.getMe();
    await RevenueCatService.init(_user!.id);
    notifyListeners();
  }

  Future<void> register({
    required String email,
    required String password,
    required String nome,
    String? telefone,
  }) async {
    final tokens = await api.register(
      email: email,
      password: password,
      nome: nome,
      telefone: telefone,
    );
    await SecureStorage.saveTokens(tokens.accessToken, tokens.refreshToken);
    api.setTokens(access: tokens.accessToken, refresh: tokens.refreshToken);
    _user = await api.getMe();
    await RevenueCatService.init(_user!.id);
    notifyListeners();
  }

  // ─── Google ────────────────────────────────────────────────────────────────

  /// Retorna `true` se for usuário novo (precisa completar perfil).
  Future<bool> loginWithGoogle() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) throw Exception("Login cancelado");

    final auth = await googleUser.authentication;
    final idToken = auth.idToken;
    if (idToken == null) throw Exception("Não foi possível obter token Google");

    final result = await api.loginWithGoogle(idToken);
    await SecureStorage.saveTokens(result.accessToken, result.refreshToken);
    api.setTokens(access: result.accessToken, refresh: result.refreshToken);
    _user = result.user;
    await RevenueCatService.init(_user!.id);
    notifyListeners();
    return result.isNewUser;
  }

  Future<void> updateProfile({String? nome, String? telefone}) async {
    _user = await api.updateProfile(nome: nome, telefone: telefone);
    notifyListeners();
  }

  // ─── Biometria ─────────────────────────────────────────────────────────────

  Future<bool> isBiometricsAvailable() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();
      return canCheck && isSupported;
    } catch (_) {
      return false;
    }
  }

  Future<bool> isBiometricsEnabled() => SecureStorage.isBiometricsEnabled();
  Future<bool> wasBiometricsPrompted() => SecureStorage.wasBiometricsPrompted();
  Future<void> markBiometricsPrompted() => SecureStorage.markBiometricsPrompted();

  Future<void> setBiometricsEnabled(bool enabled) async {
    await SecureStorage.setBiometricsEnabled(enabled);
    notifyListeners();
  }

  Future<void> loginWithBiometrics() async {
    final authenticated = await _localAuth.authenticate(
      localizedReason: "Use sua biometria para entrar no Mestre da Obra",
      options: const AuthenticationOptions(
        stickyAuth: true,
        biometricOnly: true,
      ),
    );
    if (!authenticated) throw Exception("Autenticação biométrica cancelada");

    final tokens = await SecureStorage.loadTokens();
    if (tokens == null) throw Exception("Nenhuma sessão salva");

    api.setTokens(access: tokens.access, refresh: tokens.refresh);
    _user = await api.getMe();
    await RevenueCatService.init(_user!.id);
    notifyListeners();
  }

  // ─── Logout ────────────────────────────────────────────────────────────────

  Future<void> logout() async {
    await RevenueCatService.logout();
    api.clearTokens();
    _user = null;
    await SecureStorage.clearTokens();
    await _googleSignIn.signOut().catchError((_) => null);
    notifyListeners();
  }
}
