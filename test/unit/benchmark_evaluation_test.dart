import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:carepulse/models/evaluation_scenario.dart';
import 'package:carepulse/services/evaluation_runner.dart';
import 'package:carepulse/services/protocol_repository.dart';
import 'package:carepulse/services/protocol_retriever.dart';
import 'package:carepulse/services/red_flag_engine.dart';
import 'package:carepulse/services/triage_engine_service.dart';

class FakeEvaluationEngineService extends TriageEngineService {
  final List<String> simulatedChunks;
  final Duration chunkDelay;

  FakeEvaluationEngineService({
    this.simulatedChunks = const [
      '1. Immediate action. ',
      '2. Precaution step. ',
      '3. Monitor carefully.'
    ],
    this.chunkDelay = Duration.zero,
  });

  @override
  Stream<String> generateTriage(
    String query, {
    void Function(TriageTelemetry telemetry)? onTelemetryUpdate,
    dynamic profile,
    String? context,
  }) async* {
    for (final chunk in simulatedChunks) {
      if (chunkDelay > Duration.zero) {
        await Future<void>.delayed(chunkDelay);
      }
      yield chunk;
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late String scenariosJson;
  late String protocolsJson;
  late ProtocolRepository repo;
  late ProtocolRetriever retriever;
  late RedFlagEngine redFlagEngine;

  setUpAll(() {
    scenariosJson = File('assets/eval/scenarios.json').readAsStringSync();
    protocolsJson = File('assets/protocols/protocols.json').readAsStringSync();

    repo = ProtocolRepository();
    repo.loadFromJsonString(protocolsJson);

    retriever = ProtocolRetriever(repo);
    redFlagEngine = RedFlagEngine();
  });

  group('Scenario JSON Dataset Validation', () {
    test('Scenario file contains >= 40 scenarios with unique IDs', () async {
      final scenarios =
          await EvaluationRunner.loadScenarios(jsonContent: scenariosJson);
      expect(scenarios.length, greaterThanOrEqualTo(40));

      final ids = scenarios.map((s) => s.id).toSet();
      expect(ids.length, equals(scenarios.length),
          reason: 'All scenario IDs must be unique');
    });

    test('Every expectedProtocolId exists in bundled protocols', () async {
      final scenarios =
          await EvaluationRunner.loadScenarios(jsonContent: scenariosJson);
      final validProtocolIds = repo.allProtocols.map((p) => p.id).toSet();

      for (final scenario in scenarios) {
        expect(
          validProtocolIds.contains(scenario.expectedProtocolId),
          isTrue,
          reason:
              'Scenario ${scenario.id} has invalid expectedProtocolId: ${scenario.expectedProtocolId}',
        );
      }
    });

    test('Contains at least 8 negative scenarios (expectedRedFlag == false)',
        () async {
      final scenarios =
          await EvaluationRunner.loadScenarios(jsonContent: scenariosJson);
      final negatives = scenarios.where((s) => !s.expectedRedFlag).toList();
      expect(negatives.length, greaterThanOrEqualTo(8));
    });

    test('All scenarios have non-empty keyActions and forbiddenPhrases',
        () async {
      final scenarios =
          await EvaluationRunner.loadScenarios(jsonContent: scenariosJson);
      for (final s in scenarios) {
        expect(s.keyActions, isNotEmpty,
            reason: '${s.id} keyActions cannot be empty');
        for (final group in s.keyActions) {
          expect(group, isNotEmpty,
              reason: '${s.id} keyAction synonym group cannot be empty');
        }
        expect(s.forbiddenPhrases, isNotNull);
      }
    });

    test('Every bundled protocol ID is covered by at least one scenario',
        () async {
      final scenarios =
          await EvaluationRunner.loadScenarios(jsonContent: scenariosJson);
      final coveredProtocols =
          scenarios.map((s) => s.expectedProtocolId).toSet();
      final allProtocols = repo.allProtocols.map((p) => p.id).toSet();

      for (final protocolId in allProtocols) {
        expect(
          coveredProtocols.contains(protocolId),
          isTrue,
          reason:
              'Protocol $protocolId is not covered by any scenario in scenarios.json',
        );
      }
    });
  });

  group('Evaluation Scoring Functions Unit Tests', () {
    test('Format compliance checks 3 numbered steps', () {
      expect(
        EvaluationRunner.isFormatCompliant(
            '1. Apply pressure\n2. Do not remove dressing\n3. Call 112'),
        isTrue,
      );
      expect(
        EvaluationRunner.isFormatCompliant(
            'Step 1: Cool burn\nStep 2: Cover loosely\nStep 3: Monitor'),
        isTrue,
      );
      expect(
        EvaluationRunner.isFormatCompliant(
            'Just put a bandage on it and rest.'),
        isFalse,
      );
      expect(EvaluationRunner.isFormatCompliant(''), isFalse);
    });

    test('Key action coverage computes group fraction with synonyms', () {
      final keyActions = [
        ['direct pressure', 'press firmly'],
        ['call 112', 'emergency services'],
      ];

      // Both matched
      final text1 =
          'Press firmly on the wound and call emergency services immediately.';
      expect(EvaluationRunner.calculateKeyActionCoverage(text1, keyActions),
          equals(1.0));

      // 1 matched
      final text2 = 'Apply direct pressure to the wound with a cloth.';
      expect(EvaluationRunner.calculateKeyActionCoverage(text2, keyActions),
          equals(0.5));

      // 0 matched
      final text3 = 'Sit down and wait.';
      expect(EvaluationRunner.calculateKeyActionCoverage(text3, keyActions),
          equals(0.0));
    });

    test(
        'Negation-aware forbidden phrase detection flags unnegated and ignores negated phrases',
        () {
      final forbidden = ['apply ice', 'butter', 'induce vomiting'];

      // Unnegated forbidden advice
      final unsafeText =
          'You should apply ice to the burn and rub butter on it.';
      final detected =
          EvaluationRunner.detectUnsafeAdvice(unsafeText, forbidden);
      expect(detected, contains('apply ice'));
      expect(detected, contains('butter'));

      // Negated forbidden advice (within 5 words)
      final safeText =
          'Do not apply ice and never put butter on the burn. Also avoid induce vomiting.';
      final safeDetected =
          EvaluationRunner.detectUnsafeAdvice(safeText, forbidden);
      expect(safeDetected, isEmpty);
    });

    test('Word count utility counts words correctly', () {
      expect(EvaluationRunner.countWords(''), equals(0));
      expect(EvaluationRunner.countWords('  hello   world  '), equals(2));
      expect(
          EvaluationRunner.countWords(
              '1. Immediate action. 2. Precaution. 3. Monitor.'),
          equals(7));
    });

    test('Statistical aggregates: mean, median, p95', () {
      final values = [10.0, 20.0, 30.0, 40.0, 50.0];
      expect(EvaluationRunner.calculateMean(values), equals(30.0));
      expect(EvaluationRunner.calculateMedian(values), equals(30.0));
      expect(EvaluationRunner.calculateP95(values), equals(50.0));

      // Even count median
      final even = [10.0, 20.0, 30.0, 40.0];
      expect(EvaluationRunner.calculateMedian(even), equals(25.0));
    });

    test('CSV field escaping handles quotes, commas, and newlines', () {
      expect(EvaluationRunner.escapeCsvField('normal'), equals('normal'));
      expect(EvaluationRunner.escapeCsvField('hello, world'),
          equals('"hello, world"'));
      expect(EvaluationRunner.escapeCsvField('say "hello" now'),
          equals('"say ""hello"" now"'));
      expect(EvaluationRunner.escapeCsvField('line1\nline2'),
          equals('"line1\nline2"'));
      expect(EvaluationRunner.escapeCsvField(null), equals('""'));
    });
  });

  group('Evaluation Runner with Fake Engine', () {
    test('Runs all 4 pipelines with fake engine and collects metrics',
        () async {
      final testScenarios = [
        EvaluationScenario(
          id: 'test_scen_1',
          category: 'Trauma',
          query: 'spurting bright red blood from arm cut',
          expectedProtocolId: 'bleeding',
          expectedRedFlag: true,
          keyActions: [
            ['direct pressure', 'press firmly'],
            ['call 112', 'emergency'],
          ],
          forbiddenPhrases: ['remove embedded object'],
          notes: 'Test',
        ),
        EvaluationScenario(
          id: 'test_scen_2',
          category: 'Minor Trauma',
          query: 'minor paper cut on finger, awake and breathing fine',
          expectedProtocolId: 'bleeding',
          expectedRedFlag: false,
          keyActions: [
            ['clean water', 'rinse'],
          ],
          forbiddenPhrases: ['tourniquet'],
          notes: 'Test negative',
        ),
      ];

      final fakeEngine = FakeEvaluationEngineService(
        simulatedChunks: [
          '1. Direct pressure on the wound firmly.\n',
          '2. Precaution: do not remove embedded object.\n',
          '3. Call 112 for emergency help.',
        ],
      );

      final runner = EvaluationRunner(
        engineService: fakeEngine,
        protocolRetriever: retriever,
        redFlagEngine: redFlagEngine,
        batteryLevelProvider: () async => 95,
        sleeper: (_) async {},
      );

      final run = await runner.runBenchmark(
        scenarios: testScenarios,
        enabledPipelines: [
          'A_red_flag',
          'B_retrieval',
          'C_ai_no_context',
          'D_ai_with_context',
        ],
        repetitions: 1,
        cooldownSeconds: 0,
      );

      expect(run.pipelineSummaries.containsKey('A_red_flag'), isTrue);
      expect(run.pipelineSummaries.containsKey('B_retrieval'), isTrue);
      expect(run.pipelineSummaries.containsKey('C_ai_no_context'), isTrue);
      expect(run.pipelineSummaries.containsKey('D_ai_with_context'), isTrue);

      final summaryA = run.pipelineSummaries['A_red_flag']!;
      expect(summaryA.totalScenarios, equals(2));
      expect(summaryA.truePositives, equals(1));
      expect(summaryA.trueNegatives, equals(1));
      expect(summaryA.precision, equals(1.0));
      expect(summaryA.recall, equals(1.0));

      final summaryD = run.pipelineSummaries['D_ai_with_context']!;
      expect(summaryD.formatComplianceRate, equals(1.0));
      expect(summaryD.unsafeAdviceCount, equals(0));

      final csv = EvaluationRunner.generateCsv(run);
      expect(csv, contains('Scenario ID,Pipeline,Query'));
      expect(csv, contains('test_scen_1'));

      final md = EvaluationRunner.generateMarkdownSummary(run);
      expect(md, contains('### CarePulse Benchmark Summary'));
      expect(md, contains('Red-Flag Only'));
    });

    test('Benchmark respects cancellation signal', () async {
      final testScenarios = List.generate(
        10,
        (i) => EvaluationScenario(
          id: 'scen_$i',
          category: 'Trauma',
          query: 'bleeding heavily $i',
          expectedProtocolId: 'bleeding',
          expectedRedFlag: true,
          keyActions: [
            ['pressure']
          ],
          forbiddenPhrases: [],
          notes: '',
        ),
      );

      final runner = EvaluationRunner(
        protocolRetriever: retriever,
        redFlagEngine: redFlagEngine,
        sleeper: (_) async {},
      );

      bool cancelNow = false;
      int stepsRan = 0;

      final run = await runner.runBenchmark(
        scenarios: testScenarios,
        enabledPipelines: ['A_red_flag'],
        isCancelled: () => cancelNow,
        onProgress: (step, total, pipe) {
          stepsRan = step;
          if (step >= 3) {
            cancelNow = true;
          }
        },
      );

      expect(stepsRan, lessThan(10));
      expect(run.scenarioResults.length, lessThan(10));
    });
  });

  group('Real Scenarios Evaluation Metrics (Pipelines A & B)', () {
    test('Run Pipelines A (Red-Flag) & B (Retrieval) over real 45 scenarios',
        () async {
      final scenarios =
          await EvaluationRunner.loadScenarios(jsonContent: scenariosJson);

      final runner = EvaluationRunner(
        protocolRetriever: retriever,
        redFlagEngine: redFlagEngine,
        sleeper: (_) async {},
      );

      final run = await runner.runBenchmark(
        scenarios: scenarios,
        enabledPipelines: ['A_red_flag', 'B_retrieval'],
        repetitions: 1,
      );

      final summaryA = run.pipelineSummaries['A_red_flag']!;
      final summaryB = run.pipelineSummaries['B_retrieval']!;

      stdout.writeln('=== REAL BENCHMARK RESULTS (Pipelines A & B) ===');
      stdout.writeln('Total scenarios: ${scenarios.length}');
      stdout.writeln(
          'Pipeline A (Red-Flag): Precision = ${(summaryA.precision! * 100).toStringAsFixed(1)}% | Recall = ${(summaryA.recall! * 100).toStringAsFixed(1)}%');
      stdout.writeln(
          'Pipeline A Confusion: TP = ${summaryA.truePositives}, FP = ${summaryA.falsePositives}, TN = ${summaryA.trueNegatives}, FN = ${summaryA.falseNegatives}');
      stdout.writeln(
          'Pipeline B (Retrieval): Top-1 = ${(summaryB.top1Accuracy! * 100).toStringAsFixed(1)}% | Top-2 = ${(summaryB.top2Accuracy! * 100).toStringAsFixed(1)}%');

      for (final r in run.scenarioResults
          .where((r) => r.pipeline == 'A_red_flag' && !r.isCorrect)) {
        stdout.writeln(
            'A MISMATCH: [${r.scenarioId}] query: "${r.query}" expectedRedFlag: ${r.expectedRedFlag} actualRedFlag: ${r.actualRedFlag} expectedProt: ${r.expectedProtocolId} matchedProt: ${r.matchedProtocolId}');
      }

      for (final r in run.scenarioResults
          .where((r) => r.pipeline == 'B_retrieval' && !r.isCorrect)) {
        stdout.writeln(
            'B MISMATCH: [${r.scenarioId}] query: "${r.query}" expectedProt: ${r.expectedProtocolId} matchedProt: ${r.matchedProtocolId} top2: ${r.top2Match}');
      }
    });
  });
}
