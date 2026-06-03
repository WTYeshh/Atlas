import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:googleapis/drive/v3.dart' as google_drive;
import 'package:path/path.dart' as p;
import 'database_repository.dart';
import 'auth_repository.dart';
import 'settings_repository.dart';
import '../models/note_model.dart';

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

  // Upload file to organized directories in Google Drive: Atlas -> [Subject/Category] -> File
  Future<String?> uploadNoteFile(NoteModel note) async {
    final syncEnabled = await _settingsRepo.getExternalSyncEnabled();
    if (!syncEnabled) {
      print('DriveRepository: External sync is disabled. Skipping Google Drive upload.');
      return null;
    }
    if (kIsWeb) {
      print('DriveRepository: File upload not supported on Web preview.');
      return null;
    }
    if (note.filePath == null) return null;
    final file = File(note.filePath!);
    if (!await file.exists()) return null;

    final api = await _getDriveApi();
    if (api == null) {
      print('Google Drive API not authenticated or offline. Skipping cloud upload.');
      return null;
    }

    try {
      // 1. Get or create root "Atlas" folder
      final rootFolderId = await _getOrCreateFolder(api, 'Atlas');
      if (rootFolderId == null) return null;

      // 2. Get or create category/subject subfolder (default to "General Notes")
      final subfolderName = note.subject ?? note.category ?? 'General Notes';
      final subfolderId = await _getOrCreateFolder(api, subfolderName, parentId: rootFolderId);
      if (subfolderId == null) return null;

      // 3. Prepare file metadata
      final fileName = p.basename(note.filePath!);
      final driveFile = google_drive.File()
        ..name = fileName
        ..parents = [subfolderId];

      // MimeType detection
      String mimeType = 'application/octet-stream';
      if (note.type == 'pdf') {
        mimeType = 'application/pdf';
      } else if (note.type == 'image') {
        mimeType = 'image/jpeg';
      } else if (fileName.endsWith('.docx')) {
        mimeType = 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      } else if (fileName.endsWith('.ppt') || fileName.endsWith('.pptx')) {
        mimeType = 'application/vnd.ms-powerpoint';
      }

      final media = google_drive.Media(file.openRead(), await file.length());

      google_drive.File uploadedFile;
      if (note.driveFileId != null) {
        // Update existing file in Drive
        uploadedFile = await api.files.update(
          google_drive.File()..name = fileName,
          note.driveFileId!,
          uploadMedia: media,
        );
        print('Updated file on Google Drive: ${uploadedFile.id}');
      } else {
        // Insert new file
        uploadedFile = await api.files.create(
          driveFile,
          uploadMedia: media,
        );
        print('Uploaded new file to Google Drive: ${uploadedFile.id}');

        // Update local note record with Drive ID
        final updatedNote = note.copyWith(driveFileId: uploadedFile.id);
        await _dbRepo.updateNote(updatedNote);
      }

      return uploadedFile.id;
    } catch (e) {
      print('Error uploading note file to Google Drive: $e');
      return null;
    }
  }

  // Upload text note content as Google Doc or Text file
  Future<String?> uploadTextNote(NoteModel note) async {
    final syncEnabled = await _settingsRepo.getExternalSyncEnabled();
    if (!syncEnabled) {
      print('DriveRepository: External sync is disabled. Skipping Google Drive upload.');
      return null;
    }
    if (kIsWeb) {
      print('DriveRepository: Text note upload not supported on Web preview.');
      return null;
    }
    if (note.content == null || note.content!.isEmpty) return null;

    final api = await _getDriveApi();
    if (api == null) return null;

    try {
      final rootFolderId = await _getOrCreateFolder(api, 'Atlas');
      if (rootFolderId == null) return null;

      final subfolderName = note.subject ?? note.category ?? 'General Notes';
      final subfolderId = await _getOrCreateFolder(api, subfolderName, parentId: rootFolderId);
      if (subfolderId == null) return null;

      final driveFile = google_drive.File()
        ..name = '${note.title}.txt'
        ..parents = [subfolderId]
        ..mimeType = 'text/plain';

      // Create stream from string content
      final contentBytes = Uri.encodeComponent(note.content!).codeUnits;
      final stream = Stream<List<int>>.value(contentBytes);
      final media = google_drive.Media(stream, contentBytes.length);

      google_drive.File uploadedFile;
      if (note.driveFileId != null) {
        uploadedFile = await api.files.update(
          google_drive.File()..name = '${note.title}.txt',
          note.driveFileId!,
          uploadMedia: media,
        );
      } else {
        uploadedFile = await api.files.create(
          driveFile,
          uploadMedia: media,
        );

        final updatedNote = note.copyWith(driveFileId: uploadedFile.id);
        await _dbRepo.updateNote(updatedNote);
      }

      return uploadedFile.id;
    } catch (e) {
      print('Error uploading text note to Google Drive: $e');
      return null;
    }
  }
}
