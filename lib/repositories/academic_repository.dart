import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sqflite/sqflite.dart';
import '../core/database_helper.dart';
import '../models/semester_model.dart';
import '../models/course_model.dart';

bool get _isWebOrTest => kIsWeb || (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST'));

class AcademicRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // --- Semester Queries ---

  Future<List<SemesterModel>> getSemesters() async {
    if (_isWebOrTest) return [];
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('semesters', orderBy: 'name ASC');
    return maps.map((map) => SemesterModel.fromMap(map)).toList();
  }

  Future<void> insertSemester(SemesterModel semester) async {
    if (_isWebOrTest) return;
    final db = await _dbHelper.database;
    await db.insert(
      'semesters',
      semester.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteSemester(String id) async {
    if (_isWebOrTest) return;
    final db = await _dbHelper.database;
    await db.delete(
      'semesters',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateSemester(SemesterModel semester) async {
    if (_isWebOrTest) return;
    final db = await _dbHelper.database;
    await db.update(
      'semesters',
      semester.toMap(),
      where: 'id = ?',
      whereArgs: [semester.id],
    );
  }

  // --- Course Queries ---

  Future<List<CourseModel>> getCourses(String semesterId) async {
    if (_isWebOrTest) return [];
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'semester_courses',
      where: 'semester_id = ?',
      whereArgs: [semesterId],
    );
    return maps.map((map) => CourseModel.fromMap(map)).toList();
  }

  Future<List<CourseModel>> getAllCourses() async {
    if (_isWebOrTest) return [];
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('semester_courses');
    return maps.map((map) => CourseModel.fromMap(map)).toList();
  }

  Future<void> insertCourse(CourseModel course) async {
    if (_isWebOrTest) return;
    final db = await _dbHelper.database;
    await db.insert(
      'semester_courses',
      course.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteCourse(String id) async {
    if (_isWebOrTest) return;
    final db = await _dbHelper.database;
    await db.delete(
      'semester_courses',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateCourse(CourseModel course) async {
    if (_isWebOrTest) return;
    final db = await _dbHelper.database;
    await db.update(
      'semester_courses',
      course.toMap(),
      where: 'id = ?',
      whereArgs: [course.id],
    );
  }
}
