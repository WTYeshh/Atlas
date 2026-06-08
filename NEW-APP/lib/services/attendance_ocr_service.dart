import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../core/config.dart';
import '../models/subject_model.dart';
import '../models/timetable_slot_model.dart';
import '../models/event_model.dart';
import '../repositories/attendance_repository.dart';
import '../repositories/calendar_repository.dart';
import '../repositories/settings_repository.dart';

class AttendanceOcrService {
  final AttendanceRepository _attendanceRepo = AttendanceRepository();
  final CalendarRepository _calendarRepo;
  final SettingsRepository _settingsRepo = SettingsRepository();

  AttendanceOcrService(this._calendarRepo);

  /// Processes the image at [imagePath], sends it directly to Gemini Vision API,
  /// and imports the slots (for timetables) or events (for calendars) directly into the database.
  /// Returns a map describing what was imported (e.g., type, count).
  Future<Map<String, dynamic>> parseAndImportImage(String imagePath) async {
    // 1. Read image file as base64
    final file = File(imagePath);
    if (!await file.exists()) {
      throw Exception('Image file not found at $imagePath');
    }
    final imageBytes = await file.readAsBytes();
    final base64Image = base64Encode(imageBytes);

    // Determine MIME type from extension
    final ext = imagePath.toLowerCase().split('.').last;
    String mimeType = 'image/png';
    if (ext == 'jpg' || ext == 'jpeg') mimeType = 'image/jpeg';
    if (ext == 'webp') mimeType = 'image/webp';

    // 2. Call Gemini Vision REST API (sends image directly, no local OCR needed)
    const apiKey = AppConfig.geminiApiKey;
    if (apiKey.isEmpty || apiKey == 'YOUR_GEMINI_API_KEY_HERE') {
      throw Exception('Gemini API Key is not configured.');
    }

    const model = 'gemini-2.0-flash';
    final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey');

    // 3. Formulate the prompt
    const prompt = '''
    You are an AI timetable and academic calendar parser designed for engineering students.
    Analyze the image provided.
    Determine if the image represents a "timetable" (weekly class schedule with subject names, times, and days) or a "calendar" (academic semester calendar showing key dates, holidays, exam periods).

    If it is a "timetable", extract all scheduled classes and format them as a JSON object matching this schema:
    {
      "type": "timetable",
      "slots": [
        {
          "subjectName": "Full descriptive name of the subject (e.g., Computer Networks, Engineering Mathematics)",
          "subjectCode": "Subject code or abbreviation (e.g., CN, MATH-302, DBMS) or null",
          "dayOfWeek": 1-7 (Integer where 1 = Monday, 2 = Tuesday, 3 = Wednesday, 4 = Thursday, 5 = Friday, 6 = Saturday, 7 = Sunday),
          "startTime": "HH:MM (24-hour format)",
          "endTime": "HH:MM (24-hour format)",
          "classroom": "Room number or lecture hall if specified, or null"
        }
      ]
    }

    If it is a "calendar", extract all holidays, exam periods, and key dates and format them as a JSON object matching this schema. If you can identify or estimate the overall semester start and end dates from the text, please extract them into the "semesterStartDate" and "semesterEndDate" fields:
    {
      "type": "calendar",
      "semesterStartDate": "YYYY-MM-DD or null if not found",
      "semesterEndDate": "YYYY-MM-DD or null if not found",
      "events": [
        {
          "title": "Descriptive event title (e.g., Semester Registration, Midterm Exam Week, Independence Day Holiday)",
          "date": "YYYY-MM-DD",
          "category": "Academic" | "Holiday" | "Exam",
          "description": "Any additional description or null"
        }
      ]
    }
    ''';

    try {
      final httpResponse = await http
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'x-goog-api-key': apiKey,
            },
            body: jsonEncode({
              'contents': [
                {
                  'role': 'user',
                  'parts': [
                    {'text': prompt},
                    {
                      'inline_data': {
                        'mime_type': mimeType,
                        'data': base64Image,
                      }
                    }
                  ]
                }
              ],
              'generationConfig': {'responseMimeType': 'application/json'},
            }),
          )
          .timeout(const Duration(seconds: 60));

