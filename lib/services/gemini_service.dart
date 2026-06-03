import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../repositories/settings_repository.dart';
import '../models/note_model.dart';
import '../models/chat_message.dart';
import '../core/config.dart';

class GeminiService {
  final SettingsRepository _settingsRepo = SettingsRepository();
  
  Future<GenerativeModel?> _getModel({String modelName = 'gemini-1.5-flash'}) async {
    final aiEnabled = await _settingsRepo.getGenerativeAiEnabled();
    if (!aiEnabled) {
      print('GeminiService: Generative AI features are disabled in Settings.');
      return null;
    }

    const apiKey = AppConfig.geminiApiKey;
    if (apiKey.isEmpty || apiKey == 'YOUR_GEMINI_API_KEY_HERE') {
      print('GeminiService: Gemini API Key is not configured in AppConfig.');
      return null;
    }

    return GenerativeModel(
      model: modelName,
      apiKey: apiKey,
      generationConfig: GenerationConfig(responseMimeType: 'application/json'),
    );
  }

  // Step 2: Content classification and entity extraction
  Future<Map<String, dynamic>?> classifyAndExtractContent(String text) async {
    final model = await _getModel();
    if (model == null) return null;

    final prompt = '''
    Analyze the following input content (which could be a message, OCR text from a screenshot, or a note) and classify it into one of the following:
    - "event": A calendar entry with a specific date and time.
    - "task": An assignment, homework, or to-do list item with a deadline or priority.
    - "note": Informational content, study materials, notes, or lecture summaries.
    - "reminder": A quick alert or alarm request.
    - "general": Anything else that doesn't fit the above.

    Extract the details and format them into a structured JSON object matching this schema:
    {
      "type": "event" | "task" | "note" | "reminder" | "general",
      "title": "A short descriptive title",
      "date": "YYYY-MM-DD or null if not specified",
      "time": "HH:MM (24h format) or null if not specified",
      "dueDate": "YYYY-MM-DD or null if not specified (for tasks)",
      "priority": "low" | "medium" | "high" or null (for tasks, default to medium if vague)",
      "subject": "The academic subject name (e.g., DBMS, AI, Math) or null if generic",
      "category": "The category (e.g., Study, Exam, Lecture, Personal) or null",
      "summary": "A concise summary of the content (for notes/documents) or null",
      "content": "A clean, nicely formatted version of the input text or null",
      "tags": ["extracted", "keywords", "for", "notes"]
    }

    Current Time Context: ${DateTime.now().toIso8601String()} (Today is ${DateTime.now().weekday} day of week).
    Input Content:
    """
    $text
    """
    ''';

    try {
      final response = await model.generateContent([Content.text(prompt)]);
      if (response.text == null) return null;
      return json.decode(response.text!) as Map<String, dynamic>;
    } catch (e) {
      print('Gemini classification error: $e');
      return null;
    }
  }

  // AI-generated summary for Notes Vault
  Future<String?> generateSummary(String text) async {
    // Normal text model (no JSON enforcement config)
    final aiEnabled = await _settingsRepo.getGenerativeAiEnabled();
    if (!aiEnabled) return null;

    const apiKey = AppConfig.geminiApiKey;
    if (apiKey.isEmpty || apiKey == 'YOUR_GEMINI_API_KEY_HERE') return null;
    
    final model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: apiKey);
    final prompt = 'Summarize the following note or document content into 3 concise bullet points under a header:\n\n$text';

    try {
      final response = await model.generateContent([Content.text(prompt)]);
      return response.text;
    } catch (e) {
      print('Gemini summary generation error: $e');
      return null;
    }
  }

  // Smart Chat Assistant supporting RAG context over notes, events, tasks
  Future<String> answerChat({
    required String message,
    required List<NoteModel> notes,
    required List<dynamic> upcomingEventsAndTasks,
    required List<ChatMessage> history,
  }) async {
    final aiEnabled = await _settingsRepo.getGenerativeAiEnabled();
    if (!aiEnabled) {
      return 'Generative AI assistant features are currently disabled in Settings. Please enable them to chat.';
    }

    const apiKey = AppConfig.geminiApiKey;
    if (apiKey.isEmpty || apiKey == 'YOUR_GEMINI_API_KEY_HERE') {
      return 'Generative AI assistant is not configured. Please define the Gemini API Key constant inside the application code.';
    }

    final model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: apiKey);

    // Format local notes context
    final notesContext = notes.map((n) {
      return 'Note Title: ${n.title}\nSubject: ${n.subject ?? 'None'}\nSummary: ${n.summary ?? 'None'}\nContent: ${n.content ?? 'None'}\nTags: ${n.tags.join(', ')}\n---';
    }).join('\n');

    // Format local events and tasks context
    final eventsContext = upcomingEventsAndTasks.map((item) {
      return item.toString(); // We'll serialize event/task objects in providers
    }).join('\n');

    final systemPrompt = '''
    You are "Atlas", a highly helpful, intelligent, personal academic and productivity assistant.
    You assist the user with organizing classes, assignments, notes, events, reminders, and studying.

    You have access to the user's locally stored academic data below. Use this data ONLY to answer questions about notes, files, schedules, assignments, and tasks. Do not make up facts.
    
    --- USER NOTES VAULT ---
    $notesContext
    
    --- USER UPCOMING SCHEDULES, EVENTS & TASKS ---
    $eventsContext
    
    --- INSTRUCTIONS ---
    1. If the user asks for summaries or content inside notes, refer to the "USER NOTES VAULT".
    2. If the user asks about schedules or deadlines, refer to the "USER UPCOMING SCHEDULES, EVENTS & TASKS".
    3. Be brief, neat, and use markdown to format lists, highlights, and headers.
    4. Keep answers friendly, conversational, and direct.
    ''';

    // Build chat history content
    final contents = [
      Content.text(systemPrompt),
      ...history.map((msg) {
        if (msg.role == 'user') {
          return Content.text(msg.message);
        } else {
          return Content.model([TextPart(msg.message)]);
        }
      }),
      Content.text(message)
    ];

    try {
      final response = await model.generateContent(contents);
      return response.text ?? 'I encountered an error trying to process that. Please try again.';
    } catch (e) {
      print('Gemini chat assistant error: $e');
      return 'I had trouble connecting to my AI processor. Please make sure your Gemini API key is correct and you have an active internet connection.';
    }
  }
}
