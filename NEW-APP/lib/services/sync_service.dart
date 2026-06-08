import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:googleapis/calendar/v3.dart' as google_cal;
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../repositories/database_repository.dart';
import '../repositories/settings_repository.dart';
import '../repositories/auth_repository.dart';
import '../models/event_model.dart';
import '../providers/calendar_provider.dart';
import '../providers/tasks_provider.dart';

import '../providers/auth_provider.dart';
import '../providers/repository_providers.dart';

class SyncStatusState {
  final String status; // 'success', 'failed', 'syncing'
  final String lastSyncedTime;

  SyncStatusState({required this.status, required this.lastSyncedTime});
}

class SyncStatusNotifier extends StateNotifier<SyncStatusState> {
  final SettingsRepository _settingsRepo;

  SyncStatusNotifier(this._settingsRepo)
      : super(SyncStatusState(status: 'success', lastSyncedTime: 'Never')) {
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    final statusMap = await _settingsRepo.getSyncStatus();
    state = SyncStatusState(
      status: statusMap['status'] ?? 'success',
      lastSyncedTime: statusMap['lastSyncedTime'] ?? 'Never',
    );
  }

  void updateStatus(String status, String lastSyncedTime) {
    state = SyncStatusState(status: status, lastSyncedTime: lastSyncedTime);
  }
}

final syncStatusProvider = StateNotifierProvider<SyncStatusNotifier, SyncStatusState>((ref) {
  final settingsRepo = ref.watch(settingsRepositoryProvider);
  return SyncStatusNotifier(settingsRepo);
});

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository();
});

final syncServiceProvider = Provider<SyncService>((ref) {
  final dbRepo = ref.watch(databaseRepositoryProvider);
  final settingsRepo = ref.watch(settingsRepositoryProvider);
  final authRepo = ref.watch(authRepositoryProvider);
  return SyncService(dbRepo, settingsRepo, authRepo, ref);
});

class SyncService {
  final DatabaseRepository _dbRepo;
  final SettingsRepository _settingsRepo;
  final AuthRepository _authRepo;
  final Ref _ref;

  Timer? _connectivityTimer;
  bool _wasOffline = false;
  bool _isSyncing = false;

  bool get isSyncing => _isSyncing;

  SyncService(this._dbRepo, this._settingsRepo, this._authRepo, this._ref) {
    if (!kIsWeb) {
      startConnectivityMonitoring();
    }
  }

  Future<bool> isOnline() async {
    if (kIsWeb) return true;
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 5));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  void startConnectivityMonitoring() {
    _connectivityTimer?.cancel();
    _connectivityTimer = Timer.periodic(const Duration(seconds: 20), (timer) async {
      final online = await isOnline();
      if (online && _wasOffline) {
        print('SyncService: Internet connectivity restored. Running auto-sync.');
        _wasOffline = false;
        await syncAll();
      } else if (!online) {
        _wasOffline = true;
      }
    });
  }

  void dispose() {
    _connectivityTimer?.cancel();
  }

  Future<void> syncAll() async {
    if (_isSyncing) return;
    _isSyncing = true;
    _ref.read(syncStatusProvider.notifier).updateStatus('syncing', _ref.read(syncStatusProvider).lastSyncedTime);

    try {
      // Perform local storage cleanup (manual past events & completed tasks > 60 mins)
      await _cleanupExpiredStorage();

      final lastTime = DateFormat('jm').format(DateTime.now());
      await _settingsRepo.saveSyncStatus(status: 'success', lastSyncedTime: lastTime);
      _ref.read(syncStatusProvider.notifier).updateStatus('success', lastTime);
    } catch (e) {
      print('SyncService: Sync failed: $e');
      final lastTime = _ref.read(syncStatusProvider).lastSyncedTime;
      await _settingsRepo.saveSyncStatus(status: 'failed', lastSyncedTime: lastTime);
      _ref.read(syncStatusProvider.notifier).updateStatus('failed', lastTime);
    } finally {
      _isSyncing = false;
      _reloadProviders();
    }
  }

  Future<void> _refreshProfileData() async {}
  Future<void> _processSyncQueue() async {}
  Future<void> _syncGoogleCalendar() async {}

  Future<void> _refreshTasks() async {
    // Triggers local notification reshuffling/updates
    _ref.read(tasksProvider.notifier).loadTasks();
  }

  Future<void> _cleanupExpiredStorage() async {
    try {
      final now = DateTime.now();

      // 1. Clean up past manually created events (> 60 minutes past)
      final events = await _dbRepo.getEvents();
      for (var event in events) {
        if (event.googleEventId == null) { // Skip events synced from Google
          final eventDateTime = DateTime.tryParse('${event.date}T${event.time}:00');
          if (eventDateTime != null) {
            final deleteTime = eventDateTime.add(const Duration(minutes: 60));
            if (now.isAfter(deleteTime)) {
              print('SyncService: Auto-deleting manual event past 60 mins: ${event.title}');
              await _dbRepo.deleteEvent(event.id);
            }
          }
        }
      }

      // 2. Clean up completed tasks (> 60 minutes past completion)
      final tasks = await _dbRepo.getTasks();
      for (var task in tasks) {
        if (task.status == 'completed') {
          final updatedAtTime = DateTime.tryParse(task.updatedAt);
          if (updatedAtTime != null) {
            final deleteTime = updatedAtTime.add(const Duration(minutes: 60));
            if (now.isAfter(deleteTime)) {
              print('SyncService: Auto-deleting completed task past 60 mins: ${task.title}');
              await _dbRepo.deleteTask(task.id);
            }
          }
        }
      }
    } catch (e) {
      print('SyncService: Error in auto-cleanup: $e');
    }
  }

  void _reloadProviders() {
    _ref.read(calendarProvider.notifier).loadEvents();
    _ref.read(tasksProvider.notifier).loadTasks();
    _ref.read(authProvider.notifier).refreshProfile();
  }
}
