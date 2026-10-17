import 'dart:async';
import 'dart:io';
import 'package:llama_cpp_dart/llama_cpp_dart.dart';
import '../core/constants/app_constants.dart';
import 'profile_service.dart';

class TriageTelemetry {
  final int ttftMs;
  final double tokensPerSec;
  final double ramUsageMb;

  const TriageTelemetry({
    required this.ttftMs,
    required this.tokensPerSec,
    required this.ramUsageMb,
  });
}

/// Simple asynchronous FIFO mutex ensuring sequential generation.
class AsyncMutex {
  final _queue = <Completer<void>>[];

  Future<void> acquire() {
    final completer = Completer<void>();
    if (_queue.isEmpty) {
      _queue.add(completer);
      return Future.value();
    }
    _queue.add(completer);
    return completer.future;
  }

  void release() {
    if (_queue.isNotEmpty) {
      _queue.removeAt(0);
      if (_queue.isNotEmpty) {
        _queue.first.complete();
      }
    }
  }
}

class TriageEngineService {
  LlamaEngine? _engine;
  bool _isInitialized = false;
  int _lastTtftMs = 0;
  double _lastTokensPerSec = 0.0;

  final AsyncMutex _mutex = AsyncMutex();
  EngineSession? _currentSession;
  StreamSubscription<GenerationEvent>? _currentSessionSub;
  Completer<void>? _currentCompleter;

  bool get isInitialized => _isInitialized;
  int get lastTtftMs => _lastTtftMs;
  double get lastTokensPerSec => _lastTokensPerSec;

  /// Initializes the Llama engine with specified parameters.
  Future<void> initializeEngine(String modelPath) async {
    if (_isInitialized) return;

    final file = File(modelPath);
    if (!await file.exists()) {
      throw Exception('Model file does not exist at path: $modelPath');
    }

    _engine = await LlamaEngine.spawn(
      modelParams: ModelParams(
          path: modelPath, gpuLayers: AppConstants.defaultNGpuLayers),
      contextParams: ContextParams(nCtx: AppConstants.defaultNCtx),
    );

    _isInitialized = true;
  }

  /// Cancels any in-flight generation, cleans up the session, and releases the mutex.
  Future<void> stopGeneration() async {
    final sub = _currentSessionSub;
    _currentSessionSub = null;
    if (sub != null) {
      await sub.cancel();
    }

    final session = _currentSession;
    _currentSession = null;
    if (session != null) {
      try {
        await session.clear();
      } catch (_) {}
      try {
        await session.dispose();
      } catch (_) {}
    }

    if (_currentCompleter != null && !_currentCompleter!.isCompleted) {
      _currentCompleter!.complete();
    }
  }

  /// Generates first-aid triage advice as a token stream.
  Stream<String> generateTriage(
    String query, {
    void Function(TriageTelemetry telemetry)? onTelemetryUpdate,
    UserProfile? profile,
    String? context,
  }) {
    if (!_isInitialized || _engine == null) {
      throw StateError('Triage engine is not initialized');
    }

    final controller = StreamController<String>();

    Future<void> run() async {
      await _mutex.acquire();
      EngineSession? session;
      StreamSubscription<GenerationEvent>? sub;

      try {
        String profileText = profile?.promptContext ?? '';
        String contextPrompt = profileText.isNotEmpty ? '$profileText\n\n' : '';

        final formattedPrompt =
            '$contextPrompt${AppConstants.formatEmergencyPrompt(query, context: context)}';

        final startTime = DateTime.now().millisecondsSinceEpoch;
        int? firstTokenTime;
        int tokenCount = 0;

        session = await _engine!.createSession();
        _currentSession = session;
        await session.clear();

        final genStream = session.generate(
          prompt: formattedPrompt,
          addSpecial: true,
          maxTokens: 512,
        );

        final completer = Completer<void>();
        _currentCompleter = completer;

        sub = genStream.listen(
          (event) {
            if (event is TokenEvent) {
              tokenCount++;
              final currentTime = DateTime.now().millisecondsSinceEpoch;

              if (firstTokenTime == null) {
                firstTokenTime = currentTime;
                _lastTtftMs = currentTime - startTime;
              }

              final elapsedTimeSec = (currentTime - startTime) / 1000.0;
              if (elapsedTimeSec > 0) {
                _lastTokensPerSec = tokenCount / elapsedTimeSec;
              }

              if (onTelemetryUpdate != null) {
                onTelemetryUpdate(TriageTelemetry(
                  ttftMs: _lastTtftMs,
                  tokensPerSec: _lastTokensPerSec,
                  ramUsageMb: getEstimatedRamUsageMB(),
                ));
              }

              if (!controller.isClosed) {
                controller.add(event.text);
              }
            }
          },
          onError: (Object error, StackTrace stackTrace) {
            if (!controller.isClosed) {
              controller.addError(error, stackTrace);
            }
            if (!completer.isCompleted) completer.complete();
          },
          onDone: () {
            if (!completer.isCompleted) completer.complete();
          },
          cancelOnError: true,
        );
        _currentSessionSub = sub;

        await completer.future;
      } catch (e, st) {
        if (!controller.isClosed) {
          controller.addError(e, st);
        }
      } finally {
        _currentSessionSub = null;
        if (sub != null) {
          try {
            await sub.cancel();
          } catch (_) {}
        }
        if (session != null) {
          try {
            await session.clear();
          } catch (_) {}
          try {
            await session.dispose();
          } catch (_) {}
        }
        _currentSession = null;
        _mutex.release();
        if (!controller.isClosed) {
          await controller.close();
        }
      }
    }

    controller.onCancel = () async {
      await stopGeneration();
    };

    run();

    return controller.stream;
  }

  /// Returns estimated RAM usage in MBs for telemetry monitoring.
  double getEstimatedRamUsageMB() {
    try {
      final info = ProcessInfo.currentRss;
      return info / (1024 * 1024);
    } catch (_) {
      return 450.0; // Fallback telemetry estimate
    }
  }

  /// Cleanly releases memory mapping and engine resources.
  void dispose() {
    stopGeneration();
    if (_engine != null) {
      try {
        _engine!.dispose();
      } catch (_) {}
      _engine = null;
    }
    _isInitialized = false;
  }
}
