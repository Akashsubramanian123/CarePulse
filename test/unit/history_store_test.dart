import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:carepulse/models/history_entry.dart';
import 'package:carepulse/services/history_store.dart';
import 'package:carepulse/services/model_download_service.dart';
import 'package:carepulse/services/protocol_repository.dart';
import 'package:carepulse/services/triage_engine_service.dart';
import 'package:carepulse/state/app_settings_controller.dart';
import 'package:carepulse/state/triage_controller.dart';

class MockReadyDownloadService extends ModelDownloadService {
  @override
  Future<bool> isModelReady() async => true;
  @override
  Future<String> getModelPath() async => '/mock/model.gguf';
}

class MockTriageEngine extends TriageEngineService {
  @override
  bool get isInitialized => true;

  @override
  Stream<String> generateTriage(
    String query, {
    void Function(TriageTelemetry telemetry)? onTelemetryUpdate,
    dynamic profile,
    String? context,
  }) async* {
    yield '1. IMMEDIATE ACTION: Apply direct pressure.\n2. PRECAUTION: Keep calm.\n3. MONITOR: Check pulse.';
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HistoryStore Unit Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Initial store is empty', () async {
      final store = HistoryStore();
      final entries = await store.loadEntries();
      expect(entries, isEmpty);
    });

    test('Saves entry and maintains newest-first ordering', () async {
      final store = HistoryStore();
      final now = DateTime.now();

      final e1 = HistoryEntry(
        id: '1',
        timestamp: now.subtract(const Duration(minutes: 10)),
        query: 'First aid for nosebleed',
        response: '1. Pinch nose\n2. Lean forward',
        answerSource: AnswerSource.verifiedProtocol,
      );

      final e2 = HistoryEntry(
        id: '2',
        timestamp: now,
        query: 'Cut on finger',
        response: '1. Wash hands\n2. Apply pressure',
        answerSource: AnswerSource.aiGuidedByProtocol,
      );

      await store.saveEntry(e1);
      await store.saveEntry(e2);

      final loaded = await store.loadEntries();
      expect(loaded.length, 2);
      expect(loaded[0].id, '2'); // Newer one first
      expect(loaded[1].id, '1');
    });

    test('Caps entries at 50, retaining the 50 newest', () async {
      final store = HistoryStore();
      final baseTime = DateTime(2025, 1, 1, 12, 0);

      // Save 55 entries
      for (int i = 0; i < 55; i++) {
        final entry = HistoryEntry(
          id: 'entry_$i',
          timestamp: baseTime.add(Duration(minutes: i)),
          query: 'Query $i',
          response: 'Response $i',
          answerSource: AnswerSource.aiGenerated,
        );
        await store.saveEntry(entry);
      }

      final loaded = await store.loadEntries();
      expect(loaded.length, 50);
      // Newest should be entry_54
      expect(loaded.first.id, 'entry_54');
      // Oldest retained should be entry_5 (0 to 4 dropped)
      expect(loaded.last.id, 'entry_5');
    });

    test('Delete removes entry by id', () async {
      final store = HistoryStore();
      final entry = HistoryEntry(
        id: 'del_123',
        timestamp: DateTime.now(),
        query: 'Severe burn',
        response: 'Cool with water',
        answerSource: AnswerSource.verifiedProtocol,
      );

      await store.saveEntry(entry);
      var loaded = await store.loadEntries();
      expect(loaded.length, 1);

      await store.deleteEntry('del_123');
      loaded = await store.loadEntries();
      expect(loaded, isEmpty);
    });

    test('ClearAll deletes all entries', () async {
      final store = HistoryStore();
      await store.saveEntry(HistoryEntry(
        id: 'a',
        timestamp: DateTime.now(),
        query: 'A',
        response: 'Resp A',
        answerSource: AnswerSource.aiGenerated,
      ));
      await store.saveEntry(HistoryEntry(
        id: 'b',
        timestamp: DateTime.now(),
        query: 'B',
        response: 'Resp B',
        answerSource: AnswerSource.aiGenerated,
      ));

      expect((await store.loadEntries()).length, 2);

      await store.clearAll();
      expect(await store.loadEntries(), isEmpty);
    });

    test('Not saved when saveHistory toggle is off', () async {
      final store = HistoryStore();
      final settings = AppSettingsController(defaultSaveHistory: false);

      final repo = ProtocolRepository();
      await repo.loadProtocols();

      final controller = TriageController(
        downloadService: MockReadyDownloadService(),
        engineService: MockTriageEngine(),
        protocolRepository: repo,
        historyStore: store,
        settingsController: settings,
      );
      await controller.checkModelStatus();

      // Submit emergency query that hits red flag
      await controller
          .submitEmergencyQuery('he is unconscious and not breathing');

      final entries = await store.loadEntries();
      expect(entries, isEmpty);
    });

    test('Saved when saveHistory toggle is on', () async {
      final store = HistoryStore();
      final settings = AppSettingsController(defaultSaveHistory: true);

      final repo = ProtocolRepository();
      await repo.loadProtocols();

      final controller = TriageController(
        downloadService: MockReadyDownloadService(),
        engineService: MockTriageEngine(),
        protocolRepository: repo,
        historyStore: store,
        settingsController: settings,
      );
      await controller.checkModelStatus();

      // Submit emergency query that hits red flag
      await controller
          .submitEmergencyQuery('he is unconscious and not breathing');

      final entries = await store.loadEntries();
      expect(entries.length, 1);
      expect(entries.first.query, 'he is unconscious and not breathing');
      expect(entries.first.answerSource, AnswerSource.verifiedProtocol);
    });
  });
}
