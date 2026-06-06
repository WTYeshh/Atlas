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
import '../providers/notes_provider.dart';
import '../providers/auth_provider.dart';

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
      // 0. Perform local storage cleanup (manual past events & completed tasks > 60 mins)
      await _cleanupExpiredStorage();

      final syncEnabled = await _settingsRepo.getExternalSyncEnabled();
      if (!syncEnabled) {
        print('SyncService: External Google sync is disabled by user setting.');
        final lastTime = DateFormat('jm').format(DateTime.now());
        await _settingsRepo.saveSyncStatus(status: 'success', lastSyncedTime: lastTime);
        _ref.read(syncStatusProvider.notifier).updateStatus('success', lastTime);
        return;
      }

      final online = await isOnline();
      if (!online) {
        throw const SocketException('Offline');
      }

      // 1. Refresh profile data
      await _refreshProfileData();

      // 2. Process offline modifications in queue
      await _processSyncQueue();

      // 3. Two-way Google Calendar Sync
      await _syncGoogleCalendar();

      // 4. Refresh tasks
      await _refreshTasks();

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

  Future<void> _refreshProfileData() async {
    final googleSignIn = await _authRepo.getGoogleSignIn();
    final account = googleSignIn.currentUser ?? await googleSignIn.signInSilently();
    if (account != null) {
      await _settingsRepo.saveUserProfile(
        email: account.email,
        name: account.displayName ?? account.email.split('@')[0],
        photoUrl: account.photoUrl,
      );
    }
  }

  Future<void> _processSyncQueue() async {
    final client = await _authRepo.getAuthenticatedClient();
    if (client == null) {
      print('SyncService: Skipping queue processing. Client is null.');
      return;
    }
    final calendarApi = google_cal.CalendarApi(client);
    final queue = await _settingsRepo.getSyncQueue();

    for (var item in queue) {
      final queueId = item['id'] as int;
      final entityType = item['entity_type'] as String;
      final entityId = item['entity_id'] as String;
      final action = item['action'] as String;
      final payload = item['payload'] as String?;

      try {
        if (entityType == 'event') {
          if (action == 'create' && payload != null) {
            final eventMap = jsonDecode(payload) as Map<String, dynamic>;
            final event = EventModel.fromMap(eventMap);

            final newGoogleEvent = google_cal.Event(
              summary: event.title,
              description: event.description,
              start: google_cal.EventDateTime(
                dateTime: DateTime.tryParse('${event.date}T${event.time}:00'),
                timeZone: DateTime.now().timeZoneName,
              ),
              end: google_cal.EventDateTime(
                dateTime: DateTime.tryParse('${event.date}T${event.time}:00')?.add(const Duration(hours: 1)),
                timeZone: DateTime.now().timeZoneName,
              ),
            );

            final created = await calendarApi.events.insert(newGoogleEvent, 'primary');
            if (created.id != null) {
              // Update local event googleEventId
              final localEvents = await _dbRepo.getEvents();
              final localEvent = localEvents.firstWhere((e) => e.id == event.id, orElse: () => event);
              final updatedEvent = localEvent.copyWith(googleEventId: created.id);
              await _dbRepo.updateEvent(updatedEvent);
            }
          } else if (action == 'update' && payload != null) {
            final eventMap = jsonDecode(payload) as Map<String, dynamic>;
            final event = EventModel.fromMap(eventMap);

            if (event.googleEventId != null) {
              final updatedGoogleEvent = google_cal.Event(
                summary: event.title,
                description: event.description,
                start: google_cal.EventDateTime(
                  dateTime: DateTime.tryParse('${event.date}T${event.time}:00'),
                  timeZone: DateTime.now().timeZoneName,
                ),
                end: google_cal.EventDateTime(
                  dateTime: DateTime.tryParse('${event.date}T${event.time}:00')?.add(const Duration(hours: 1)),
                  timeZone: DateTime.now().timeZoneName,
                ),
              );
              await calendarApi.events.update(updatedGoogleEvent, 'primary', event.googleEventId!);
            }
          } else if (action == 'delete') {
            await calendarApi.events.delete('primary', entityId);
          }
        }
        await _settingsRepo.removeFromSyncQueue(queueId);
      } catch (e) {
        print('SyncService: Error processing queue item $queueId: $e');
        if (e.toString().contains('404') || e.toString().contains('Requested entity was not found')) {
          // If deleted already on remote, clear from queue
          await _settingsRepo.removeFromSyncQueue(queueId);
        } else {
          rethrow;
        }
      }
    }
  }

  Future<void> _syncGoogleCalendar() async {
    final client = await _authRepo.getAuthenticatedClient();
    if (client == null) return;
    final calendarApi = google_cal.CalendarApi(client);

    // Fetch all remote Google Calendar events (paginated)
    final List<google_cal.Event> items = [];
    String? pageToken;
    try {
      do {
        final googleEvents = await calendarApi.events.list(
          'primary',
          maxResults: 250,
          pageToken: pageToken,
        );
        if (googleEvents.items != null) {
          items.addAll(googleEvents.items!);
        }
        pageToken = googleEvents.nextPageToken;
      } while (pageToken != null);
    } catch (e) {
      print('SyncService: Error listing remote Google Calendar events: $e');
      rethrow;
    }

    final localEvents = await _dbRepo.getEvents();

    // 1. Process/Sync remote updates/inserts to local DB
    for (var item in items) {
      if (item.id == null || item.summary == null) continue;

      String dateStr = '';
      String timeStr = '00:00';

      if (item.start?.dateTime != null) {
        final dt = item.start!.dateTime!.toLocal();
        dateStr = '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
        timeStr = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      } else if (item.start?.date != null) {
        final d = item.start!.date!;
        dateStr = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      }

      if (dateStr.isEmpty) continue;

      final existingLocal = localEvents.cast<EventModel?>().firstWhere(
            (e) => e?.googleEventId == item.id,
            orElse: () => null,
          );

      if (existingLocal == null) {
        final newEvent = EventModel(
          id: const Uuid().v4(),
          title: item.summary!,
          date: dateStr,
          time: timeStr,
          description: item.description,
          category: 'Google Sync',
          googleEventId: item.id,
          updatedAt: DateTime.now().toIso8601String(),
        );
        await _dbRepo.insertEvent(newEvent);
      } else {
        final googleUpdated = item.updated ?? DateTime.now();
        final localUpdated = DateTime.tryParse(existingLocal.updatedAt) ?? DateTime.fromMillisecondsSinceEpoch(0);

        if (googleUpdated.isAfter(localUpdated)) {
          final updatedEvent = existingLocal.copyWith(
            title: item.summary!,
            date: dateStr,
            time: timeStr,
            description: item.description,
            updatedAt: googleUpdated.toIso8601String(),
          );
          await _dbRepo.updateEvent(updatedEvent);
        }
      }
    }

    // 2. Identify and delete local events whose googleEventId is no longer present or is cancelled in the fetched remote events list
    final activeGoogleIds = items
        .where((item) => item.id != null && item.status != 'cancelled')
        .map((item) => item.id!)
        .toSet();

    for (var localEvent in localEvents) {
      if (localEvent.googleEventId != null && !activeGoogleIds.contains(localEvent.googleEventId)) {
        print('SyncService: Auto-deleting local event that was deleted on Google Calendar: ${localEvent.title}');
        await _dbRepo.deleteEvent(localEvent.id);
      }
    }
  }

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
    _ref.read(notesProvider.notifier).loadNotes();
    _ref.read(authProvider.notifier).refreshProfile();
  }
}
