import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/task_model.dart';
import '../repositories/database_repository.dart';
import '../services/notification_service.dart';
import 'notes_provider.dart';

final tasksProvider = StateNotifierProvider<TasksNotifier, List<TaskModel>>((ref) {
  final dbRepo = ref.watch(databaseRepositoryProvider);
  return TasksNotifier(dbRepo);
});

class TasksNotifier extends StateNotifier<List<TaskModel>> {
  final DatabaseRepository _dbRepo;
  final NotificationService _notificationService = NotificationService();

  TasksNotifier(this._dbRepo) : super([]) {
    loadTasks();
  }

  Future<void> loadTasks() async {
    final list = await _dbRepo.getTasks();
    state = list;
  }

  Future<void> addTask(TaskModel task) async {
    await _dbRepo.insertTask(task);
    await loadTasks();

    // Schedule notification reminder if dueDate is set
    _scheduleReminder(task);
  }

  Future<void> updateTask(TaskModel task) async {
    await _dbRepo.updateTask(task);
    await loadTasks();

    if (task.status == 'completed') {
      if (task.reminderId != null) {
        await _notificationService.cancelNotification(task.reminderId!);
      }
    } else {
      _scheduleReminder(task);
    }
  }

  Future<void> deleteTask(String id) async {
    final taskIndex = state.indexWhere((t) => t.id == id);
    if (taskIndex != -1) {
      final task = state[taskIndex];
      if (task.reminderId != null) {
        await _notificationService.cancelNotification(task.reminderId!);
      }
    }
    await _dbRepo.deleteTask(id);
    await loadTasks();
  }

  Future<void> toggleTaskStatus(String id) async {
    final taskIndex = state.indexWhere((t) => t.id == id);
    if (taskIndex == -1) return;

    final task = state[taskIndex];
    final updatedTask = task.copyWith(
      status: task.status == 'completed' ? 'pending' : 'completed',
      updatedAt: DateTime.now().toIso8601String(),
    );
    await updateTask(updatedTask);
  }

  // Schedule notification reminder
  Future<void> _scheduleReminder(TaskModel task) async {
    if (task.status == 'completed') return;

    try {
      final dueDate = DateTime.tryParse(task.dueDate);
      if (dueDate != null) {
        // Schedule reminder for 9:00 AM on the due date
        final reminderTime = DateTime(dueDate.year, dueDate.month, dueDate.day, 9, 0);
        
        int reminderId = task.reminderId ?? task.hashCode;
        
        await _notificationService.scheduleNotification(
          id: reminderId,
          title: 'Assignment Deadline Today',
          body: '${task.subject != null ? "[${task.subject}] " : ""}${task.title} is due today.',
          scheduledDate: reminderTime,
        );

        if (task.reminderId == null) {
          final updated = task.copyWith(reminderId: reminderId);
          await _dbRepo.updateTask(updated);
        }
      }
    } catch (e) {
      print('Failed to schedule reminder for task ${task.id}: $e');
    }
  }
}
