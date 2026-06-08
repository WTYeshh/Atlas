import 'package:sqflite/sqflite.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;
import '../core/database_helper.dart';
import '../models/past_semester_model.dart';

bool get _isWebOrTest => kIsWeb || (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST'));

class PastSemesterRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  
  static final List<Map<String, dynamic>> _webPastSemesters = [];

  Future<List<PastSemesterModel>> getPastSemesters() async {
    if (_isWebOrTest) {
      return _webPastSemesters.map((map) => PastSemesterModel.fromMap(map)).toList();
    }
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('past_semesters', orderBy: 'end_date DESC');
    return maps.map((map) => PastSemesterModel.fromMap(map)).toList();
  }

  Future<void> insertPastSemester(PastSemesterModel sem) async {
    if (_isWebOrTest) {
      _webPastSemesters.removeWhere((s) => s['id'] == sem.id);
      _webPastSemesters.add(sem.toMap());
      return;
    }
    final db = await _dbHelper.database;
    await db.insert(
      'past_semesters',
      sem.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deletePastSemester(String id) async {
    if (_isWebOrTest) {
      _webPastSemesters.removeWhere((s) => s['id'] == id);
      return;
    }
    final db = await _dbHelper.database;
    await db.delete(
      'past_semesters',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
