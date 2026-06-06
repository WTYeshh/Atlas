import 'package:uuid/uuid.dart';
import '../models/task_model.dart';
import '../models/event_model.dart';
import '../repositories/database_repository.dart';
import '../repositories/calendar_repository.dart';
import 'notification_service.dart';

/// Parses plain text messages (e.g. from Discord) and extracts:
/// - Tasks / assignments (with due dates)
/// - Events / classes / reminders (with date + time)
/// Then saves them directly to the DB and schedules notifications.
class MessageParserService {
  final DatabaseRepository _dbRepo;
  final CalendarRepository _calendarRepo;
  final NotificationService _notificationService = NotificationService();


  MessageParserService(this._dbRepo, this._calendarRepo);

  // ──────────────────────────────────────────────
  //  PUBLIC ENTRY
  // ──────────────────────────────────────────────

  /// Parse a message and save whatever is found.
  /// Returns a human-readable summary of what was created.
  Future<String> processMessage(String text) async {
    final lower = text.toLowerCase().trim();

    // 1. Try to detect an event / reminder with date+time
    final eventResult = _tryParseEvent(text, lower);
    if (eventResult != null) {
      await _saveEvent(eventResult);
      return 'Event created: ${eventResult['title']}';
    }

    // 2. Try to detect a task / assignment with a due date
    final taskResult = _tryParseTask(text, lower);
    if (taskResult != null) {
      await _saveTask(taskResult);
      return 'Task created: ${taskResult['title']}';
    }

    // 3. Fallback: treat the whole message as a quick reminder today
    final fallback = _makeFallbackReminder(text);
    await _saveEvent(fallback);
    return 'Reminder created: ${fallback['title']}';
  }

  // ──────────────────────────────────────────────
  //  PARSERS
  // ──────────────────────────────────────────────

  Map<String, dynamic>? _tryParseEvent(String raw, String lower) {
    // Patterns that indicate an event/reminder (with time)
    final eventKeywords = ['class', 'lecture', 'exam', 'test', 'meeting',
      'seminar', 'lab', 'session', 'reminder', 'event', 'at', 'from',
      'starts', 'begins', 'scheduled', 'appointment'];
    final hasEventKw = eventKeywords.any((kw) => lower.contains(kw));

    final date = _extractDate(lower);
    final time = _extractTime(lower);

    if (date != null && time != null && hasEventKw) {
      return {
        'title': _cleanTitle(raw),
        'date': date,
        'time': time,
        'type': 'event',
      };
    }

    // Even without keyword: if we have a future date + time, treat as event
    if (date != null && time != null) {
      return {
        'title': _cleanTitle(raw),
        'date': date,
        'time': time,
        'type': 'event',
      };
    }

    return null;
  }

  Map<String, dynamic>? _tryParseTask(String raw, String lower) {
    // Keywords strongly indicating a task
    final taskKeywords = ['submit', 'assignment', 'homework', 'due', 'deadline',
      'complete', 'finish', 'task', 'project', 'report', 'quiz'];
    final hasTaskKw = taskKeywords.any((kw) => lower.contains(kw));

    if (!hasTaskKw) return null;

    final dueDate = _extractDate(lower) ?? _todayString();
    final priority = _extractPriority(lower);
    final subject = _extractSubject(lower);

    return {
      'title': _cleanTitle(raw),
      'dueDate': dueDate,
      'priority': priority,
      'subject': subject,
    };
  }

  Map<String, dynamic> _makeFallbackReminder(String raw) {
    final date = _extractDate(raw.toLowerCase()) ?? _todayString();
    final time = _extractTime(raw.toLowerCase()) ?? '09:00';
    return {
      'title': _cleanTitle(raw),
      'date': date,
      'time': time,
      'type': 'reminder',
    };
  }

  // ──────────────────────────────────────────────
  //  DATE / TIME EXTRACTION
  // ──────────────────────────────────────────────

