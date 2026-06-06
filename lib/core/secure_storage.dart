import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage {
  static final SecureStorage _instance = SecureStorage._internal();
  // Note: encryptedSharedPreferences=false avoids AEADBadTagException on
  // Android after reinstalls / keystore resets. Standard mode still uses
  // the Android Keystore and is secure enough for this use-case.
  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: false,
      resetOnError: true,
    ),
  );

  factory SecureStorage() => _instance;

  SecureStorage._internal();

  // Keys
  static const String _geminiApiKey = 'gemini_api_key';
  static const String _googleClientId = 'google_client_id';
  static const String _themeMode = 'theme_mode';
  static const String _googleAuthToken = 'google_auth_token';
  static const String _userEmail = 'user_email';
  static const String _userName = 'user_name';
  static const String _userPhotoUrl = 'user_photo_url';
  static const String _updateCheckUrl = 'update_check_url';

  // Gemini API Key
  Future<void> saveGeminiApiKey(String key) async {
    await _storage.write(key: _geminiApiKey, value: key);
  }

  Future<String?> getGeminiApiKey() async {
    return await _storage.read(key: _geminiApiKey);
  }

  Future<void> deleteGeminiApiKey() async {
    await _storage.delete(key: _geminiApiKey);
  }

  // Google Sign-In Client ID (Web/Custom)
  Future<void> saveGoogleClientId(String clientId) async {
    await _storage.write(key: _googleClientId, value: clientId);
  }

  Future<String?> getGoogleClientId() async {
    return await _storage.read(key: _googleClientId);
  }

  Future<void> deleteGoogleClientId() async {
    await _storage.delete(key: _googleClientId);
  }

  // Update Check URL
  Future<void> saveUpdateCheckUrl(String url) async {
    await _storage.write(key: _updateCheckUrl, value: url);
  }

  Future<String?> getUpdateCheckUrl() async {
    return await _storage.read(key: _updateCheckUrl);
  }

  Future<void> deleteUpdateCheckUrl() async {
    await _storage.delete(key: _updateCheckUrl);
  }

  // Theme Mode (light, dark, system)
  Future<void> saveThemeMode(String mode) async {
    await _storage.write(key: _themeMode, value: mode);
  }

  Future<String> getThemeMode() async {
    return await _storage.read(key: _themeMode) ?? 'light';
  }

  // Google Sign-In Credentials
  Future<void> saveGoogleAuthToken(String token) async {
    await _storage.write(key: _googleAuthToken, value: token);
  }

  Future<String?> getGoogleAuthToken() async {
    return await _storage.read(key: _googleAuthToken);
  }

  Future<void> deleteGoogleAuthToken() async {
    await _storage.delete(key: _googleAuthToken);
  }

  // User Profile Data
  Future<void> saveUserProfile({required String email, required String name, String? photoUrl}) async {
    await _storage.write(key: _userEmail, value: email);
    await _storage.write(key: _userName, value: name);
    if (photoUrl != null) {
      await _storage.write(key: _userPhotoUrl, value: photoUrl);
    }
  }

  Future<Map<String, String?>> getUserProfile() async {
    final email = await _storage.read(key: _userEmail);
    final name = await _storage.read(key: _userName);
    final photoUrl = await _storage.read(key: _userPhotoUrl);
    return {
      'email': email,
      'name': name,
      'photoUrl': photoUrl,
    };
  }

  Future<void> clearUserSession() async {
    await _storage.delete(key: _googleAuthToken);
    await _storage.delete(key: _userEmail);
    await _storage.delete(key: _userName);
    await _storage.delete(key: _userPhotoUrl);
  }

  Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
