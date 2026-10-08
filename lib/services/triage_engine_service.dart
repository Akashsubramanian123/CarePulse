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

class TriageEngineService {
  LlamaEngine? _engine;
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

    _engine = await LlamaEngine.spawn(
      modelParams: ModelParams(
        path: modelPath, 
        gpuLayers: AppConstants.defaultNGpuLayers
      ),
      contextParams: ContextParams(
        nCtx: AppConstants.defaultNCtx
      ),
    );

    _isInitialized = true;
  }

  /// Generates first-aid triage advice as a token stream.
  Stream<String> generateTriage(
    String query, {
    void Function(TriageTelemetry telemetry)? onTelemetryUpdate,
    UserProfile? profile,
    String? vaultContext,
  }) async* {
    if (!_isInitialized || _engine == null) {
      throw StateError('Triage engine is not initialized');
    }

    String profileText = profile?.promptContext ?? '';
    String contextPrompt = profileText.isNotEmpty ? '$profileText\n\n' : '';
    String vaultText = vaultContext != null && vaultContext.isNotEmpty ? '$vaultContext\n\n' : '';
    
    final formattedPrompt = '$contextPrompt$vaultText${AppConstants.formatEmergencyPrompt(query)}';

    final startTime = DateTime.now().millisecondsSinceEpoch;
    int? firstTokenTime;
    int tokenCount = 0;

    final session = await _engine!.createSession();

    await for (final event in session.generate(
      prompt: formattedPrompt,
      addSpecial: true,
      maxTokens: 512,
    )) {
      if (event is TokenEvent) {
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

        yield event.text;
      }
    }
    await session.dispose();
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
    if (_engine != null) {
      try {
        _engine!.dispose();
      } catch (_) {}
      _engine = null;
    }
    _isInitialized = false;
  }
}
