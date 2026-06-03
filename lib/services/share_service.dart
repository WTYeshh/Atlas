import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:uuid/uuid.dart';
import 'gemini_service.dart';
import 'ocr_service.dart';
import 'notification_service.dart';
import '../repositories/database_repository.dart';
import '../repositories/calendar_repository.dart';
import '../repositories/drive_repository.dart';
import '../models/event_model.dart';
import '../models/task_model.dart';
import '../models/note_model.dart';

class ShareService {
  final DatabaseRepository _dbRepo;
  final CalendarRepository _calendarRepo;
  final DriveRepository _driveRepo;
  final GeminiService _geminiService = GeminiService();
  final OcrService _ocrService = OcrService();
  final NotificationService _notificationService = NotificationService();
  
  StreamSubscription? _intentDataStreamSubscription;
  
  ShareService(this._dbRepo, this._calendarRepo, this._driveRepo);

  void init() {
    if (kIsWeb) {
      print('ShareService: Sharing intent listener is not supported on Web.');
      return;
    }
    // Listen to media sharing when app is in memory
    _intentDataStreamSubscription = ReceiveSharingIntent.instance.getMediaStream().listen(
      (List<SharedMediaFile> value) {
        _processSharedFiles(value);
      },
      onError: (err) {
        print("getIntentDataStream error: $err");
      },
    );

    // Listen to media sharing when app is cold started
    ReceiveSharingIntent.instance.getInitialMedia().then((List<SharedMediaFile> value) {
      if (value.isNotEmpty) {
        _processSharedFiles(value);
        ReceiveSharingIntent.instance.reset();
      }
    });
  }

  void dispose() {
    if (kIsWeb) return;
    _intentDataStreamSubscription?.cancel();
    _ocrService.dispose();
  }

  // Process shared text or files (PDFs, Images, Docs)
  Future<void> _processSharedFiles(List<SharedMediaFile> files) async {
    for (var file in files) {
      final path = file.path;
      final type = file.type;

      if (type == SharedMediaType.text) {
        // Text sharing (e.g., from WhatsApp or Telegram)
        await _processText(path);
      } else if (type == SharedMediaType.image) {
        // Image / screenshot sharing (trigger OCR)
        await _processImageFile(path);
      } else if (type == SharedMediaType.file) {
        // Document sharing (PDF, docx, etc.)
        await _processDocumentFile(path);
      }
    }
  }

  // Step 1: Text processing and smart classification
  Future<void> _processText(String text) async {
    print('Processing shared text: "$text"');
    
    // Classify using Gemini
    final extracted = await _geminiService.classifyAndExtractContent(text);
    if (extracted == null) {
      print('Failed to parse content with Gemini. Saving as generic note.');
      await _saveAsGenericNote(text, 'Shared Snippet');
      return;
    }

    await _saveExtractedContent(extracted, originalText: text);
  }

  // Step 1: Extract text from image using OCR first, then process
  Future<void> _processImageFile(String path) async {
    print('Processing shared image: $path');
    
    // Extract text via OCR
    final extractedText = await _ocrService.extractTextFromImage(path);
    if (extractedText == null || extractedText.trim().isEmpty) {
      print('OCR could not read text. Saving image file directly to Notes Vault.');
      await _saveFileNote(path, 'image');
      return;
    }

    print('OCR Extracted Text: $extractedText');

    // Run extracted text through Gemini for classification
    final extracted = await _geminiService.classifyAndExtractContent(extractedText);
    if (extracted == null) {
      print('Gemini classification failed. Saving OCR text as note.');
      await _saveAsGenericNote(extractedText, 'OCR Extracted Image Text', filePath: path, type: 'image');
      return;
    }

    await _saveExtractedContent(extracted, originalText: extractedText, filePath: path, fileType: 'image');
  }

  // Process documents (PDFs, PPTs, DOCs)
  Future<void> _processDocumentFile(String path) async {
    print('Processing shared document: $path');
    final separator = kIsWeb ? '/' : Platform.pathSeparator;
    final fileName = path.split(separator).last;
    
    // Save file as note
    await _saveFileNote(path, 'pdf'); // Defaulting file notes to pdf/doc structure
  }

