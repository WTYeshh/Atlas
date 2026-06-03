import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/event_model.dart';
import '../repositories/calendar_repository.dart';
import '../repositories/database_repository.dart';
import '../services/notification_service.dart';
import '../services/sync_service.dart';
import 'notes_provider.dart';

final calendarRepositoryProvider = Provider<CalendarRepository>((ref) {
  final dbRepo = ref.watch(databaseRepositoryProvider);
  return CalendarRepository(dbRepo);
});

final calendarProvider = StateNotifierProvider<CalendarNotifier, List<EventModel>>((ref) {
  final dbRepo = ref.watch(databaseRepositoryProvider);
  final calendarRepo = ref.watch(calendarRepositoryProvider);
  return CalendarNotifier(dbRepo, calendarRepo, ref);
});

class CalendarNotifier extends StateNotifier<List<EventModel>> {
  final DatabaseRepository _dbRepo;
  final CalendarRepository _calendarRepo;
  final Ref _ref;
  final NotificationService _notificationService = NotificationService();

  bool get isSyncing => _ref.watch(syncStatusProvider).status == 'syncing';

  CalendarNotifier(this._dbRepo, this._calendarRepo, this._ref) : super([]) {
    loadEvents();
  }

  Future<void> loadEvents() async {
    final list = await _dbRepo.getEvents();
    state = list;
  }

  Future<void> addEvent(EventModel event) async {
    await _calendarRepo.createEvent(event);
    await loadEvents();
    _scheduleReminder(event);
  }

  Future<void> updateEvent(EventModel event) async {
    await _calendarRepo.updateEvent(event);
    await loadEvents();
    _scheduleReminder(event);
  }

  Future<void> deleteEvent(String id, String? googleEventId) async {
    final eventIndex = state.indexWhere((e) => e.id == id);
    if (eventIndex != -1) {
      final event = state[eventIndex];
      if (event.reminderId != null) {
        await _notificationService.cancelNotification(event.reminderId!);
      }
    }
    await _calendarRepo.deleteEvent(id, googleEventId);
    await loadEvents();
  }

  // Trigger Two-Way Sync via SyncService
  Future<void> syncGoogleCalendar() async {
    await _ref.read(syncServiceProvider).syncAll();
  }

  // Schedule notification reminders
  Future<void> _scheduleReminder(EventModel event) async {
    try {
      final eventDateTime = DateTime.tryParse('${event.date}T${event.time}:00');
      if (eventDateTime != null) {
        // Remind 15 minutes before the event
        final reminderTime = eventDateTime.subtract(const Duration(minutes: 15));
        
        int reminderId = event.reminderId ?? event.hashCode;
        
        await _notificationService.scheduleNotification(
          id: reminderId,
          title: 'Upcoming Event Alert',
          body: '"${event.title}" starts in 15 minutes.',
          scheduledDate: reminderTime,
        );

        if (event.reminderId == null) {
          final updated = event.copyWith(reminderId: reminderId);
          await _dbRepo.updateEvent(updated);
        }
      }
    } catch (e) {
      print('Failed to schedule reminder for event ${event.id}: $e');
    }
  }
}
