import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../services/tts_service.dart';

abstract class CprClock {
  Stopwatch createStopwatch();
  Timer createPeriodicTimer(Duration interval, void Function(Timer) callback);
}

class SystemCprClock implements CprClock {
  const SystemCprClock();

  @override
  Stopwatch createStopwatch() => Stopwatch();

  @override
  Timer createPeriodicTimer(Duration interval, void Function(Timer) callback) {
    return Timer.periodic(interval, callback);
  }
}

class CprController extends ChangeNotifier {
  final CprClock _clock;
  final TtsService _ttsService;

  int _bpm = 110;
  bool _isRunning = false;
  bool _isMuted = false;

  int _compressionCount = 0;
  int _currentCycle = 1;
  double _nextBeatMs = 0.0;

  Stopwatch? _stopwatch;
  Timer? _tickerTimer;
  String? _lastVoicePrompt;

  // Optional beat and prompt callbacks for testing
  void Function()? onBeatFired;
  void Function(String prompt)? onPromptFired;

  CprController({
    CprClock? clock,
    TtsService? ttsService,
  })  : _clock = clock ?? const SystemCprClock(),
        _ttsService = ttsService ?? TtsService();

  int get bpm => _bpm;
  bool get isRunning => _isRunning;
  bool get isMuted => _isMuted;
  int get compressionCount => _compressionCount;
  int get currentCycle => _currentCycle;
  String? get lastVoicePrompt => _lastVoicePrompt;

  /// Duration of a single beat in milliseconds.
  int get beatIntervalMs => (60000.0 / _bpm).round();

  Duration get elapsedTime => _stopwatch?.elapsed ?? Duration.zero;

  /// Sets the BPM clamped between 100 and 120.
  void setBpm(int newBpm) {
    final clamped = newBpm.clamp(100, 120);
    if (_bpm != clamped) {
      _bpm = clamped;
      notifyListeners();
    }
  }

  void toggleMute() {
    _isMuted = !_isMuted;
    if (_isMuted) {
      _ttsService.stop();
    }
    notifyListeners();
  }

  /// Starts or resumes the CPR rhythm session.
  Future<void> start() async {
    if (_isRunning) return;

    _isRunning = true;
    _stopwatch ??= _clock.createStopwatch();
    _stopwatch!.start();

    // Enable wakelock to prevent screen sleep during an active resuscitation attempt
    try {
      await WakelockPlus.enable();
    } catch (_) {}

    // Initial voice prompt
    _speakPrompt('Push hard and fast in the center of the chest');

    // Compute next beat
    _nextBeatMs = (_stopwatch!.elapsedMilliseconds + beatIntervalMs).toDouble();

    _tickerTimer?.cancel();
    _tickerTimer = _clock.createPeriodicTimer(
      const Duration(milliseconds: 20),
      (_) => _onClockTick(),
    );

    notifyListeners();
  }

  void _onClockTick() {
    if (!_isRunning || _stopwatch == null) return;

    final elapsed = _stopwatch!.elapsedMilliseconds.toDouble();
    final interval = 60000.0 / _bpm;

    while (elapsed >= _nextBeatMs) {
      _triggerBeat();
      _nextBeatMs += interval;
    }
  }

  /// Triggers a single compression beat.
  void triggerManualBeatForTesting() {
    _triggerBeat();
  }

  void _triggerBeat() {
    _compressionCount++;

    if (!_isMuted) {
      try {
        HapticFeedback.mediumImpact();
      } catch (_) {}
      try {
        SystemSound.play(SystemSoundType.click);
      } catch (_) {}
    }

    onBeatFired?.call();

    // Check 30-compression cycle milestone
    if (_compressionCount > 0 && _compressionCount % 30 == 0) {
      _currentCycle = (_compressionCount ~/ 30) + 1;
      _speakPrompt(
        'If you are trained, give two rescue breaths. Otherwise keep pushing',
      );
    }

    notifyListeners();
  }

  void _speakPrompt(String text) {
    _lastVoicePrompt = text;
    onPromptFired?.call(text);
    if (!_isMuted) {
      _ttsService.speak(text);
    }
  }

  /// Pauses the ongoing session without resetting counts.
  Future<void> pause() async {
    if (!_isRunning) return;
    _isRunning = false;
    _stopwatch?.stop();
    _tickerTimer?.cancel();
    _tickerTimer = null;

    try {
      await WakelockPlus.disable();
    } catch (_) {}

    _ttsService.stop();
    notifyListeners();
  }

  /// Stops and completely resets the session.
  Future<void> stop() async {
    _isRunning = false;
    _tickerTimer?.cancel();
    _tickerTimer = null;
    _stopwatch?.stop();
    _stopwatch?.reset();

    try {
      await WakelockPlus.disable();
    } catch (_) {}

    _ttsService.stop();

    _compressionCount = 0;
    _currentCycle = 1;
    _nextBeatMs = 0.0;
    _lastVoicePrompt = null;

    notifyListeners();
  }

  @override
  void dispose() {
    _tickerTimer?.cancel();
    _stopwatch?.stop();
    try {
      WakelockPlus.disable();
    } catch (_) {}
    _ttsService.stop();
    super.dispose();
  }
}
