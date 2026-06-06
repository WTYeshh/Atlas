import '../core/database_helper.dart';
import '../models/event_model.dart';
import '../models/task_model.dart';
import 'package:sqflite/sqflite.dart';
import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;

bool get _isWebOrTest => kIsWeb || (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST'));


class DatabaseRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // In-memory database lists to store mock/preview data on Web
  static final List<Map<String, dynamic>> _webEvents = [
    {
      'id': 'e1',
      'title': 'Project Atlas Demo Presentation',
      'date': DateTime.now().add(const Duration(days: 1)).toIso8601String().substring(0, 10),
      'time': '14:30',
      'description': 'Presenting the prototype of Atlas AI Academic Assistant. Reviewing offline SQLite, Google Sign-in flow, and Gemini OCR.',
      'category': 'Academic',
      'reminder_id': 1001,
      'google_event_id': 'g_e1',
      'updated_at': DateTime.now().toIso8601String(),
    },
    {
      'id': 'e2',
      'title': 'Advanced Calculus Lecture',
      'date': DateTime.now().toIso8601String().substring(0, 10),
      'time': '09:00',
      'description': 'Intro to vector fields and double integrals. Room 402-B.',
      'category': 'Classes',
      'reminder_id': 1002,
      'google_event_id': null,
      'updated_at': DateTime.now().toIso8601String(),
    }
  ];

  static final List<Map<String, dynamic>> _webTasks = [
    {
      'id': 't1',
      'title': 'Submit Math Assignment 3',
      'due_date': DateTime.now().add(const Duration(days: 2)).toIso8601String().substring(0, 10),
      'priority': 'high',
      'subject': 'Calculus III',
      'status': 'pending',
      'reminder_id': 2001,
      'updated_at': DateTime.now().toIso8601String(),
    },
    {
      'id': 't2',
      'title': 'Read Gemini API Integration Docs',
      'due_date': DateTime.now().toIso8601String().substring(0, 10),
      'priority': 'medium',
      'subject': 'Software Engineering',
      'status': 'completed',
      'reminder_id': null,
      'updated_at': DateTime.now().toIso8601String(),
    }
  ];



  // --- EVENTS CRUD ---
  Future<List<EventModel>> getEvents() async {
    if (_isWebOrTest) {
      final list = _webEvents.map((map) => EventModel.fromMap(map)).toList();
      list.sort((a, b) {
        int cmp = a.date.compareTo(b.date);
        if (cmp != 0) return cmp;
        return a.time.compareTo(b.time);
      });
      return list;
    }
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('events', orderBy: 'date ASC, time ASC');
    return maps.map((map) => EventModel.fromMap(map)).toList();
  }

  Future<void> insertEvent(EventModel event) async {
    if (_isWebOrTest) {
      _webEvents.removeWhere((e) => e['id'] == event.id);
      _webEvents.add(event.toMap());
      return;
    }
    final db = await _dbHelper.database;
    await db.insert(
      'events',
      event.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateEvent(EventModel event) async {
    if (_isWebOrTest) {
      final index = _webEvents.indexWhere((e) => e['id'] == event.id);
      if (index != -1) {
        _webEvents[index] = event.toMap();
      } else {
        _webEvents.add(event.toMap());
      }
      return;
    }
    final db = await _dbHelper.database;
    await db.update(
      'events',
      event.toMap(),
      where: 'id = ?',
      whereArgs: [event.id],
    );
  }

  Future<void> deleteEvent(String id) async {
    if (_isWebOrTest) {
      _webEvents.removeWhere((e) => e['id'] == id);
      return;
    }
    final db = await _dbHelper.database;
    await db.delete(
      'events',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // --- TASKS CRUD ---
  Future<List<TaskModel>> getTasks() async {
    if (_isWebOrTest) {
      final list = _webTasks.map((map) => TaskModel.fromMap(map)).toList();
      list.sort((a, b) => a.dueDate.compareTo(b.dueDate));
      return list;
    }
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('tasks', orderBy: 'due_date ASC');
    return maps.map((map) => TaskModel.fromMap(map)).toList();
  }

  Future<void> insertTask(TaskModel task) async {
    if (_isWebOrTest) {
      _webTasks.removeWhere((t) => t['id'] == task.id);
      _webTasks.add(task.toMap());
      return;
    }
    final db = await _dbHelper.database;
    await db.insert(
      'tasks',
      task.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateTask(TaskModel task) async {
    if (_isWebOrTest) {
      final index = _webTasks.indexWhere((t) => t['id'] == task.id);
      if (index != -1) {
        _webTasks[index] = task.toMap();
      } else {
        _webTasks.add(task.toMap());
      }
      return;
    }
    final db = await _dbHelper.database;
    await db.update(
      'tasks',
      task.toMap(),
      where: 'id = ?',
      whereArgs: [task.id],
    );
  }

  Future<void> deleteTask(String id) async {
    if (_isWebOrTest) {
      _webTasks.removeWhere((t) => t['id'] == id);
      return;
    }
    final db = await _dbHelper.database;
    await db.delete(
      'tasks',
      where: 'id = ?',
      whereArgs: [id],
    );
  }



  // --- GLOBAL SEARCH ---
  Future<Map<String, List<dynamic>>> searchAll(String query) async {
    if (_isWebOrTest) {
      final cleanQuery = query.toLowerCase();
      
      final eventMaps = _webEvents.where((e) {
        final title = (e['title'] as String? ?? '').toLowerCase();
        final desc = (e['description'] as String? ?? '').toLowerCase();
        final cat = (e['category'] as String? ?? '').toLowerCase();
        return title.contains(cleanQuery) || desc.contains(cleanQuery) || cat.contains(cleanQuery);
      }).toList();

      final taskMaps = _webTasks.where((t) {
        final title = (t['title'] as String? ?? '').toLowerCase();
        final subj = (t['subject'] as String? ?? '').toLowerCase();
        return title.contains(cleanQuery) || subj.contains(cleanQuery);
      }).toList();

      final events = eventMaps.map((map) => EventModel.fromMap(map)).toList();
      final tasks = taskMaps.map((map) => TaskModel.fromMap(map)).toList();
      
      return {
        'events': events,
        'tasks': tasks,
      };
    }

    final db = await _dbHelper.database;
    final cleanQuery = '%$query%';

    final List<Map<String, dynamic>> eventMaps = await db.query(
      'events',
      where: 'title LIKE ? OR description LIKE ? OR category LIKE ?',
      whereArgs: [cleanQuery, cleanQuery, cleanQuery],
    );

    final List<Map<String, dynamic>> taskMaps = await db.query(
      'tasks',
      where: 'title LIKE ? OR subject LIKE ?',
      whereArgs: [cleanQuery, cleanQuery],
    );

    final events = eventMaps.map((map) => EventModel.fromMap(map)).toList();
    final tasks = taskMaps.map((map) => TaskModel.fromMap(map)).toList();
    
    return {
      'events': events,
      'tasks': tasks,
    };
  }
}
