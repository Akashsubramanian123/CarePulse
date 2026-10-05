import 'dart:async';
import 'dart:io';
import 'package:llama_cpp_dart/llama_cpp_dart.dart';
import '../core/constants/app_constants.dart';

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

class TriageEngineService {
  Llama? _llama;
  bool _isInitialized = false;
  int _lastTtftMs = 0;
  double _lastTokensPerSec = 0.0;

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

    final modelParams = ModelParams();
    modelParams.nGpuLayers = AppConstants.defaultNGpuLayers;

    final contextParams = ContextParams();
    contextParams.nCtx = AppConstants.defaultNCtx;

    if (Platform.isAndroid) {
      final androidCandidates = [
        'libmtmd.so',
        'libllama.so',
        'libggml.so',
      ];

      Llama? instance;
      Object? lastError;

      for (final lib in androidCandidates) {
        try {
          Llama.libraryPath = lib;
          instance = Llama(
            modelPath,
            modelParams: modelParams,
            contextParams: contextParams,
          );
          break;
        } catch (e) {
          lastError = e;
        }
      }

      if (instance == null) {
        throw lastError ?? Exception('Failed to initialize Llama engine on Android');
      } else {
        _llama = instance;
      }
    } else if (Platform.isIOS) {
      final iosCandidates = [
        'llama_cpp_dart.framework/llama_cpp_dart',
        'Llama.framework/Llama',
        'Frameworks/Llama.framework/Llama',
      ];

      Llama? instance;
      Object? lastError;

      for (final path in iosCandidates) {
        try {
          Llama.libraryPath = path;
          instance = Llama(
            modelPath,
            modelParams: modelParams,
            contextParams: contextParams,
          );
          break;
        } catch (e) {
          lastError = e;
        }
      }

      if (instance == null) {
        try {
          Llama.libraryPath = null;
          _llama = Llama(
            modelPath,
            modelParams: modelParams,
            contextParams: contextParams,
          );
        } catch (_) {
          throw lastError ?? Exception('Failed to initialize Llama engine on iOS');
        }
      } else {
        _llama = instance;
      }
    } else {
      _llama = Llama(
        modelPath,
        modelParams: modelParams,
        contextParams: contextParams,
      );
    }

    _isInitialized = true;
  }

  /// Generates first-aid triage advice as a token stream.
  Stream<String> generateTriage(
    String query, {
    void Function(TriageTelemetry telemetry)? onTelemetryUpdate,
  }) async* {
    if (!_isInitialized || _llama == null) {
      throw StateError('Triage engine is not initialized');
    }

    final formattedPrompt = AppConstants.formatEmergencyPrompt(query);
    _llama!.setPrompt(formattedPrompt);

    final startTime = DateTime.now().millisecondsSinceEpoch;
    int? firstTokenTime;
    int tokenCount = 0;

    await for (final token in _llama!.generateText()) {
      tokenCount++;
      final currentTime = DateTime.now().millisecondsSinceEpoch;

      if (firstTokenTime == null) {
        firstTokenTime = currentTime;
        _lastTtftMs = firstTokenTime - startTime;
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

      yield token;
    }
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
    if (_llama != null) {
      try {
        _llama!.dispose();
      } catch (_) {}
      _llama = null;
    }
    _isInitialized = false;
  }
}
