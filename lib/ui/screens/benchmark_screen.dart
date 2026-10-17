import 'dart:convert';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../models/benchmark_result.dart';
import '../../services/benchmark_store.dart';
import '../../services/evaluation_runner.dart';
import '../../state/triage_controller.dart';
import '../widgets/glass_card.dart';

class BenchmarkScreen extends StatefulWidget {
  const BenchmarkScreen({super.key});

  @override
  State<BenchmarkScreen> createState() => _BenchmarkScreenState();
}

class _BenchmarkScreenState extends State<BenchmarkScreen> {
  final BenchmarkStore _benchmarkStore = BenchmarkStore();
  final DeviceInfoPlugin _deviceInfoPlugin = DeviceInfoPlugin();

  String _deviceModel = 'Loading...';
  String _osVersion = 'Loading...';

  // Config options
  bool _enablePipelineA = true;
  bool _enablePipelineB = true;
  bool _enablePipelineC = false;
  bool _enablePipelineD = false;
  int _repetitions = 1;
  int _cooldownSeconds = 2;

  // Running state
  bool _isRunning = false;
  bool _cancelled = false;
  int _currentStep = 0;
  int _totalSteps = 0;
  String _currentPipelineName = '';

  BenchmarkRun? _currentRun;
  List<BenchmarkRun> _pastRuns = [];
  bool _showPastRuns = false;

  @override
  void initState() {
    super.initState();
    _loadDeviceInfo();
    _loadPastRuns();
  }

  Future<void> _loadDeviceInfo() async {
    String model = 'Unknown';
    String os = Platform.operatingSystem;
    try {
      if (Platform.isAndroid) {
        final info = await _deviceInfoPlugin.androidInfo;
        model = '${info.manufacturer} ${info.model}';
        os = 'Android ${info.version.release} (SDK ${info.version.sdkInt})';
      } else if (Platform.isIOS) {
        final info = await _deviceInfoPlugin.iosInfo;
        model = info.utsname.machine;
        os = '${info.systemName} ${info.systemVersion}';
      } else if (Platform.isWindows) {
        final info = await _deviceInfoPlugin.windowsInfo;
        model = info.computerName;
        os = info.productName;
      } else if (Platform.isLinux) {
        final info = await _deviceInfoPlugin.linuxInfo;
        model = info.name;
        os = info.versionId ?? 'Linux';
      } else if (Platform.isMacOS) {
        final info = await _deviceInfoPlugin.macOsInfo;
        model = info.model;
        os = 'macOS ${info.osRelease}';
      }
    } catch (_) {
      model = Platform.localHostname;
    }

    if (mounted) {
      setState(() {
        _deviceModel = model;
        _osVersion = os;
      });
    }
  }

  Future<void> _loadPastRuns() async {
    final runs = await _benchmarkStore.getRuns();
    if (mounted) {
      setState(() {
        _pastRuns = runs;
        if (_currentRun == null && runs.isNotEmpty) {
          _currentRun = runs.first;
        }
      });
    }
  }

  Future<void> _startBenchmark(TriageController triageController) async {
    final enabledPipelines = <String>[];
    if (_enablePipelineA) enabledPipelines.add('A_red_flag');
    if (_enablePipelineB) enabledPipelines.add('B_retrieval');
    if (_enablePipelineC && triageController.isReady) {
      enabledPipelines.add('C_ai_no_context');
    }
    if (_enablePipelineD && triageController.isReady) {
      enabledPipelines.add('D_ai_with_context');
    }

    if (enabledPipelines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please select at least one pipeline to benchmark.')),
      );
      return;
    }

    setState(() {
      _isRunning = true;
      _cancelled = false;
      _currentStep = 0;
      _totalSteps = 0;
      _currentPipelineName = 'Loading scenarios...';
    });

