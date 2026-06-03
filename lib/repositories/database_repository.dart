import '../core/database_helper.dart';
import '../models/event_model.dart';
import '../models/task_model.dart';
import '../models/note_model.dart';
import '../models/chat_message.dart';
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

  static final List<Map<String, dynamic>> _webNotes = [
    {
      'id': 'n1',
      'title': 'Machine Learning Study Guide',
      'content': 'Key Topics in ML:\n1. Supervised Learning: Regression & Classification\n2. Unsupervised Learning: K-Means Clustering, PCA\n3. Neural Networks: Feedforward networks, backpropagation algorithm.\n\nRecommended study: focus on cost functions and optimization algorithms.',
      'type': 'text',
      'subject': 'Machine Learning',
      'category': 'Study Guide',
      'summary': 'This study guide covers ML concepts including supervised, unsupervised learning, and neural network optimization.',
      'file_path': null,
      'drive_file_id': null,
      'updated_at': DateTime.now().toIso8601String(),
    }
  ];

  static final List<Map<String, dynamic>> _webTags = [
    {'id': 'tag1', 'name': 'exams'},
    {'id': 'tag2', 'name': 'calculus'},
  ];

  static final List<Map<String, dynamic>> _webNoteTags = [
    {'note_id': 'n1', 'tag_id': 'tag1'},
  ];

  static final List<Map<String, dynamic>> _webChatMessages = [
    {
      'id': 'msg1',
      'role': 'model',
      'message': 'Hello! I am your Atlas AI Assistant. How can I help you with your classes, notes, or tasks today?',
      'timestamp': DateTime.now().subtract(const Duration(minutes: 5)).toIso8601String(),
    }
  ];

  // Helper for web note tags
  List<String> _getNoteTagsWeb(String noteId) {
    final List<String> result = [];
    for (var nt in _webNoteTags) {
      if (nt['note_id'] == noteId) {
        final tag = _webTags.firstWhere((t) => t['id'] == nt['tag_id'], orElse: () => <String, dynamic>{});
        if (tag.isNotEmpty) {
          result.add(tag['name'] as String);
        }
      }
    }
    return result;
  }

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

  // --- NOTES CRUD ---
  Future<List<NoteModel>> getNotes() async {
    if (_isWebOrTest) {
      final list = _webNotes.map((map) => NoteModel.fromMap(map, tags: _getNoteTagsWeb(map['id'] as String))).toList();
      list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return list;
    }
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('notes', orderBy: 'updated_at DESC');
    
    List<NoteModel> notes = [];
    for (var map in maps) {
      final id = map['id'] as String;
      final tags = await _getNoteTags(id);
      notes.add(NoteModel.fromMap(map, tags: tags));
    }
    return notes;
  }

  Future<void> insertNote(NoteModel note) async {
    if (_isWebOrTest) {
      _webNotes.removeWhere((n) => n['id'] == note.id);
      _webNotes.add(note.toMap());

      // Delete existing note_tags mapping
      _webNoteTags.removeWhere((nt) => nt['note_id'] == note.id);

      // Insert new tags and relations
      for (var tagName in note.tags) {
        final cleanTagName = tagName.trim().toLowerCase();
        if (cleanTagName.isEmpty) continue;

        final existingIndex = _webTags.indexWhere((t) => t['name'] == cleanTagName);
        String tagId;
        if (existingIndex == -1) {
          tagId = DateTime.now().microsecondsSinceEpoch.toString();
          _webTags.add({'id': tagId, 'name': cleanTagName});
        } else {
          tagId = _webTags[existingIndex]['id'] as String;
        }

        _webNoteTags.add({
          'note_id': note.id,
          'tag_id': tagId,
        });
      }
      return;
    }
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      await txn.insert(
        'notes',
        note.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // Delete existing note_tags mapping
      await txn.delete(
        'note_tags',
        where: 'note_id = ?',
        whereArgs: [note.id],
      );

      // Insert new tags and relations
      for (var tagName in note.tags) {
        // Tag search/insert
        final cleanTagName = tagName.trim().toLowerCase();
        if (cleanTagName.isEmpty) continue;

        List<Map<String, dynamic>> existingTags = await txn.query(
          'tags',
          where: 'name = ?',
          whereArgs: [cleanTagName],
        );

        String tagId;
        if (existingTags.isEmpty) {
          tagId = DateTime.now().microsecondsSinceEpoch.toString();
          await txn.insert('tags', {'id': tagId, 'name': cleanTagName});
        } else {
          tagId = existingTags.first['id'] as String;
        }

        await txn.insert('note_tags', {
          'note_id': note.id,
          'tag_id': tagId,
        });
      }
    });
  }

  Future<void> updateNote(NoteModel note) async {
    await insertNote(note); // insertNote with ConflictAlgorithm.replace updates content and rebuilds tags.
  }

  Future<void> deleteNote(String id) async {
    if (_isWebOrTest) {
      _webNoteTags.removeWhere((nt) => nt['note_id'] == id);
      _webNotes.removeWhere((n) => n['id'] == id);
      return;
    }
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      await txn.delete(
        'note_tags',
        where: 'note_id = ?',
        whereArgs: [id],
      );
      await txn.delete(
        'notes',
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }

  Future<List<String>> _getNoteTags(String noteId) async {
    if (_isWebOrTest) {
      return _getNoteTagsWeb(noteId);
    }
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT tags.name FROM tags
      INNER JOIN note_tags ON tags.id = note_tags.tag_id
      WHERE note_tags.note_id = ?
    ''', [noteId]);
    return maps.map((map) => map['name'] as String).toList();
  }

  // --- CHAT HISTORY CRUD ---
  Future<List<ChatMessage>> getChatHistory() async {
    if (_isWebOrTest) {
      final list = _webChatMessages.map((map) => ChatMessage.fromMap(map)).toList();
      list.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      return list;
    }
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('chat_messages', orderBy: 'timestamp ASC');
    return maps.map((map) => ChatMessage.fromMap(map)).toList();
  }

  Future<void> insertChatMessage(ChatMessage msg) async {
    if (_isWebOrTest) {
      _webChatMessages.removeWhere((m) => m['id'] == msg.id);
      _webChatMessages.add(msg.toMap());
      return;
    }
    final db = await _dbHelper.database;
    await db.insert(
      'chat_messages',
      msg.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> clearChatHistory() async {
    if (_isWebOrTest) {
      _webChatMessages.clear();
      return;
    }
    final db = await _dbHelper.database;
    await db.delete('chat_messages');
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

      final noteMaps = _webNotes.where((n) {
        final title = (n['title'] as String? ?? '').toLowerCase();
        final content = (n['content'] as String? ?? '').toLowerCase();
        final subj = (n['subject'] as String? ?? '').toLowerCase();
        final cat = (n['category'] as String? ?? '').toLowerCase();
        return title.contains(cleanQuery) || content.contains(cleanQuery) || subj.contains(cleanQuery) || cat.contains(cleanQuery);
      }).toList();

      final events = eventMaps.map((map) => EventModel.fromMap(map)).toList();
      final tasks = taskMaps.map((map) => TaskModel.fromMap(map)).toList();
      
      List<NoteModel> notes = [];
      for (var map in noteMaps) {
        final id = map['id'] as String;
        final tags = _getNoteTagsWeb(id);
        notes.add(NoteModel.fromMap(map, tags: tags));
      }

      return {
        'events': events,
        'tasks': tasks,
        'notes': notes,
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

    final List<Map<String, dynamic>> noteMaps = await db.query(
      'notes',
      where: 'title LIKE ? OR content LIKE ? OR subject LIKE ? OR category LIKE ?',
      whereArgs: [cleanQuery, cleanQuery, cleanQuery, cleanQuery],
    );

    final events = eventMaps.map((map) => EventModel.fromMap(map)).toList();
    final tasks = taskMaps.map((map) => TaskModel.fromMap(map)).toList();
    
    List<NoteModel> notes = [];
    for (var map in noteMaps) {
      final id = map['id'] as String;
      final tags = await _getNoteTags(id);
      notes.add(NoteModel.fromMap(map, tags: tags));
    }

    return {
      'events': events,
      'tasks': tasks,
      'notes': notes,
    };
  }
}
