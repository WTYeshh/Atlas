import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/subject_model.dart';
import '../models/timetable_slot_model.dart';
import '../models/attendance_log_model.dart';
import '../models/event_model.dart';
import '../repositories/attendance_repository.dart';
import '../repositories/settings_repository.dart';
import '../services/attendance_reminder_service.dart';

class AttendanceState {
  final List<SubjectModel> subjects;
  final List<TimetableSlotModel> slots;
  final List<AttendanceLogModel> logs;
  final String? semesterStartDate;
  final String? semesterEndDate;
  final bool isLoading;
  final bool isOnline;

  AttendanceState({
    this.subjects = const [],
    this.slots = const [],
    this.logs = const [],
    this.semesterStartDate,
    this.semesterEndDate,
    this.isLoading = false,
    this.isOnline = true,
  });

  AttendanceState copyWith({
    List<SubjectModel>? subjects,
    List<TimetableSlotModel>? slots,
    List<AttendanceLogModel>? logs,
    String? semesterStartDate,
    String? semesterEndDate,
    bool? isLoading,
    bool? isOnline,
  }) {
    return AttendanceState(
      subjects: subjects ?? this.subjects,
      slots: slots ?? this.slots,
      logs: logs ?? this.logs,
      semesterStartDate: semesterStartDate ?? this.semesterStartDate,
      semesterEndDate: semesterEndDate ?? this.semesterEndDate,
      isLoading: isLoading ?? this.isLoading,
      isOnline: isOnline ?? this.isOnline,
    );
  }
}

final attendanceRepositoryProvider = Provider<AttendanceRepository>((ref) {
  return AttendanceRepository();
});

final attendanceProvider = StateNotifierProvider<AttendanceNotifier, AttendanceState>((ref) {
  final repo = ref.watch(attendanceRepositoryProvider);
  return AttendanceNotifier(repo);
});

class AttendanceNotifier extends StateNotifier<AttendanceState> {
  final AttendanceRepository _repo;
  final AttendanceReminderService _reminderService = AttendanceReminderService();
  final SettingsRepository _settingsRepo = SettingsRepository();

  AttendanceNotifier(this._repo) : super(AttendanceState()) {
    loadAll();
  }

  Future<void> loadAll() async {
    state = state.copyWith(isLoading: true);
    
    bool online = true;
    try {
      final result = await InternetAddress.lookup('google.com').timeout(const Duration(seconds: 3));
      online = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      online = false;
    }

    final subjects = await _repo.getSubjects();
    final slots = await _repo.getTimetableSlots();
    final logs = await _repo.getAttendanceLogs();
    final semStart = await _settingsRepo.getSetting('semester_start_date');
    final semEnd = await _settingsRepo.getSetting('semester_end_date');
    state = AttendanceState(
      subjects: subjects,
      slots: slots,
      logs: logs,
      semesterStartDate: semStart,
      semesterEndDate: semEnd,
      isLoading: false,
      isOnline: online,
    );
  }

  Future<void> setSemesterDates(String start, String end) async {
    await _settingsRepo.saveSetting('semester_start_date', start);
    await _settingsRepo.saveSetting('semester_end_date', end);
    await loadAll();
  }