    try {
      final scenarios = await EvaluationRunner.loadScenarios();

      final runner = EvaluationRunner(
        engineService: triageController.isReady ? null : null,
      );

      final run = await runner.runBenchmark(
        scenarios: scenarios,
        enabledPipelines: enabledPipelines,
        repetitions: _repetitions,
        cooldownSeconds: _cooldownSeconds,
        deviceModel: _deviceModel,
        osVersion: _osVersion,
        modelFileName: AppConstants.modelFileName,
        modelSizeBytes: AppConstants.modelSizeBytes,
        isCancelled: () => _cancelled,
        onProgress: (step, total, pipeline) {
          if (mounted) {
            setState(() {
              _currentStep = step;
              _totalSteps = total;
              _currentPipelineName = pipeline;
            });
          }
        },
      );

      await _benchmarkStore.saveRun(run);
      await _loadPastRuns();

      if (mounted) {
        setState(() {
          _currentRun = run;
          _isRunning = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Benchmark completed successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isRunning = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Benchmark error: $e')),
        );
      }
    }
  }

  void _cancelBenchmark() {
    setState(() {
      _cancelled = true;
      _isRunning = false;
    });
  }

  Future<void> _exportCsv() async {
    if (_currentRun == null) return;
    final csv = EvaluationRunner.generateCsv(_currentRun!);
    // ignore: deprecated_member_use
    await Share.share(
      csv,
      subject: 'CarePulse_Benchmark_${_currentRun!.id}.csv',
    );
  }

  Future<void> _exportJson() async {
    if (_currentRun == null) return;
    final jsonStr =
        const JsonEncoder.withIndent('  ').convert(_currentRun!.toJson());
    // ignore: deprecated_member_use
    await Share.share(
      jsonStr,
      subject: 'CarePulse_Benchmark_${_currentRun!.id}.json',
    );
  }

