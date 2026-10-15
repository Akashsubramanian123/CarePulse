import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  static final TtsService _instance = TtsService._internal();
  factory TtsService() => _instance;
  TtsService._internal();

  final FlutterTts _flutterTts = FlutterTts();
  final ValueNotifier<bool> isSpeakingNotifier = ValueNotifier<bool>(false);
  bool _isInitialized = false;

  bool get isSpeaking => isSpeakingNotifier.value;

  Future<void> _init() async {
    if (_isInitialized) return;
    try {
      await _flutterTts.setSpeechRate(0.45);
      await _flutterTts.awaitSpeakCompletion(true);
      _flutterTts.setStartHandler(() {
        isSpeakingNotifier.value = true;
      });
      _flutterTts.setCompletionHandler(() {
        isSpeakingNotifier.value = false;
      });
      _flutterTts.setCancelHandler(() {
        isSpeakingNotifier.value = false;
      });
      _flutterTts.setErrorHandler((_) {
        isSpeakingNotifier.value = false;
      });
      _isInitialized = true;
    } catch (_) {
      // In tests or headless environments, initialization may fail safely
    }
  }

  Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;
    await _init();
    try {
      await _flutterTts.stop();
      isSpeakingNotifier.value = true;
      await _flutterTts.speak(text);
    } catch (_) {
      isSpeakingNotifier.value = false;
    }
  }

  Future<void> stop() async {
    try {
      await _flutterTts.stop();
    } catch (_) {}
    isSpeakingNotifier.value = false;
  }
}
