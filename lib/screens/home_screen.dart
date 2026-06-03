import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/calendar_provider.dart';
import '../providers/tasks_provider.dart';
import '../providers/notes_provider.dart';
import '../models/event_model.dart';
import '../models/task_model.dart';
import '../models/note_model.dart';
import 'package:intl/intl.dart';
import 'sync_status_badge.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(calendarProvider);
    final tasks = ref.watch(tasksProvider);
    final notes = ref.watch(notesProvider);

    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

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

    // Get recent notes (last 3)
    final recentNotes = notes.take(3).toList();

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(calendarProvider.notifier).syncGoogleCalendar();
          await ref.read(tasksProvider.notifier).loadTasks();
          await ref.read(notesProvider.notifier).loadNotes();
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

              // Recent Notes
              _buildSectionTitle(context, "Recent Notes"),
              const SizedBox(height: 10),
              _buildRecentNotes(context, recentNotes),
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

  Widget _buildRecentNotes(BuildContext context, List<NoteModel> recentNotes) {
    if (recentNotes.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Center(
            child: Text(
              'Notes Vault is empty.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ),
      );
    }

    return Column(
      children: recentNotes.map((note) {
        IconData typeIcon = Icons.notes_outlined;
        if (note.type == 'pdf') typeIcon = Icons.picture_as_pdf_outlined;
        if (note.type == 'image') typeIcon = Icons.image_outlined;

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Icon(typeIcon, color: Theme.of(context).primaryColor),
            title: Text(
              note.title,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              note.subject ?? note.category ?? 'Unorganized',
              style: const TextStyle(fontSize: 12),
            ),
            trailing: const Icon(Icons.chevron_right, size: 20),
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
}
