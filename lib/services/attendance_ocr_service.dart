import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:uuid/uuid.dart';
import '../core/config.dart';
import '../models/subject_model.dart';
import '../models/timetable_slot_model.dart';
import '../models/event_model.dart';
import '../repositories/attendance_repository.dart';
import '../repositories/calendar_repository.dart';
import 'ocr_service.dart';

class AttendanceOcrService {
  final OcrService _ocrService = OcrService();
  final AttendanceRepository _attendanceRepo = AttendanceRepository();
  final CalendarRepository _calendarRepo;

  AttendanceOcrService(this._calendarRepo);

  /// Processes the image at [imagePath], extracts text, classifies it via Gemini, 
  /// and imports the slots (for timetables) or events (for calendars) directly into the database.
  /// Returns a map describing what was imported (e.g., type, count).
  Future<Map<String, dynamic>> parseAndImportImage(String imagePath) async {
    // 1. Extract raw text from image using OCR
    final ocrText = await _ocrService.extractTextFromImage(imagePath);
    if (ocrText == null || ocrText.trim().isEmpty) {
      throw Exception('Could not extract any text from the uploaded image.');
    }

    // 2. Load Gemini model
    const apiKey = AppConfig.geminiApiKey;
    if (apiKey.isEmpty || apiKey == 'YOUR_GEMINI_API_KEY_HERE') {
      throw Exception('Gemini API Key is not configured.');
    }

    final model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: apiKey,
      generationConfig: GenerationConfig(responseMimeType: 'application/json'),
    );

    // 3. Formulate the prompt
    final prompt = '''
    You are an AI timetable and academic calendar parser designed for engineering students.
    Analyze the following raw text extracted from an image via OCR.
    Determine if the text represents a "timetable" (weekly class schedule with subject names, times, and days) or a "calendar" (academic semester calendar showing key dates, holidays, exam periods).

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

    If it is a "calendar", extract all holidays, exam periods, and key dates and format them as a JSON object matching this schema:
    {
      "type": "calendar",
      "events": [
        {
          "title": "Descriptive event title (e.g., Semester Registration, Midterm Exam Week, Independence Day Holiday)",
          "date": "YYYY-MM-DD",
          "category": "Academic" | "Holiday" | "Exam",
          "description": "Any additional description or null"
        }
      ]
    }

    Raw OCR Text:
    """
    $ocrText
    """
    ''';

    try {
      final response = await model.generateContent([Content.text(prompt)]);
      if (response.text == null) {
        throw Exception('Gemini did not return any classification results.');
      }

      final Map<String, dynamic> result = json.decode(response.text!);
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

  void dispose() {
    _ocrService.dispose();
  }
}
