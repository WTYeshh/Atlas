import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/event_model.dart';
import '../repositories/calendar_repository.dart';
import '../repositories/database_repository.dart';
import '../services/sync_service.dart';
import '../services/auto_reminder_service.dart';
import 'repository_providers.dart';


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
    // Reschedule all reminders so this new event gets its notifications
    await AutoReminderService().rescheduleAll(calendarRepo: _calendarRepo);
  }

  Future<void> updateEvent(EventModel event) async {
    await _calendarRepo.updateEvent(event);
    await loadEvents();
    // Reschedule all reminders after change
    await AutoReminderService().rescheduleAll(calendarRepo: _calendarRepo);
  }

  Future<void> deleteEvent(String id, String? googleEventId) async {
    await _calendarRepo.deleteEvent(id, googleEventId);
    await loadEvents();
    // Reschedule all reminders to remove the deleted event's notifications
    await AutoReminderService().rescheduleAll(calendarRepo: _calendarRepo);
  }

  // Trigger Two-Way Sync via SyncService
  Future<void> syncGoogleCalendar() async {
    await _ref.read(syncServiceProvider).syncAll();
  }
}

