import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:sqflite/sqflite.dart' show getDatabasesPath;
import 'package:path/path.dart' show join;
import 'package:permission_handler/permission_handler.dart';
import '../models/past_semester_model.dart';
import '../repositories/past_semester_repository.dart';
import '../core/database_helper.dart';
import '../repositories/settings_repository.dart';

final pastSemesterRepositoryProvider = Provider<PastSemesterRepository>((ref) {
  return PastSemesterRepository();
});

final pastSemesterProvider = StateNotifierProvider<PastSemesterNotifier, List<PastSemesterModel>>((ref) {
  final repo = ref.watch(pastSemesterRepositoryProvider);
  return PastSemesterNotifier(repo);
});

class PastSemesterNotifier extends StateNotifier<List<PastSemesterModel>> {
  final PastSemesterRepository _repo;

  PastSemesterNotifier(this._repo) : super([]) {
    loadPastSemesters();
  }

  Future<void> loadPastSemesters() async {
    final list = await _repo.getPastSemesters();
    state = list;
  }

  Future<void> archiveSemester({
    required String name,
    required String startDate,
    required String endDate,
    required List<dynamic> subjects, // List<SubjectModel>
    required Map<String, Map<String, dynamic>> subjectStats,
    required Map<String, List<double?>> subjectIaMarks, // maps subjectId to List of [ia1, ia2, ia3]
  }) async {
    final List<Map<String, dynamic>> compiledList = [];

    for (var sub in subjects) {
      final subId = sub.id;
      final stats = subjectStats[subId] ?? {'held': 0, 'attended': 0, 'percentage': 0.0};
      final iaList = subjectIaMarks[subId] ?? [null, null, null];
      
      // Compute Best of 2 Total
      double? ia1 = iaList.length > 0 ? iaList[0] : null;
      double? ia2 = iaList.length > 1 ? iaList[1] : null;
      double? ia3 = iaList.length > 2 ? iaList[2] : null;
      
      final marks = [ia1 ?? 0.0, ia2 ?? 0.0, ia3 ?? 0.0];
      marks.sort((a, b) => b.compareTo(a)); // Descending order
      double bestOfTwo = marks[0] + marks[1];

      compiledList.add({
        'subjectId': subId,
        'subjectName': sub.name,
        'subjectCode': sub.code,
        'minPercentage': sub.minPercentage,
        'heldClasses': stats['held'] ?? 0,
        'attendedClasses': stats['attended'] ?? 0,
        'attendancePercentage': stats['percentage'] ?? 0.0,
        'ia1': ia1,
        'ia2': ia2,
        'ia3': ia3,
        'bestOfTwo': bestOfTwo,
      });
    }

    final compiledJson = jsonEncode(compiledList);

    final sem = PastSemesterModel(
      id: const Uuid().v4(),
      name: name,
      startDate: startDate,
      endDate: endDate,
      compiledJson: compiledJson,
    );

    await _repo.insertPastSemester(sem);
    await loadPastSemesters();
  }

  Future<void> deleteSemester(String id) async {
    await _repo.deletePastSemester(id);
    await loadPastSemesters();
  }

  Future<String> downloadSemesterReport(PastSemesterModel sem) async {
    // Generate human-readable text report
    final buffer = StringBuffer();
    buffer.writeln('========================================');
    buffer.writeln('    NOVA STUDY ACADEMIC SEMESTER REPORT  ');
    buffer.writeln('========================================');
    buffer.writeln('Semester Name : ${sem.name}');
    buffer.writeln('Start Date    : ${sem.startDate}');
    buffer.writeln('End Date      : ${sem.endDate}');
    buffer.writeln('Report Date   : ${DateTime.now().toIso8601String().split('T')[0]}');
    buffer.writeln('----------------------------------------');
    buffer.writeln('');

    final List<dynamic> data = jsonDecode(sem.compiledJson);
    for (var item in data) {
      final codeStr = item['subjectCode'] != null ? '[${item['subjectCode']}] ' : '';
      buffer.writeln('Subject: $codeStr${item['subjectName']}');
      
      final double attPercent = (item['attendancePercentage'] as num).toDouble();
      final int attended = (item['attendedClasses'] as num).toInt();
      final int held = (item['heldClasses'] as num).toInt();
      buffer.writeln('  Attendance: ${attPercent.toStringAsFixed(1)}% ($attended/$held classes)');
      
      final ia1 = item['ia1'];
      final ia2 = item['ia2'];
      final ia3 = item['ia3'];
      final double bestOfTwo = (item['bestOfTwo'] as num).toDouble();
      buffer.writeln('  IA Marks:');
      buffer.writeln('    IA-1: ${ia1 ?? "N/A"}');
      buffer.writeln('    IA-2: ${ia2 ?? "N/A"}');
      buffer.writeln('    IA-3: ${ia3 ?? "N/A"}');
      buffer.writeln('    Best of 2 Total: ${bestOfTwo.toStringAsFixed(1)} / 100.0');
      buffer.writeln('----------------------------------------');
    }

    final reportContent = buffer.toString();
    final fileName = 'NovaStudy_${sem.name.replaceAll(' ', '_')}_Report.txt';

    // Request permissions
    await Permission.storage.request();

    Directory? targetDir;
    if (Platform.isAndroid) {
      // Try creating directory in external Downloads folder
      final downloadsPath = Directory('/storage/emulated/0/Download/NovaStudyApp');
      try {
        if (!await downloadsPath.exists()) {
          await downloadsPath.create(recursive: true);
        }
        targetDir = downloadsPath;
      } catch (_) {
        // Fallback to local files if fails
      }
    }

    if (targetDir == null) {
      // Local fallback (documents folder derived from db path)
      final dbPath = await getDatabasesPath();
      final localFolder = Directory(join(Directory(dbPath).parent.path, 'files'));
      if (!await localFolder.exists()) {
        await localFolder.create(recursive: true);
      }
      targetDir = localFolder;
    }

    final file = File(join(targetDir.path, fileName));
    await file.writeAsString(reportContent);
    return file.path;
  }

  Future<void> resetSemester() async {
    if (!kIsWeb) {
      final dbHelper = DatabaseHelper();
      final db = await dbHelper.database;
      await db.delete('subjects');
      await db.delete('timetable_slots');
      await db.delete('attendance_logs');
      await db.delete('ia_marks');
      
      final settingsRepo = SettingsRepository();
      await settingsRepo.deleteSetting('semester_start_date');
      await settingsRepo.deleteSetting('semester_end_date');
      await settingsRepo.deleteSetting('semester_name');
    }
  }
}
