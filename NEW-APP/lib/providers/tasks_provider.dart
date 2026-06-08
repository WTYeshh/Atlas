import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/task_model.dart';
import '../repositories/database_repository.dart';
import '../services/auto_reminder_service.dart';
import 'repository_providers.dart';



final tasksProvider = StateNotifierProvider<TasksNotifier, List<TaskModel>>((ref) {
  final dbRepo = ref.watch(databaseRepositoryProvider);
  return TasksNotifier(dbRepo);
});

class TasksNotifier extends StateNotifier<List<TaskModel>> {
  final DatabaseRepository _dbRepo;

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
    // Reschedule all reminders so this new task gets its notifications
    await AutoReminderService().rescheduleAll(dbRepo: _dbRepo);
  }

  Future<void> updateTask(TaskModel task) async {
    await _dbRepo.updateTask(task);
    await loadTasks();
    // Reschedule all reminders after change
    await AutoReminderService().rescheduleAll(dbRepo: _dbRepo);
  }

  Future<void> deleteTask(String id) async {
    await _dbRepo.deleteTask(id);
    await loadTasks();
    // Reschedule all reminders to remove the deleted task's notifications
    await AutoReminderService().rescheduleAll(dbRepo: _dbRepo);
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
}

