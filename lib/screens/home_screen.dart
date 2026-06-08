import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/calendar_provider.dart';
import '../providers/tasks_provider.dart';
import '../providers/attendance_provider.dart';
import '../providers/past_semester_provider.dart';
import '../providers/ia_marks_provider.dart';
import '../repositories/settings_repository.dart';
import '../models/event_model.dart';
import '../models/task_model.dart';
import 'package:intl/intl.dart';
import 'sync_status_badge.dart';
import '../services/discord_service.dart';
import '../services/discord_digest_service.dart';
import 'attendance_dashboard_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _isDialogShowing = false;

  Future<void> _checkSemesterCompletion(String endDate) async {
    if (_isDialogShowing) return;
    
    // Check if end date has passed
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final end = DateTime.tryParse(endDate);
    if (end == null) return;
    final endDateObj = DateTime(end.year, end.month, end.day);
    
    if (!todayDate.isAfter(endDateObj)) {
      return; // Not passed yet
    }
    
    final settingsRepo = SettingsRepository();
    final shown = await settingsRepo.getSetting('congratulatory_popup_shown_for_$endDate');
    if (shown == 'true') return;
    
    _isDialogShowing = true;
    if (!mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Congratulations!', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text(
          'Congratulations on completing your semester!\n\nWould you like to archive your academic records (attendance percentage, course details, and IA scores) before preparing the app for the next semester?',
        ),
        actions: [
          TextButton(
            onPressed: () async {
              // Mark popup as shown
              final settingsRepo = SettingsRepository();
              await settingsRepo.saveSetting('congratulatory_popup_shown_for_$endDate', 'true');
              
              if (context.mounted) {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => const Center(child: CircularProgressIndicator()),
                );
              }
              
              await ref.read(pastSemesterProvider.notifier).resetSemester();
              await ref.read(attendanceProvider.notifier).loadAll();
              await ref.read(iaMarksProvider.notifier).loadAll();
              
              if (context.mounted) {
                Navigator.of(context).pop(); // dismiss loading
                Navigator.of(context).pop(); // dismiss dialog
              }
              _isDialogShowing = false;
            },
            child: Text(
              'Reset Only',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.45),
                fontSize: 11,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              // Archive data
              final attendanceNotifier = ref.read(attendanceProvider.notifier);
              final iaNotifier = ref.read(iaMarksProvider.notifier);
              
              final subjects = ref.read(attendanceProvider).subjects;
              final subjectStats = attendanceNotifier.getSubjectStats();
              
              final Map<String, List<double?>> subjectIaMarks = {};
              for (var sub in subjects) {
                final result = iaNotifier.computeBestOf2(sub.id);
                subjectIaMarks[sub.id] = [result.ia1, result.ia2, result.ia3];
              }
              
              final startStr = ref.read(attendanceProvider).semesterStartDate ?? '';
              final endStr = ref.read(attendanceProvider).semesterEndDate ?? '';
              
              // Mark popup as shown
              final settingsRepo = SettingsRepository();
              await settingsRepo.saveSetting('congratulatory_popup_shown_for_$endDate', 'true');
              
              if (context.mounted) {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => const Center(child: CircularProgressIndicator()),
                );
              }
              
              // Archive to SQLite
              await ref.read(pastSemesterProvider.notifier).archiveSemester(
                name: 'Semester ending $endDate',
                startDate: startStr,
                endDate: endStr,
                subjects: subjects,
                subjectStats: subjectStats,
                subjectIaMarks: subjectIaMarks,
              );
              
              // Perform reset
              await ref.read(pastSemesterProvider.notifier).resetSemester();
              await ref.read(attendanceProvider.notifier).loadAll();
              await ref.read(iaMarksProvider.notifier).loadAll();
              
              if (context.mounted) {
                Navigator.of(context).pop(); // dismiss loading
                Navigator.of(context).pop(); // dismiss dialog
              }
              _isDialogShowing = false;
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              elevation: 2,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            child: const Text(
              'Archive & Reset',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final events = ref.watch(calendarProvider);
    final tasks = ref.watch(tasksProvider);
    final attendanceState = ref.watch(attendanceProvider);
    final attendanceNotifier = ref.read(attendanceProvider.notifier);

    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

    // Check for semester completion dialog triggering
    final semesterEndDate = attendanceState.semesterEndDate;
    if (semesterEndDate != null && semesterEndDate.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkSemesterCompletion(semesterEndDate);
      });
    }

    // Filter today's events
    final todayEvents = events.where((e) => e.date == todayStr).toList();
    // Filter upcoming events (next 7 days, excluding today)
    final upcomingEvents = events.where((e) {
      if (e.date == todayStr) return false;
      final eDate = DateTime.tryParse(e.date);
      if (eDate == null) return false;
      return eDate.isAfter(DateTime.now()) && eDate.isBefore(DateTime.now().add(const Duration(days: 7)));
    }).toList();

    // Filter pending tasks
    final pendingTasks = tasks.where((t) => t.status == 'pending').toList();
    // Sort tasks by due date
    pendingTasks.sort((a, b) => a.dueDate.compareTo(b.dueDate));

    final overallStats = attendanceNotifier.getOverallStats();
    final double overallPercentage = overallStats['percentage'] ?? 0.0;
    final int pendingConfirmations = attendanceNotifier.getPendingConfirmations().length;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(calendarProvider.notifier).syncGoogleCalendar();
          await ref.read(tasksProvider.notifier).loadTasks();
          await ref.read(attendanceProvider.notifier).loadAll();
          try {
            await ref.read(discordServiceProvider).syncDiscord();
            await ref.read(discordDigestServiceProvider).checkAndTriggerDigests();
          } catch (e) {
            print('HomeScreen: Discord sync/digest failed during refresh: $e');
          }
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome Banner
              _buildHeader(context),
              const SizedBox(height: 24),

              // Attendance Overview Card
              _buildAttendanceCard(
                context,
                overallPercentage,
                pendingConfirmations,
                attendanceState.subjects.length,
              ),

              // Today's Agendas
              _buildSectionTitle(context, "Today's Schedule"),
              const SizedBox(height: 10),
              _buildTodaySchedule(context, todayEvents),
              const SizedBox(height: 24),

              // Pending Assignments
              _buildSectionTitle(context, "Pending Tasks & Assignments"),
              const SizedBox(height: 10),
              _buildPendingTasks(context, pendingTasks, ref),
              const SizedBox(height: 24),

              // Upcoming Events
              _buildSectionTitle(context, "Upcoming Events"),
              const SizedBox(height: 10),
              _buildUpcomingEvents(context, upcomingEvents),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final now = DateTime.now();
    final formattedDate = DateFormat('EEEE, dd-MM-yy').format(now);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              formattedDate,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 4),
            Text(
              'Overview',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: Theme.of(context).colorScheme.onBackground,
                  ),
            ),
          ],
        ),
        const Padding(
          padding: EdgeInsets.only(bottom: 4.0),
          child: SyncStatusBadge(),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
    );
  }

  Widget _buildTodaySchedule(BuildContext context, List<EventModel> todayEvents) {
    if (todayEvents.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Center(
            child: Text(
              'No classes or events scheduled for today.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ),
      );
    }

    return Column(
      children: todayEvents.map((event) {
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                event.time,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ),
            title: Text(
              event.title,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: event.description != null ? Text(event.description!) : null,
            trailing: event.category != null
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).dividerColor,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      event.category!,
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  )
                : null,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPendingTasks(BuildContext context, List<TaskModel> pendingTasks, WidgetRef ref) {
    if (pendingTasks.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Center(
            child: Text(
              'All caught up! No pending assignments.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ),
      );
    }

    return Column(
      children: pendingTasks.take(3).map((task) {
        // Priority color indicator
        Color priorityColor = Colors.grey;
        if (task.priority == 'high') {
          priorityColor = Colors.redAccent;
        } else if (task.priority == 'medium') {
          priorityColor = Colors.orangeAccent;
        } else {
          priorityColor = Colors.green;
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Checkbox(
              value: false,
              onChanged: (_) {
                ref.read(tasksProvider.notifier).toggleTaskStatus(task.id);
              },
            ),
            title: Text(
              task.title,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              'Due: ${_formatDate(task.dueDate)} ${task.subject != null ? "• ${task.subject}" : ""}',
              style: const TextStyle(fontSize: 12),
            ),
            trailing: Container(
              height: 12,
              width: 12,
              decoration: BoxDecoration(
                color: priorityColor,
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildUpcomingEvents(BuildContext context, List<EventModel> upcomingEvents) {
    if (upcomingEvents.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Center(
            child: Text(
              'No upcoming events scheduled for this week.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ),
      );
    }

    return Column(
      children: upcomingEvents.map((event) {
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            title: Text(
              event.title,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text('${_formatDate(event.date)} at ${event.time}'),
            trailing: const Icon(Icons.calendar_today, size: 16),
          ),
        );
      }).toList(),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final parts = dateStr.split('-');
      if (parts.length == 3) {
        final year = parts[0];
        final month = parts[1];
        final day = parts[2];
        final shortYear = year.length >= 4 ? year.substring(2) : year;
        return '$day-$month-$shortYear';
      }
    } catch (_) {}
    return dateStr;
  }

  Widget _buildAttendanceCard(BuildContext context, double percentage, int pendingCount, int totalSubjects) {
    final primaryColor = Theme.of(context).primaryColor;

    if (totalSubjects == 0) {
      return Card(
        margin: const EdgeInsets.only(bottom: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 2,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AttendanceDashboardScreen()),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.calendar_view_week,
                    color: primaryColor,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Setup Attendance Tracking',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Upload your timetable to automatically track your attendance.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
              ],
            ),
          ),
        ),
      );
    }

    final isLow = percentage < 75.0;
    final alertColor = isLow ? Colors.redAccent : Colors.green;

    return Card(
      margin: const EdgeInsets.only(bottom: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 3,
      shadowColor: alertColor.withOpacity(0.15),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AttendanceDashboardScreen()),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: alertColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isLow ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                  color: alertColor,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                       'Attendance Overview',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      pendingCount > 0
                          ? '$pendingCount classes pending confirmation'
                          : 'All attendance logs up-to-date',
                      style: TextStyle(
                        fontSize: 12,
                        color: pendingCount > 0 ? Colors.orangeAccent : Colors.grey,
                        fontWeight: pendingCount > 0 ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${percentage.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      color: alertColor,
                    ),
                  ),
                  Text(
                    isLow ? 'Low Standing' : 'Good Standing',
                    style: TextStyle(
                      fontSize: 10,
                      color: alertColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
