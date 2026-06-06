import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/chat_message.dart';
import '../repositories/database_repository.dart';
import '../services/gemini_service.dart';
import 'notes_provider.dart';
import 'tasks_provider.dart';
import 'calendar_provider.dart';

class AssistantState {
  final List<ChatMessage> messages;
  final bool isLoading;

  AssistantState({
    this.messages = const [],
    this.isLoading = false,
  });

  AssistantState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
  }) {
    return AssistantState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

final assistantProvider = StateNotifierProvider<AssistantNotifier, AssistantState>((ref) {
  final dbRepo = ref.watch(databaseRepositoryProvider);
  return AssistantNotifier(dbRepo, ref);
});

class AssistantNotifier extends StateNotifier<AssistantState> {
  final DatabaseRepository _dbRepo;
  final Ref _ref;
  final GeminiService _geminiService = GeminiService();

  AssistantNotifier(this._dbRepo, this._ref) : super(AssistantState()) {
    _clearHistoryOnStartup();
  }

  Future<void> _clearHistoryOnStartup() async {
    // Clear old SQLite history on startup to save device storage
    await _dbRepo.clearChatHistory();
    state = AssistantState(messages: [], isLoading: false);
  }

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    final userMsg = ChatMessage(
      id: const Uuid().v4(),
      role: 'user',
      message: text,
      timestamp: DateTime.now().toIso8601String(),
    );

    // 1. Add user message locally (RAM only)
    state = state.copyWith(
      messages: [...state.messages, userMsg],
      isLoading: true,
    );

    // 2. Fetch context for RAG
    final notes = _ref.read(notesProvider);
    final tasks = _ref.read(tasksProvider);
    final events = _ref.read(calendarProvider);

    // Prepare text summaries of upcoming schedules/deadlines for prompt context
    final List<String> scheduleContext = [];
    for (var task in tasks) {
      scheduleContext.add('Task: ${task.title} | Status: ${task.status} | Priority: ${task.priority} | Due: ${task.dueDate} | Subject: ${task.subject ?? 'None'}');
    }
    for (var event in events) {
      scheduleContext.add('Event: ${event.title} | Date: ${event.date} | Time: ${event.time} | Desc: ${event.description ?? 'None'} | Category: ${event.category ?? 'None'}');
    }

    // 3. Ask Gemini
    final responseText = await _geminiService.answerChat(
      message: text,
      notes: notes,
      upcomingEventsAndTasks: scheduleContext,
      history: state.messages,
    );

    final assistantMsg = ChatMessage(
      id: const Uuid().v4(),
      role: 'model',
      message: responseText,
      timestamp: DateTime.now().toIso8601String(),
    );

    // 4. Save and update state (RAM only)
    state = state.copyWith(
      messages: [...state.messages, assistantMsg],
      isLoading: false,
    );
  }

  Future<void> clearHistory() async {
    await _dbRepo.clearChatHistory();
    state = AssistantState(messages: [], isLoading: false);
  }
}
