import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/tasks_provider.dart';
import '../models/task_model.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/scholar_provider.dart';

class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key});

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

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

  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(tasksProvider);

    final pendingTasks = tasks.where((t) => t.status == 'pending').toList();
    final completedTasks = tasks.where((t) => t.status == 'completed').toList();

    // Sort tasks by due date
    pendingTasks.sort((a, b) => a.dueDate.compareTo(b.dueDate));
    completedTasks.sort((a, b) => b.dueDate.compareTo(a.dueDate)); // Reverse for history

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(48),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor, width: 1)),
          ),
          child: TabBar(
            controller: _tabController,
            indicatorColor: Theme.of(context).primaryColor,
            labelColor: Theme.of(context).primaryColor,
            unselectedLabelColor: Theme.of(context).colorScheme.secondary,
            tabs: [
              Tab(text: 'Pending (${pendingTasks.length})'),
              Tab(text: 'Completed (${completedTasks.length})'),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTaskList(pendingTasks),
          _buildTaskList(completedTasks),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddTaskDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildTaskList(List<TaskModel> tasksList) {
    if (tasksList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assignment_turned_in_outlined, size: 48, color: Theme.of(context).dividerColor),
            const SizedBox(height: 16),
            Text(
              'No tasks in this list.',
              style: TextStyle(color: Theme.of(context).colorScheme.secondary),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: tasksList.length,
      itemBuilder: (context, index) {
        final task = tasksList[index];

        Color priorityColor = Colors.grey;
        if (task.priority == 'high') {
          priorityColor = Colors.redAccent;
        } else if (task.priority == 'medium') {
          priorityColor = Colors.orangeAccent;
        } else {
          priorityColor = Colors.green;
        }

        return Dismissible(
          key: Key(task.id),
          direction: DismissDirection.endToStart,
          background: Container(
            color: Colors.redAccent,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          onDismissed: (_) {
            ref.read(tasksProvider.notifier).deleteTask(task.id);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Task "${task.title}" deleted')),
            );
          },
          child: Card(
            margin: const EdgeInsets.only(bottom: 12.0),
            child: ListTile(
              leading: Checkbox(
                value: task.status == 'completed',
                onChanged: (_) async {
                  final wasCompleted = task.status == 'completed';
                  ref.read(tasksProvider.notifier).toggleTaskStatus(task.id);
                  if (!wasCompleted) {
                    final reward = await ref.read(scholarProvider.notifier).completeTask(task);
                    if (context.mounted) {
                      _showXpGainedSnackBar(context, reward);
                    }
                  }
                },
              ),
              title: Text(
                task.title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  decoration: task.status == 'completed' ? TextDecoration.lineThrough : null,
                  color: task.status == 'completed'
                      ? Theme.of(context).colorScheme.secondary
                      : Theme.of(context).colorScheme.onBackground,
                ),
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
          ),
        );
      },
    );
  }

  void _showAddTaskDialog(BuildContext context) {
    final titleController = TextEditingController();
    final subjectController = TextEditingController();
    
    String selectedPriority = 'medium';
    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add Task / Assignment'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(hintText: 'Assignment Title'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: subjectController,
                      decoration: const InputDecoration(hintText: 'Subject (e.g., DBMS, AI, Math)'),
                    ),
                    const SizedBox(height: 16),
                    // Priority selector
                    Row(
                      children: [
                        const Text('Priority:'),
                        const SizedBox(width: 12),
                        ...['low', 'medium', 'high'].map((p) {
                          final isSel = selectedPriority == p;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6.0),
                            child: ChoiceChip(
                              label: Text(p),
                              selected: isSel,
                              onSelected: (_) {
                                setDialogState(() {
                                  selectedPriority = p;
                                });
                              },
                            ),
                          );
                        }),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      leading: const Icon(Icons.calendar_today),
                      title: Text(DateFormat('dd-MM-yy').format(selectedDate)),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) {
                          setDialogState(() {
                            selectedDate = picked;
                          });
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
                TextButton(
                  onPressed: () {
                    if (titleController.text.trim().isEmpty) return;

                    final dateStr = DateFormat('yyyy-MM-dd').format(selectedDate);

                    final newTask = TaskModel(
                      id: const Uuid().v4(),
                      title: titleController.text.trim(),
                      dueDate: dateStr,
                      priority: selectedPriority,
                      subject: subjectController.text.trim().isEmpty ? null : subjectController.text.trim(),
                      status: 'pending',
                      updatedAt: DateTime.now().toIso8601String(),
                    );

                    ref.read(tasksProvider.notifier).addTask(newTask);
                    Navigator.pop(context);
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showXpGainedSnackBar(BuildContext context, Map<String, dynamic> reward) {
    final xpGained = reward['xpGained'] as int;
    final coinsGained = reward['coinsGained'] as int;
    final leveledUp = reward['leveledUp'] as bool;
    final newLevel = reward['newLevel'] as int;
    final hasPenalty = reward['hasPenalty'] as bool? ?? false;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.flash_on, color: Colors.amber, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '+$xpGained XP  •  🪙 +$coinsGained Coins' + 
                    (hasPenalty ? ' (Late/Rescheduled Penalty!) ⚠️' : ''),
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
            if (leveledUp) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.amber,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'LEVEL UP: $newLevel!',
                  style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 10),
                ),
              ),
            ]
          ],
        ),
        backgroundColor: leveledUp ? Colors.purple : const Color(0xFF1C1C1E),
        duration: const Duration(seconds: 3),
      ),
    );

    if (leveledUp) {
      _showLevelUpDialog(context, newLevel);
    }
  }

  void _showLevelUpDialog(BuildContext context, int newLevel) {
    final title = ref.read(scholarProvider.notifier).getScholarTitle(newLevel);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.shield_outlined, color: Colors.amber),
            SizedBox(width: 8),
            Text('SCHOLAR LEVEL UP!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Congratulations YESHWANTH! You reached a new tier in the Scholar Guild:'),
            const SizedBox(height: 12),
            Text(
              'Level $newLevel',
              style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            Text(
              title,
              style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.amber),
            ),
            const SizedBox(height: 12),
            const Text('Level Up Bonus: 🪙 Coins and stats increased!', textAlign: TextAlign.center),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('GUILD ONWARD'),
          )
        ],
      ),
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