      if (httpResponse.statusCode != 200) {
        throw Exception('Gemini API error ${httpResponse.statusCode}: ${httpResponse.body}');
      }

      final decoded = jsonDecode(httpResponse.body) as Map<String, dynamic>;
      final candidates = decoded['candidates'] as List?;
      if (candidates == null || candidates.isEmpty) {
        throw Exception('Gemini did not return any classification results.');
      }
      final parts = candidates[0]['content']?['parts'] as List?;
      if (parts == null || parts.isEmpty) {
        throw Exception('Gemini returned empty parts.');
      }
      final rawText = parts[0]['text'] as String? ?? '';
      // Strip markdown code fences if present
      final cleaned = rawText
          .replaceAll(RegExp(r'^```json\s*', multiLine: true), '')
          .replaceAll(RegExp(r'^```\s*', multiLine: true), '')
          .trim();

      final Map<String, dynamic> result = json.decode(cleaned);
      final String type = result['type'] as String? ?? 'unknown';

      if (type == 'timetable') {
        final List<dynamic> slotsJson = result['slots'] ?? [];
        int slotsCount = 0;
        
        // Load existing subjects to match names/codes
        final existingSubjects = await _attendanceRepo.getSubjects();

        for (var slotMap in slotsJson) {
          final sName = slotMap['subjectName'] as String? ?? 'Untitled Course';
          final sCode = slotMap['subjectCode'] as String?;
          final int day = slotMap['dayOfWeek'] as int? ?? 1;
          final sTime = slotMap['startTime'] as String? ?? '09:00';
          final eTime = slotMap['endTime'] as String? ?? '10:00';
          final room = slotMap['classroom'] as String?;

          // Match or create Subject
          SubjectModel? matchedSubject = existingSubjects.cast<SubjectModel?>().firstWhere(
            (sub) => sub?.name.toLowerCase() == sName.toLowerCase() || 
                     (sCode != null && sub?.code?.toLowerCase() == sCode.toLowerCase()),
            orElse: () => null,
          );

          if (matchedSubject == null) {
            matchedSubject = SubjectModel(
              id: const Uuid().v4(),
              name: sName,
              code: sCode,
            );
            await _attendanceRepo.insertSubject(matchedSubject);
            existingSubjects.add(matchedSubject);
          }

          // Insert Timetable Slot
          final newSlot = TimetableSlotModel(
            id: const Uuid().v4(),
            subjectId: matchedSubject.id,
            dayOfWeek: day,
            startTime: sTime,
            endTime: eTime,
            classroom: room,
          );

          await _attendanceRepo.insertTimetableSlot(newSlot);
          slotsCount++;
        }

        return {
          'type': 'timetable',
          'count': slotsCount,
        };
      } else if (type == 'calendar') {
        final List<dynamic> eventsJson = result['events'] ?? [];
        int eventsCount = 0;

        final semStart = result['semesterStartDate'] as String?;
        final semEnd = result['semesterEndDate'] as String?;

        if (semStart != null && semStart.trim().isNotEmpty) {
          await _settingsRepo.saveSetting('semester_start_date', semStart.trim());
        }
        if (semEnd != null && semEnd.trim().isNotEmpty) {
          await _settingsRepo.saveSetting('semester_end_date', semEnd.trim());
        }

        for (var eventMap in eventsJson) {
          final title = eventMap['title'] as String? ?? 'Academic Event';
          final dateStr = eventMap['date'] as String? ?? DateTime.now().toIso8601String().substring(0, 10);
          final category = eventMap['category'] as String? ?? 'Academic';
          final desc = eventMap['description'] as String?;

          final event = EventModel(
            id: const Uuid().v4(),
            title: title,
            date: dateStr,
            time: '09:00', // Default start time for all-day calendar events
            category: category,
            description: desc,
            updatedAt: DateTime.now().toIso8601String(),
          );

          await _calendarRepo.createEvent(event);
          eventsCount++;
        }

        return {
          'type': 'calendar',
          'count': eventsCount,
        };
      } else {
        throw Exception('Image was not recognized as either a Timetable or a Semester Calendar.');
      }
    } catch (e) {
      print('AttendanceOcrService parsing failed: $e');
      rethrow;
    }
  }
}
