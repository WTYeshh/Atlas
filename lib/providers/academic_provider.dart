import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/semester_model.dart';
import '../models/course_model.dart';
import '../repositories/academic_repository.dart';
import '../repositories/settings_repository.dart';

class AcademicState {
  final List<SemesterModel> semesters;
  final Map<String, List<CourseModel>> courses;
  final bool isLoading;

  AcademicState({
    this.semesters = const [],
    this.courses = const {},
    this.isLoading = false,
  });

  AcademicState copyWith({
    List<SemesterModel>? semesters,
    Map<String, List<CourseModel>>? courses,
    bool? isLoading,
  }) {
    return AcademicState(
      semesters: semesters ?? this.semesters,
      courses: courses ?? this.courses,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

final academicRepositoryProvider = Provider<AcademicRepository>((ref) {
  return AcademicRepository();
});

final academicProvider = StateNotifierProvider<AcademicNotifier, AcademicState>((ref) {
  final repo = ref.watch(academicRepositoryProvider);
  return AcademicNotifier(repo);
});

class AcademicNotifier extends StateNotifier<AcademicState> {
  final AcademicRepository _repo;
  final SettingsRepository _settingsRepo = SettingsRepository();
  final _uuid = const Uuid();

  AcademicNotifier(this._repo) : super(AcademicState()) {
    loadAll();
  }

  Future<void> loadAll() async {
    state = state.copyWith(isLoading: true);
    try {
      final semesters = await _repo.getSemesters();
      final Map<String, List<CourseModel>> coursesMap = {};
      for (var sem in semesters) {
        final courses = await _repo.getCourses(sem.id);
        coursesMap[sem.id] = courses;
      }
      state = AcademicState(
        semesters: semesters,
        courses: coursesMap,
        isLoading: false,
      );
    } catch (e) {
      print('AcademicNotifier: Error loading academic data: $e');
      state = state.copyWith(isLoading: false);
    }
  }

  // --- Semester Actions ---

  Future<void> addSemester(String name, {double? targetGpa}) async {
    final semester = SemesterModel(
      id: _uuid.v4(),
      name: name,
      targetGpa: targetGpa,
    );
    await _repo.insertSemester(semester);
    await loadAll();
  }

  Future<void> updateSemester(SemesterModel semester) async {
    await _repo.updateSemester(semester);
    await loadAll();
  }

  Future<void> deleteSemester(String id) async {
    await _repo.deleteSemester(id);
    await loadAll();
  }

  // --- Course Actions ---

  Future<void> addCourse({
    required String semesterId,
    required String name,
    required double credits,
    double? gradePoint,
    double? marks,
    bool isCompleted = true,
  }) async {
    final course = CourseModel(
      id: _uuid.v4(),
      semesterId: semesterId,
      name: name,
      credits: credits,
      gradePoint: gradePoint,
      marks: marks,
      isCompleted: isCompleted,
    );
    await _repo.insertCourse(course);
    await loadAll();
  }

  Future<void> updateCourse(CourseModel course) async {
    await _repo.updateCourse(course);
    await loadAll();
  }

  Future<void> deleteCourse(String courseId) async {
    await _repo.deleteCourse(courseId);
    await loadAll();
  }

  // --- GPA Calculator Logic ---

  double getSemesterSgpa(String semesterId, {bool includeSimulated = false}) {
    final courses = state.courses[semesterId] ?? [];
    if (courses.isEmpty) return 0.0;

    double totalCredits = 0.0;
    double weightedPoints = 0.0;

    for (var course in courses) {
      if (!includeSimulated && !course.isCompleted) continue;
      final gp = course.calculatedGradePoint;
      if (gp == null) continue;

      totalCredits += course.credits;
      weightedPoints += course.credits * gp;
    }

    if (totalCredits == 0.0) return 0.0;
    return weightedPoints / totalCredits;
  }

  double getOverallCgpa({bool includeSimulated = false}) {
    double totalCredits = 0.0;
    double weightedPoints = 0.0;

    state.courses.forEach((semId, courses) {
      for (var course in courses) {
        if (!includeSimulated && !course.isCompleted) continue;
        final gp = course.calculatedGradePoint;
        if (gp == null) continue;

        totalCredits += course.credits;
        weightedPoints += course.credits * gp;
      }
    });

    if (totalCredits == 0.0) return 0.0;
    return weightedPoints / totalCredits;
  }

  double getTotalCredits({bool includeSimulated = false}) {
    double totalCredits = 0.0;

    state.courses.forEach((semId, courses) {
      for (var course in courses) {
        if (!includeSimulated && !course.isCompleted) continue;
        final gp = course.calculatedGradePoint;
        if (gp == null) continue;

        totalCredits += course.credits;
      }
    });

    return totalCredits;
  }

  // --- Goal Setting Logic ---

  Future<Map<String, dynamic>> getGoalProjections() async {
    final targetStr = await _settingsRepo.getSetting('target_cgpa');
    final totalCreditsStr = await _settingsRepo.getSetting('graduation_credits');

    if (targetStr == null || totalCreditsStr == null) {
      return {'hasGoal': false};
    }

    final double? targetCgpa = double.tryParse(targetStr);
    final double? totalGradCredits = double.tryParse(totalCreditsStr);

    if (targetCgpa == null || totalGradCredits == null || totalGradCredits <= 0.0) {
      return {'hasGoal': false};
    }

    final double completedCredits = getTotalCredits(includeSimulated: false);
    final double currentCgpa = getOverallCgpa(includeSimulated: false);

    final double remainingCredits = totalGradCredits - completedCredits;

    if (remainingCredits <= 0.0) {
      return {
        'hasGoal': true,
        'targetCgpa': targetCgpa,
        'totalGradCredits': totalGradCredits,
        'completedCredits': completedCredits,
        'currentCgpa': currentCgpa,
        'remainingCredits': 0.0,
        'requiredGpa': 0.0,
        'status': currentCgpa >= targetCgpa ? 'achieved' : 'failed',
        'statusMessage': currentCgpa >= targetCgpa 
            ? 'Congratulations! You achieved your target CGPA.' 
            : 'Degrees completed, target was not reached.',
      };
    }

    // Required GPA formula:
    // (targetCGPA * totalCredits - currentCGPA * completedCredits) / remainingCredits
    final double totalNeededPoints = targetCgpa * totalGradCredits;
    final double completedPoints = currentCgpa * completedCredits;
    final double requiredGpa = (totalNeededPoints - completedPoints) / remainingCredits;

    String status = 'on_track';
    String statusMessage = '';

    if (requiredGpa > 10.0) {
      status = 'unreachable';
      statusMessage = 'Target unreachable! Required remaining GPA is ${requiredGpa.toStringAsFixed(2)}, which exceeds the maximum scale.';
    } else if (requiredGpa < 0.0) {
      status = 'safe';
      statusMessage = 'You have already secured enough grade points! You need a 0.0 GPA in remaining subjects to hit your target.';
    } else {
      statusMessage = 'To hit $targetCgpa CGPA, you must average ${requiredGpa.toStringAsFixed(2)} GPA across the remaining ${remainingCredits.toInt()} credits.';
    }

    return {
      'hasGoal': true,
      'targetCgpa': targetCgpa,
      'totalGradCredits': totalGradCredits,
      'completedCredits': completedCredits,
      'currentCgpa': currentCgpa,
      'remainingCredits': remainingCredits,
      'requiredGpa': requiredGpa,
      'status': status,
      'statusMessage': statusMessage,
    };
  }
}
