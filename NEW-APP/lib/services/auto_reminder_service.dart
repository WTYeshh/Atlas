import 'package:flutter/foundation.dart';
import '../repositories/database_repository.dart';
import '../repositories/calendar_repository.dart';
import 'notification_service.dart';

/// Automatically reschedules all pending reminders for tasks and events.
/// Call [rescheduleAll] on app startup and after any data change.
class AutoReminderService {
  static final AutoReminderService _instance = AutoReminderService._internal();
  factory AutoReminderService() => _instance;
  AutoReminderService._internal();

  final NotificationService _notificationService = NotificationService();

  // Notification ID ranges:
  //  Tasks:  50000 + index  (due-day reminder)
  //  Tasks:  51000 + index  (1-day-early reminder)
  //  Events: 52000 + index  (15-min-before reminder)
  //  Events: 53000 + index  (1-day-before reminder)

  /// Wipes and rewrites all task + event reminders based on current DB data.
  Future<void> rescheduleAll({
    DatabaseRepository? dbRepo,
    CalendarRepository? calendarRepo,
  }) async {
    if (kIsWeb) return;

    try {
      // Cancel all auto-reminder IDs in our reserved ranges
      for (int i = 50000; i < 56000; i++) {
        await _notificationService.cancelNotification(i);
      }

      if (dbRepo != null) await _rescheduleTasks(dbRepo);
      if (calendarRepo != null) await _rescheduleEvents(calendarRepo);

      print('AutoReminderService: All reminders rescheduled.');
    } catch (e) {
      print('AutoReminderService: Error during reschedule: $e');
    }
  }

  // ──────────────────────────────────────────────────────
  //  TASK REMINDERS
  // ──────────────────────────────────────────────────────

  Future<void> _rescheduleTasks(DatabaseRepository dbRepo) async {
    final tasks = await dbRepo.getTasks();
    final now = DateTime.now();
    int scheduled = 0;

    for (int i = 0; i < tasks.length; i++) {
      final task = tasks[i];
      if (task.status == 'completed') continue;

      final dueDate = DateTime.tryParse(task.dueDate);
      if (dueDate == null) continue;

      // Assume a task is due at 18:00 (6:00 PM) on the due day
      var taskDueDt = DateTime(dueDate.year, dueDate.month, dueDate.day, 18, 0);

      // ─── 1-hour before task due ───
      final oneHourBefore = taskDueDt.subtract(const Duration(hours: 1));
      if (oneHourBefore.isAfter(now)) {
        await _notificationService.scheduleNotification(
          id: 50000 + i,
          title: '⏰ Task due in 1 hour',
          body: '${task.subject != null ? '[${task.subject}] ' : ''}${task.title} is due at ${taskDueDt.hour}:${taskDueDt.minute.toString().padLeft(2, "0")}',
          scheduledDate: oneHourBefore,
          payload: 'task:${task.id}',
        );
        scheduled++;
      }

      // ─── 30-minutes before task due ───
      final thirtyMinBefore = taskDueDt.subtract(const Duration(minutes: 30));
      if (thirtyMinBefore.isAfter(now)) {
        await _notificationService.scheduleNotification(
          id: 51000 + i,
          title: '⏰ Task due in 30 minutes',
          body: '${task.subject != null ? '[${task.subject}] ' : ''}${task.title} is due at ${taskDueDt.hour}:${taskDueDt.minute.toString().padLeft(2, "0")}',
          scheduledDate: thirtyMinBefore,
          payload: 'task:${task.id}',
        );
        scheduled++;
      }

      // ─── Overdue task reminder at 9:00 PM (21:00) on the due day ───
      final overdueReminder = DateTime(dueDate.year, dueDate.month, dueDate.day, 21, 0);
      if (overdueReminder.isAfter(now)) {
        await _notificationService.scheduleNotification(
          id: 52000 + i,
          title: '⚠️ Task Overdue Alert',
          body: 'Did you complete "${task.title}" on time? Tap to update it now.',
          scheduledDate: overdueReminder,
          payload: 'task:${task.id}',
        );
        scheduled++;
      }
    }

    print('AutoReminderService: Scheduled $scheduled task reminder(s) for ${tasks.length} tasks.');
  }

  // ──────────────────────────────────────────────────────
  //  EVENT REMINDERS
  // ──────────────────────────────────────────────────────

  Future<void> _rescheduleEvents(CalendarRepository calendarRepo) async {
    final events = await calendarRepo.getEvents();
    final now = DateTime.now();
    int scheduled = 0;

    for (int i = 0; i < events.length; i++) {
      final event = events[i];

      final eventDt = DateTime.tryParse('${event.date}T${event.time}:00');
      if (eventDt == null || eventDt.isBefore(now)) continue;

      // ─── 1-hour before event ───
      final oneHour = eventDt.subtract(const Duration(hours: 1));
      if (oneHour.isAfter(now)) {
        await _notificationService.scheduleNotification(
          id: 53000 + i,
          title: '⏰ Upcoming: ${event.category ?? 'Event'} in 1 hour',
          body: '"${event.title}" starts at ${event.time}.',
          scheduledDate: oneHour,
          payload: 'event:${event.id}',
        );
        scheduled++;
      }

      // ─── 30-minute before event ───
      final thirtyMin = eventDt.subtract(const Duration(minutes: 30));
      if (thirtyMin.isAfter(now)) {
        await _notificationService.scheduleNotification(
          id: 54000 + i,
          title: '⏰ Upcoming: ${event.category ?? 'Event'} in 30 minutes',
          body: '"${event.title}" starts at ${event.time}.',
          scheduledDate: thirtyMin,
          payload: 'event:${event.id}',
        );
        scheduled++;
      }
    }

    print('AutoReminderService: Scheduled $scheduled event reminder(s) for ${events.length} events.');
  }
}