  Future<void> _copyMarkdownSummary() async {
    if (_currentRun == null) return;
    final md = EvaluationRunner.generateMarkdownSummary(_currentRun!);
    await Clipboard.setData(ClipboardData(text: md));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Markdown summary copied to clipboard!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final glass = Theme.of(context).extension<CarePulseGlass>()!;
    final triage = Provider.of<TriageController?>(context);
    final isModelReady = triage?.isReady ?? false;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Benchmark & Evaluation'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (_pastRuns.isNotEmpty)
            IconButton(
              icon: Icon(
                _showPastRuns
                    ? Icons.assessment_rounded
                    : Icons.history_rounded,
                color: glass.accentMint,
              ),
              tooltip: _showPastRuns ? 'Show Results' : 'Past Runs',
              onPressed: () {
                setState(() => _showPastRuns = !_showPastRuns);
              },
            ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: glass.backgroundGradient,
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_showPastRuns) ...[
                  _buildPastRunsList(glass),
                ] else ...[
                  _buildDeviceAndModelCard(glass, isModelReady),
                  const SizedBox(height: 14),
                  _buildControlsCard(glass, isModelReady, triage),
                  const SizedBox(height: 14),
                  if (_isRunning) _buildProgressCard(glass),
                  if (_currentRun != null && !_isRunning) ...[
                    _buildSummaryCard(glass, _currentRun!),
                    const SizedBox(height: 14),
                    _buildVisualBarsCard(glass, _currentRun!),
                    const SizedBox(height: 14),
                    _buildExportBar(glass),
                    const SizedBox(height: 14),
                    _buildDetailedResultsCard(glass, _currentRun!),
                  ],
                ],
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDeviceAndModelCard(CarePulseGlass glass, bool isModelReady) {
    final sizeMb =
        (AppConstants.modelSizeBytes / (1024 * 1024)).toStringAsFixed(0);

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.memory_rounded, color: glass.accentMint, size: 20),
              const SizedBox(width: 8),
              Text(
                'Device & Model Runtime',
                style: TextStyle(
                  color: glass.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildInfoRow('Device', _deviceModel, glass),
          _buildInfoRow('Operating System', _osVersion, glass),
          _buildInfoRow('Model File', AppConstants.modelFileName, glass),
          _buildInfoRow('Model Size',
              '$sizeMb MB (${AppConstants.modelSizeBytes} bytes)', glass),
          _buildInfoRow('Quantization', 'Q4_K_M (4-bit Medium)', glass),
          _buildInfoRow(
              'Context / GPU Layers', 'nCtx: 2048 | nGpuLayers: 0', glass),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isModelReady
                  ? glass.accentMint.withValues(alpha: 0.15)
                  : const Color(0xFFE05A4F).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color:
                    isModelReady ? glass.accentMint : const Color(0xFFE05A4F),
                width: 0.8,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isModelReady
                      ? Icons.check_circle_outline_rounded
                      : Icons.info_outline_rounded,
                  color:
                      isModelReady ? glass.accentMint : const Color(0xFFE05A4F),
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  isModelReady
                      ? 'AI Model Ready on Device'
                      : 'AI Model Not Loaded (Pipelines A & B work 100% offline)',
                  style: TextStyle(
                    color: isModelReady
                        ? glass.accentMint
                        : const Color(0xFFE05A4F),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, CarePulseGlass glass) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: TextStyle(color: glass.textSecondary, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: glass.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlsCard(
    CarePulseGlass glass,
    bool isModelReady,
    TriageController? triage,
  ) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tune_rounded, color: glass.accentMint, size: 20),
              const SizedBox(width: 8),
              Text(
                'Evaluation Pipelines & Options',
                style: TextStyle(
                  color: glass.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Pipeline selection checkboxes
          CheckboxListTile(
            title: Text('Pipeline A: Red-Flag Engine Only',
                style: TextStyle(color: glass.textPrimary, fontSize: 14)),
            subtitle: Text('Tests clinical emergency rules, precision & recall',
                style: TextStyle(color: glass.textSecondary, fontSize: 12)),
            value: _enablePipelineA,
            activeColor: glass.accentMint,
            contentPadding: EdgeInsets.zero,
            onChanged: _isRunning
                ? null
                : (v) => setState(() => _enablePipelineA = v ?? false),
          ),
          CheckboxListTile(
            title: Text('Pipeline B: Protocol Retriever Only',
                style: TextStyle(color: glass.textPrimary, fontSize: 14)),
            subtitle: Text('Tests Top-1 and Top-2 retrieval accuracy',
                style: TextStyle(color: glass.textSecondary, fontSize: 12)),
            value: _enablePipelineB,
            activeColor: glass.accentMint,
            contentPadding: EdgeInsets.zero,
            onChanged: _isRunning
                ? null
                : (v) => setState(() => _enablePipelineB = v ?? false),
          ),
          CheckboxListTile(
            title: Text('Pipeline C: AI Inference (Zero Context)',
                style: TextStyle(
                    color:
                        isModelReady ? glass.textPrimary : glass.textSecondary,
                    fontSize: 14)),
            subtitle: Text(
              isModelReady
                  ? 'Generates direct triage without protocol grounding'
                  : 'Requires downloaded AI model',
              style: TextStyle(color: glass.textSecondary, fontSize: 12),
            ),
            value: _enablePipelineC,
            activeColor: glass.accentMint,
            contentPadding: EdgeInsets.zero,
            onChanged: (_isRunning || !isModelReady)
                ? null
                : (v) => setState(() => _enablePipelineC = v ?? false),
          ),
          CheckboxListTile(
            title: Text('Pipeline D: AI Grounded With Protocols',
                style: TextStyle(
                    color:
                        isModelReady ? glass.textPrimary : glass.textSecondary,
                    fontSize: 14)),
            subtitle: Text(
              isModelReady
                  ? 'Full app pipeline with protocol context injection'
                  : 'Requires downloaded AI model',
              style: TextStyle(color: glass.textSecondary, fontSize: 12),
            ),
            value: _enablePipelineD,
            activeColor: glass.accentMint,
            contentPadding: EdgeInsets.zero,
            onChanged: (_isRunning || !isModelReady)
                ? null
                : (v) => setState(() => _enablePipelineD = v ?? false),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Repetitions',
                        style: TextStyle(
                            color: glass.textSecondary, fontSize: 13)),
                    const SizedBox(height: 4),
                    DropdownButton<int>(
                      value: _repetitions,
                      dropdownColor:
                          Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFF1B242D)
                              : Colors.white,
                      isExpanded: true,
                      items: const [
                        DropdownMenuItem(value: 1, child: Text('1 Repetition')),
                        DropdownMenuItem(
                            value: 2, child: Text('2 Repetitions')),
                        DropdownMenuItem(
                            value: 3, child: Text('3 Repetitions')),
                      ],
                      onChanged: _isRunning
                          ? null
                          : (v) => setState(() => _repetitions = v ?? 1),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Cooldown',
                        style: TextStyle(
                            color: glass.textSecondary, fontSize: 13)),
                    const SizedBox(height: 4),
                    DropdownButton<int>(
                      value: _cooldownSeconds,
                      dropdownColor:
                          Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFF1B242D)
                              : Colors.white,
                      isExpanded: true,
                      items: const [
                        DropdownMenuItem(value: 1, child: Text('1s Cooldown')),
                        DropdownMenuItem(value: 2, child: Text('2s Cooldown')),
                        DropdownMenuItem(value: 3, child: Text('3s Cooldown')),
                        DropdownMenuItem(value: 5, child: Text('5s Cooldown')),
                      ],
                      onChanged: _isRunning
                          ? null
                          : (v) => setState(() => _cooldownSeconds = v ?? 2),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.bolt_rounded, color: Colors.amber, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Run on the charger and let the phone cool between runs for stable numbers.',
                    style: TextStyle(color: glass.textPrimary, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_isRunning)
            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                key: const ValueKey('cancel_benchmark_button'),
                onPressed: _cancelBenchmark,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE05A4F),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  minimumSize: const Size(double.infinity, 48),
                ),
                icon: const Icon(Icons.cancel_rounded),
                label: const Text('Cancel Benchmark'),
              ),
            )
          else
            SizedBox(
              height: 52,
              child: InkWell(
                key: const ValueKey('start_benchmark_button'),
                onTap: triage != null ? () => _startBenchmark(triage) : null,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: glass.primaryActionGradient,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.play_arrow_rounded, color: Colors.white),
                        SizedBox(width: 8),
                        Text(
                          'Start Benchmark',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProgressCard(CarePulseGlass glass) {
    final double progress =
        _totalSteps > 0 ? (_currentStep / _totalSteps).clamp(0.0, 1.0) : 0.0;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Running: $_currentPipelineName',
                style: TextStyle(
                  color: glass.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '$_currentStep / $_totalSteps',
                style: TextStyle(
                  color: glass.accentMint,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: glass.glassBorderColor,
              valueColor: AlwaysStoppedAnimation<Color>(glass.accentMint),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(CarePulseGlass glass, BenchmarkRun run) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Benchmark Results Summary',
                style: TextStyle(
                  color: glass.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${run.scenarioResults.length} records',
                style: TextStyle(color: glass.textSecondary, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final entry in run.pipelineSummaries.entries) ...[
            _buildPipelineSummarySection(entry.key, entry.value, glass),
            const Divider(height: 20),
          ],
        ],
      ),
    );
  }

  Widget _buildPipelineSummarySection(
    String pipeline,
    PipelineSummary p,
    CarePulseGlass glass,
  ) {
    String title = pipeline;
    if (pipeline == 'A_red_flag') {
      title = 'Pipeline A: Red-Flag Engine';
    } else if (pipeline == 'B_retrieval') {
      title = 'Pipeline B: Protocol Retriever';
    } else if (pipeline == 'C_ai_no_context') {
      title = 'Pipeline C: AI Without Context';
    } else if (pipeline == 'D_ai_with_context') {
      title = 'Pipeline D: AI With Protocol Grounding';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: glass.accentMint,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        if (pipeline == 'A_red_flag') ...[
          _buildMetricRow('Precision',
              '${((p.precision ?? 0) * 100).toStringAsFixed(1)}%', glass),
          _buildMetricRow('Recall',
              '${((p.recall ?? 0) * 100).toStringAsFixed(1)}%', glass),
          _buildMetricRow(
            'Confusion Counts',
            'TP: ${p.truePositives ?? 0} | FP: ${p.falsePositives ?? 0} | TN: ${p.trueNegatives ?? 0} | FN: ${p.falseNegatives ?? 0}',
            glass,
          ),
        ] else if (pipeline == 'B_retrieval') ...[
          _buildMetricRow('Top-1 Accuracy',
              '${((p.top1Accuracy ?? 0) * 100).toStringAsFixed(1)}%', glass),
          _buildMetricRow('Top-2 Accuracy',
              '${((p.top2Accuracy ?? 0) * 100).toStringAsFixed(1)}%', glass),
        ] else ...[
          _buildMetricRow(
              'Format Compliance (3 steps)',
              '${((p.formatComplianceRate ?? 0) * 100).toStringAsFixed(1)}%',
              glass),
          _buildMetricRow(
              'Key Action Coverage',
              '${((p.avgKeyActionCoverage ?? 0) * 100).toStringAsFixed(1)}%',
              glass),
          _buildMetricRow('Unsafe Advice Detected',
              '${p.unsafeAdviceCount ?? 0} violations', glass),
          _buildMetricRow('Average Word Count',
              '${(p.avgWordCount ?? 0).toStringAsFixed(0)} words', glass),
          _buildMetricRow(
              'TTFT (Time to First Token)',
              '${(p.ttftMean ?? 0).toStringAsFixed(0)} ms (p95: ${(p.ttftP95 ?? 0).toStringAsFixed(0)} ms)',
              glass),
          _buildMetricRow(
              'Generation Speed',
              '${(p.tokensPerSecMean ?? 0).toStringAsFixed(1)} tok/s (approx chunks)',
              glass),
        ],
      ],
    );
  }

  Widget _buildMetricRow(String label, String value, CarePulseGlass glass) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(color: glass.textSecondary, fontSize: 13)),
          Text(value,
              style: TextStyle(
                  color: glass.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildVisualBarsCard(CarePulseGlass glass, BenchmarkRun run) {
    final summaryA = run.pipelineSummaries['A_red_flag'];
    final summaryB = run.pipelineSummaries['B_retrieval'];
    final summaryC = run.pipelineSummaries['C_ai_no_context'];
    final summaryD = run.pipelineSummaries['D_ai_with_context'];

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Visual Performance Comparison',
            style: TextStyle(
              color: glass.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          if (summaryA != null) ...[
            _buildCustomBar('Red-Flag Precision', summaryA.precision ?? 0,
                glass.accentMint, glass),
            _buildCustomBar('Red-Flag Recall', summaryA.recall ?? 0,
                Colors.lightGreenAccent, glass),
          ],
          if (summaryB != null) ...[
            _buildCustomBar('Retriever Top-1', summaryB.top1Accuracy ?? 0,
                Colors.cyanAccent, glass),
            _buildCustomBar('Retriever Top-2', summaryB.top2Accuracy ?? 0,
                Colors.tealAccent, glass),
          ],
          if (summaryC != null) ...[
            _buildCustomBar('AI (Zero-Context) Coverage',
                summaryC.avgKeyActionCoverage ?? 0, Colors.orangeAccent, glass),
          ],
          if (summaryD != null) ...[
            _buildCustomBar('AI (With Context) Coverage',
                summaryD.avgKeyActionCoverage ?? 0, Colors.amberAccent, glass),
          ],
        ],
      ),
    );
  }