  Map<String, dynamic> getSubjectProjections(String subjectId, List<EventModel> events) {
    final startStr = state.semesterStartDate;
    final endStr = state.semesterEndDate;

    if (startStr == null || endStr == null || startStr.trim().isEmpty || endStr.trim().isEmpty) {
      return {'available': false};
    }

    final startDate = DateTime.tryParse(startStr);
    final endDate = DateTime.tryParse(endStr);
    if (startDate == null || endDate == null) {
      return {'available': false};
    }

    // Filter slots for this subject
    final subjectSlots = state.slots.where((s) => s.subjectId == subjectId).toList();
    if (subjectSlots.isEmpty) {
      return {
        'available': true,
        'totalClasses': 0,
        'futureClasses': 0,
        'heldSoFar': 0,
        'attendedSoFar': 0,
        'projectedMax': 0.0,
        'projectedMin': 0.0,
        'statusMessage': 'No classes scheduled in weekly timetable.',
        'statusColor': 'grey',
      };
    }

    // Create a set of holiday/exam dates
    final holidays = events
        .where((e) => e.category?.toLowerCase() == 'holiday' || e.category?.toLowerCase() == 'exam' || e.category?.toLowerCase() == 'google sync')
        .map((e) => e.date)
        .toSet();

    int totalClasses = 0;
    int futureClasses = 0;

    final now = DateTime.now();
    final todayStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    final todayDate = DateTime.tryParse(todayStr) ?? now;

    // Iterate through all days in semester range
    final daysCount = endDate.difference(startDate).inDays;
    for (int i = 0; i <= daysCount; i++) {
      final date = startDate.add(Duration(days: i));
      final dateStr = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";

      // If it is a holiday/exam, skip it
      if (holidays.contains(dateStr)) continue;

      final weekday = date.weekday; // 1 = Monday, 7 = Sunday
      final dailySlots = subjectSlots.where((s) => s.dayOfWeek == weekday).length;

      totalClasses += dailySlots;

      if (date.isAfter(todayDate) && dailySlots > 0) {
        futureClasses += dailySlots;
      }
    }

    // Get actual manual logs for this subject
    final subjectLogs = state.logs.where((l) => l.subjectId == subjectId).toList();
    final heldSoFar = subjectLogs.where((l) => l.status == 'present' || l.status == 'absent').length;
    final attendedSoFar = subjectLogs.where((l) => l.status == 'present').length;

    // Projected percentages
    final totalExpected = heldSoFar + futureClasses;
    final double projectedMax = totalExpected == 0 ? 0.0 : ((attendedSoFar + futureClasses) / totalExpected) * 100.0;
    final double projectedMin = totalExpected == 0 ? 0.0 : (attendedSoFar / totalExpected) * 100.0;

    // Target minimum percentage
    final subject = state.subjects.firstWhere((s) => s.id == subjectId, orElse: () => SubjectModel(id: '', name: '', minPercentage: 75.0));
    final double minRequired = subject.minPercentage;
    final double targetRatio = minRequired / 100.0;

    String statusMessage = '';
    String statusColor = 'green';

    // Calculate actions
    if (totalExpected == 0) {
      statusMessage = 'No classes held or scheduled yet.';
      statusColor = 'grey';
    } else {
      // If attending all future classes cannot reach target:
      if (projectedMax < minRequired) {
        statusMessage = 'Goal unreachable! Maximum possible attendance is ${projectedMax.toStringAsFixed(1)}%.';
        statusColor = 'red';
      } else {
        // Safe check: how many classes can be missed?
        // (attendedSoFar + futureClasses - Y) / totalExpected >= targetRatio
        // attendedSoFar + futureClasses - Y >= targetRatio * totalExpected
        // Y <= attendedSoFar + futureClasses - targetRatio * totalExpected
        final double maxMissable = (attendedSoFar + futureClasses) - (targetRatio * totalExpected);
        final int affordToMiss = maxMissable.floor();

        // Required next classes to reach target (if currently below target ratio on total expected):
        // (attendedSoFar + X) / (heldSoFar + X) >= targetRatio
        // X >= (targetRatio * heldSoFar - attendedSoFar) / (1 - targetRatio)
        final double reqNext = (targetRatio * heldSoFar - attendedSoFar) / (1 - targetRatio);
        final int needToAttend = reqNext > 0 ? reqNext.ceil() : 0;

        if (needToAttend > 0) {
          statusMessage = 'Alert: Must attend the next $needToAttend class${needToAttend > 1 ? "es" : ""} to reach ${minRequired.toInt()}%.';
          statusColor = 'orange';
        } else {
          statusMessage = 'Safe: You can afford to miss up to $affordToMiss class${affordToMiss != 1 ? "es" : ""} this semester.';
          statusColor = 'green';
        }
      }
    }

    return {
      'available': true,
      'totalClasses': totalClasses,
      'futureClasses': futureClasses,
      'heldSoFar': heldSoFar,
      'attendedSoFar': attendedSoFar,
      'projectedMax': projectedMax,
      'projectedMin': projectedMin,
      'statusMessage': statusMessage,
      'statusColor': statusColor,
    };
  }

