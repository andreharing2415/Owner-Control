import "dart:convert";
import "package:flutter/foundation.dart";
import "package:shared_preferences/shared_preferences.dart";

import "../models/auth.dart";
import "../services/api_client.dart";

class AuthProvider extends ChangeNotifier {
  AuthProvider({required this.api});

  final ApiClient api;
  User? _user;
  bool _loading = true;

  User? get user => _user;
  bool get isAuthenticated => _user != null;
  bool get loading => _loading;

  static const _tokenKey = "auth_tokens";

  Future<void> init() async {
    _loading = true;
    notifyListeners();
    try {
      final tokens = await _loadTokens();
      if (tokens != null) {
        api.setTokens(access: tokens["access"]!, refresh: tokens["refresh"]!);
        _user = await api.getMe();
      }
    } catch (_) {
      api.clearTokens();
      await _clearTokens();
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> login({required String email, required String password}) async {
    final tokens = await api.login(email: email, password: password);
    await _saveTokens(tokens.accessToken, tokens.refreshToken);
    _user = await api.getMe();
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
    await _saveTokens(tokens.accessToken, tokens.refreshToken);
    _user = await api.getMe();
    notifyListeners();
  }

  Future<void> logout() async {
    api.clearTokens();
    _user = null;
    await _clearTokens();
    notifyListeners();
  }

  Future<void> _saveTokens(String access, String refresh) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _tokenKey, jsonEncode({"access": access, "refresh": refresh}));
  }

  Future<Map<String, String>?> _loadTokens() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_tokenKey);
      if (raw == null) return null;
      final data = jsonDecode(raw) as Map<String, dynamic>;
      return {
        "access": data["access"] as String,
        "refresh": data["refresh"] as String,
      };
    } catch (_) {
      return null;
    }
  }

  Future<void> _clearTokens() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
    } catch (_) {}
  }
}