  Widget _buildCustomBar(
      String label, double value, Color barColor, CarePulseGlass glass) {
    final clamped = value.clamp(0.0, 1.0);
    final percentStr = (clamped * 100).toStringAsFixed(1);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label,
                  style: TextStyle(color: glass.textSecondary, fontSize: 12)),
              Text('$percentStr%',
                  style: TextStyle(
                      color: glass.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 4),
          Container(
            height: 10,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(5),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: clamped,
              child: Container(
                decoration: BoxDecoration(
                  color: barColor,
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExportBar(CarePulseGlass glass) {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 48,
            child: OutlinedButton.icon(
              onPressed: _exportCsv,
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: glass.accentMint),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              icon: Icon(Icons.table_chart_rounded,
                  color: glass.accentMint, size: 18),
              label: Text('Export CSV',
                  style: TextStyle(color: glass.accentMint, fontSize: 13)),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: SizedBox(
            height: 48,
            child: OutlinedButton.icon(
              onPressed: _copyMarkdownSummary,
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: glass.accentMint),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              icon: Icon(Icons.copy_rounded, color: glass.accentMint, size: 18),
              label: Text('Copy Report',
                  style: TextStyle(color: glass.accentMint, fontSize: 13)),
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: _exportJson,
          tooltip: 'Export JSON',
          icon: Icon(Icons.code_rounded, color: glass.accentMint),
        ),
      ],
    );
  }

  Widget _buildDetailedResultsCard(CarePulseGlass glass, BenchmarkRun run) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Per-Scenario Results & Manual Review',
            style: TextStyle(
              color: glass.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tap any scenario to inspect answers and submit 1-5 quality ratings.',
            style: TextStyle(color: glass.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 12),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: run.scenarioResults.length,
            itemBuilder: (ctx, idx) {
              final item = run.scenarioResults[idx];
              return _buildScenarioResultTile(item, glass, run);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildScenarioResultTile(
    ScenarioResult item,
    CarePulseGlass glass,
    BenchmarkRun run,
  ) {
    return Card(
      color: Colors.transparent,
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: glass.glassBorderColor),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        title: Text(
          item.query,
          style: TextStyle(
              color: glass.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600),
        ),
        subtitle: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: item.isCorrect
                    ? Colors.green.withValues(alpha: 0.2)
                    : Colors.red.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                item.isCorrect ? 'PASS' : 'FAIL',
                style: TextStyle(
                  color: item.isCorrect
                      ? Colors.greenAccent
                      : const Color(0xFFE05A4F),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              item.pipeline,
              style: TextStyle(color: glass.textSecondary, fontSize: 11),
            ),
            if (item.hasUnsafeAdvice == true) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFE05A4F).withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'UNSAFE',
                  style: TextStyle(
                      color: Color(0xFFE05A4F),
                      fontSize: 10,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ],
        ),
        childrenPadding: const EdgeInsets.all(12),
        children: [
          Row(
            children: [
              Text('Expected: ${item.expectedProtocolId}',
                  style: TextStyle(color: glass.textSecondary, fontSize: 12)),
              const Spacer(),
              Text('Matched: ${item.matchedProtocolId ?? "none"}',
                  style: TextStyle(color: glass.textPrimary, fontSize: 12)),
            ],
          ),
          if (item.aiResponse != null) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                item.aiResponse!,
                style: TextStyle(color: glass.textPrimary, fontSize: 12),
              ),
            ),
          ],
          if (item.unsafePhrasesDetected.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Unsafe Phrases: ${item.unsafePhrasesDetected.join(", ")}',
              style: const TextStyle(
                  color: Color(0xFFE05A4F),
                  fontSize: 12,
                  fontWeight: FontWeight.bold),
            ),
          ],
          const SizedBox(height: 10),
          // Manual review controls
          Row(
            children: [
              Text('Review:',
                  style: TextStyle(color: glass.textSecondary, fontSize: 12)),
              const SizedBox(width: 8),
              for (int star = 1; star <= 5; star++)
                InkWell(
                  onTap: () {
                    setState(() {
                      item.manualScore = star;
                    });
                    _benchmarkStore.saveRun(run);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Icon(
                      star <= (item.manualScore ?? 0)
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      color: Colors.amber,
                      size: 24,
                    ),
                  ),
                ),
              const Spacer(),
              Row(
                children: [
                  Checkbox(
                    value: item.manualUnsafe,
                    activeColor: const Color(0xFFE05A4F),
                    onChanged: (v) {
                      setState(() {
                        item.manualUnsafe = v ?? false;
                      });
                      _benchmarkStore.saveRun(run);
                    },
                  ),
                  const Text('Flag Unsafe',
                      style: TextStyle(color: Color(0xFFE05A4F), fontSize: 11)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPastRunsList(CarePulseGlass glass) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Past Benchmark Runs (${_pastRuns.length}/20)',
                style: TextStyle(
                  color: glass.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () async {
                  await _benchmarkStore.clearRuns();
                  await _loadPastRuns();
                },
                child: const Text('Clear All',
                    style: TextStyle(color: Color(0xFFE05A4F))),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final r in _pastRuns)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                'Run on ${r.timestamp.toLocal().toString().substring(0, 16)}',
                style: TextStyle(
                    color: glass.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                '${r.scenarioResults.length} tests | ${r.deviceModel}',
                style: TextStyle(color: glass.textSecondary, fontSize: 12),
              ),
              trailing: ElevatedButton(
                onPressed: () {
                  setState(() {
                    _currentRun = r;
                    _showPastRuns = false;
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: glass.accentMint,
                  foregroundColor: Colors.black,
                  minimumSize: const Size(64, 36),
                ),
                child: const Text('View'),
              ),
            ),
        ],
      ),
    );
  }
}