  // Step 3: Save structures in Database and sync, sending local alerts
  Future<void> _saveExtractedContent(Map<String, dynamic> data, {
    required String originalText,
    String? filePath,
    String? fileType,
  }) async {
    final type = data['type'] as String? ?? 'general';
    final title = data['title'] as String? ?? 'Untitled Shared Content';
    final dateStr = data['date'] as String?;
    final timeStr = data['time'] as String? ?? '09:00';
    final dueDateStr = data['dueDate'] as String?;
    final priority = data['priority'] as String? ?? 'medium';
    final subject = data['subject'] as String?;
    final category = data['category'] as String?;
    final summary = data['summary'] as String?;
    final formattedContent = data['content'] as String? ?? originalText;
    final List<String> tags = List<String>.from(data['tags'] ?? []);

    final id = const Uuid().v4();
    final now = DateTime.now().toIso8601String();

    if (type == 'event' && dateStr != null) {
      // Save Event
      final event = EventModel(
        id: id,
        title: title,
        date: dateStr,
        time: timeStr,
        description: formattedContent,
        category: category ?? 'Academic',
        updatedAt: now,
      );
      await _calendarRepo.createEvent(event);
      await _notificationService.showNotification(
        id: event.hashCode,
        title: 'Calendar Event Created',
        body: 'Saved "$title" for $dateStr at $timeStr',
      );
    } else if (type == 'task' && dueDateStr != null) {
      // Save Task
      final task = TaskModel(
        id: id,
        title: title,
        dueDate: dueDateStr,
        priority: priority,
        subject: subject,
        status: 'pending',
        updatedAt: now,
      );
      await _dbRepo.insertTask(task);
      await _notificationService.showNotification(
        id: task.hashCode,
        title: 'New Assignment Added',
        body: 'Task "$title" due on $dueDateStr',
      );
    } else {
      // Save Note
      final note = NoteModel(
        id: id,
        title: title,
        content: formattedContent,
        type: fileType ?? 'text',
        subject: subject,
        category: category ?? 'General',
        summary: summary,
        filePath: filePath,
        updatedAt: now,
        tags: tags,
      );
      await _dbRepo.insertNote(note);

      // Trigger Drive sync in background
      if (filePath != null) {
        _driveRepo.uploadNoteFile(note);
      } else {
        _driveRepo.uploadTextNote(note);
      }

      await _notificationService.showNotification(
        id: note.hashCode,
        title: 'Notes Vault Updated',
        body: 'Added note "$title" under ${subject ?? category ?? 'General'}',
      );
    }
  }

  Future<void> _saveAsGenericNote(String text, String defaultTitle, {String? filePath, String? type}) async {
    final id = const Uuid().v4();
    final note = NoteModel(
      id: id,
      title: defaultTitle,
      content: text,
      type: type ?? 'text',
      category: 'Inbox',
      updatedAt: DateTime.now().toIso8601String(),
    );
    await _dbRepo.insertNote(note);

    if (filePath != null) {
      _driveRepo.uploadNoteFile(note);
    } else {
      _driveRepo.uploadTextNote(note);
    }

    await _notificationService.showNotification(
      id: note.hashCode,
      title: 'Saved to Notes Vault',
      body: 'Saved shared raw item into Inbox.',
    );
  }

  Future<void> _saveFileNote(String filePath, String type) async {
    final separator = kIsWeb ? '/' : Platform.pathSeparator;
    final fileName = filePath.split(separator).last;
    final id = const Uuid().v4();
    final note = NoteModel(
      id: id,
      title: fileName,
      type: type,
      category: 'Documents',
      filePath: filePath,
      updatedAt: DateTime.now().toIso8601String(),
    );
    await _dbRepo.insertNote(note);
    _driveRepo.uploadNoteFile(note);

    await _notificationService.showNotification(
      id: note.hashCode,
      title: 'Document Saved',
      body: 'Document "$fileName" saved to Notes Vault.',
    );
  }
}
