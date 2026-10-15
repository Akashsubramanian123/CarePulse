import 'package:speech_to_text/speech_to_text.dart' as stt;

class VoiceInputService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isInitialized = false;
  bool _usedOnDeviceFallback = false;

  bool get isListening => _speech.isListening;
  bool get usedOnDeviceFallback => _usedOnDeviceFallback;
  bool get isAvailable => _isInitialized;

  /// Initializes the speech recognizer.
  Future<bool> initialize({
    void Function(String status)? onStatus,
    void Function(String error)? onError,
  }) async {
    if (_isInitialized) return true;

    try {
      _isInitialized = await _speech.initialize(
        onStatus: onStatus,
        onError: (err) {
          if (onError != null) onError(err.errorMsg);
        },
      );
      return _isInitialized;
    } catch (e) {
      if (onError != null) onError(e.toString());
      return false;
    }
  }

  /// Starts speech recognition preferring on-device processing.
  /// Falls back to default recognizer if on-device is unsupported.
  Future<bool> startListening({
    required void Function(String recognizedText, bool isFinal) onResult,
    void Function(String error)? onError,
    void Function()? onFallbackToCloud,
  }) async {
    if (!_isInitialized) {
      final success = await initialize(onError: onError);
      if (!success) {
        if (onError != null) {
          onError('Microphone permission denied or speech recognition unavailable');
        }
        return false;
      }
    }

    _usedOnDeviceFallback = false;

    // Prefer on-device recognition
    try {
      await _speech.listen(
        onResult: (result) {
          onResult(result.recognizedWords, result.finalResult);
        },
        listenOptions: stt.SpeechListenOptions(
          onDevice: true,
          partialResults: true,
          listenMode: stt.ListenMode.dictation,
        ),
      );
      return true;
    } catch (_) {
      // Fallback to standard recognizer (shows subtle note in UI)
      _usedOnDeviceFallback = true;
      if (onFallbackToCloud != null) onFallbackToCloud();

      try {
        await _speech.listen(
          onResult: (result) {
            onResult(result.recognizedWords, result.finalResult);
          },
          listenOptions: stt.SpeechListenOptions(
            onDevice: false,
            partialResults: true,
          ),
        );
        return true;
      } catch (e) {
        if (onError != null) onError(e.toString());
        return false;
      }
    }
  }

  /// Stops listening without clearing text; caller handles final submission.
  Future<void> stopListening() async {
    try {
      await _speech.stop();
    } catch (_) {}
  }

  Future<void> cancelListening() async {
    try {
      await _speech.cancel();
    } catch (_) {}
  }
}
