import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'animated_builder.dart';

class VoiceInput extends StatefulWidget {
  final Function(String text) onSend;
  final Function(String text) onVoiceResult;

  const VoiceInput({
    super.key,
    required this.onSend,
    required this.onVoiceResult,
  });

  @override
  State<VoiceInput> createState() => _VoiceInputState();
}

class _VoiceInputState extends State<VoiceInput>
    with SingleTickerProviderStateMixin {
  final _textController = TextEditingController();
  final _stt = stt.SpeechToText();
  bool _isListening = false;
  bool _speechAvailable = false;
  String _recognizedText = '';
  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      duration: const Duration(milliseconds: 550),
      vsync: this,
    );
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    final available = await _stt.initialize();
    if (mounted) {
      setState(() => _speechAvailable = available);
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  void _startListening() {
    if (!_speechAvailable) return;
    _recognizedText = '';
    _stt.listen(
      onResult: (result) {
        setState(() => _recognizedText = result.recognizedWords);
        widget.onVoiceResult(result.recognizedWords);
      },
      localeId: 'zh_CN',
    );
    setState(() => _isListening = true);
    _waveController.repeat(reverse: true);
  }

  void _stopListening() {
    _stt.stop();
    setState(() => _isListening = false);
    _waveController.stop();
    _waveController.reset();
    if (_recognizedText.trim().isNotEmpty) {
      _textController.text = _recognizedText.trim();
    }
  }

  void _sendText() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    widget.onSend(text);
    _textController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: EdgeInsets.fromLTRB(
        _isListening ? 0 : 16, 8, _isListening ? 0 : 16, 14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        constraints: BoxConstraints(
          minHeight: _isListening ? 112 : 0,
        ),
        decoration: BoxDecoration(
          color: _isListening
              ? theme.colorScheme.primary
              : (isDark
                  ? Colors.white.withAlpha(18)
                  : Colors.white.withAlpha(200)),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: _isListening
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurface.withAlpha(20),
            width: 2,
          ),
          boxShadow: _isListening
              ? [
                  BoxShadow(
                    color: theme.colorScheme.primary.withAlpha(30),
                    blurRadius: 16,
                    spreadRadius: 2,
                  )
                ]
              : null,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (_isListening) _buildListeningContent(),
            IgnorePointer(
              ignoring: _isListening,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: _isListening ? 0 : 1,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _textController,
                        maxLines: 2,
                        minLines: 1,
                        style: TextStyle(
                          fontSize: 16,
                          color: theme.colorScheme.onSurface,
                        ),
                        decoration: InputDecoration(
                          hintText: '输入指令，或按住说话...',
                          hintStyle: TextStyle(
                            color:
                                theme.colorScheme.onSurface.withAlpha(100),
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: _sendText,
                      child: Container(
                        width: 36,
                        height: 36,
                        margin: const EdgeInsets.only(bottom: 8, right: 8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: theme.colorScheme.primary,
                          boxShadow: [
                            BoxShadow(
                              color:
                                  theme.colorScheme.primary.withAlpha(60),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.arrow_upward,
                            color: Colors.white, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_speechAvailable)
              Positioned.fill(
                child: GestureDetector(
                  onLongPressStart: (_) => _startListening(),
                  onLongPressEnd: (_) => _stopListening(),
                  onLongPressCancel: () => _stopListening(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildListeningContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 16),
        _buildWaveBars(),
        const SizedBox(height: 10),
        if (_recognizedText.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              _recognizedText,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        const Spacer(),
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text(
            '正在聆听...',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWaveBars() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(7, (i) {
        return SimpleAnimatedBuilder(
          animation: _waveController,
          builder: (_, child) {
            final delay = i * 0.06;
            final t = (_waveController.value + delay) % 1.0;
            final height = 6.0 + 24.0 * (1.0 - (t - 0.5).abs() * 2);
            return Container(
              width: 3,
              height: height,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(235),
                borderRadius: BorderRadius.circular(999),
              ),
            );
          },
        );
      }),
    );
  }
}