  /// Try to find a date string in the text. Returns 'YYYY-MM-DD' or null.
  String? _extractDate(String lower) {
    final now = DateTime.now();

    // Relative keywords
    if (lower.contains('today')) return _fmt(now);
    if (lower.contains('tomorrow')) return _fmt(now.add(const Duration(days: 1)));
    if (lower.contains('day after tomorrow')) return _fmt(now.add(const Duration(days: 2)));

    // "next monday", "next friday", etc.
    final nextDayMatch = RegExp(r'next\s+(monday|tuesday|wednesday|thursday|friday|saturday|sunday)')
        .firstMatch(lower);
    if (nextDayMatch != null) {
      final dayName = nextDayMatch.group(1)!;
      return _fmt(_nextWeekday(dayName));
    }

    // "this friday", "this monday"
    final thisDayMatch = RegExp(r'this\s+(monday|tuesday|wednesday|thursday|friday|saturday|sunday)')
        .firstMatch(lower);
    if (thisDayMatch != null) {
      final dayName = thisDayMatch.group(1)!;
      return _fmt(_nextWeekdayThisWeek(dayName));
    }

    // "on monday", "on friday"
    final onDayMatch = RegExp(r'\bon\s+(monday|tuesday|wednesday|thursday|friday|saturday|sunday)')
        .firstMatch(lower);
    if (onDayMatch != null) {
      final dayName = onDayMatch.group(1)!;
      return _fmt(_nextWeekday(dayName));
    }

    // DD/MM/YYYY or DD-MM-YYYY
    final dmyMatch = RegExp(r'(\d{1,2})[/\-](\d{1,2})[/\-](\d{2,4})').firstMatch(lower);
    if (dmyMatch != null) {
      try {
        final d = int.parse(dmyMatch.group(1)!);
        final m = int.parse(dmyMatch.group(2)!);
        int y = int.parse(dmyMatch.group(3)!);
        if (y < 100) y += 2000;
        return '${y.toString().padLeft(4, '0')}-${m.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}';
      } catch (_) {}
    }

    // YYYY-MM-DD
    final isoMatch = RegExp(r'(\d{4})-(\d{2})-(\d{2})').firstMatch(lower);
    if (isoMatch != null) {
      return '${isoMatch.group(1)}-${isoMatch.group(2)}-${isoMatch.group(3)}';
    }

    // "15 june", "june 15", "15th june"
    final months = ['january','february','march','april','may','june',
      'july','august','september','october','november','december'];
    for (int i = 0; i < months.length; i++) {
      final mon = months[i];
      // "15 june" or "15th june" or "june 15"
      final m1 = RegExp(r'(\d{1,2})(?:st|nd|rd|th)?\s+' + mon).firstMatch(lower);
      final m2 = RegExp(mon + r'\s+(\d{1,2})(?:st|nd|rd|th)?').firstMatch(lower);
      final match = m1 ?? m2;
      if (match != null) {
        final day = int.parse(match.group(1)!);
        final year = now.month > (i + 1) ? now.year + 1 : now.year;
        return '${year.toString()}-${(i + 1).toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
      }
    }

    return null;
  }

  /// Try to find a time string in the text. Returns 'HH:MM' or null.
  String? _extractTime(String lower) {
    // "3:30 pm", "3pm", "15:30", "9:00 am"
    final timePat = RegExp(r'(\d{1,2})(?::(\d{2}))?\s*(am|pm)?(?!\d)');
    for (final match in timePat.allMatches(lower)) {
      int hour = int.parse(match.group(1)!);
      final min = int.tryParse(match.group(2) ?? '0') ?? 0;
      final ampm = match.group(3);

      // Skip bare numbers that are obviously years / dates (> 23 hours)
      if (ampm == null && hour > 23) continue;
      if (ampm == null && hour < 1) continue;

      if (ampm == 'pm' && hour < 12) hour += 12;
      if (ampm == 'am' && hour == 12) hour = 0;

      return '${hour.toString().padLeft(2, '0')}:${min.toString().padLeft(2, '0')}';
    }
    return null;
  }

  // ──────────────────────────────────────────────
  //  HELPER EXTRACTORS
  // ──────────────────────────────────────────────

  String _extractPriority(String lower) {
    if (lower.contains('urgent') || lower.contains('asap') || lower.contains('immediately') ||
        lower.contains('high priority') || lower.contains('important')) return 'high';
    if (lower.contains('low priority') || lower.contains('whenever') || lower.contains('optional')) return 'low';
    return 'medium';
  }

  String? _extractSubject(String lower) {
    final subjectKeywords = {
      'math': 'Mathematics', 'maths': 'Mathematics', 'calculus': 'Calculus',
      'physics': 'Physics', 'chemistry': 'Chemistry', 'biology': 'Biology',
      'english': 'English', 'history': 'History', 'geography': 'Geography',
      'cs': 'Computer Science', 'computer science': 'Computer Science',
      'programming': 'Programming', 'python': 'Programming', 'java': 'Programming',
      'c++': 'Programming', 'data structures': 'Data Structures',
      'algorithms': 'Algorithms', 'os': 'Operating Systems',
      'operating system': 'Operating Systems', 'networking': 'Networking',
      'dbms': 'Database Systems', 'database': 'Database Systems',
      'software': 'Software Engineering', 'ai': 'Artificial Intelligence',
      'machine learning': 'Machine Learning', 'ml': 'Machine Learning',
    };
    for (final entry in subjectKeywords.entries) {
      if (lower.contains(entry.key)) return entry.value;
    }
    return null;
  }