  // --- Subject Actions ---
  Future<void> addSubject(String name, String? code, double minPercent) async {
    final newSubject = SubjectModel(
      id: const Uuid().v4(),
      name: name,
      code: code,
      minPercentage: minPercent,
    );
    await _repo.insertSubject(newSubject);
    await loadAll();
  }

  Future<void> deleteSubject(String id) async {
    await _repo.deleteSubject(id);
    await loadAll();
    await _reminderService.rescheduleAllReminders();
  }

  // --- Timetable Actions ---
  Future<void> addTimetableSlot(String subjectId, int dayOfWeek, String start, String end, String? room) async {
    final slot = TimetableSlotModel(
      id: const Uuid().v4(),
      subjectId: subjectId,
      dayOfWeek: dayOfWeek,
      startTime: start,
      endTime: end,
      classroom: room,
    );
    await _repo.insertTimetableSlot(slot);
    await loadAll();
    await _reminderService.rescheduleAllReminders();
  }

  Future<void> deleteTimetableSlot(String id) async {
    await _repo.deleteTimetableSlot(id);
    await loadAll();
    await _reminderService.rescheduleAllReminders();
  }

  Future<void> updateTimetableSlot({
    required String id,
    required String subjectId,
    required int dayOfWeek,
    required String start,
    required String end,
    required String? room,
  }) async {
    final slot = TimetableSlotModel(
      id: id,
      subjectId: subjectId,
      dayOfWeek: dayOfWeek,
      startTime: start,
      endTime: end,
      classroom: room,
    );
    await _repo.insertTimetableSlot(slot);
    await loadAll();
    await _reminderService.rescheduleAllReminders();
  }

  Future<void> clearTimetable() async {
    await _repo.clearTimetable();
    await loadAll();
    await _reminderService.rescheduleAllReminders();
  }

  bool isDateWithinSemesterRange(String dateStr) {
    final startStr = state.semesterStartDate;
    final endStr = state.semesterEndDate;
    if (startStr == null || endStr == null || startStr.trim().isEmpty || endStr.trim().isEmpty) {
      return true; // No dates configured, allow logging
    }
    final targetDate = DateTime.tryParse(dateStr);
    final startDate = DateTime.tryParse(startStr);
    final endDate = DateTime.tryParse(endStr);
    
    if (targetDate == null || startDate == null || endDate == null) {
      return true;
    }
    
    final minDate = startDate.subtract(const Duration(days: 5));
    final maxDate = endDate.add(const Duration(days: 5));
    
    final target = DateTime(targetDate.year, targetDate.month, targetDate.day);
    final min = DateTime(minDate.year, minDate.month, minDate.day);
    final max = DateTime(maxDate.year, maxDate.month, maxDate.day);
    
    return (target.isAtSameMomentAs(min) || target.isAfter(min)) &&
           (target.isAtSameMomentAs(max) || target.isBefore(max));
  }

  // --- Attendance Actions ---
  Future<void> markAttendance({
    required String subjectId,
    required String date,
    required String status, // 'present', 'absent', 'cancelled'
    String? slotId,
  }) async {
    if (!isDateWithinSemesterRange(date)) {
      throw Exception('outside_range');
    }

    // Check if there is an existing log for this subject on this date and slotId
    final existingIndex = state.logs.indexWhere((l) => l.subjectId == subjectId && l.date == date && l.slotId == slotId);
    
    if (existingIndex != -1) {
      final existingLog = state.logs[existingIndex];
      final updatedLog = existingLog.copyWith(
        status: status,
        updatedAt: DateTime.now().toIso8601String(),
      );
      await _repo.insertAttendanceLog(updatedLog);
    } else {
      final newLog = AttendanceLogModel(
        id: const Uuid().v4(),
        subjectId: subjectId,
        date: date,
        status: status,
        slotId: slotId,
        updatedAt: DateTime.now().toIso8601String(),
      );
      await _repo.insertAttendanceLog(newLog);
    }
    await loadAll();
    await _reminderService.rescheduleAllReminders();
  }

