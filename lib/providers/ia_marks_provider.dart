import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/ia_mark_model.dart';
import '../repositories/ia_marks_repository.dart';

// ──────────────────────────────────────────────
// State
// ──────────────────────────────────────────────

class IaMarksState {
  /// All IA marks keyed by subjectId → list of up to 3 IaMarkModels
  final Map<String, List<IaMarkModel>> marksBySubject;
  final bool isLoading;

  const IaMarksState({
    this.marksBySubject = const {},
    this.isLoading = false,
  });

  IaMarksState copyWith({
    Map<String, List<IaMarkModel>>? marksBySubject,
    bool? isLoading,
  }) {
    return IaMarksState(
      marksBySubject: marksBySubject ?? this.marksBySubject,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

// ──────────────────────────────────────────────
// Provider
// ──────────────────────────────────────────────

final iaMarksRepositoryProvider = Provider<IaMarksRepository>((ref) {
  return IaMarksRepository();
});

final iaMarksProvider =
    StateNotifierProvider<IaMarksNotifier, IaMarksState>((ref) {
  final repo = ref.watch(iaMarksRepositoryProvider);
  return IaMarksNotifier(repo);
});

// ──────────────────────────────────────────────
// Notifier
// ──────────────────────────────────────────────

class IaMarksNotifier extends StateNotifier<IaMarksState> {
  final IaMarksRepository _repo;
  final _uuid = const Uuid();

  IaMarksNotifier(this._repo) : super(const IaMarksState()) {
    loadAll();
  }

  Future<void> loadAll() async {
    state = state.copyWith(isLoading: true);
    try {
      final all = await _repo.getAllMarks();
      final Map<String, List<IaMarkModel>> grouped = {};
      for (final mark in all) {
        grouped.putIfAbsent(mark.subjectId, () => []).add(mark);
      }
      // Sort each subject's list by IA number
      for (final list in grouped.values) {
        list.sort((a, b) => a.iaNumber.compareTo(b.iaNumber));
      }
      state = IaMarksState(marksBySubject: grouped, isLoading: false);
    } catch (e) {
      print('IaMarksNotifier: loadAll error: $e');
      state = state.copyWith(isLoading: false);
    }
  }

  /// Save or update a single IA mark for a subject.
  /// [iaNumber] must be 1, 2, or 3.
  /// [obtained] is the raw marks out of 50.
  Future<void> saveMark({
    required String subjectId,
    required int iaNumber,
    required double obtained,
  }) async {
    // Check if there is already a mark for this subject + IA number
    final existing = state.marksBySubject[subjectId]
        ?.firstWhere((m) => m.iaNumber == iaNumber, orElse: () => IaMarkModel(id: '', subjectId: subjectId, iaNumber: iaNumber, obtained: 0));

    final mark = IaMarkModel(
      id: (existing != null && existing.id.isNotEmpty) ? existing.id : _uuid.v4(),
      subjectId: subjectId,
      iaNumber: iaNumber,
      obtained: obtained,
    );
    await _repo.upsertMark(mark);
    await loadAll();
  }

  Future<void> deleteMark(String markId) async {
    await _repo.deleteMark(markId);
    await loadAll();
  }

  Future<void> clearAllMarksForSubject(String subjectId) async {
    await _repo.deleteAllMarksForSubject(subjectId);
    await loadAll();
  }

  // ──────────────────────────────────────────────
  // Business Logic — Best of 2 (no scaling)
  // ──────────────────────────────────────────────

  /// Minimum marks per IA required to be considered for best-of-2 selection.
  static const double iaMinimumMarks = 20.0;

  /// Maximum marks per IA
  static const double iaMaxMarks = 50.0;

  /// Green threshold for best-of-2 total
  static const double greenThreshold = 36.0;

  /// Returns the IA marks list for a subject (sorted by IA number).
  List<IaMarkModel> getMarksForSubject(String subjectId) {
    return state.marksBySubject[subjectId] ?? [];
  }

  /// Returns a [IaBestOf2Result] containing which IAs are counted and the total.
  IaBestOf2Result computeBestOf2(String subjectId) {
    final marks = getMarksForSubject(subjectId);

    // Build a map: iaNumber → obtained
    final Map<int, double> marksMap = {for (var m in marks) m.iaNumber: m.obtained};

    // Collect all 3 IAs (null if not entered)
    final ia1 = marksMap[1];
    final ia2 = marksMap[2];
    final ia3 = marksMap[3];

    // Only IAs with obtained >= minimum qualify
    final candidates = <int, double>{};
    if (ia1 != null && ia1 >= iaMinimumMarks) candidates[1] = ia1;
    if (ia2 != null && ia2 >= iaMinimumMarks) candidates[2] = ia2;
    if (ia3 != null && ia3 >= iaMinimumMarks) candidates[3] = ia3;

    // Pick top 2 by marks
    final sorted = candidates.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final best = sorted.take(2).toList();
    final bestNumbers = best.map((e) => e.key).toSet();
    final total = best.fold(0.0, (sum, e) => sum + e.value);

    return IaBestOf2Result(
      ia1: ia1,
      ia2: ia2,
      ia3: ia3,
      bestIaNumbers: bestNumbers,
      total: total,
      countedIas: best.length,
    );
  }
}

// ──────────────────────────────────────────────
// Result Model
// ──────────────────────────────────────────────

class IaBestOf2Result {
  final double? ia1;
  final double? ia2;
  final double? ia3;

  /// Which IA numbers (1, 2, or 3) are selected as best-of-2
  final Set<int> bestIaNumbers;

  /// Sum of best 2 raw marks
  final double total;

  /// How many IAs are actually counted (could be < 2 if fewer qualify)
  final int countedIas;

  const IaBestOf2Result({
    required this.ia1,
    required this.ia2,
    required this.ia3,
    required this.bestIaNumbers,
    required this.total,
    required this.countedIas,
  });

  /// True if total > 36
  bool get isGreen => total > IaMarksNotifier.greenThreshold;

  /// Whether an IA was entered but is below the minimum (flagged as disqualified)
  bool isDisqualified(int iaNumber) {
    final obtained = iaNumber == 1 ? ia1 : iaNumber == 2 ? ia2 : ia3;
    if (obtained == null) return false;
    return obtained < IaMarksNotifier.iaMinimumMarks;
  }

  bool isCounted(int iaNumber) => bestIaNumbers.contains(iaNumber);
}