  String _cleanTitle(String raw) {
    // Remove common command prefixes like "remind me to", "add task:", etc.
    var title = raw
        .replaceAll(RegExp(r'^(remind me (to|about|of)?|add (task|event|reminder):?|task:?|event:?)\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    // Capitalize first letter
    if (title.isNotEmpty) {
      title = title[0].toUpperCase() + title.substring(1);
    }

    // Truncate if too long
    if (title.length > 80) title = '${title.substring(0, 77)}...';

    return title.isEmpty ? 'Discord Message' : title;
  }

  // ──────────────────────────────────────────────
  //  DATE HELPERS
  // ──────────────────────────────────────────────

  String _fmt(DateTime dt) =>
      '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  String _todayString() => _fmt(DateTime.now());

  DateTime _nextWeekday(String name) {
    final map = {'monday': 1, 'tuesday': 2, 'wednesday': 3, 'thursday': 4,
      'friday': 5, 'saturday': 6, 'sunday': 7};
    final target = map[name] ?? 1;
    final now = DateTime.now();
    int diff = (target - now.weekday + 7) % 7;
    if (diff == 0) diff = 7; // "next monday" when it's already monday → next week
    return now.add(Duration(days: diff));
  }

  DateTime _nextWeekdayThisWeek(String name) {
    final map = {'monday': 1, 'tuesday': 2, 'wednesday': 3, 'thursday': 4,
      'friday': 5, 'saturday': 6, 'sunday': 7};
    final target = map[name] ?? 1;
    final now = DateTime.now();
    int diff = (target - now.weekday + 7) % 7;
    return now.add(Duration(days: diff == 0 ? 0 : diff));
  }

  // ──────────────────────────────────────────────
  //  SAVE HELPERS
  // ──────────────────────────────────────────────

  Future<void> _saveEvent(Map<String, dynamic> data) async {
    final id = const Uuid().v4();
    final reminderId = id.hashCode.abs() % 100000 + 10000;
    final now = DateTime.now().toIso8601String();

    final event = EventModel(
      id: id,
      title: data['title'] as String,
      date: data['date'] as String,
      time: data['time'] as String,
      description: 'Created via Discord message',
      category: data['type'] == 'reminder' ? 'Reminder' : 'Academic',
      reminderId: reminderId,
      updatedAt: now,
    );

    await _calendarRepo.createEvent(event);

    // Schedule a reminder 15 mins before
    try {
      final eventDt = DateTime.tryParse('${event.date}T${event.time}:00');
      if (eventDt != null) {
        final reminderTime = eventDt.subtract(const Duration(minutes: 15));
        if (reminderTime.isAfter(DateTime.now())) {
          await _notificationService.scheduleNotification(
            id: reminderId,
            title: event.category == 'Reminder' ? '⏰ Reminder' : '📅 Upcoming Event',
            body: '"${event.title}" ${event.category == 'Reminder' ? 'is due now!' : 'starts in 15 minutes.'}',
            scheduledDate: reminderTime,
          );
        }
      }
    } catch (e) {
      print('MessageParserService: Failed to schedule event notification: $e');
    }

    // Immediate confirmation notification
    await _notificationService.showNotification(
      id: reminderId + 1,
      title: event.category == 'Reminder' ? '✅ Reminder Set' : '✅ Event Added',
      body: '"${event.title}" on ${event.date} at ${event.time}',
    );

    print('MessageParserService: Saved event "${event.title}"');
  }

  Future<void> _saveTask(Map<String, dynamic> data) async {
    final id = const Uuid().v4();
    final reminderId = id.hashCode.abs() % 100000 + 20000;
    final now = DateTime.now().toIso8601String();

    final task = TaskModel(
      id: id,
      title: data['title'] as String,
      dueDate: data['dueDate'] as String,
      priority: data['priority'] as String,
      subject: data['subject'] as String?,
      status: 'pending',
      reminderId: reminderId,
      updatedAt: now,
    );

    await _dbRepo.insertTask(task);

    // Schedule reminder at 9:00 AM on due date
    try {
      final dueDate = DateTime.tryParse(task.dueDate);
      if (dueDate != null) {
        final reminderTime = DateTime(dueDate.year, dueDate.month, dueDate.day, 9, 0);
        if (reminderTime.isAfter(DateTime.now())) {
          await _notificationService.scheduleNotification(
            id: reminderId,
            title: '📚 Assignment Due Today',
            body: '${task.subject != null ? '[${task.subject}] ' : ''}${task.title}',
            scheduledDate: reminderTime,
          );
        }
      }
    } catch (e) {
      print('MessageParserService: Failed to schedule task notification: $e');
    }

    // Also schedule an early reminder 1 day before
    try {
      final dueDate = DateTime.tryParse(task.dueDate);
      if (dueDate != null) {
        final earlyReminder = DateTime(dueDate.year, dueDate.month, dueDate.day - 1, 18, 0);
        if (earlyReminder.isAfter(DateTime.now())) {
          await _notificationService.scheduleNotification(
            id: reminderId + 1,
            title: '⚠️ Assignment Due Tomorrow',
            body: '${task.subject != null ? '[${task.subject}] ' : ''}${task.title}',
            scheduledDate: earlyReminder,
          );
        }
      }
    } catch (e) {
      print('MessageParserService: Failed to schedule early task notification: $e');
    }

    // Immediate confirmation notification
    await _notificationService.showNotification(
      id: reminderId + 2,
      title: '✅ Task Added',
      body: '"${task.title}" due ${task.dueDate}${task.subject != null ? ' • ${task.subject}' : ''}',
    );

    print('MessageParserService: Saved task "${task.title}"');
  }
}
