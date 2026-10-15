import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  static TtsService _instance = TtsService._internal();
  factory TtsService() => _instance;
  TtsService._internal();

  @visibleForTesting
  static void setMockInstance(TtsService mock) {
    _instance = mock;
  }

  FlutterTts? _flutterTts;
  FlutterTts get _tts => _flutterTts ??= FlutterTts();

  final ValueNotifier<bool> isSpeakingNotifier = ValueNotifier<bool>(false);
  bool _isInitialized = false;

  bool get isSpeaking => isSpeakingNotifier.value;

  Future<void> _init() async {
    if (_isInitialized) return;
    try {
      await _tts.setSpeechRate(0.45);
      await _tts.awaitSpeakCompletion(true);
      _tts.setStartHandler(() {
        isSpeakingNotifier.value = true;
      });
      _tts.setCompletionHandler(() {
        isSpeakingNotifier.value = false;
      });
      _tts.setCancelHandler(() {
        isSpeakingNotifier.value = false;
      });
      _tts.setErrorHandler((_) {
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
      await _tts.stop();
      isSpeakingNotifier.value = true;
      await _tts.speak(text);
    } catch (_) {
      isSpeakingNotifier.value = false;
    }
  }

  Future<void> stop() async {
    try {
      if (_flutterTts != null) {
        await _tts.stop();
      }
    } catch (_) {}
    isSpeakingNotifier.value = false;
  }
}
