import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:carepulse/core/constants/app_constants.dart';
import 'package:carepulse/models/protocol.dart';
import 'package:carepulse/services/protocol_repository.dart';

void main() {
  group('Protocol JSON Validation Tests', () {
    late String jsonString;
    late List<Protocol> protocols;
    late ProtocolRepository repo;

    setUpAll(() async {
      final file = File('assets/protocols/protocols.json');
      expect(file.existsSync(), isTrue, reason: 'assets/protocols/protocols.json must exist');
      jsonString = await file.readAsString();
      repo = ProtocolRepository();
      protocols = repo.loadFromJsonString(jsonString);
    });

    test('protocols.json loads successfully with valid JSON', () {
      final decoded = json.decode(jsonString);
      expect(decoded, isA<List<dynamic>>());
      expect(protocols, isNotEmpty);
      expect(protocols.length, greaterThanOrEqualTo(20));
    });

    test('all protocol IDs are unique', () {
      final ids = protocols.map((p) => p.id).toList();
      final uniqueIds = ids.toSet();
      expect(uniqueIds.length, equals(ids.length), reason: 'Duplicate protocol IDs found!');
    });

    test('all required fields are present and non-empty', () {
      for (final p in protocols) {
        expect(p.id.trim(), isNotEmpty, reason: 'Protocol ${p.id} has empty id');
        expect(p.title.trim(), isNotEmpty, reason: 'Protocol ${p.id} has empty title');
        expect(p.keywords, isNotEmpty, reason: 'Protocol ${p.id} has empty keywords');
        expect(p.synonyms, isNotEmpty, reason: 'Protocol ${p.id} has empty synonyms');
        expect(p.immediate.trim(), isNotEmpty, reason: 'Protocol ${p.id} has empty immediate action');
        expect(p.precaution.trim(), isNotEmpty, reason: 'Protocol ${p.id} has empty precaution');
        expect(p.monitor.trim(), isNotEmpty, reason: 'Protocol ${p.id} has empty monitor instruction');
        expect(p.doNot, isNotEmpty, reason: 'Protocol ${p.id} has empty doNot list');
        expect(p.sources, isNotEmpty, reason: 'Protocol ${p.id} has empty sources list');
      }
    });

    test('every preset in app_constants.dart maps to a protocol', () {
      for (final preset in emergencyPresets) {
        final match = repo.getById(preset.id);
        expect(
          match,
          isNotNull,
          reason: 'Emergency preset "${preset.id}" (${preset.title}) does not map to any protocol ID!',
        );
      }
    });

    test('every red-flag target id exists in protocols', () {
      const redFlagTargetIds = [
        'cardiac_arrest',
        'unconscious_breathing',
        'bleeding',
        'choking',
        'choking_child',
        'choking_infant',
        'seizure',
        'stroke',
        'anaphylaxis',
        'chest_pain',
        'drowning',
        'electric_shock',
        'poisoning',
        'heatstroke',
        'snakebite',
      ];

      for (final targetId in redFlagTargetIds) {
        final match = repo.getById(targetId);
        expect(
          match,
          isNotNull,
          reason: 'Red flag target ID "$targetId" does not exist in protocols.json!',
        );
      }
    });
  });
}
