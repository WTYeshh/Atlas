import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/settings_repository.dart';
import '../repositories/database_repository.dart';
import '../repositories/calendar_repository.dart';
import '../repositories/drive_repository.dart';
import '../providers/notes_provider.dart';
import '../providers/calendar_provider.dart';
import '../providers/tasks_provider.dart';
import '../providers/attendance_provider.dart';
import '../services/sync_service.dart';
import 'share_service.dart';
import 'attendance_ocr_service.dart';

final discordServiceProvider = Provider<DiscordService>((ref) {
  final settingsRepo = ref.watch(settingsRepositoryProvider);
  final dbRepo = ref.watch(databaseRepositoryProvider);
  final calendarRepo = ref.watch(calendarRepositoryProvider);
  final driveRepo = ref.watch(driveRepositoryProvider);
  return DiscordService(settingsRepo, dbRepo, calendarRepo, driveRepo, ref);
});

class DiscordService {
  final SettingsRepository _settingsRepo;
  final DatabaseRepository _dbRepo;
  final CalendarRepository _calendarRepo;
  final DriveRepository _driveRepo;
  final Ref _ref;

  DiscordService(
    this._settingsRepo,
    this._dbRepo,
    this._calendarRepo,
    this._driveRepo,
    this._ref,
  );

  /// Fetches new messages from the designated Discord channel and processes them.
  /// Returns the number of successfully processed messages.
  Future<int> syncDiscord() async {
    final enabled = await _settingsRepo.getDiscordSyncEnabled();
    if (!enabled) {
      print('DiscordService: Integration is disabled in Settings.');
      return 0;
    }

    final botToken = await _settingsRepo.getDiscordBotToken();
    final channelId = await _settingsRepo.getDiscordChannelId();

    if (botToken == null || botToken.trim().isEmpty ||
        channelId == null || channelId.trim().isEmpty) {
      throw Exception('Discord credentials are not configured in Settings.');
    }

    final lastMsgId = await _settingsRepo.getDiscordLastMsgId();

    String url = 'https://discord.com/api/v10/channels/$channelId/messages';
    if (lastMsgId != null && lastMsgId.trim().isNotEmpty) {
      url += '?after=${lastMsgId.trim()}&limit=50';
    } else {
      url += '?limit=10'; // Limit to 10 on first sync to avoid history overload
    }

    print('DiscordService: Fetching from $url');
    final response = await http.get(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bot ${botToken.trim()}',
      },
    );

    if (response.statusCode != 200) {
      final errorBody = response.body;
      print('DiscordService: Failed fetching messages: ${response.statusCode} - $errorBody');
      throw Exception('Failed to connect to Discord API (Status ${response.statusCode}). Please check your bot token and channel ID.');
    }

    final List<dynamic> messages = json.decode(response.body);
    if (messages.isEmpty) {
      print('DiscordService: No new messages found.');
      return 0;
    }

    // Initialize ShareService inside the method to use the latest repos
    final shareService = ShareService(_dbRepo, _calendarRepo, _driveRepo);

    int processedCount = 0;

    // Discord returns messages newest first.
    // Process in chronological order (oldest to newest): loop from length-1 down to 0
    for (int i = messages.length - 1; i >= 0; i--) {
      final msg = messages[i];
      final msgId = msg['id'] as String?;
      final content = msg['content'] as String?;
      final isBot = msg['author']?['bot'] as bool? ?? false;
      final attachments = msg['attachments'] as List<dynamic>?;

      if (msgId == null || isBot) {
        continue;
      }

      bool isProcessedSuccessfully = false;

      // 1. Process attachments if there are any image uploads (e.g. timetable or calendar screenshots)
      if (attachments != null && attachments.isNotEmpty) {
        for (var attachment in attachments) {
          final url = attachment['url'] as String?;
          final filename = attachment['filename'] as String? ?? 'image.png';
          final contentType = attachment['content_type'] as String? ?? '';

          if (url != null && contentType.startsWith('image/')) {
            print('DiscordService: Found image attachment: $filename');
            final localPath = await _downloadAttachment(url, filename, botToken);
            if (localPath != null) {
              try {
                final ocrService = AttendanceOcrService(_calendarRepo);
                final importResult = await ocrService.parseAndImportImage(localPath);
                print('DiscordService: Attachment processed successfully: $importResult');
                isProcessedSuccessfully = true;
                
                // Delete temp file
                await File(localPath).delete();
              } catch (e) {
                print('DiscordService: Error parsing attachment image: $e');
              }
            }
          }
        }
      }

      // 2. Process text content if present
      if (content != null && content.trim().isNotEmpty) {
        print('DiscordService: Processing message text: $content');
        try {
          await shareService.processText(content);
          isProcessedSuccessfully = true;
        } catch (e) {
          print('DiscordService: Error processing text $msgId: $e');
        }
      }

      // Always progress the cursor to avoid double-processing or loop traps
      await _settingsRepo.saveDiscordLastMsgId(msgId);
      if (isProcessedSuccessfully) {
        processedCount++;
      }
    }

    if (processedCount > 0) {
      _reloadProviders();
    }

    return processedCount;
  }

  Future<String?> _downloadAttachment(String url, String filename, String botToken) async {
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bot ${botToken.trim()}',
        },
      );
      if (response.statusCode == 200) {
        final tempDir = Directory.systemTemp;
        final cleanFilename = filename.replaceAll(RegExp(r'[^\w\.\-]'), '_');
        final tempFile = File('${tempDir.path}/$cleanFilename');
        await tempFile.writeAsBytes(response.bodyBytes);
        return tempFile.path;
      } else {
        print('DiscordService: Failed downloading attachment: ${response.statusCode}');
      }
    } catch (e) {
      print('DiscordService: Error downloading attachment: $e');
    }
    return null;
  }

  void _reloadProviders() {
    _ref.read(calendarProvider.notifier).loadEvents();
    _ref.read(tasksProvider.notifier).loadTasks();
    _ref.read(notesProvider.notifier).loadNotes();
    _ref.read(attendanceProvider.notifier).loadAll();
  }
}
