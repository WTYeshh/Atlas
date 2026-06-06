import 'dart:io' show Platform;
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (kIsWeb || (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST'))) {
      throw UnsupportedError('DatabaseHelper is not supported on Web/Test. Use in-memory fallback.');
    }
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'atlas.db');

    return await openDatabase(
      path,
      version: 3,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Events table
    await db.execute('''
      CREATE TABLE events (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        date TEXT NOT NULL,
        time TEXT NOT NULL,
        description TEXT,
        category TEXT,
        reminder_id INTEGER,
        google_event_id TEXT,
        updated_at TEXT NOT NULL
      )
    ''');

    // Tasks table
    await db.execute('''
      CREATE TABLE tasks (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        due_date TEXT NOT NULL,
        priority TEXT NOT NULL,
        subject TEXT,
        status TEXT NOT NULL,
        reminder_id INTEGER,
        updated_at TEXT NOT NULL
      )
    ''');

    // Notes table
    await db.execute('''
      CREATE TABLE notes (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        content TEXT,
        type TEXT NOT NULL,
        subject TEXT,
        category TEXT,
        summary TEXT,
        file_path TEXT,
        drive_file_id TEXT,
        updated_at TEXT NOT NULL
      )
    ''');

    // Tags table (for Notes)
    await db.execute('''
      CREATE TABLE tags (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL UNIQUE
      )
    ''');

    // Note Tags relation table
    await db.execute('''
      CREATE TABLE note_tags (
        note_id TEXT,
        tag_id TEXT,
        PRIMARY KEY (note_id, tag_id),
        FOREIGN KEY (note_id) REFERENCES notes (id) ON DELETE CASCADE,
        FOREIGN KEY (tag_id) REFERENCES tags (id) ON DELETE CASCADE
      )
    ''');

    // Chat messages table (for Assistant history)
    await db.execute('''
      CREATE TABLE chat_messages (
        id TEXT PRIMARY KEY,
        role TEXT NOT NULL,
        message TEXT NOT NULL,
        timestamp TEXT NOT NULL
      )
    ''');

    // Settings table
    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');

    // Sync queue table
    await db.execute('''
      CREATE TABLE sync_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        entity_type TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        action TEXT NOT NULL,
        payload TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    // Subjects table
    await db.execute('''
      CREATE TABLE subjects (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        code TEXT,
        min_percentage REAL DEFAULT 75.0
      )
    ''');

    // Timetable Slots table
    await db.execute('''
      CREATE TABLE timetable_slots (
        id TEXT PRIMARY KEY,
        subject_id TEXT NOT NULL,
        day_of_week INTEGER NOT NULL,
        start_time TEXT NOT NULL,
        end_time TEXT NOT NULL,
        classroom TEXT,
        FOREIGN KEY (subject_id) REFERENCES subjects (id) ON DELETE CASCADE
      )
    ''');

    // Attendance logs table
    await db.execute('''
      CREATE TABLE attendance_logs (
        id TEXT PRIMARY KEY,
        subject_id TEXT NOT NULL,
        date TEXT NOT NULL,
        status TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (subject_id) REFERENCES subjects (id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE settings (
          key TEXT PRIMARY KEY,
          value TEXT
        )
      ''');
      await db.execute('''
        CREATE TABLE sync_queue (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          entity_type TEXT NOT NULL,
          entity_id TEXT NOT NULL,
          action TEXT NOT NULL,
          payload TEXT,
          created_at TEXT NOT NULL
        )
      ''');
    }
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE subjects (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          code TEXT,
          min_percentage REAL DEFAULT 75.0
        )
      ''');
      await db.execute('''
        CREATE TABLE timetable_slots (
          id TEXT PRIMARY KEY,
          subject_id TEXT NOT NULL,
          day_of_week INTEGER NOT NULL,
          start_time TEXT NOT NULL,
          end_time TEXT NOT NULL,
          classroom TEXT,
          FOREIGN KEY (subject_id) REFERENCES subjects (id) ON DELETE CASCADE
        )
      ''');
      await db.execute('''
        CREATE TABLE attendance_logs (
          id TEXT PRIMARY KEY,
          subject_id TEXT NOT NULL,
          date TEXT NOT NULL,
          status TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          FOREIGN KEY (subject_id) REFERENCES subjects (id) ON DELETE CASCADE
        )
      ''');
    }
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
