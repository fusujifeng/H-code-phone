import 'dart:async';

class VoiceService {
  bool _isListening = false;
  bool get isListening => _isListening;

  final StreamController<String> _resultController =
      StreamController<String>.broadcast();
  Stream<String> get results => _resultController.stream;

  Future<bool> initialize() async {
    // TODO: initialize speech_to_text plugin
    return true;
  }

  Future<void> startListening() async {
    _isListening = true;
    // TODO: start speech recognition
  }

  Future<String?> stopListening() async {
    _isListening = false;
    // TODO: stop recognition, return transcribed text
    return null;
  }

  void dispose() {
    _resultController.close();
  }
}
