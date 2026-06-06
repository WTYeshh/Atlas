import '../models/subject_model.dart';
import '../repositories/attendance_repository.dart';
import 'notification_service.dart';

class AttendanceReminderService {
  final AttendanceRepository _attendanceRepo = AttendanceRepository();
  final NotificationService _notificationService = NotificationService();

  static const int reminderBaseId = 2000;

  /// Recalculates and schedules individual reminders for each class slot that hasn't been logged yet.
  Future<void> rescheduleAllReminders() async {
    // 1. Cancel all scheduled attendance reminders in our range (2000 to 2200)
    for (int i = 2000; i < 2200; i++) {
      await _notificationService.cancelNotification(i);
    }

    // 2. Fetch all subjects, slots, and logs
    final subjects = await _attendanceRepo.getSubjects();
    final slots = await _attendanceRepo.getTimetableSlots();
    final logs = await _attendanceRepo.getAttendanceLogs();

    if (slots.isEmpty) {
      print('AttendanceReminderService: No timetable slots found.');
      return;
    }

    final now = DateTime.now();
    int scheduledCount = 0;
    int idCounter = 2000;

    // 3. Scan the next 7 days (including today)
    for (int dayOffset = 0; dayOffset <= 7; dayOffset++) {
      final date = now.add(Duration(days: dayOffset));
      final dateStr = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
      final weekday = date.weekday; // 1 = Monday, 7 = Sunday

      // Get slots scheduled for this weekday
      final daySlots = slots.where((s) => s.dayOfWeek == weekday).toList();

      for (var slot in daySlots) {
        // Find subject
        final subject = subjects.firstWhere(
          (sub) => sub.id == slot.subjectId,
          orElse: () => SubjectModel(id: '', name: 'Unknown Subject'),
        );

        // Check if there is an attendance log for this subject on this date
        final hasLog = logs.any((l) => l.subjectId == slot.subjectId && l.date == dateStr);
        if (hasLog) {
          continue; // Already marked present/absent/cancelled, no reminder needed
        }

        // Parse slot end time
        try {
          final timeParts = slot.endTime.split(':');
          if (timeParts.length == 2) {
            final int hour = int.parse(timeParts[0]);
            final int minute = int.parse(timeParts[1]);

            // Target notification time: 15 minutes after class end time
            var notificationTime = DateTime(date.year, date.month, date.day, hour, minute).add(const Duration(minutes: 15));

            // Only schedule if it's in the future and we haven't exceeded our notification range limit
            if (notificationTime.isAfter(now) && idCounter < 2200) {
              await _notificationService.scheduleNotification(
                id: idCounter,
                title: '⏰ Missed marking attendance?',
                body: 'Did you attend your "${subject.name}" class today? Tap to mark your attendance.',
                scheduledDate: notificationTime,
                payload: 'attendance_slot_missed:${slot.id}:$dateStr',
              );
              idCounter++;
              scheduledCount++;
            }
          }
        } catch (e) {
          print('AttendanceReminderService: Error processing slot ${slot.id}: $e');
        }
      }
    }
    print('AttendanceReminderService: Scheduled $scheduledCount attendance reminders.');
  }
}
