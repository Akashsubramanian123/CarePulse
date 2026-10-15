import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:carepulse/services/protocol_repository.dart';
import 'package:carepulse/services/protocol_retriever.dart';

void main() {
  group('ProtocolRetriever Unit Tests', () {
    late ProtocolRetriever retriever;
    late ProtocolRepository repository;

    setUpAll(() async {
      final file = File('assets/protocols/protocols.json');
      final jsonString = await file.readAsString();
      repository = ProtocolRepository();
      repository.loadFromJsonString(jsonString);
      retriever = ProtocolRetriever(repository);
    });

    test('boiling water spilled on my arm matches burns', () {
      final matches = retriever.topMatches('boiling water spilled on my arm');
      expect(matches, isNotEmpty);
      expect(matches.first.id, equals('burns'));
    });

    test('he is shaking and fell, foaming at the mouth matches seizure', () {
      final matches =
          retriever.topMatches('he is shaking and fell, foaming at the mouth');
      expect(matches, isNotEmpty);
      expect(matches.first.id, equals('seizure'));
    });

    test('swallowed bleach matches poisoning', () {
      final matches = retriever.topMatches('swallowed bleach');
      expect(matches, isNotEmpty);
      expect(matches.first.id, equals('poisoning'));
    });

    test('gibberish query yields no match above threshold', () {
      final matches =
          retriever.topMatches('aslkdjf zxcvbnm qwertyuiop lkjhgfds');
      expect(matches, isEmpty);
    });
  });
}
