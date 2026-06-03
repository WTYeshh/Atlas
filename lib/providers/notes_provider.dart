import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/note_model.dart';
import '../repositories/database_repository.dart';
import '../repositories/drive_repository.dart';
import '../services/gemini_service.dart';
import 'auth_provider.dart';

final databaseRepositoryProvider = Provider<DatabaseRepository>((ref) {
  return DatabaseRepository();
});

final driveRepositoryProvider = Provider<DriveRepository>((ref) {
  final dbRepo = ref.watch(databaseRepositoryProvider);
  final authRepo = ref.watch(authRepositoryProvider);
  return DriveRepository(dbRepo, authRepo);
});

final notesProvider = StateNotifierProvider<NotesNotifier, List<NoteModel>>((ref) {
  final dbRepo = ref.watch(databaseRepositoryProvider);
  final driveRepo = ref.watch(driveRepositoryProvider);
  return NotesNotifier(dbRepo, driveRepo);
});

class NotesNotifier extends StateNotifier<List<NoteModel>> {
  final DatabaseRepository _dbRepo;
  final DriveRepository _driveRepo;
  final GeminiService _geminiService = GeminiService();

  NotesNotifier(this._dbRepo, this._driveRepo) : super([]) {
    loadNotes();
  }

  Future<void> loadNotes() async {
    final list = await _dbRepo.getNotes();
    state = list;
  }

  Future<void> addNote(NoteModel note) async {
    await _dbRepo.insertNote(note);
    await loadNotes();

    // Trigger Google Drive sync in the background
    _syncNoteToDrive(note);
  }

  Future<void> updateNote(NoteModel note) async {
    await _dbRepo.updateNote(note);
    await loadNotes();

    // Trigger Google Drive update in the background
    _syncNoteToDrive(note);
  }

  Future<void> deleteNote(String id) async {
    await _dbRepo.deleteNote(id);
    await loadNotes();
  }

  // Generate summary for a note using Gemini
  Future<void> summarizeNote(String id) async {
    final noteIndex = state.indexWhere((n) => n.id == id);
    if (noteIndex == -1) return;

    final note = state[noteIndex];
    if (note.content == null || note.content!.isEmpty) return;

    final summary = await _geminiService.generateSummary(note.content!);
    if (summary != null) {
      final updatedNote = note.copyWith(summary: summary);
      await updateNote(updatedNote);
    }
  }

  // Helper background task to sync to Drive
  Future<void> _syncNoteToDrive(NoteModel note) async {
    try {
      if (note.type == 'text' && note.content != null) {
        await _driveRepo.uploadTextNote(note);
      } else if (note.filePath != null) {
        await _driveRepo.uploadNoteFile(note);
      }
      // Reload notes to capture any updated driveFileId
      await loadNotes();
    } catch (e) {
      print('Notes sync failed in background: $e');
    }
  }
}
