import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:carepulse/services/history_store.dart';
import 'package:carepulse/services/model_download_service.dart';
import 'package:carepulse/services/protocol_repository.dart';
import 'package:carepulse/services/protocol_retriever.dart';
import 'package:carepulse/services/red_flag_engine.dart';
import 'package:carepulse/services/triage_clarifier.dart';
import 'package:carepulse/services/triage_engine_service.dart';
import 'package:carepulse/state/app_settings_controller.dart';
import 'package:carepulse/state/triage_controller.dart';
import 'package:carepulse/models/history_entry.dart';

class CountingEngineService extends TriageEngineService {
  int callCount = 0;

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
    callCount++;
    yield '1. IMMEDIATE ACTION: Apply pressure to bleeding area.';
  }
}

class CountingHistoryStore extends HistoryStore {
  int saveCount = 0;

  @override
  Future<void> saveEntry(HistoryEntry entry) async {
    saveCount++;
  }
}

class MockDownloadService extends ModelDownloadService {
  bool ready = false;

  @override
  Future<bool> isModelReady() async => ready;

  @override
  Future<String> getModelPath() async => '/fake/model.gguf';

  @override
  Future<bool> hasUnverifiedModel() async => false;

  @override
  Future<int> getPartialBytes() async => 0;

  @override
  Future<bool> hasPartialDownload() async => false;
}

void main() {
  late ProtocolRepository repo;
  late ProtocolRetriever retriever;
  late RedFlagEngine redFlagEngine;
  late TriageClarifier clarifier;

  setUpAll(() async {
    final file = File('assets/protocols/protocols.json');
    final jsonStr = await file.readAsString();
    repo = ProtocolRepository();
    repo.loadFromJsonString(jsonStr);
    retriever = ProtocolRetriever(repo);
    redFlagEngine = RedFlagEngine();
    clarifier = TriageClarifier(
      protocolRetriever: retriever,
      redFlagEngine: redFlagEngine,
    );
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'onboarding_v2_seen': true,
      'profile_prompt_dismissed': true,
    });
  });

  group('Intent Gate Controller Tests with Fakes', () {
    test(
        '"who are you" without model -> instant appInfo reply, no clarifying card, no engine call, not in history',
        () async {
      final downloadService = MockDownloadService()..ready = false;
      final engineService = CountingEngineService();
      final historyStore = CountingHistoryStore();
      final settings = AppSettingsController(defaultEmergencyNumber: '112');

      final controller = TriageController(
        downloadService: downloadService,
        engineService: engineService,
        protocolRepository: repo,
        protocolRetriever: retriever,
        redFlagEngine: redFlagEngine,
        triageClarifier: clarifier,
        historyStore: historyStore,
        settingsController: settings,
      );

      await controller.checkModelStatus();
      expect(controller.isReady, isFalse);

      await controller.submitEmergencyQuery('who are you');

      // 1. Instant reply produced with appInfo source
      expect(controller.answerSource, equals(AnswerSource.appInfo));
      expect(controller.streamedResponse,
          contains("I'm CarePulse, an offline first-aid assistant"));
      expect(controller.streamedResponse, contains('call 112'));

      // 2. No clarifying question
      expect(controller.pendingQuestion, isNull);

      // 3. No engine call
      expect(engineService.callCount, equals(0));

      // 4. Not saved to history
      expect(historyStore.saveCount, equals(0));

      // 5. No emergency call banner
      expect(controller.callEmergencyNow, isFalse);
    });

    test(
        '"help me" -> emergencyMedical intent and clarifying card ("Is the person awake and responding?")',
        () async {
      final downloadService = MockDownloadService()..ready = false;
      final engineService = CountingEngineService();
      final historyStore = CountingHistoryStore();

      final controller = TriageController(
        downloadService: downloadService,
        engineService: engineService,
        protocolRepository: repo,
        protocolRetriever: retriever,
        redFlagEngine: redFlagEngine,
        triageClarifier: clarifier,
        historyStore: historyStore,
      );

      await controller.checkModelStatus();
      await controller.submitEmergencyQuery('help me');

      // "help me" is < 4 words and emergencyMedical -> triggers clarifying question
      expect(controller.pendingQuestion, isNotNull);
      expect(controller.pendingQuestion!.text,
          equals('Is the person awake and responding?'));
      expect(controller.answerSource, isNot(AnswerSource.appInfo));
    });

    test('Red flags remain instant and unaffected by intent gate', () async {
      final downloadService = MockDownloadService()..ready = false;
      final engineService = CountingEngineService();
      final historyStore = CountingHistoryStore();

      final controller = TriageController(
        downloadService: downloadService,
        engineService: engineService,
        protocolRepository: repo,
        protocolRetriever: retriever,
        redFlagEngine: redFlagEngine,
        triageClarifier: clarifier,
        historyStore: historyStore,
      );

      await controller.checkModelStatus();

      // "he is not breathing" is a cardiac arrest red flag
      await controller.submitEmergencyQuery('he is not breathing');

      expect(controller.callEmergencyNow, isTrue);
      expect(controller.answerSource, equals(AnswerSource.verifiedProtocol));
      expect(controller.pendingQuestion,
          isNull); // Red flag never asks clarifying questions
      expect(controller.selectedProtocol?.id, equals('cardiac_arrest'));
      expect(
          controller.streamedResponse, contains('IMMEDIATE ACTION: Call 112'));
    });

    test(
        '"severe bleeding on limb" -> emergencyMedical with confident retrieval, no clarifying card',
        () async {
      final downloadService = MockDownloadService()..ready = false;
      final engineService = CountingEngineService();
      final historyStore = CountingHistoryStore();

      final controller = TriageController(
        downloadService: downloadService,
        engineService: engineService,
        protocolRepository: repo,
        protocolRetriever: retriever,
        redFlagEngine: redFlagEngine,
        triageClarifier: clarifier,
        historyStore: historyStore,
      );

      await controller.checkModelStatus();
      await controller.submitEmergencyQuery('severe bleeding on limb');

      // 4 words, confident retrieval for severe_bleeding -> no clarifying question
      expect(controller.pendingQuestion, isNull);
      expect(controller.answerSource, equals(AnswerSource.verifiedProtocol));
    });

    test(
        '"what is the capital of France" -> outOfScope instant reply, no engine call, not in history',
        () async {
      final downloadService = MockDownloadService()..ready = true;
      final engineService = CountingEngineService();
      final historyStore = CountingHistoryStore();
      final settings = AppSettingsController(defaultEmergencyNumber: '911');

      final controller = TriageController(
        downloadService: downloadService,
        engineService: engineService,
        protocolRepository: repo,
        protocolRetriever: retriever,
        redFlagEngine: redFlagEngine,
        triageClarifier: clarifier,
        historyStore: historyStore,
        settingsController: settings,
      );

      await controller.checkModelStatus();
      await controller.submitEmergencyQuery('what is the capital of France');

      expect(controller.answerSource, equals(AnswerSource.appInfo));
      expect(controller.streamedResponse,
          contains('I can help with first aid and emergencies.'));
      expect(controller.streamedResponse, contains('call 911'));
      expect(controller.pendingQuestion, isNull);
      expect(engineService.callCount, equals(0));
      expect(historyStore.saveCount, equals(0));
    });
  });
}
