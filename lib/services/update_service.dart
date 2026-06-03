import 'dart:convert';
import 'package:http/http.dart' as http;
import '../repositories/settings_repository.dart';

class UpdateInfo {
  final String version;
  final int buildNumber;
  final String releaseNotes;
  final String downloadUrl;

  UpdateInfo({
    required this.version,
    required this.buildNumber,
    required this.releaseNotes,
    required this.downloadUrl,
  });
}

class UpdateService {
  static const String currentVersion = '1.0.3';
  static const int currentBuildNumber = 4;
  static const String defaultUpdateCheckUrl = 'https://raw.githubusercontent.com/WTYeshh/Atlas/main/version.json';

  final SettingsRepository _settingsRepo = SettingsRepository();

  Future<UpdateInfo?> checkForUpdates() async {
    try {
      final configuredUrl = await _settingsRepo.getUpdateCheckUrl();
      final url = (configuredUrl == null || configuredUrl.trim().isEmpty) 
          ? defaultUpdateCheckUrl 
          : configuredUrl.trim();

      final uri = Uri.tryParse(url);
      if (uri == null) {
        print('Update check failed: Invalid URL: $url');
        return null;
      }

      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        print('Update check failed: HTTP Status ${response.statusCode}');
        return null;
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final remoteVer = data['version'] as String? ?? '1.0.0';
      final remoteBuild = data['build_number'] as int? ?? 1;
      final releaseNotes = data['release_notes'] as String? ?? 'No details provided.';
      final downloadUrl = data['download_url'] as String? ?? '';

      if (isUpdateAvailable(remoteVer, remoteBuild)) {
        return UpdateInfo(
          version: remoteVer,
          buildNumber: remoteBuild,
          releaseNotes: releaseNotes,
          downloadUrl: downloadUrl,
        );
      }
    } catch (e) {
      print('Error checking for updates: $e');
    }
    return null;
  }

  bool isUpdateAvailable(String remoteVer, int remoteBuild) {
    if (remoteBuild > currentBuildNumber) return true;

    // Check version strings as fallback
    final currentParts = currentVersion.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final remoteParts = remoteVer.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    final maxLength = currentParts.length > remoteParts.length ? currentParts.length : remoteParts.length;
    for (int i = 0; i < maxLength; i++) {
      final currentVal = i < currentParts.length ? currentParts[i] : 0;
      final remoteVal = i < remoteParts.length ? remoteParts[i] : 0;

      if (remoteVal > currentVal) return true;
      if (remoteVal < currentVal) return false;
    }

    return false;
  }
}
