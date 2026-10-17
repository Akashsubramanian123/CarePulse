import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:carepulse/core/constants/app_constants.dart';
import 'package:carepulse/models/triage_question.dart';
import 'package:carepulse/services/history_store.dart';
import 'package:carepulse/services/model_download_service.dart';
import 'package:carepulse/services/protocol_repository.dart';
import 'package:carepulse/services/protocol_retriever.dart';
import 'package:carepulse/services/red_flag_engine.dart';
import 'package:carepulse/services/triage_clarifier.dart';
import 'package:carepulse/services/triage_engine_service.dart';
import 'package:carepulse/state/app_settings_controller.dart';
import 'package:carepulse/state/triage_controller.dart';

class MockReadyDownloadService extends ModelDownloadService {
  @override
  Future<bool> isModelReady() async => true;
  @override
  Future<String> getModelPath() async => '/mock/model.gguf';
}

class MockNotReadyDownloadService extends ModelDownloadService {
  @override
  Future<bool> isModelReady() async => false;
}

class ContextRecordingEngine extends TriageEngineService {
  String? lastContextReceived;

  @override
  bool get isInitialized => true;

  @override
  Future<void> initializeEngine(String modelPath) async {}

  @override
  Stream<String> generateTriage(
    String query, {
    void Function(TriageTelemetry telemetry)? onTelemetryUpdate,
    dynamic profile,
    String? context,
  }) async* {
    lastContextReceived = context;
    yield '1. IMMEDIATE ACTION: Rest calmly.\n2. PRECAUTION: Stay warm.\n3. MONITOR: Watch breathing.';
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProtocolRepository repo;
  late ProtocolRetriever retriever;
  late RedFlagEngine redFlagEngine;
  late TriageClarifier clarifier;

  setUpAll(() async {
    repo = ProtocolRepository();
    await repo.loadProtocols();
    retriever = ProtocolRetriever(repo);
    redFlagEngine = RedFlagEngine();
    clarifier = TriageClarifier(
      protocolRetriever: retriever,
      redFlagEngine: redFlagEngine,
    );
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('TriageClarifier Decision Logic', () {
    test('Vague query asks for clarification', () {
      expect(clarifier.shouldAskClarification('he is not well'), isTrue);
      expect(clarifier.shouldAskClarification('someone help me'), isTrue);
      expect(clarifier.shouldAskClarification('feeling sick'), isTrue);
    });

    test('Red-flag query NEVER asks for clarification', () {
      expect(
          clarifier.shouldAskClarification(
              'he is unconscious and stopped breathing'),
          isFalse);
      expect(
          clarifier.shouldAskClarification(
              'crushing chest pain radiating to left arm'),
          isFalse);
    });

    test('Preset query NEVER asks for clarification', () {
      for (final preset in emergencyPresets) {
        expect(clarifier.shouldAskClarification(preset.query), isFalse);
      }
    });

    test('Clear match above threshold NEVER asks for clarification', () {
      expect(
          clarifier.shouldAskClarification(
              'boiling water spilled on my arm, severe skin burn'),
          isFalse);
    });
  });

  group('TriageController Clarification Question Flow', () {
    test('Vague query enters clarification flow with awake question', () async {
      final controller = TriageController(
        downloadService: MockReadyDownloadService(),
        engineService: ContextRecordingEngine(),
        protocolRepository: repo,
        protocolRetriever: retriever,
        redFlagEngine: redFlagEngine,
        triageClarifier: clarifier,
        historyStore: HistoryStore(),
        settingsController: AppSettingsController(),
      );
      await controller.checkModelStatus();

      await controller.submitEmergencyQuery('he is not well');

      expect(controller.pendingQuestion, isNotNull);
      expect(controller.pendingQuestion!.id, TriageQuestion.awake.id);
      expect(controller.isGenerating, isFalse);
    });

    test('Awake = No triggers unresponsive protocol through red-flag path',
        () async {
      final controller = TriageController(
        downloadService: MockReadyDownloadService(),
        engineService: ContextRecordingEngine(),
        protocolRepository: repo,
        protocolRetriever: retriever,
        redFlagEngine: redFlagEngine,
        triageClarifier: clarifier,
        historyStore: HistoryStore(),
        settingsController: AppSettingsController(),
      );
      await controller.checkModelStatus();

      await controller.submitEmergencyQuery('he is not well');
      expect(controller.pendingQuestion, isNotNull);

      await controller.answerClarifyingQuestion(TriageAnswer.no);

      expect(controller.pendingQuestion, isNull);
      expect(controller.callEmergencyNow, isTrue);
      expect(controller.answerSource, AnswerSource.verifiedProtocol);
      expect(controller.selectedProtocol?.id,
          TriageClarifier.unresponsiveProtocolId);
      expect(controller.clarificationNote,
          TriageClarifier.emergencyClarificationNote);
      expect(controller.streamedResponse, isNotEmpty);
    });

    test('Awake = Not sure triggers unresponsive protocol', () async {
      final controller = TriageController(
        downloadService: MockReadyDownloadService(),
        engineService: ContextRecordingEngine(),
        protocolRepository: repo,
        protocolRetriever: retriever,
        redFlagEngine: redFlagEngine,
        triageClarifier: clarifier,
        historyStore: HistoryStore(),
        settingsController: AppSettingsController(),
      );
      await controller.checkModelStatus();

      await controller.submitEmergencyQuery('he is not well');
      await controller.answerClarifyingQuestion(TriageAnswer.notSure);

      expect(controller.callEmergencyNow, isTrue);
      expect(controller.selectedProtocol?.id,
          TriageClarifier.unresponsiveProtocolId);
      expect(controller.clarificationNote,
          TriageClarifier.emergencyClarificationNote);
    });

    test('Awake = Yes advances to Breathing question', () async {
      final controller = TriageController(
        downloadService: MockReadyDownloadService(),
        engineService: ContextRecordingEngine(),
        protocolRepository: repo,
        protocolRetriever: retriever,
        redFlagEngine: redFlagEngine,
        triageClarifier: clarifier,
        historyStore: HistoryStore(),
        settingsController: AppSettingsController(),
      );
      await controller.checkModelStatus();

      await controller.submitEmergencyQuery('he is not well');
      await controller.answerClarifyingQuestion(TriageAnswer.yes);

      expect(controller.pendingQuestion, isNotNull);
      expect(controller.pendingQuestion!.id, TriageQuestion.breathing.id);
      expect(controller.callEmergencyNow, isFalse);
    });

    test(
        'Breathing = No triggers cardiac arrest protocol through red-flag path',
        () async {
      final controller = TriageController(
        downloadService: MockReadyDownloadService(),
        engineService: ContextRecordingEngine(),
        protocolRepository: repo,
        protocolRetriever: retriever,
        redFlagEngine: redFlagEngine,
        triageClarifier: clarifier,
        historyStore: HistoryStore(),
        settingsController: AppSettingsController(),
      );
      await controller.checkModelStatus();

      await controller.submitEmergencyQuery('he is not well');
      await controller.answerClarifyingQuestion(TriageAnswer.yes);
      await controller.answerClarifyingQuestion(TriageAnswer.no);

      expect(controller.pendingQuestion, isNull);
      expect(controller.callEmergencyNow, isTrue);
      expect(controller.answerSource, AnswerSource.verifiedProtocol);
      expect(controller.selectedProtocol?.id,
          TriageClarifier.cardiacArrestProtocolId);
      expect(controller.clarificationNote,
          TriageClarifier.emergencyClarificationNote);
    });

    test('Breathing = Not sure triggers cardiac arrest protocol', () async {
      final controller = TriageController(
        downloadService: MockReadyDownloadService(),
        engineService: ContextRecordingEngine(),
        protocolRepository: repo,
        protocolRetriever: retriever,
        redFlagEngine: redFlagEngine,
        triageClarifier: clarifier,
        historyStore: HistoryStore(),
        settingsController: AppSettingsController(),
      );
      await controller.checkModelStatus();

      await controller.submitEmergencyQuery('he is not well');
      await controller.answerClarifyingQuestion(TriageAnswer.yes);
      await controller.answerClarifyingQuestion(TriageAnswer.notSure);

      expect(controller.callEmergencyNow, isTrue);
      expect(controller.selectedProtocol?.id,
          TriageClarifier.cardiacArrestProtocolId);
    });

    test('Yes + Yes reaches AI engine with normal observation context line',
        () async {
      final engine = ContextRecordingEngine();
      final controller = TriageController(
        downloadService: MockReadyDownloadService(),
        engineService: engine,
        protocolRepository: repo,
        protocolRetriever: retriever,
        redFlagEngine: redFlagEngine,
        triageClarifier: clarifier,
        historyStore: HistoryStore(),
        settingsController: AppSettingsController(),
      );
      await controller.checkModelStatus();

      await controller.submitEmergencyQuery('he is not well');
      await controller.answerClarifyingQuestion(TriageAnswer.yes);
      await controller.answerClarifyingQuestion(TriageAnswer.yes);

      expect(controller.pendingQuestion, isNull);
      expect(engine.lastContextReceived,
          contains('Person is awake and breathing normally.'));
      expect(controller.streamedResponse, contains('IMMEDIATE ACTION'));
    });

    test('Skip continues normal flow', () async {
      final engine = ContextRecordingEngine();
      final controller = TriageController(
        downloadService: MockReadyDownloadService(),
        engineService: engine,
        protocolRepository: repo,
        protocolRetriever: retriever,
        redFlagEngine: redFlagEngine,
        triageClarifier: clarifier,
        historyStore: HistoryStore(),
        settingsController: AppSettingsController(),
      );
      await controller.checkModelStatus();

      await controller.submitEmergencyQuery('he is not well');
      await controller.answerClarifyingQuestion(TriageAnswer.skip);

      expect(controller.pendingQuestion, isNull);
      expect(controller.streamedResponse, contains('IMMEDIATE ACTION'));
    });

    test(
        'Yes + Yes when model is not ready shows friendly message pointing to Guides',
        () async {
      final controller = TriageController(
        downloadService: MockNotReadyDownloadService(),
        engineService: ContextRecordingEngine(),
        protocolRepository: repo,
        protocolRetriever: retriever,
        redFlagEngine: redFlagEngine,
        triageClarifier: clarifier,
        historyStore: HistoryStore(),
        settingsController: AppSettingsController(),
      );
      await controller.checkModelStatus();

      await controller.submitEmergencyQuery('he is not well');
      await controller.answerClarifyingQuestion(TriageAnswer.yes);
      await controller.answerClarifyingQuestion(TriageAnswer.yes);

      expect(controller.pendingQuestion, isNull);
      expect(controller.streamedResponse,
          contains('The offline AI model is not downloaded yet'));
    });
  });
}
