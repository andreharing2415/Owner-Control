import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../api/api.dart';

/// Singleton que gerencia tokens JWT e credenciais do usuário.
///
/// Uso:
/// ```dart
/// await AuthService.instance.initialize();
/// if (AuthService.instance.isLoggedIn) { ... }
/// ```
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  static const _keyAccessToken = 'access_token';
  static const _keyRefreshToken = 'refresh_token';
  static const _keyUserJson = 'user_json';

  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  String? _accessToken;
  String? _refreshToken;
  Map<String, dynamic>? _userJson;

  // ─── Getters ─────────────────────────────────────────────────────────────

  String? get accessToken => _accessToken;
  bool get isLoggedIn => _accessToken != null;
  Map<String, dynamic>? get cachedUser => _userJson;

  // ─── Inicializar (chamar no app start) ────────────────────────────────────

  Future<void> initialize() async {
    _accessToken = await _storage.read(key: _keyAccessToken);
    _refreshToken = await _storage.read(key: _keyRefreshToken);
    final userStr = await _storage.read(key: _keyUserJson);
    if (userStr != null) {
      try {
        _userJson = jsonDecode(userStr) as Map<String, dynamic>;
      } catch (_) {
        _userJson = null;
      }
    }
  }

  // ─── Salvar tokens após login/register ────────────────────────────────────

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
    required Map<String, dynamic> user,
  }) async {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
    _userJson = user;
    await _storage.write(key: _keyAccessToken, value: accessToken);
    await _storage.write(key: _keyRefreshToken, value: refreshToken);
    await _storage.write(key: _keyUserJson, value: jsonEncode(user));
  }

  // ─── Limpar (logout) ─────────────────────────────────────────────────────

  Future<void> clear() async {
    _accessToken = null;
    _refreshToken = null;
    _userJson = null;
    await _storage.deleteAll();
  }

  // ─── Refresh token ────────────────────────────────────────────────────────

  Future<bool> refreshAccessToken() async {
    if (_refreshToken == null) return false;
    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/api/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh_token': _refreshToken}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        await saveTokens(
          accessToken: data['access_token'] as String,
          refreshToken: data['refresh_token'] as String,
          user: data['user'] as Map<String, dynamic>,
        );
        return true;
      }
    } catch (e) {
      debugPrint('[AuthService] refresh failed: $e');
    }
    return false;
  }

  // ─── Validar token salvo (via /me) ────────────────────────────────────────

  Future<bool> validateToken() async {
    if (_accessToken == null) return false;
    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/api/auth/me'),
        headers: {'Authorization': 'Bearer $_accessToken'},
      );
      if (response.statusCode == 200) {
        _userJson = jsonDecode(response.body) as Map<String, dynamic>;
        return true;
      }
      if (response.statusCode == 401) {
        return await refreshAccessToken();
      }
    } catch (e) {
      debugPrint('[AuthService] validate failed: $e');
    }
    return false;
  }
}
