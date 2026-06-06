import '../models/timetable_slot_model.dart';
import '../repositories/attendance_repository.dart';
import 'notification_service.dart';

class AttendanceReminderService {
  final AttendanceRepository _attendanceRepo = AttendanceRepository();
  final NotificationService _notificationService = NotificationService();

  static const int reminderBaseId = 2000;

  /// Recalculates and schedules the daily end-of-class reminders based on the current timetable.
  Future<void> rescheduleAllReminders() async {
    // 1. Cancel all existing weekly attendance reminders (IDs 2001-2007)
    for (int day = 1; day <= 7; day++) {
      await _notificationService.cancelNotification(reminderBaseId + day);
    }

    // 2. Fetch all timetable slots
    final slots = await _attendanceRepo.getTimetableSlots();
    if (slots.isEmpty) {
      print('AttendanceReminderService: No timetable slots found. Reminders cleared.');
      return;
    }

    // 3. Group slots by day of the week
    final Map<int, List<TimetableSlotModel>> slotsByDay = {};
    for (var slot in slots) {
      slotsByDay.putIfAbsent(slot.dayOfWeek, () => []).add(slot);
    }

    // 4. For each day, schedule a notification at the end of the last class
    for (int day = 1; day <= 7; day++) {
      final daySlots = slotsByDay[day];
      if (daySlots == null || daySlots.isEmpty) {
        continue;
      }

      // Find the slot with the latest end time
      TimetableSlotModel latestSlot = daySlots.first;
      for (var slot in daySlots) {
        if (_compareTimeStrings(slot.endTime, latestSlot.endTime) > 0) {
          latestSlot = slot;
        }
      }

      // Parse the latest end time (e.g. "16:30")
      try {
        final parts = latestSlot.endTime.split(':');
        if (parts.length == 2) {
          final int hour = int.parse(parts[0]);
          final int minute = int.parse(parts[1]);

          final int reminderId = reminderBaseId + day;

          // Schedule weekly reminder for this day at this end time
          await _notificationService.scheduleWeeklyNotification(
            id: reminderId,
            title: 'Attendance Confirmation',
            body: 'Your classes for today have ended. Did you attend them? Tap to confirm.',
            dayOfWeek: day,
            hour: hour,
            minute: minute,
            payload: 'attendance_confirmation_day_$day',
          );
          print('AttendanceReminderService: Scheduled reminder ID $reminderId for Day $day at $hour:$minute');
        }
      } catch (e) {
        print('AttendanceReminderService: Error parsing time ${latestSlot.endTime}: $e');
      }
    }
  }

  /// Compares two time strings in "HH:MM" format.
  /// Returns > 0 if timeA is later than timeB, < 0 if timeA is earlier than timeB, 0 if equal.
  int _compareTimeStrings(String timeA, String timeB) {
    final aParts = timeA.split(':');
    final bParts = timeB.split(':');
    if (aParts.length != 2 || bParts.length != 2) return 0;

    final aHour = int.tryParse(aParts[0]) ?? 0;
    final aMin = int.tryParse(aParts[1]) ?? 0;
    final bHour = int.tryParse(bParts[0]) ?? 0;
    final bMin = int.tryParse(bParts[1]) ?? 0;

    if (aHour != bHour) {
      return aHour.compareTo(bHour);
    }
    return aMin.compareTo(bMin);
  }
}
