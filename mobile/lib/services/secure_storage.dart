import "package:flutter_secure_storage/flutter_secure_storage.dart";

/// Centraliza o armazenamento seguro de tokens e preferências de auth.
class SecureStorage {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const _accessKey = "auth_access_token";
  static const _refreshKey = "auth_refresh_token";
  static const _biometricsEnabledKey = "biometrics_enabled";
  static const _biometricsPromptedKey = "biometrics_prompted";

  static Future<void> saveTokens(String access, String refresh) async {
    await _storage.write(key: _accessKey, value: access);
    await _storage.write(key: _refreshKey, value: refresh);
  }

  static Future<({String access, String refresh})?> loadTokens() async {
    final access = await _storage.read(key: _accessKey);
    final refresh = await _storage.read(key: _refreshKey);
    if (access == null || refresh == null) return null;
    return (access: access, refresh: refresh);
  }

  static Future<void> clearTokens() async {
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
  }

  static Future<bool> isBiometricsEnabled() async {
    return await _storage.read(key: _biometricsEnabledKey) == "true";
  }

  static Future<void> setBiometricsEnabled(bool enabled) async {
    await _storage.write(key: _biometricsEnabledKey, value: enabled.toString());
  }

  static Future<bool> wasBiometricsPrompted() async {
    return await _storage.read(key: _biometricsPromptedKey) == "true";
  }

  static Future<void> markBiometricsPrompted() async {
    await _storage.write(key: _biometricsPromptedKey, value: "true");
  }

  static Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
