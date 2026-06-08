import 'package:sqflite/sqflite.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;
import '../core/database_helper.dart';
import '../models/ia_mark_model.dart';

bool get _isWebOrTest => kIsWeb || (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST'));

class IaMarksRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // In-memory fallback for Web / tests
  static final List<Map<String, dynamic>> _webMarks = [];

  Future<List<IaMarkModel>> getMarksForSubject(String subjectId) async {
    if (_isWebOrTest) {
      return _webMarks
          .where((m) => m['subject_id'] == subjectId)
          .map((m) => IaMarkModel.fromMap(m))
          .toList();
    }
    final db = await _dbHelper.database;
    final maps = await db.query(
      'ia_marks',
      where: 'subject_id = ?',
      whereArgs: [subjectId],
      orderBy: 'ia_number ASC',
    );
    return maps.map((m) => IaMarkModel.fromMap(m)).toList();
  }

  Future<List<IaMarkModel>> getAllMarks() async {
    if (_isWebOrTest) {
      return _webMarks.map((m) => IaMarkModel.fromMap(m)).toList();
    }
    final db = await _dbHelper.database;
    final maps = await db.query('ia_marks', orderBy: 'subject_id ASC, ia_number ASC');
    return maps.map((m) => IaMarkModel.fromMap(m)).toList();
  }

  /// Upserts an IA mark (insert or replace by subject_id + ia_number uniqueness)
  Future<void> upsertMark(IaMarkModel mark) async {
    if (_isWebOrTest) {
      _webMarks.removeWhere(
        (m) => m['subject_id'] == mark.subjectId && m['ia_number'] == mark.iaNumber,
      );
      _webMarks.add(mark.toMap());
      return;
    }
    final db = await _dbHelper.database;
    await db.insert(
      'ia_marks',
      mark.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteMark(String id) async {
    if (_isWebOrTest) {
      _webMarks.removeWhere((m) => m['id'] == id);
      return;
    }
    final db = await _dbHelper.database;
    await db.delete('ia_marks', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteAllMarksForSubject(String subjectId) async {
    if (_isWebOrTest) {
      _webMarks.removeWhere((m) => m['subject_id'] == subjectId);
      return;
    }
    final db = await _dbHelper.database;
    await db.delete('ia_marks', where: 'subject_id = ?', whereArgs: [subjectId]);
  }
}
