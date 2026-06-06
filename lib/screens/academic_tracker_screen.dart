import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/academic_provider.dart';
import '../models/semester_model.dart';
import '../models/course_model.dart';
import '../repositories/settings_repository.dart';

class AcademicTrackerScreen extends ConsumerStatefulWidget {
  const AcademicTrackerScreen({super.key});

  @override
  ConsumerState<AcademicTrackerScreen> createState() => _AcademicTrackerScreenState();
}

class _AcademicTrackerScreenState extends ConsumerState<AcademicTrackerScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final SettingsRepository _settingsRepo = SettingsRepository();

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

  // Dialog to Add/Edit a Semester
  void _showSemesterDialog({SemesterModel? semester}) {
    final nameController = TextEditingController(text: semester?.name ?? '');
    final targetController = TextEditingController(text: semester?.targetGpa?.toString() ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(semester == null ? 'Add Semester' : 'Edit Semester', style: const TextStyle(fontWeight: FontWeight.bold)),
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

  // Dialog to Add/Edit a Course
  void _showCourseDialog(String semesterId, {CourseModel? course}) {
    final nameController = TextEditingController(text: course?.name ?? '');
    final creditsController = TextEditingController(text: course?.credits.toString() ?? '4.0');
    final gradeController = TextEditingController(text: course?.gradePoint?.toString() ?? '');
    bool isCompleted = course?.isCompleted ?? true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: Text(course == null ? 'Add Course' : 'Edit Course', style: const TextStyle(fontWeight: FontWeight.bold)),
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
                  controller: gradeController,
                  decoration: const InputDecoration(
                    labelText: 'Grade Point / GPA (Optional)',
                    hintText: 'e.g. 9.0, 4.0 (empty if ungraded)',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 16),
                CheckboxListTile(
                  title: const Text('Completed & Graded', style: TextStyle(fontSize: 14)),
                  subtitle: const Text('Uncheck to treat as a "What-If" simulated course', style: TextStyle(fontSize: 11)),
                  value: isCompleted,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (val) {
                    if (val != null) {
                      setStateDialog(() => isCompleted = val);
                    }
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
                final grade = double.tryParse(gradeController.text.trim());
                final notifier = ref.read(academicProvider.notifier);

                if (name.isEmpty) return;

                if (course == null) {
                  await notifier.addCourse(
                    semesterId: semesterId,
                    name: name,
                    credits: credits,
                    gradePoint: grade,
                    isCompleted: isCompleted,
                  );
                } else {
                  await notifier.updateCourse(course.copyWith(
                    name: name,
                    credits: credits,
                    gradePoint: grade,
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

  // Set Graduation Goal parameters
  void _showSetGoalDialog() async {
    final targetStr = await _settingsRepo.getSetting('target_cgpa') ?? '';
    final creditsStr = await _settingsRepo.getSetting('graduation_credits') ?? '';

    final targetController = TextEditingController(text: targetStr);
    final creditsController = TextEditingController(text: creditsStr);

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set Graduation Target', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: targetController,
              decoration: const InputDecoration(
                labelText: 'Target CGPA',
                hintText: 'e.g. 8.5',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: creditsController,
              decoration: const InputDecoration(
                labelText: 'Total Graduation Credits',
                hintText: 'e.g. 160.0',
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
              final target = targetController.text.trim();
              final credits = creditsController.text.trim();
              if (target.isNotEmpty && credits.isNotEmpty) {
                await _settingsRepo.saveSetting('target_cgpa', target);
                await _settingsRepo.saveSetting('graduation_credits', credits);
                await ref.read(academicProvider.notifier).loadAll();
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
            Tab(text: 'Goal Planner'),
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
          // 1. Semesters Tab
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
                                children: state.semesters.map((sem) => _buildSemesterCard(sem, state.courses[sem.id] ?? [], notifier)).toList(),
                              ),
                      ],
                    ),
                  ),
                ),

          // 2. Goal Planner Tab
          FutureBuilder<Map<String, dynamic>>(
            future: notifier.getGoalProjections(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final data = snapshot.data ?? {'hasGoal': false};
              return SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: _buildGoalPlannerView(data),
              );
            },
          ),
        ],
      ),
    );
  }

  // CGPA Header Summary Card
  Widget _buildCgpaSummaryCard(double actualCgpa, double simulatedCgpa, double actualCreds, double simCreds) {
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
            colors: [
              primaryColor.withOpacity(0.08),
              primaryColor.withOpacity(0.02),
            ],
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
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey, letterSpacing: 1.0),
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
              Container(
                width: 1,
                height: 70,
                color: Colors.grey.withOpacity(0.2),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'SIMULATED CGPA',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.orangeAccent, letterSpacing: 1.0),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      simulatedCgpa.toStringAsFixed(2),
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 36, color: Colors.orangeAccent),
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

  // Expandable Semester Details Card
  Widget _buildSemesterCard(SemesterModel semester, List<CourseModel> courses, AcademicNotifier notifier) {
    final double actualSgpa = notifier.getSemesterSgpa(semester.id, includeSimulated: false);
    final double simulatedSgpa = notifier.getSemesterSgpa(semester.id, includeSimulated: true);
    final bool hasSim = simulatedSgpa != actualSgpa;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        title: Text(
          semester.name,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Row(
          children: [
            Text(
              'SGPA: ${actualSgpa.toStringAsFixed(2)}',
              style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold, fontSize: 13),
            ),
            if (hasSim) ...[
              const SizedBox(width: 8),
              Text(
                '(Sim: ${simulatedSgpa.toStringAsFixed(2)})',
                style: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold, fontSize: 13),
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
                  content: Text('Are you sure you want to delete "${semester.name}"? This deletes all courses inside it.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
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
            PopupMenuItem(value: 'delete', child: Text('Delete Semester', style: TextStyle(color: Colors.red))),
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
                  'Credits: ${course.credits}  ${course.isCompleted ? "" : "• [SIMULATED]"}',
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: Text(
                  course.gradePoint != null ? course.gradePoint!.toStringAsFixed(1) : 'Ungraded',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: course.isCompleted ? Theme.of(context).primaryColor : Colors.orangeAccent,
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
                  onPressed: () => _showCourseDialog(semester.id, course: CourseModel(
                    id: '',
                    semesterId: semester.id,
                    name: 'Simulated Subject',
                    credits: 4.0,
                    gradePoint: 8.0,
                    isCompleted: false,
                  )),
                  icon: const Icon(Icons.science_outlined, size: 16, color: Colors.orangeAccent),
                  label: const Text('Simulate What-If', style: TextStyle(fontSize: 13, color: Colors.orangeAccent)),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  // Goal Tracker / Planner View
  Widget _buildGoalPlannerView(Map<String, dynamic> data) {
    final hasGoal = data['hasGoal'] as bool;
    final primaryColor = Theme.of(context).primaryColor;

    if (!hasGoal) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.track_changes, size: 80, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'No Graduation Target Configured',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 8),
            const Text(
              'Configure a target CGPA and credit load to compute remaining GPA requirements.',
              style: TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _showSetGoalDialog,
              style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
              child: Text('Set Target Goal', style: TextStyle(color: Theme.of(context).colorScheme.onPrimary)),
            ),
          ],
        ),
      );
    }

    final double targetCgpa = data['targetCgpa'];
    final double totalGradCredits = data['totalGradCredits'];
    final double completedCredits = data['completedCredits'];
    final double currentCgpa = data['currentCgpa'];
    final double remainingCredits = data['remainingCredits'];
    final double requiredGpa = data['requiredGpa'];
    final String status = data['status'];
    final String statusMessage = data['statusMessage'];

    Color statusColor = Colors.green;
    IconData statusIcon = Icons.check_circle_outline;

    if (status == 'unreachable') {
      statusColor = Colors.redAccent;
      statusIcon = Icons.error_outline;
    } else if (status == 'safe') {
      statusColor = Colors.green;
      statusIcon = Icons.stars;
    } else if (status == 'on_track') {
      statusColor = requiredGpa >= 8.5 ? Colors.orangeAccent : Colors.blueAccent;
      statusIcon = Icons.trending_up;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          elevation: 3,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Graduation Target', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    IconButton(
                      icon: const Icon(Icons.edit, size: 20, color: Colors.grey),
                      onPressed: _showSetGoalDialog,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildPlannerMetric('Target CGPA', targetCgpa.toStringAsFixed(2)),
                    _buildPlannerMetric('Total Credits', totalGradCredits.toInt().toString()),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Text('Projections Checklist', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 10),
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                _buildGoalPlannerCheckrow('Credits Completed', '${completedCredits.toInt()} / ${totalGradCredits.toInt()}'),
                const Divider(),
                _buildGoalPlannerCheckrow('Remaining Credits', '${remainingCredits.toInt()}'),
                const Divider(),
                _buildGoalPlannerCheckrow('Current CGPA', currentCgpa.toStringAsFixed(2)),
                const Divider(),
                _buildGoalPlannerCheckrow(
                  'Req. Remaining GPA',
                  status == 'safe' 
                      ? '0.00' 
                      : status == 'unreachable' 
                          ? 'Unreachable' 
                          : requiredGpa.toStringAsFixed(2),
                  valueColor: statusColor,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: statusColor.withOpacity(0.2)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(statusIcon, color: statusColor, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      status == 'unreachable'
                          ? 'ALERT'
                          : status == 'safe'
                              ? 'GOAL SECURED'
                              : 'TARGET FORECAST',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: statusColor, letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      statusMessage,
                      style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onBackground, height: 1.3),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPlannerMetric(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 28, color: Theme.of(context).primaryColor),
        ),
      ],
    );
  }

  Widget _buildGoalPlannerCheckrow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w500)),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: valueColor ?? Theme.of(context).colorScheme.onBackground,
            ),
          ),
        ],
      ),
    );
  }
}
