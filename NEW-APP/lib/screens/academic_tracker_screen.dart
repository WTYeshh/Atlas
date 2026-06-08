import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/academic_provider.dart';
import '../providers/attendance_provider.dart';
import '../providers/ia_marks_provider.dart';
import '../models/semester_model.dart';
import '../models/course_model.dart';
import '../models/subject_model.dart';

class AcademicTrackerScreen extends ConsumerStatefulWidget {
  const AcademicTrackerScreen({super.key});

  @override
  ConsumerState<AcademicTrackerScreen> createState() => _AcademicTrackerScreenState();
}

class _AcademicTrackerScreenState extends ConsumerState<AcademicTrackerScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // IA Marks tab state
  String? _selectedSubjectId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────
  // Semester / Course dialogs (unchanged)
  // ─────────────────────────────────────────────

  void _showSemesterDialog({SemesterModel? semester}) {
    final nameController = TextEditingController(text: semester?.name ?? '');
    final targetController = TextEditingController(text: semester?.targetGpa?.toString() ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(semester == null ? 'Add Semester' : 'Edit Semester',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Semester Name',
                hintText: 'e.g. Semester 1, Fall 2026',
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: targetController,
              decoration: const InputDecoration(
                labelText: 'Target SGPA (Optional)',
                hintText: 'e.g. 8.5',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) return;

              final target = double.tryParse(targetController.text.trim());
              final notifier = ref.read(academicProvider.notifier);

              if (semester == null) {
                await notifier.addSemester(name, targetGpa: target);
              } else {
                await notifier.updateSemester(semester.copyWith(name: name, targetGpa: target));
              }

              if (context.mounted) Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor),
            child: Text('Save', style: TextStyle(color: Theme.of(context).colorScheme.onPrimary)),
          ),
        ],
      ),
    );
  }

  void _showCourseDialog(String semesterId, {CourseModel? course}) {
    final nameController = TextEditingController(text: course?.name ?? '');
    final creditsController = TextEditingController(text: course?.credits.toString() ?? '4.0');
    final marksController = TextEditingController(text: course?.marks?.toString() ?? '');
    bool isCompleted = course?.isCompleted ?? true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: Text(course == null ? 'Add Course' : 'Edit Course',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Course Name',
                    hintText: 'e.g. Data Structures',
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: creditsController,
                  decoration: const InputDecoration(
                    labelText: 'Course Credits',
                    hintText: 'e.g. 4.0, 3.0',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: marksController,
                  decoration: const InputDecoration(
                    labelText: 'Total Marks (0-100)',
                    hintText: 'e.g. 85 (leave empty if ungraded)',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 16),
                CheckboxListTile(
                  title: const Text('Completed & Graded', style: TextStyle(fontSize: 14)),
                  subtitle: const Text(
                    'Uncheck to treat as a "What-If" simulated course',
                    style: TextStyle(fontSize: 11),
                  ),
                  value: isCompleted,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (val) {
                    if (val != null) setStateDialog(() => isCompleted = val);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            if (course != null)
              TextButton(
                onPressed: () async {
                  await ref.read(academicProvider.notifier).deleteCourse(course.id);
                  if (context.mounted) Navigator.pop(context);
                },
                child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
              ),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                final credits = double.tryParse(creditsController.text.trim()) ?? 4.0;
                final marks = double.tryParse(marksController.text.trim());
                if (name.isEmpty) return;

                final notifier = ref.read(academicProvider.notifier);
                if (course == null) {
                  await notifier.addCourse(
                    semesterId: semesterId,
                    name: name,
                    credits: credits,
                    marks: marks,
                    isCompleted: isCompleted,
                  );
                } else {
                  await notifier.updateCourse(course.copyWith(
                    name: name,
                    credits: credits,
                    marks: marks,
                    gradePoint: null,
                    isCompleted: isCompleted,
                  ));
                }

                if (context.mounted) Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor),
              child: Text('Save', style: TextStyle(color: Theme.of(context).colorScheme.onPrimary)),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // IA Marks dialog — enter marks for one IA
  // ─────────────────────────────────────────────

  void _showIaMarkDialog({
    required SubjectModel subject,
    required int iaNumber,
    double? currentValue,
  }) {
    final controller = TextEditingController(
      text: currentValue != null ? currentValue.toStringAsFixed(0) : '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'IA-$iaNumber — ${subject.name}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Marks Obtained (out of 50)',
                hintText: 'e.g. 32',
                suffixText: '/ 50',
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.withOpacity(0.3)),
              ),
              child: const Text(
                'Min 20/50 required for this IA to qualify for Best-of-2.',
                style: TextStyle(fontSize: 12, color: Colors.amber),
              ),
            ),
          ],
        ),
        actions: [
          if (currentValue != null)
            TextButton(
              onPressed: () async {
                final marks = ref.read(iaMarksProvider).marksBySubject[subject.id] ?? [];
                final toDelete = marks.where((m) => m.iaNumber == iaNumber).toList();
                for (final m in toDelete) {
                  await ref.read(iaMarksProvider.notifier).deleteMark(m.id);
                }
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Clear', style: TextStyle(color: Colors.redAccent)),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final val = double.tryParse(controller.text.trim());
              if (val == null || val < 0 || val > 50) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Enter a valid score between 0 and 50.')),
                );
                return;
              }
              final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
              final inRange = ref.read(attendanceProvider.notifier).isDateWithinSemesterRange(todayStr);
              if (!inRange) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Cannot save IA marks outside semester range (5 days margin).'),
                    backgroundColor: Colors.redAccent,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                return;
              }
              await ref.read(iaMarksProvider.notifier).saveMark(
                    subjectId: subject.id,
                    iaNumber: iaNumber,
                    obtained: val,
                  );
              if (context.mounted) Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor),
            child: Text('Save', style: TextStyle(color: Theme.of(context).colorScheme.onPrimary)),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(academicProvider);
    final notifier = ref.read(academicProvider.notifier);

    final actualCgpa = notifier.getOverallCgpa(includeSimulated: false);
    final simulatedCgpa = notifier.getOverallCgpa(includeSimulated: true);
    final actualCredits = notifier.getTotalCredits(includeSimulated: false);
    final simulatedCredits = notifier.getTotalCredits(includeSimulated: true);

    return Scaffold(
      appBar: AppBar(
        title: const Text('ACADEMIC TRACKER', style: TextStyle(fontWeight: FontWeight.w900)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Theme.of(context).primaryColor,
          tabs: const [
            Tab(text: 'Semesters'),
            Tab(text: 'IA Marks'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'Add Semester',
            onPressed: () => _showSemesterDialog(),
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ── Tab 1: Semesters ──────────────────────────────
          state.isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: () => notifier.loadAll(),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildCgpaSummaryCard(actualCgpa, simulatedCgpa, actualCredits, simulatedCredits),
                        const SizedBox(height: 20),
                        const Text(
                          'Semesters Breakdown',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 10),
                        state.semesters.isEmpty
                            ? Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(20.0),
                                  child: Center(
                                    child: Column(
                                      children: [
                                        const Text('No semesters added yet.'),
                                        const SizedBox(height: 8),
                                        ElevatedButton(
                                          onPressed: () => _showSemesterDialog(),
                                          child: const Text('Create Semester'),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              )
                            : Column(
                                children: state.semesters
                                    .map((sem) => _buildSemesterCard(
                                          sem,
                                          state.courses[sem.id] ?? [],
                                          notifier,
                                        ))
                                    .toList(),
                              ),
                      ],
                    ),
                  ),
                ),

          // ── Tab 2: IA Marks ──────────────────────────────
          _buildIaMarksTab(),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // IA Marks Tab
  // ─────────────────────────────────────────────

  Widget _buildIaMarksTab() {
    final attendanceState = ref.watch(attendanceProvider);
    final iaState = ref.watch(iaMarksProvider);
    final iaNotifier = ref.read(iaMarksProvider.notifier);
    final subjects = attendanceState.subjects;
    final primaryColor = Theme.of(context).primaryColor;

    if (attendanceState.isLoading || iaState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (subjects.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.assignment_outlined, size: 72, color: primaryColor.withOpacity(0.4)),
              const SizedBox(height: 16),
              const Text(
                'No subjects found',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 8),
              const Text(
                'Add subjects in the Attendance Tracker first. IA marks will use the same subject list.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    // Auto-select the first subject if none selected (or if the selected one was removed)
    if (_selectedSubjectId == null || !subjects.any((s) => s.id == _selectedSubjectId)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _selectedSubjectId = subjects.first.id);
      });
    }

    final selectedSubject = subjects.firstWhere(
      (s) => s.id == _selectedSubjectId,
      orElse: () => subjects.first,
    );

    return Row(
      children: [
        // ── Subject List (left panel) ────────────────
        Container(
          width: 130,
          decoration: BoxDecoration(
            border: Border(right: BorderSide(color: Theme.of(context).dividerColor)),
          ),
          child: ListView.builder(
            itemCount: subjects.length,
            itemBuilder: (context, index) {
              final subject = subjects[index];
              final result = iaNotifier.computeBestOf2(subject.id);
              final isSelected = subject.id == _selectedSubjectId;

              Color dotColor = Colors.grey;
              if (result.countedIas > 0) {
                dotColor = result.isGreen ? Colors.green : Colors.redAccent;
              }

              return InkWell(
                onTap: () => setState(() => _selectedSubjectId = subject.id),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? primaryColor.withOpacity(0.08) : Colors.transparent,
                    border: Border(
                      left: BorderSide(
                        color: isSelected ? primaryColor : Colors.transparent,
                        width: 3,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: dotColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (subject.code != null)
                              Text(
                                subject.code!,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected ? primaryColor : Theme.of(context).colorScheme.onSurface,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            Text(
                              subject.name,
                              style: TextStyle(
                                fontSize: 11,
                                color: isSelected
                                    ? primaryColor
                                    : Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        // ── IA Detail Panel (right) ───────────────────
        Expanded(
          child: _buildIaDetailPanel(selectedSubject, iaNotifier),
        ),
      ],
    );
  }

  Widget _buildIaDetailPanel(SubjectModel subject, IaMarksNotifier iaNotifier) {
    final result = iaNotifier.computeBestOf2(subject.id);
    final primaryColor = Theme.of(context).primaryColor;

    final bool hasAnyMark = result.ia1 != null || result.ia2 != null || result.ia3 != null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Subject name header
          Text(
            subject.code != null ? '[${subject.code}] ${subject.name}' : subject.name,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: primaryColor,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),

          // Best-of-2 Summary card
          _buildBestOf2SummaryCard(result),

          const SizedBox(height: 14),

          // Info rule banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.07),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.withOpacity(0.25)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 14, color: Colors.amber),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Best 2 of 3 IAs counted  •  Min 20/50 per IA  •  Green if total > 36',
                    style: TextStyle(fontSize: 11, color: Colors.amber),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // IA-1 card
          _buildIaCard(
            subject: subject,
            iaNumber: 1,
            obtained: result.ia1,
            isCounted: result.isCounted(1),
            isDisqualified: result.isDisqualified(1),
          ),
          const SizedBox(height: 10),

          // IA-2 card
          _buildIaCard(
            subject: subject,
            iaNumber: 2,
            obtained: result.ia2,
            isCounted: result.isCounted(2),
            isDisqualified: result.isDisqualified(2),
          ),
          const SizedBox(height: 10),

          // IA-3 card
          _buildIaCard(
            subject: subject,
            iaNumber: 3,
            obtained: result.ia3,
            isCounted: result.isCounted(3),
            isDisqualified: result.isDisqualified(3),
          ),

          if (!hasAnyMark) ...[
            const SizedBox(height: 16),
            Center(
              child: Text(
                'Tap any IA card to enter marks',
                style: TextStyle(fontSize: 12, color: Colors.grey.withOpacity(0.7)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBestOf2SummaryCard(IaBestOf2Result result) {
    final primaryColor = Theme.of(context).primaryColor;
    final bool hasData = result.countedIas > 0;
    final Color scoreColor = hasData
        ? (result.isGreen ? Colors.green : Colors.redAccent)
        : Colors.grey;

    // Which IAs are counted for display label
    String countedLabel = '';
    if (result.countedIas > 0) {
      final nums = result.bestIaNumbers.toList()..sort();
      countedLabel = 'IA-${nums.join(" & IA-")} counted';
    }

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      shadowColor: scoreColor.withOpacity(0.2),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            colors: [
              scoreColor.withOpacity(0.07),
              scoreColor.withOpacity(0.02),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            // Score
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'BEST OF 2 TOTAL',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                    color: Colors.grey,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      hasData ? result.total.toStringAsFixed(0) : '--',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 40,
                        color: scoreColor,
                        height: 1.0,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        ' / 100',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.grey.withOpacity(0.7),
                        ),
                      ),
                    ),
                  ],
                ),
                if (countedLabel.isNotEmpty)
                  Text(
                    countedLabel,
                    style: TextStyle(fontSize: 11, color: scoreColor),
                  ),
              ],
            ),

            const Spacer(),

            // Status badge
            if (hasData)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: scoreColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: scoreColor.withOpacity(0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      result.isGreen ? Icons.check_circle_outline : Icons.warning_amber_rounded,
                      size: 14,
                      color: scoreColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      result.isGreen ? 'GOOD' : 'LOW',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: scoreColor,
                      ),
                    ),
                  ],
                ),
              )
            else
              Icon(Icons.edit_note_outlined, color: primaryColor.withOpacity(0.4), size: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildIaCard({
    required SubjectModel subject,
    required int iaNumber,
    required double? obtained,
    required bool isCounted,
    required bool isDisqualified,
  }) {
    final primaryColor = Theme.of(context).primaryColor;
    final bool isEmpty = obtained == null;

    Color headerColor = primaryColor;
    Color badgeColor = Colors.grey;
    String badgeText = 'NOT ENTERED';
    IconData badgeIcon = Icons.edit_outlined;

    if (!isEmpty) {
      if (isDisqualified) {
        headerColor = Colors.redAccent;
        badgeColor = Colors.redAccent;
        badgeText = 'BELOW MIN';
        badgeIcon = Icons.cancel_outlined;
      } else if (isCounted) {
        headerColor = Colors.green.shade700;
        badgeColor = Colors.green;
        badgeText = 'COUNTED';
        badgeIcon = Icons.check_circle_outline;
      } else {
        // Qualified but not in best 2
        headerColor = primaryColor.withOpacity(0.7);
        badgeColor = Colors.grey;
        badgeText = 'NOT BEST';
        badgeIcon = Icons.remove_circle_outline;
      }
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showIaMarkDialog(
          subject: subject,
          iaNumber: iaNumber,
          currentValue: obtained,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // IA header strip
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [headerColor, headerColor.withOpacity(0.75)],
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Internal Assessment $iaNumber',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  Icon(Icons.edit, color: Colors.white.withOpacity(0.7), size: 14),
                ],
              ),
            ),

            // Body
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  _buildIaStatCol('Max Marks', '50'),
                  const VerticalDivider(width: 24),
                  _buildIaStatCol(
                    'Obtained',
                    isEmpty ? '—' : obtained!.toStringAsFixed(0),
                    highlight: !isEmpty,
                  ),
                  const Spacer(),
                  // Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: badgeColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: badgeColor.withOpacity(0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(badgeIcon, size: 12, color: badgeColor),
                        const SizedBox(width: 4),
                        Text(
                          badgeText,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: badgeColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Warning if below minimum
            if (isDisqualified)
              Padding(
                padding: const EdgeInsets.only(left: 14, right: 14, bottom: 10),
                child: Text(
                  '⚠ Below minimum 20 marks — not eligible for Best-of-2',
                  style: TextStyle(fontSize: 11, color: Colors.redAccent.withOpacity(0.8)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildIaStatCol(String label, String value, {bool highlight = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Colors.grey),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: highlight ? Theme.of(context).colorScheme.onSurface : Colors.grey,
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────
  // Semester Tab Widgets (unchanged from before)
  // ─────────────────────────────────────────────

  Widget _buildCgpaSummaryCard(
      double actualCgpa, double simulatedCgpa, double actualCreds, double simCreds) {
    final primaryColor = Theme.of(context).primaryColor;
    final bool hasSim = simulatedCgpa != actualCgpa || simCreds != actualCreds;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      shadowColor: primaryColor.withOpacity(0.1),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [primaryColor.withOpacity(0.08), primaryColor.withOpacity(0.02)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(20.0),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'CUMULATIVE CGPA',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey, letterSpacing: 1.0),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    actualCgpa.toStringAsFixed(2),
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 36, color: primaryColor),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Credits Earned: ${actualCreds.toInt()}',
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ],
              ),
            ),
            if (hasSim) ...[
              Container(width: 1, height: 70, color: Colors.grey.withOpacity(0.2)),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'SIMULATED CGPA',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: Colors.orangeAccent,
                          letterSpacing: 1.0),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      simulatedCgpa.toStringAsFixed(2),
                      style: const TextStyle(
                          fontWeight: FontWeight.w900, fontSize: 36, color: Colors.orangeAccent),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Total Sim Credits: ${simCreds.toInt()}',
                      style: const TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSemesterCard(SemesterModel semester, List<CourseModel> courses,
      AcademicNotifier notifier) {
    final double actualSgpa = notifier.getSemesterSgpa(semester.id, includeSimulated: false);
    final double simulatedSgpa = notifier.getSemesterSgpa(semester.id, includeSimulated: true);
    final bool hasSim = simulatedSgpa != actualSgpa;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        title: Text(semester.name,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Row(
          children: [
            Text(
              'SGPA: ${actualSgpa.toStringAsFixed(2)}',
              style: TextStyle(
                  color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold, fontSize: 13),
            ),
            if (hasSim) ...[
              const SizedBox(width: 8),
              Text(
                '(Sim: ${simulatedSgpa.toStringAsFixed(2)})',
                style: const TextStyle(
                    color: Colors.orangeAccent, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ],
            const SizedBox(width: 12),
            Text(
              '•  ${courses.length} Course${courses.length != 1 ? 's' : ''}',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (val) {
            if (val == 'edit') {
              _showSemesterDialog(semester: semester);
            } else if (val == 'delete') {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Delete Semester?'),
                  content: Text(
                      'Are you sure you want to delete "${semester.name}"? This deletes all courses inside it.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                    TextButton(
                      onPressed: () {
                        notifier.deleteSemester(semester.id);
                        Navigator.pop(context);
                      },
                      child: const Text('Delete', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem(value: 'edit', child: Text('Edit Semester')),
            PopupMenuItem(
                value: 'delete',
                child: Text('Delete Semester', style: TextStyle(color: Colors.red))),
          ],
        ),
        children: [
          const Divider(height: 1),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: courses.length,
            separatorBuilder: (context, i) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final course = courses[i];
              return ListTile(
                title: Text(
                  course.name,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: course.isCompleted ? null : Colors.orangeAccent,
                  ),
                ),
                subtitle: Text(
                  course.marks != null
                      ? 'Credits: ${course.credits}  •  Marks: ${course.marks!.toStringAsFixed(0)} (${course.calculatedGrade})'
                      : 'Credits: ${course.credits}  ${course.isCompleted ? "" : "• [SIMULATED]"}',
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: Text(
                  course.calculatedGradePoint != null
                      ? course.calculatedGradePoint!.toStringAsFixed(1)
                      : 'Ungraded',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: course.isCompleted
                        ? Theme.of(context).primaryColor
                        : Colors.orangeAccent,
                  ),
                ),
                onTap: () => _showCourseDialog(semester.id, course: course),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  onPressed: () => _showCourseDialog(semester.id),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add Course', style: TextStyle(fontSize: 13)),
                ),
                TextButton.icon(
                  onPressed: () => _showCourseDialog(
                    semester.id,
                    course: CourseModel(
                      id: '',
                      semesterId: semester.id,
                      name: 'Simulated Subject',
                      credits: 4.0,
                      marks: 85.0,
                      isCompleted: false,
                    ),
                  ),
                  icon: const Icon(Icons.science_outlined, size: 16, color: Colors.orangeAccent),
                  label: const Text('Simulate What-If',
                      style: TextStyle(fontSize: 13, color: Colors.orangeAccent)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
