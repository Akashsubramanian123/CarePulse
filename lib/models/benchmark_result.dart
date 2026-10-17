class ScenarioResult {
  final String scenarioId;
  final String query;
  final String
      pipeline; // 'A_red_flag', 'B_retrieval', 'C_ai_no_context', 'D_ai_with_context'
  final String expectedProtocolId;
  final String? matchedProtocolId;
  final bool? expectedRedFlag;
  final bool? actualRedFlag;
  final bool isCorrect;
  final bool? top1Match;
  final bool? top2Match;
  final String? aiResponse;
  final bool? formatCompliant;
  final double? keyActionCoverage;
  final int? matchedKeyActionCount;
  final int? totalKeyActionCount;
  final bool? hasUnsafeAdvice;
  final List<String> unsafePhrasesDetected;
  final int? wordCount;
  final int? ttftMs;
  final double? tokensPerSec;
  int? manualScore; // 1 to 5
  bool manualUnsafe;

  ScenarioResult({
    required this.scenarioId,
    required this.query,
    required this.pipeline,
    required this.expectedProtocolId,
    this.matchedProtocolId,
    this.expectedRedFlag,
    this.actualRedFlag,
    required this.isCorrect,
    this.top1Match,
    this.top2Match,
    this.aiResponse,
    this.formatCompliant,
    this.keyActionCoverage,
    this.matchedKeyActionCount,
    this.totalKeyActionCount,
    this.hasUnsafeAdvice,
    this.unsafePhrasesDetected = const [],
    this.wordCount,
    this.ttftMs,
    this.tokensPerSec,
    this.manualScore,
    this.manualUnsafe = false,
  });

  Map<String, dynamic> toJson() => {
        'scenarioId': scenarioId,
        'query': query,
        'pipeline': pipeline,
        'expectedProtocolId': expectedProtocolId,
        'matchedProtocolId': matchedProtocolId,
        'expectedRedFlag': expectedRedFlag,
        'actualRedFlag': actualRedFlag,
        'isCorrect': isCorrect,
        'top1Match': top1Match,
        'top2Match': top2Match,
        'aiResponse': aiResponse,
        'formatCompliant': formatCompliant,
        'keyActionCoverage': keyActionCoverage,
        'matchedKeyActionCount': matchedKeyActionCount,
        'totalKeyActionCount': totalKeyActionCount,
        'hasUnsafeAdvice': hasUnsafeAdvice,
        'unsafePhrasesDetected': unsafePhrasesDetected,
        'wordCount': wordCount,
        'ttftMs': ttftMs,
        'tokensPerSec': tokensPerSec,
        'manualScore': manualScore,
        'manualUnsafe': manualUnsafe,
      };

  factory ScenarioResult.fromJson(Map<String, dynamic> json) {
    return ScenarioResult(
      scenarioId: json['scenarioId'] as String,
      query: json['query'] as String,
      pipeline: json['pipeline'] as String,
      expectedProtocolId: json['expectedProtocolId'] as String,
      matchedProtocolId: json['matchedProtocolId'] as String?,
      expectedRedFlag: json['expectedRedFlag'] as bool?,
      actualRedFlag: json['actualRedFlag'] as bool?,
      isCorrect: json['isCorrect'] as bool? ?? false,
      top1Match: json['top1Match'] as bool?,
      top2Match: json['top2Match'] as bool?,
      aiResponse: json['aiResponse'] as String?,
      formatCompliant: json['formatCompliant'] as bool?,
      keyActionCoverage: (json['keyActionCoverage'] as num?)?.toDouble(),
      matchedKeyActionCount: json['matchedKeyActionCount'] as int?,
      totalKeyActionCount: json['totalKeyActionCount'] as int?,
      hasUnsafeAdvice: json['hasUnsafeAdvice'] as bool?,
      unsafePhrasesDetected: (json['unsafePhrasesDetected'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      wordCount: json['wordCount'] as int?,
      ttftMs: json['ttftMs'] as int?,
      tokensPerSec: (json['tokensPerSec'] as num?)?.toDouble(),
      manualScore: json['manualScore'] as int?,
      manualUnsafe: json['manualUnsafe'] as bool? ?? false,
    );
  }
}

class PipelineSummary {
  final String pipeline;
  final int totalScenarios;
  final double? precision;
  final double? recall;
  final int? truePositives;
  final int? falsePositives;
  final int? trueNegatives;
  final int? falseNegatives;
  final double? top1Accuracy;
  final double? top2Accuracy;
  final double? formatComplianceRate;
  final double? avgKeyActionCoverage;
  final int? unsafeAdviceCount;
  final double? avgWordCount;
  final double? ttftMean;
  final double? ttftMedian;
  final double? ttftP95;
  final double? tokensPerSecMean;
  final double? tokensPerSecMedian;
  final double? tokensPerSecP95;
  final double? peakRssMb;
  final int? batteryDelta;

  const PipelineSummary({
    required this.pipeline,
    required this.totalScenarios,
    this.precision,
    this.recall,
    this.truePositives,
    this.falsePositives,
    this.trueNegatives,
    this.falseNegatives,
    this.top1Accuracy,
    this.top2Accuracy,
    this.formatComplianceRate,
    this.avgKeyActionCoverage,
    this.unsafeAdviceCount,
    this.avgWordCount,
    this.ttftMean,
    this.ttftMedian,
    this.ttftP95,
    this.tokensPerSecMean,
    this.tokensPerSecMedian,
    this.tokensPerSecP95,
    this.peakRssMb,
    this.batteryDelta,
  });

  Map<String, dynamic> toJson() => {
        'pipeline': pipeline,
        'totalScenarios': totalScenarios,
        'precision': precision,
        'recall': recall,
        'truePositives': truePositives,
        'falsePositives': falsePositives,
        'trueNegatives': trueNegatives,
        'falseNegatives': falseNegatives,
        'top1Accuracy': top1Accuracy,
        'top2Accuracy': top2Accuracy,
        'formatComplianceRate': formatComplianceRate,
        'avgKeyActionCoverage': avgKeyActionCoverage,
        'unsafeAdviceCount': unsafeAdviceCount,
        'avgWordCount': avgWordCount,
        'ttftMean': ttftMean,
        'ttftMedian': ttftMedian,
        'ttftP95': ttftP95,
        'tokensPerSecMean': tokensPerSecMean,
        'tokensPerSecMedian': tokensPerSecMedian,
        'tokensPerSecP95': tokensPerSecP95,
        'peakRssMb': peakRssMb,
        'batteryDelta': batteryDelta,
      };

  factory PipelineSummary.fromJson(Map<String, dynamic> json) {
    return PipelineSummary(
      pipeline: json['pipeline'] as String,
      totalScenarios: json['totalScenarios'] as int? ?? 0,
      precision: (json['precision'] as num?)?.toDouble(),
      recall: (json['recall'] as num?)?.toDouble(),
      truePositives: json['truePositives'] as int?,
      falsePositives: json['falsePositives'] as int?,
      trueNegatives: json['trueNegatives'] as int?,
      falseNegatives: json['falseNegatives'] as int?,
      top1Accuracy: (json['top1Accuracy'] as num?)?.toDouble(),
      top2Accuracy: (json['top2Accuracy'] as num?)?.toDouble(),
      formatComplianceRate: (json['formatComplianceRate'] as num?)?.toDouble(),
      avgKeyActionCoverage: (json['avgKeyActionCoverage'] as num?)?.toDouble(),
      unsafeAdviceCount: json['unsafeAdviceCount'] as int?,
      avgWordCount: (json['avgWordCount'] as num?)?.toDouble(),
      ttftMean: (json['ttftMean'] as num?)?.toDouble(),
      ttftMedian: (json['ttftMedian'] as num?)?.toDouble(),
      ttftP95: (json['ttftP95'] as num?)?.toDouble(),
      tokensPerSecMean: (json['tokensPerSecMean'] as num?)?.toDouble(),
      tokensPerSecMedian: (json['tokensPerSecMedian'] as num?)?.toDouble(),
      tokensPerSecP95: (json['tokensPerSecP95'] as num?)?.toDouble(),
      peakRssMb: (json['peakRssMb'] as num?)?.toDouble(),
      batteryDelta: json['batteryDelta'] as int?,
    );
  }
}

class BenchmarkRun {
  final String id;
  final DateTime timestamp;
  final String deviceModel;
  final String osVersion;
  final String modelFileName;
  final int modelSizeBytes;
  final String quantization;
  final int nCtx;
  final int nGpuLayers;
  final int repetitions;
  final int cooldownSeconds;
  final Map<String, PipelineSummary> pipelineSummaries;
  final List<ScenarioResult> scenarioResults;

  BenchmarkRun({
    required this.id,
    required this.timestamp,
    required this.deviceModel,
    required this.osVersion,
    required this.modelFileName,
    required this.modelSizeBytes,
    required this.quantization,
    required this.nCtx,
    required this.nGpuLayers,
    required this.repetitions,
    required this.cooldownSeconds,
    required this.pipelineSummaries,
    required this.scenarioResults,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'timestamp': timestamp.toIso8601String(),
        'deviceModel': deviceModel,
        'osVersion': osVersion,
        'modelFileName': modelFileName,
        'modelSizeBytes': modelSizeBytes,
        'quantization': quantization,
        'nCtx': nCtx,
        'nGpuLayers': nGpuLayers,
        'repetitions': repetitions,
        'cooldownSeconds': cooldownSeconds,
        'pipelineSummaries':
            pipelineSummaries.map((k, v) => MapEntry(k, v.toJson())),
        'scenarioResults': scenarioResults.map((e) => e.toJson()).toList(),
      };

  factory BenchmarkRun.fromJson(Map<String, dynamic> json) {
    final summariesMap =
        (json['pipelineSummaries'] as Map<String, dynamic>?) ?? {};
    final summaries = summariesMap.map(
      (k, v) =>
          MapEntry(k, PipelineSummary.fromJson(v as Map<String, dynamic>)),
    );

    final resultsList = (json['scenarioResults'] as List<dynamic>?) ?? [];
    final results = resultsList
        .map((e) => ScenarioResult.fromJson(e as Map<String, dynamic>))
        .toList();

    return BenchmarkRun(
      id: json['id'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      deviceModel: json['deviceModel'] as String? ?? 'Unknown',
      osVersion: json['osVersion'] as String? ?? 'Unknown',
      modelFileName: json['modelFileName'] as String? ?? 'Unknown',
      modelSizeBytes: json['modelSizeBytes'] as int? ?? 0,
      quantization: json['quantization'] as String? ?? 'Unknown',
      nCtx: json['nCtx'] as int? ?? 2048,
      nGpuLayers: json['nGpuLayers'] as int? ?? 0,
      repetitions: json['repetitions'] as int? ?? 1,
      cooldownSeconds: json['cooldownSeconds'] as int? ?? 2,
      pipelineSummaries: summaries,
      scenarioResults: results,
    );
  }
}
