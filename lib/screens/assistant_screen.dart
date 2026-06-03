import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/assistant_provider.dart';
import '../models/chat_message.dart';
import 'package:intl/intl.dart';

class AssistantScreen extends ConsumerStatefulWidget {
  const AssistantScreen({super.key});

  @override
  ConsumerState<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends ConsumerState<AssistantScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final assistantState = ref.watch(assistantProvider);
    final notifier = ref.read(assistantProvider.notifier);

    // Auto scroll to bottom when new messages arrive or loading status changes
    ref.listen(assistantProvider, (prev, next) {
      if (prev?.messages.length != next.messages.length || prev?.isLoading != next.isLoading) {
        _scrollToBottom();
      }
    });

    final suggestions = [
      'What assignments are due this week?',
      'Show upcoming exams.',
      'Find DBMS notes.',
    ];

    return Scaffold(
      body: Column(
        children: [
          // Clear history button
          if (assistantState.messages.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => notifier.clearHistory(),
                icon: const Icon(Icons.delete_sweep_outlined, size: 16),
                label: const Text('Clear Chat History', style: TextStyle(fontSize: 12)),
              ),
            ),

          // Messages / Suggestions Area
          Expanded(
            child: assistantState.messages.isEmpty
                ? _buildEmptyState(suggestions, notifier)
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16.0),
                    itemCount: assistantState.messages.length,
                    itemBuilder: (context, index) {
                      final msg = assistantState.messages[index];
                      return _buildChatBubble(msg);
                    },
                  ),
          ),

          // Loading indicator
          if (assistantState.isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    height: 14,
                    width: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Atlas is thinking...',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.secondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),

          // Bottom Input bar
          Container(
            padding: const EdgeInsets.all(12.0),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              border: Border(
                top: BorderSide(color: Theme.of(context).dividerColor, width: 1),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: 'Ask Atlas anything...',
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onSubmitted: (val) {
                      if (val.trim().isNotEmpty && !assistantState.isLoading) {
                        notifier.sendMessage(val.trim());
                        _messageController.clear();
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send),
                  color: Theme.of(context).primaryColor,
                  onPressed: assistantState.isLoading
                      ? null
                      : () {
                          if (_messageController.text.trim().isNotEmpty) {
                            notifier.sendMessage(_messageController.text.trim());
                            _messageController.clear();
                          }
                        },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(List<String> suggestions, AssistantNotifier notifier) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              height: 72,
              width: 72,
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.auto_awesome,
                size: 32,
                color: Theme.of(context).primaryColor,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'How can Atlas help you today?',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              'Ask questions about your schedules, search notes, or summarize classes.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.secondary),
            ),
            const SizedBox(height: 24),
            // Suggestion chips
            Wrap(
              direction: Axis.vertical,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              children: suggestions.map((s) {
                return ActionChip(
                  label: Text(s),
                  onPressed: () {
                    notifier.sendMessage(s);
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatBubble(ChatMessage msg) {
    final isMe = msg.role == 'user';
    final parsedTime = DateTime.tryParse(msg.timestamp) ?? DateTime.now();
    final timeStr = DateFormat('jm').format(parsedTime);

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isMe
              ? Theme.of(context).primaryColor
              : Theme.of(context).cardColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: isMe ? const Radius.circular(14) : Radius.zero,
            bottomRight: isMe ? Radius.zero : const Radius.circular(14),
          ),
          border: isMe
              ? null
              : Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              msg.message,
              style: TextStyle(
                color: isMe ? Colors.white : Theme.of(context).colorScheme.onBackground,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.bottomRight,
              child: Text(
                timeStr,
                style: TextStyle(
                  color: isMe ? Colors.white70 : Theme.of(context).colorScheme.secondary,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
