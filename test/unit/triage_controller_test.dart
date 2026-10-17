import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:carepulse/services/profile_service.dart';
import 'package:carepulse/services/model_download_service.dart';
import 'package:carepulse/services/protocol_repository.dart';
import 'package:carepulse/services/protocol_retriever.dart';
import 'package:carepulse/services/red_flag_engine.dart';
import 'package:carepulse/services/triage_engine_service.dart';
import 'package:carepulse/models/triage_question.dart';
import 'package:carepulse/state/triage_controller.dart';

class FakeModelDownloadService extends ModelDownloadService {
  final bool ready;
  FakeModelDownloadService({this.ready = false});

  @override
  Future<bool> isModelReady() async => ready;

  @override
  Future<String> getModelPath() async => '/fake/model.gguf';
}

class FakeTriageEngineService extends TriageEngineService {
  String? lastPassedQuery;
  String? lastPassedContext;
  bool stopCalled = false;
  Duration delayBetweenTokens = Duration.zero;

  @override
  bool get isInitialized => true;

  @override
  Future<void> initializeEngine(String modelPath) async {}

  @override
  Future<void> stopGeneration() async {
    stopCalled = true;
    await super.stopGeneration();
  }

  @override
  Stream<String> generateTriage(
    String query, {
    void Function(TriageTelemetry telemetry)? onTelemetryUpdate,
    UserProfile? profile,
    String? context,
  }) {
    lastPassedQuery = query;
    lastPassedContext = context;
    if (delayBetweenTokens > Duration.zero) {
      late StreamController<String> sc;
      Timer? timer;
      sc = StreamController<String>(
        onListen: () {
          sc.add('1. IMMEDIATE ACTION: ');
          timer = Timer(delayBetweenTokens, () {
            if (!sc.isClosed) {
              sc.add('Simulated advice.');
              sc.close();
            }
          });
        },
        onCancel: () {
          timer?.cancel();
        },
      );
      return sc.stream;
    } else {
      return Stream.value('1. IMMEDIATE ACTION: Simulated advice.');
    }
  }
}

void main() {
  group('TriageController Unit Tests', () {
    late ProtocolRepository protocolRepo;
    late ProtocolRetriever protocolRetriever;
    late RedFlagEngine redFlagEngine;

    setUpAll(() async {
      final file = File('assets/protocols/protocols.json');
      final jsonStr = await file.readAsString();
      protocolRepo = ProtocolRepository();
      protocolRepo.loadFromJsonString(jsonStr);
      protocolRetriever = ProtocolRetriever(protocolRepo);
      redFlagEngine = RedFlagEngine();
    });

    test('Red flag bypasses model and works when model is not ready', () async {
      final fakeEngine = FakeTriageEngineService();
      final fakeDownload = FakeModelDownloadService(ready: false);

      final controller = TriageController(
        downloadService: fakeDownload,
        engineService: fakeEngine,
        protocolRepository: protocolRepo,
        protocolRetriever: protocolRetriever,
        redFlagEngine: redFlagEngine,
      );

      // Model is not ready
      expect(controller.isReady, isFalse);

      await controller.submitEmergencyQuery('he is not breathing');

      // Verified protocol returned immediately
      expect(controller.answerSource, equals(AnswerSource.verifiedProtocol));
      expect(controller.callEmergencyNow, isTrue);
      expect(controller.streamedResponse, contains('IMMEDIATE ACTION'));
      expect(controller.streamedResponse, contains('Call 112'));

      // Engine was NOT called
      expect(fakeEngine.lastPassedQuery, isNull);
    });

    test(
        'Non-red-flag query when model is not ready shows friendly guidance message',
        () async {
      final fakeEngine = FakeTriageEngineService();
      final fakeDownload = FakeModelDownloadService(ready: false);

      final controller = TriageController(
        downloadService: fakeDownload,
        engineService: fakeEngine,
        protocolRepository: protocolRepo,
        protocolRetriever: protocolRetriever,
        redFlagEngine: redFlagEngine,
      );

      expect(controller.isReady, isFalse);

      await controller.submitEmergencyQuery('how to treat a mild headache');
      if (controller.pendingQuestion != null) {
        await controller.answerClarifyingQuestion(TriageAnswer.skip);
      }

      expect(controller.streamedResponse,
          contains('offline AI model is not downloaded yet'));
      expect(controller.streamedResponse, contains('Guides tab'));
      expect(fakeEngine.lastPassedQuery, isNull);
    });

    test(
        'Non-red-flag query when model is ready uses AI engine with protocol context',
        () async {
      final fakeEngine = FakeTriageEngineService();
      final fakeDownload = FakeModelDownloadService(ready: true);

      final controller = TriageController(
        downloadService: fakeDownload,
        engineService: fakeEngine,
        protocolRepository: protocolRepo,
        protocolRetriever: protocolRetriever,
        redFlagEngine: redFlagEngine,
      );

      // Allow async checkModelStatus and loadEngine to complete
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(controller.isReady, isTrue);

      await controller.submitEmergencyQuery('boiling water spilled on my arm');

      expect(controller.answerSource, equals(AnswerSource.aiGuidedByProtocol));
      expect(fakeEngine.lastPassedQuery, contains('boiling water'));
      expect(fakeEngine.lastPassedContext, isNotNull);
      expect(fakeEngine.lastPassedContext, contains('Burns and Scalds'));
      expect(controller.streamedResponse, contains('Simulated advice'));
    });

    test(
        'Stop mid-stream keeps partial text, sets isGenerating=false, next query succeeds, stop when idle is a no-op',
        () async {
      final fakeEngine = FakeTriageEngineService();
      fakeEngine.delayBetweenTokens = const Duration(milliseconds: 200);
      final fakeDownload = FakeModelDownloadService(ready: true);

      final controller = TriageController(
        downloadService: fakeDownload,
        engineService: fakeEngine,
        protocolRepository: protocolRepo,
        protocolRetriever: protocolRetriever,
        redFlagEngine: redFlagEngine,
      );

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(controller.isReady, isTrue);

      // Stop with nothing running is a no-op
      expect(controller.isGenerating, isFalse);
      expect(controller.wasStopped, isFalse);
      await controller.stopGeneration();
      expect(controller.isGenerating, isFalse);
      expect(controller.wasStopped, isFalse);

      // Start generation
      final queryFuture =
          controller.submitEmergencyQuery('boiling water spilled on my arm');

      // Wait until first token arrives
      await Future<void>.delayed(const Duration(milliseconds: 25));
      expect(controller.isGenerating, isTrue);
      expect(controller.streamedResponse, equals('1. IMMEDIATE ACTION: '));

      // Stop mid-stream
      await controller.stopGeneration();
      await queryFuture;

      expect(controller.isGenerating, isFalse);
      expect(controller.wasStopped, isTrue);
      // Keeps partial text
      expect(controller.streamedResponse, equals('1. IMMEDIATE ACTION: '));
      expect(fakeEngine.stopCalled, isTrue);

      // Next query succeeds
      fakeEngine.delayBetweenTokens = Duration.zero;
      await controller.submitEmergencyQuery('boiling water spilled on my arm');

      expect(controller.wasStopped, isFalse);
      expect(controller.isGenerating, isFalse);
      expect(controller.streamedResponse,
          equals('1. IMMEDIATE ACTION: Simulated advice.'));
    });
  });
}
