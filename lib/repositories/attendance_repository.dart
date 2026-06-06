import 'package:sqflite/sqflite.dart';
import '../core/database_helper.dart';
import '../models/subject_model.dart';
import '../models/timetable_slot_model.dart';
import '../models/attendance_log_model.dart';

class AttendanceRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // --- Subjects ---
  Future<List<SubjectModel>> getSubjects() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('subjects');
    return maps.map((map) => SubjectModel.fromMap(map)).toList();
  }

  Future<void> insertSubject(SubjectModel subject) async {
    final db = await _dbHelper.database;
    await db.insert(
      'subjects',
      subject.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateSubject(SubjectModel subject) async {
    final db = await _dbHelper.database;
    await db.update(
      'subjects',
      subject.toMap(),
      where: 'id = ?',
      whereArgs: [subject.id],
    );
  }

  Future<void> deleteSubject(String id) async {
    final db = await _dbHelper.database;
    await db.delete(
      'subjects',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // --- Timetable Slots ---
  Future<List<TimetableSlotModel>> getTimetableSlots() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('timetable_slots');
    return maps.map((map) => TimetableSlotModel.fromMap(map)).toList();
  }

  Future<List<TimetableSlotModel>> getSlotsForDay(int dayOfWeek) async {
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
    final db = await _dbHelper.database;
    await db.insert(
      'timetable_slots',
      slot.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteTimetableSlot(String id) async {
    final db = await _dbHelper.database;
    await db.delete(
      'timetable_slots',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> clearTimetable() async {
    final db = await _dbHelper.database;
    await db.delete('timetable_slots');
  }

  // --- Attendance Logs ---
  Future<List<AttendanceLogModel>> getAttendanceLogs() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('attendance_logs', orderBy: 'date DESC');
    return maps.map((map) => AttendanceLogModel.fromMap(map)).toList();
  }

  Future<List<AttendanceLogModel>> getLogsForSubject(String subjectId) async {
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
    final db = await _dbHelper.database;
    await db.insert(
      'attendance_logs',
      log.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteAttendanceLog(String id) async {
    final db = await _dbHelper.database;
    await db.delete(
      'attendance_logs',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
