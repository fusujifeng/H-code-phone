import 'package:flutter/material.dart';

class _ThinkingDots extends StatefulWidget {
  const _ThinkingDots();

  @override
  State<_ThinkingDots> createState() => _ThinkingDotsState();
}

class _ThinkingDotsState extends State<_ThinkingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final delay = i * 0.2;
            final t = (_controller.value + delay) % 1.0;
            final scale = 0.4 + 0.6 * (1.0 - ((t - 0.5).abs() * 2));
            return Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withAlpha((120 + 135 * scale).round()),
              ),
            );
          }),
        );
      },
    );
  }
}

class ChatBubble extends StatelessWidget {
  final String content;
  final bool isUser;
  final bool isVoice;
  final int? voiceDuration;
  final bool isSystem;
  final bool isThinking;

  const ChatBubble({
    super.key,
    required this.content,
    this.isUser = false,
    this.isVoice = false,
    this.voiceDuration,
    this.isSystem = false,
    this.isThinking = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (isSystem) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            content,
            style: TextStyle(
              color: theme.colorScheme.onSurface.withAlpha(128),
              fontSize: 12,
            ),
          ),
        ),
      );
    }

    if (isThinking) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.78,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withAlpha(30),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
                bottomRight: Radius.circular(20),
                bottomLeft: Radius.circular(8),
              ),
            ),
            child: const _ThinkingDots(),
          ),
        ),
      );
    }

    final bubbleColor = isUser
        ? theme.colorScheme.primary
        : theme.colorScheme.surface;
    final textColor =
        isUser ? Colors.white : theme.colorScheme.onSurface;
    final alignment =
        isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final borderRadius = BorderRadius.only(
      topLeft: const Radius.circular(20),
      topRight: const Radius.circular(20),
      bottomLeft:
          isUser ? const Radius.circular(20) : const Radius.circular(8),
      bottomRight:
          isUser ? const Radius.circular(8) : const Radius.circular(20),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: alignment,
        children: [
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.78,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: borderRadius,
              border: isUser
                  ? null
                  : Border.all(
                      color: theme.colorScheme.onSurface.withAlpha(12)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(10),
                  blurRadius: 12,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isVoice && voiceDuration != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.mic,
                          size: 14, color: textColor.withAlpha(200)),
                      const SizedBox(width: 6),
                      Text(
                        '语音 · 0:${voiceDuration.toString().padLeft(2, '0')}',
                        style: TextStyle(
                          fontSize: 11,
                          color: textColor.withAlpha(200),
                        ),
                      ),
                    ],
                  ),
                if (isVoice) const SizedBox(height: 4),
                Text(
                  content,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.5,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
