import 'package:sqflite/sqflite.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;
import '../core/database_helper.dart';
import '../models/subject_model.dart';
import '../models/timetable_slot_model.dart';
import '../models/attendance_log_model.dart';

bool get _isWebOrTest => kIsWeb || (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST'));

class AttendanceRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // In-memory data store for Web preview
  static final List<Map<String, dynamic>> _webSubjects = [
    {
      'id': 'sub1',
      'name': 'Data Structures & Algorithms',
      'code': 'CS-201',
      'min_percentage': 75.0,
    },
    {
      'id': 'sub2',
      'name': 'Database Management Systems',
      'code': 'CS-202',
      'min_percentage': 75.0,
    },
  ];

  static final List<Map<String, dynamic>> _webSlots = [
    {
      'id': 'slot1',
      'subject_id': 'sub1',
      'day_of_week': 1, // Monday
      'start_time': '09:00',
      'end_time': '10:00',
      'classroom': 'Room 301',
    },
    {
      'id': 'slot2',
      'subject_id': 'sub2',
      'day_of_week': 1, // Monday
      'start_time': '10:15',
      'end_time': '11:15',
      'classroom': 'Lab 2',
    },
    {
      'id': 'slot3',
      'subject_id': 'sub1',
      'day_of_week': 2, // Tuesday
      'start_time': '09:00',
      'end_time': '10:00',
      'classroom': 'Room 301',
    },
  ];

  static final List<Map<String, dynamic>> _webLogs = [];

  // --- Subjects ---
  Future<List<SubjectModel>> getSubjects() async {
    if (_isWebOrTest) {
      return _webSubjects.map((map) => SubjectModel.fromMap(map)).toList();
    }
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('subjects');
    return maps.map((map) => SubjectModel.fromMap(map)).toList();
  }

  Future<void> insertSubject(SubjectModel subject) async {
    if (_isWebOrTest) {
      _webSubjects.removeWhere((s) => s['id'] == subject.id);
      _webSubjects.add(subject.toMap());
      return;
    }
    final db = await _dbHelper.database;
    await db.insert(
      'subjects',
      subject.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateSubject(SubjectModel subject) async {
    if (_isWebOrTest) {
      final index = _webSubjects.indexWhere((s) => s['id'] == subject.id);
      if (index != -1) {
        _webSubjects[index] = subject.toMap();
      } else {
        _webSubjects.add(subject.toMap());
      }
      return;
    }
    final db = await _dbHelper.database;
    await db.update(
      'subjects',
      subject.toMap(),
      where: 'id = ?',
      whereArgs: [subject.id],
    );
  }

  Future<void> deleteSubject(String id) async {
    if (_isWebOrTest) {
      _webSubjects.removeWhere((s) => s['id'] == id);
      _webSlots.removeWhere((s) => s['subject_id'] == id);
      _webLogs.removeWhere((l) => l['subject_id'] == id);
      return;
    }
    final db = await _dbHelper.database;
    await db.delete(
      'subjects',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // --- Timetable Slots ---
  Future<List<TimetableSlotModel>> getTimetableSlots() async {
    if (_isWebOrTest) {
      return _webSlots.map((map) => TimetableSlotModel.fromMap(map)).toList();
    }
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('timetable_slots');
    return maps.map((map) => TimetableSlotModel.fromMap(map)).toList();
  }

  Future<List<TimetableSlotModel>> getSlotsForDay(int dayOfWeek) async {
    if (_isWebOrTest) {
      final list = _webSlots
          .where((s) => s['day_of_week'] == dayOfWeek)
          .map((map) => TimetableSlotModel.fromMap(map))
          .toList();
      list.sort((a, b) => a.startTime.compareTo(b.startTime));
      return list;
    }
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'timetable_slots',
      where: 'day_of_week = ?',
      whereArgs: [dayOfWeek],
      orderBy: 'start_time ASC',
    );
    return maps.map((map) => TimetableSlotModel.fromMap(map)).toList();
  }

  Future<void> insertTimetableSlot(TimetableSlotModel slot) async {
    if (_isWebOrTest) {
      _webSlots.removeWhere((s) => s['id'] == slot.id);
      _webSlots.add(slot.toMap());
      return;
    }
    final db = await _dbHelper.database;
    await db.insert(
      'timetable_slots',
      slot.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteTimetableSlot(String id) async {
    if (_isWebOrTest) {
      _webSlots.removeWhere((s) => s['id'] == id);
      return;
    }
    final db = await _dbHelper.database;
    await db.delete(
      'timetable_slots',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> clearTimetable() async {
    if (_isWebOrTest) {
      _webSlots.clear();
      return;
    }
    final db = await _dbHelper.database;
    await db.delete('timetable_slots');
  }

  // --- Attendance Logs ---
  Future<List<AttendanceLogModel>> getAttendanceLogs() async {
    if (_isWebOrTest) {
      final list = _webLogs.map((map) => AttendanceLogModel.fromMap(map)).toList();
      list.sort((a, b) => b.date.compareTo(a.date));
      return list;
    }
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('attendance_logs', orderBy: 'date DESC');
    return maps.map((map) => AttendanceLogModel.fromMap(map)).toList();
  }

  Future<List<AttendanceLogModel>> getLogsForSubject(String subjectId) async {
    if (_isWebOrTest) {
      final list = _webLogs
          .where((l) => l['subject_id'] == subjectId)
          .map((map) => AttendanceLogModel.fromMap(map))
          .toList();
      list.sort((a, b) => b.date.compareTo(a.date));
      return list;
    }
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'attendance_logs',
      where: 'subject_id = ?',
      whereArgs: [subjectId],
      orderBy: 'date DESC',
    );
    return maps.map((map) => AttendanceLogModel.fromMap(map)).toList();
  }

  Future<void> insertAttendanceLog(AttendanceLogModel log) async {
    if (_isWebOrTest) {
      _webLogs.removeWhere((l) => l['subject_id'] == log.subjectId && l['date'] == log.date);
      _webLogs.add(log.toMap());
      return;
    }
    final db = await _dbHelper.database;
    await db.insert(
      'attendance_logs',
      log.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteAttendanceLog(String id) async {
    if (_isWebOrTest) {
      _webLogs.removeWhere((l) => l['id'] == id);
      return;
    }
    final db = await _dbHelper.database;
    await db.delete(
      'attendance_logs',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
