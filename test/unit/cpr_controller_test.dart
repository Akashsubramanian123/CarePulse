import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:carepulse/state/cpr_controller.dart';

class FakeTimer implements Timer {
  final void Function() onCancel;
  FakeTimer(this.onCancel);

  @override
  bool get isActive => true;

  @override
  int get tick => 0;

  @override
  void cancel() {
    onCancel();
  }
}

class FakeStopwatch implements Stopwatch {
  int _elapsedMs = 0;
  bool _running = false;

  void advance(int ms) {
    if (_running) _elapsedMs += ms;
  }

  @override
  int get elapsedMilliseconds => _elapsedMs;

  @override
  Duration get elapsed => Duration(milliseconds: _elapsedMs);

  @override
  int get elapsedTicks => _elapsedMs * 1000;

  @override
  int get frequency => 1000000;

  @override
  bool get isRunning => _running;

  @override
  void reset() {
    _elapsedMs = 0;
  }

  @override
  void start() {
    _running = true;
  }

  @override
  void stop() {
    _running = false;
  }
}

class FakeCprClock implements CprClock {
  final FakeStopwatch stopwatch = FakeStopwatch();
  void Function(Timer)? timerCallback;
  bool timerCancelled = false;

  @override
  Stopwatch createStopwatch() => stopwatch;

  @override
  Timer createPeriodicTimer(Duration interval, void Function(Timer) callback) {
    timerCallback = callback;
    return FakeTimer(() {
      timerCancelled = true;
    });
  }

  void tick() {
    timerCallback?.call(FakeTimer(() {}));
  }
}

void main() {
  group('CprController Unit Tests', () {
    late FakeCprClock fakeClock;
    late CprController controller;

    setUp(() {
      fakeClock = FakeCprClock();
      controller = CprController(clock: fakeClock);
    });

    test('BPM is clamped between 100 and 120', () {
      expect(controller.bpm, equals(110)); // default

      controller.setBpm(90);
      expect(controller.bpm, equals(100), reason: 'Should clamp to min 100');

      controller.setBpm(140);
      expect(controller.bpm, equals(120), reason: 'Should clamp to max 120');

      controller.setBpm(115);
      expect(controller.bpm, equals(115));
    });

    test('Beat interval equals (60000 / bpm) ms', () {
      controller.setBpm(100);
      expect(controller.beatIntervalMs, equals(600));

      controller.setBpm(120);
      expect(controller.beatIntervalMs, equals(500));

      controller.setBpm(110);
      expect(controller.beatIntervalMs, equals((60000 / 110).round()));
    });

    test('Count increments as clock advances across beat intervals', () async {
      await controller.start();
      expect(controller.isRunning, isTrue);
      expect(controller.compressionCount, equals(0));

      // Advance by 1 beat (default 110 bpm ~545ms)
      final interval = controller.beatIntervalMs;
      fakeClock.stopwatch.advance(interval + 10);
      fakeClock.tick();

      expect(controller.compressionCount, equals(1));

      // Advance another beat
      fakeClock.stopwatch.advance(interval);
      fakeClock.tick();
      expect(controller.compressionCount, equals(2));
    });

    test('30-compression cycle prompt fires at 30 compressions', () async {
      String? lastPrompt;
      controller.onPromptFired = (prompt) => lastPrompt = prompt;

      await controller.start();
      expect(lastPrompt, contains('Push hard and fast'));

      // Fire 30 beats
      for (int i = 0; i < 30; i++) {
        controller.triggerManualBeatForTesting();
      }

      expect(controller.compressionCount, equals(30));
      expect(controller.currentCycle, equals(2));
      expect(lastPrompt, contains('two rescue breaths'));
    });

    test('Stop cancels everything and resets state', () async {
      await controller.start();
      controller.triggerManualBeatForTesting();
      expect(controller.compressionCount, equals(1));
      expect(controller.isRunning, isTrue);

      await controller.stop();
      expect(controller.isRunning, isFalse);
      expect(controller.compressionCount, equals(0));
      expect(controller.currentCycle, equals(1));
      expect(fakeClock.timerCancelled, isTrue);
    });
  });
}
