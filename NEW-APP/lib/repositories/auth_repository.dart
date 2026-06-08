import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import '../core/secure_storage.dart';
import 'settings_repository.dart';

class AuthRepository {
  final SecureStorage _secureStorage = SecureStorage();
  final SettingsRepository _settingsRepo = SettingsRepository();

  Future<bool> checkCurrentUser() async {
    final profile = await _settingsRepo.getUserProfile();
    return profile['name'] != null && profile['name']!.isNotEmpty;
  }

  Future<bool> signIn() async {
    // Normal signIn is skipped since welcome screen onboarding handles names
    return false;
  }

  Future<bool> signInWithLocalName(String name) async {
    await _settingsRepo.saveUserProfile(
      email: 'local@novastudy.app',
      name: name,
      photoUrl: null,
    );
    return true;
  }

  Future<void> signOut() async {
    await _settingsRepo.clearUserSession();
  }

  Future<Map<String, String?>> getLocalProfile() async {
    return await _settingsRepo.getUserProfile();
  }

  Future<dynamic> getSignedInAccount() async {
    return null;
  }

  Future<http.Client?> getAuthenticatedClient() async {
    return null;
  }
}
