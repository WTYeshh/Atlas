import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/config.dart';
import '../repositories/settings_repository.dart';
import '../repositories/database_repository.dart';
import '../repositories/calendar_repository.dart';
import '../repositories/drive_repository.dart';
import '../providers/calendar_provider.dart';
import '../providers/tasks_provider.dart';
import '../providers/attendance_provider.dart';
import '../services/sync_service.dart';
import 'attendance_ocr_service.dart';
import 'message_parser_service.dart';
import 'auto_reminder_service.dart';
import '../providers/repository_providers.dart';

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
    return 0;
  }

  void _reloadProviders() {
    _ref.read(calendarProvider.notifier).loadEvents();
    _ref.read(tasksProvider.notifier).loadTasks();
    _ref.read(attendanceProvider.notifier).loadAll();
  }
}
