import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:googleapis/drive/v3.dart' as google_drive;
import 'package:path/path.dart' as p;
import 'database_repository.dart';
import 'auth_repository.dart';
import 'settings_repository.dart';

class DriveRepository {
  final DatabaseRepository _dbRepo;
  final AuthRepository _authRepo;
  final SettingsRepository _settingsRepo = SettingsRepository();

  DriveRepository(this._dbRepo, this._authRepo);

  Future<google_drive.DriveApi?> _getDriveApi() async {
    try {
      final client = await _authRepo.getAuthenticatedClient();
      if (client == null) return null;

      return google_drive.DriveApi(client);
    } catch (e) {
      print('Failed to authenticate Google Drive Client: $e');
      return null;
    }
  }

  // Find or create a folder in Google Drive
  Future<String?> _getOrCreateFolder(google_drive.DriveApi api, String folderName, {String? parentId}) async {
    try {
      String query = "name = '$folderName' and mimeType = 'application/vnd.google-apps.folder' and trashed = false";
      if (parentId != null) {
        query += " and '$parentId' in parents";
      }

      final list = await api.files.list(q: query, spaces: 'drive');
      if (list.files != null && list.files!.isNotEmpty) {
        return list.files!.first.id;
      }

      // If folder doesn't exist, create it
      final folder = google_drive.File()
        ..name = folderName
        ..mimeType = 'application/vnd.google-apps.folder';
      
      if (parentId != null) {
        folder.parents = [parentId];
      }

      final createdFolder = await api.files.create(folder);
      return createdFolder.id;
    } catch (e) {
      print('Error getting/creating folder $folderName: $e');
      return null;
    }
  }
}
