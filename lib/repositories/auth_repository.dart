import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:http/http.dart' as http;
import '../core/secure_storage.dart';
import 'settings_repository.dart';

class AuthRepository {
  static const String defaultWebClientId =
      '600003966208-dvpdiavl8qh5lr5igh7dstggc2q5i966.apps.googleusercontent.com';

  final SecureStorage _secureStorage = SecureStorage();
  final SettingsRepository _settingsRepo = SettingsRepository();
  GoogleSignIn? _googleSignInInstance;
  String? _loadedClientId;

  Future<GoogleSignIn> getGoogleSignIn() async {
    final customClientId = await _settingsRepo.getGoogleClientId();
    final activeClientId = (customClientId != null && customClientId.trim().isNotEmpty)
        ? customClientId.trim()
        : defaultWebClientId;

    if (_googleSignInInstance == null || _loadedClientId != activeClientId) {
      _loadedClientId = activeClientId;
      _googleSignInInstance = GoogleSignIn(
        clientId: kIsWeb ? activeClientId : null,
        serverClientId: activeClientId,
        scopes: [
          'email',
          'https://www.googleapis.com/auth/calendar',
          'https://www.googleapis.com/auth/drive.file',
        ],
      );
    }
    return _googleSignInInstance!;
  }
  GoogleSignInAccount? _currentUser;

  GoogleSignInAccount? get currentUser => _currentUser;

  Future<bool> checkCurrentUser() async {
    // On web, signInSilently can hang or fail in local dev — skip it
    // and rely on locally-stored profile/token instead.
    if (kIsWeb) {
      final profile = await _settingsRepo.getUserProfile();
      return profile['email'] != null;
    }

    try {
      final googleSignIn = await getGoogleSignIn();
      _currentUser = await googleSignIn.signInSilently();
      if (_currentUser != null) {
        final auth = await _currentUser!.authentication;
        if (auth.accessToken != null) {
          await _secureStorage.saveGoogleAuthToken(auth.accessToken!);
          await _settingsRepo.saveUserProfile(
            email: _currentUser!.email,
            name: _currentUser!.displayName ?? '',
            photoUrl: _currentUser!.photoUrl,
          );
          return true;
        }
      }
    } catch (e) {
      print('Google silent sign in error: $e');
    }
    return false;
  }

  Future<bool> signIn() async {
    try {
      final googleSignIn = await getGoogleSignIn();
      _currentUser = await googleSignIn.signIn();
      if (_currentUser != null) {
        // Try to save access token (may fail on web if People API disabled)
        try {
          final auth = await _currentUser!.authentication;
          if (auth.accessToken != null) {
            await _secureStorage.saveGoogleAuthToken(auth.accessToken!);
          }
        } catch (_) {}
        await _settingsRepo.saveUserProfile(
          email: _currentUser!.email,
          name: _currentUser!.displayName ?? _currentUser!.email.split('@')[0],
          photoUrl: _currentUser!.photoUrl,
        );
        return true;
      }
    } catch (e) {
      print('Google sign in error: $e');
      // On web the People API may return 403 even though OAuth succeeded.
      // The FedCM credential populates googleSignIn.currentUser — use it.
      if (kIsWeb) {
        final googleSignIn = await getGoogleSignIn();
        final fallbackUser = googleSignIn.currentUser;
        if (fallbackUser != null) {
          _currentUser = fallbackUser;
          await _settingsRepo.saveUserProfile(
            email: fallbackUser.email,
            name: fallbackUser.displayName ?? fallbackUser.email.split('@')[0],
            photoUrl: fallbackUser.photoUrl,
          );
          return true;
        }
      }
    }
    return false;
  }

  Future<void> signOut() async {
    try {
      final googleSignIn = await getGoogleSignIn();
      await googleSignIn.disconnect();
    } catch (_) {}
    try {
      final googleSignIn = await getGoogleSignIn();
      await googleSignIn.signOut();
    } catch (_) {}
    _currentUser = null;
    await _settingsRepo.clearUserSession();
  }

  Future<Map<String, String?>> getLocalProfile() async {
    return await _settingsRepo.getUserProfile();
  }

  Future<GoogleSignInAccount?> getSignedInAccount() async {
    if (_currentUser != null) return _currentUser;
    final googleSignIn = await getGoogleSignIn();
    _currentUser = googleSignIn.currentUser ?? await googleSignIn.signInSilently();
    return _currentUser;
  }

  Future<http.Client?> getAuthenticatedClient() async {
    final account = await getSignedInAccount();
    if (account == null) return null;
    final googleSignIn = await getGoogleSignIn();
    return await googleSignIn.authenticatedClient();
  }
}
