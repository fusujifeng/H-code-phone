import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/chat_message.dart';

class ChatState {
  final List<ChatMessage> messages;
  ChatState([List<ChatMessage>? messages]) : messages = messages ?? [];
}

class ChatNotifier extends StateNotifier<ChatState> {
  ChatNotifier() : super(ChatState());

  void addMessage(ChatMessage msg) {
    state = ChatState([...state.messages, msg]);
  }

  void upsertThinking(String content) {
    final msgs = List<ChatMessage>.from(state.messages);
    // Find the last thinking message and update it, or add a new one
    for (int i = msgs.length - 1; i >= 0; i--) {
      if (msgs[i].id.startsWith('thinking-')) {
        msgs[i] = ChatMessage(
          id: msgs[i].id,
          type: MessageType.ai,
          content: content,
          timestamp: msgs[i].timestamp,
        );
        state = ChatState(msgs);
        return;
      }
    }
    // No existing thinking message, add new one
    state = ChatState([...msgs, ChatMessage(
      id: 'thinking-${DateTime.now().millisecondsSinceEpoch}',
      type: MessageType.ai,
      content: content,
      timestamp: DateTime.now(),
    )]);
  }

  void removeThinking() {
    state = ChatState(state.messages.where((m) => !m.id.startsWith('thinking-')).toList());
  }

  void setMessages(List<ChatMessage> msgs) {
    state = ChatState(msgs);
  }

  void clear() {
    state = ChatState();
  }
}

final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  return ChatNotifier();
});