  Future<void> removeAttendanceLog(String id) async {
    await _repo.deleteAttendanceLog(id);
    await loadAll();
    await _reminderService.rescheduleAllReminders();
  }

  // --- Helper Getters for Stats ---

  /// Returns overall stats: { 'held': int, 'attended': int, 'percentage': double }
  Map<String, dynamic> getOverallStats() {
    int totalHeld = 0;
    int totalAttended = 0;

    for (var subject in state.subjects) {
      final subjectLogs = state.logs.where((l) => l.subjectId == subject.id).toList();
      
      final held = subjectLogs.where((l) => l.status == 'present' || l.status == 'absent').length;
      final attended = subjectLogs.where((l) => l.status == 'present').length;

      totalHeld += held;
      totalAttended += attended;
    }

    final double percentage = totalHeld == 0 ? 0.0 : (totalAttended / totalHeld) * 100.0;

    return {
      'held': totalHeld,
      'attended': totalAttended,
      'percentage': percentage,
    };
  }

  /// Returns subject stats: { subjectId: { 'held': int, 'attended': int, 'percentage': double } }
  Map<String, Map<String, dynamic>> getSubjectStats() {
    final Map<String, Map<String, dynamic>> stats = {};

    for (var subject in state.subjects) {
      final subjectLogs = state.logs.where((l) => l.subjectId == subject.id).toList();
      
      final held = subjectLogs.where((l) => l.status == 'present' || l.status == 'absent').length;
      final attended = subjectLogs.where((l) => l.status == 'present').length;

      final double percentage = held == 0 ? 0.0 : (attended / held) * 100.0;

      stats[subject.id] = {
        'held': held,
        'attended': attended,
        'percentage': percentage,
      };
    }

    return stats;
  }

  /// Calculates pending classes that occurred in the last 7 days according to the weekly timetable,
  /// but have not been logged/confirmed yet.
  List<Map<String, dynamic>> getPendingConfirmations() {
    if (!state.isOnline) {
      return []; // Return empty list when offline to prevent marking unconfirmed classes
    }

    final now = DateTime.now();
    final List<Map<String, dynamic>> pending = [];
    
    // We scan the past 7 days up to today
    final startDate = now.subtract(const Duration(days: 7));
    
    for (int i = 0; i <= 7; i++) {
      final date = startDate.add(Duration(days: i));
      final dateStr = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
      final todayStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
      
      final weekday = date.weekday; // 1 = Mon, 7 = Sun
      
      // Find slots scheduled for this weekday
      final daySlots = state.slots.where((s) => s.dayOfWeek == weekday).toList();
      
      for (var slot in daySlots) {
        // Check if there is an attendance log for this subject, date, and slotId
        final hasLog = state.logs.any((l) => l.subjectId == slot.subjectId && l.date == dateStr && l.slotId == slot.id);
        if (!hasLog) {
          // If it's today, check if the class end time has already passed
          if (dateStr == todayStr) {
            final nowTime = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
            if (slot.endTime.compareTo(nowTime) > 0) {
              // Class hasn't ended yet today, do not show as pending
              continue;
            }
          }
          
          final subject = state.subjects.firstWhere((sub) => sub.id == slot.subjectId, orElse: () => SubjectModel(id: '', name: ''));
          if (subject.id.isNotEmpty) {
            pending.add({
              'subject': subject,
              'slot': slot,
              'date': dateStr,
              'formattedDate': "${_getWeekdayName(weekday)}, ${_formatDateString(dateStr)}",
            });
          }
        }
      }
    }

    // Sort: oldest pending date first
    pending.sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));
    return pending;
  }

  String _getWeekdayName(int day) {
    switch (day) {
      case 1: return 'Monday';
      case 2: return 'Tuesday';
      case 3: return 'Wednesday';
      case 4: return 'Thursday';
      case 5: return 'Friday';
      case 6: return 'Saturday';
      case 7: return 'Sunday';
      default: return '';
    }
  }

  String _formatDateString(String dateStr) {
    try {
      final parts = dateStr.split('-');
      if (parts.length == 3) {
        return "${parts[2]}-${parts[1]}-${parts[0].substring(2)}";
      }
    } catch (_) {}
    return dateStr;
  }
}
