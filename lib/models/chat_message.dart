enum MessageType { ai, user, system }

class ChatMessage {
  final String id;
  final MessageType type;
  final String content;
  final bool isVoice;
  final int? voiceDuration;
  final DateTime timestamp;

  const ChatMessage({
    required this.id,
    required this.type,
    required this.content,
    this.isVoice = false,
    this.voiceDuration,
    required this.timestamp,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      type: MessageType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => MessageType.system,
      ),
      content: json['content'] as String,
      isVoice: json['isVoice'] as bool? ?? false,
      voiceDuration: json['voiceDuration'] as int?,
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int),
    );
  }
}
