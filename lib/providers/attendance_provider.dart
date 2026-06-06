import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/subject_model.dart';
import '../models/timetable_slot_model.dart';
import '../models/attendance_log_model.dart';
import '../repositories/attendance_repository.dart';
import '../services/attendance_reminder_service.dart';

class AttendanceState {
  final List<SubjectModel> subjects;
  final List<TimetableSlotModel> slots;
  final List<AttendanceLogModel> logs;
  final bool isLoading;

  AttendanceState({
    this.subjects = const [],
    this.slots = const [],
    this.logs = const [],
    this.isLoading = false,
  });

  AttendanceState copyWith({
    List<SubjectModel>? subjects,
    List<TimetableSlotModel>? slots,
    List<AttendanceLogModel>? logs,
    bool? isLoading,
  }) {
    return AttendanceState(
      subjects: subjects ?? this.subjects,
      slots: slots ?? this.slots,
      logs: logs ?? this.logs,
      isLoading: isLoading ?? this.isLoading,
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

  AttendanceNotifier(this._repo) : super(AttendanceState()) {
    loadAll();
  }

  Future<void> loadAll() async {
    state = state.copyWith(isLoading: true);
    final subjects = await _repo.getSubjects();
    final slots = await _repo.getTimetableSlots();
    final logs = await _repo.getAttendanceLogs();
    state = AttendanceState(
      subjects: subjects,
      slots: slots,
      logs: logs,
      isLoading: false,
    );
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

  Future<void> clearTimetable() async {
    await _repo.clearTimetable();
    await loadAll();
    await _reminderService.rescheduleAllReminders();
  }

  // --- Attendance Actions ---
  Future<void> markAttendance({
    required String subjectId,
    required String date,
    required String status, // 'present', 'absent', 'cancelled'
  }) async {
    // Check if there is an existing log for this subject on this date
    final existingIndex = state.logs.indexWhere((l) => l.subjectId == subjectId && l.date == date);
    
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
        updatedAt: DateTime.now().toIso8601String(),
      );
      await _repo.insertAttendanceLog(newLog);
    }
    await loadAll();
  }

  Future<void> removeAttendanceLog(String id) async {
    await _repo.deleteAttendanceLog(id);
    await loadAll();
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

  /// Calculates pending classes that occurred in the last 14 days according to the weekly timetable,
  /// but have not been logged/confirmed yet.
  List<Map<String, dynamic>> getPendingConfirmations() {
    final now = DateTime.now();
    final List<Map<String, dynamic>> pending = [];
    
    // We scan the past 14 days up to today
    final startDate = now.subtract(const Duration(days: 14));
    
    for (int i = 0; i <= 14; i++) {
      final date = startDate.add(Duration(days: i));
      final dateStr = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
      final todayStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
      
      final weekday = date.weekday; // 1 = Mon, 7 = Sun
      
      // Find slots scheduled for this weekday
      final daySlots = state.slots.where((s) => s.dayOfWeek == weekday).toList();
      
      for (var slot in daySlots) {
        // Check if there is an attendance log for this subject on this date
        final hasLog = state.logs.any((l) => l.subjectId == slot.subjectId && l.date == dateStr);
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
