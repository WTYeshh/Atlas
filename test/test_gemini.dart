import 'package:flutter_test/flutter_test.dart';
import 'package:atlas/services/gemini_service.dart';
import 'package:atlas/models/chat_message.dart';

void main() {
  test('Test GeminiService.answerChat directly', () async {
    final service = GeminiService();
    
    final result = await service.answerChat(
      message: 'Hi, tell me a joke and format today\'s date (June 3, 2026).',
      notes: [],
      upcomingEventsAndTasks: [],
      history: [
        ChatMessage(id: '1', role: 'user', message: 'Hi Atlas', timestamp: DateTime.now().toIso8601String()),
        ChatMessage(id: '2', role: 'model', message: 'Hello! I am Atlas, your assistant.', timestamp: DateTime.now().toIso8601String()),
      ],
    );
    
    print('Chat Result: $result');
    expect(result, isNotNull);
    expect(result, contains('03-06-26'));
  });
}
