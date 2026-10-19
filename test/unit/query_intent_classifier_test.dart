import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:carepulse/services/query_intent_classifier.dart';
import 'package:carepulse/services/red_flag_engine.dart';

void main() {
  group('QueryIntentClassifier Intent Table Tests', () {
    final Map<String, QueryIntent> testTable = {
      // 1. appHelp - Greetings
      'hello': QueryIntent.appHelp,
      'hi': QueryIntent.appHelp,
      'hi there': QueryIntent.appHelp,
      'hello there': QueryIntent.appHelp,
      'hey': QueryIntent.appHelp,
      'hey there': QueryIntent.appHelp,
      'good morning': QueryIntent.appHelp,
      'good afternoon': QueryIntent.appHelp,
      'good evening': QueryIntent.appHelp,
      'greetings': QueryIntent.appHelp,

      // 2. appHelp - Identity
      'who are you': QueryIntent.appHelp,
      'what are you': QueryIntent.appHelp,
      'what is carepulse': QueryIntent.appHelp,
      'who made you': QueryIntent.appHelp,
      'are you a doctor': QueryIntent.appHelp,
      'are you doctor': QueryIntent.appHelp,

      // 3. appHelp - Capability / Usage
      'what can you do': QueryIntent.appHelp,
      'how do you work': QueryIntent.appHelp,
      'how does this work': QueryIntent.appHelp,
      'how does carepulse work': QueryIntent.appHelp,
      'do you need internet': QueryIntent.appHelp,
      'are you offline': QueryIntent.appHelp,
      'can you work offline': QueryIntent.appHelp,

      // 4. appHelp - Thanks / Bye / Ok
      'thanks': QueryIntent.appHelp,
      'thank you': QueryIntent.appHelp,
      'thanks a lot': QueryIntent.appHelp,
      'thank you very much': QueryIntent.appHelp,
      'bye': QueryIntent.appHelp,
      'goodbye': QueryIntent.appHelp,
      'ok': QueryIntent.appHelp,
      'okay': QueryIntent.appHelp,
      'alright': QueryIntent.appHelp,

      // 5. emergencyMedical - Direct help & urgent
      'help': QueryIntent.emergencyMedical,
      'help me': QueryIntent.emergencyMedical,
      'i need help': QueryIntent.emergencyMedical,
      'emergency': QueryIntent.emergencyMedical,
      'urgent': QueryIntent.emergencyMedical,
      'call ambulance': QueryIntent.emergencyMedical,

      // 6. emergencyMedical - Third person & symptoms
      'he is not well': QueryIntent.emergencyMedical,
      'my friend looks pale and weak': QueryIntent.emergencyMedical,
      'someone fell down': QueryIntent.emergencyMedical,
      'baby is choking': QueryIntent.emergencyMedical,
      'child has a fever': QueryIntent.emergencyMedical,
      'mother collapsed on floor': QueryIntent.emergencyMedical,
      'dad has chest pain': QueryIntent.emergencyMedical,
      'he looks very sick': QueryIntent.emergencyMedical,
      'she feels dizzy and faint': QueryIntent.emergencyMedical,
      'someone was hit by car': QueryIntent.emergencyMedical,
      'patient is bleeding heavily': QueryIntent.emergencyMedical,

      // 7. emergencyMedical - First person symptoms & medical terms
      'severe bleeding on limb': QueryIntent.emergencyMedical,
      'i have a deep cut on hand': QueryIntent.emergencyMedical,
      'burned my finger on pan': QueryIntent.emergencyMedical,
      'bee sting on my arm': QueryIntent.emergencyMedical,
      'swallowed household bleach': QueryIntent.emergencyMedical,
      'chest hurts badly': QueryIntent.emergencyMedical,
      'broken ankle cannot walk': QueryIntent.emergencyMedical,
      'seizure active on ground': QueryIntent.emergencyMedical,

      // 8. outOfScope - General knowledge & non-emergency
      'what is the capital of France': QueryIntent.outOfScope,
      'write a poem': QueryIntent.outOfScope,
      'tell me a joke': QueryIntent.outOfScope,
      'how is the weather in Paris': QueryIntent.outOfScope,
      'what is the stock price of Apple': QueryIntent.outOfScope,
      'who won the world cup in 2022': QueryIntent.outOfScope,
      'explain quantum mechanics': QueryIntent.outOfScope,
      'write python code for quicksort': QueryIntent.outOfScope,
      'best restaurant in New York': QueryIntent.outOfScope,
      'solve 24 * 7': QueryIntent.outOfScope,
    };

    test(
        'Table test contains >= 40 distinct phrases with accurate intent classification',
        () {
      expect(testTable.length, greaterThanOrEqualTo(40));

      testTable.forEach((phrase, expectedIntent) {
        final actual = classify(phrase);
        expect(
          actual,
          equals(expectedIntent),
          reason: 'Failed classification for phrase: "$phrase"',
        );
      });
    });

    test('Red-flag phrase "he is not breathing" is detected by RedFlagEngine',
        () {
      final rfEngine = RedFlagEngine();
      final result = rfEngine.evaluate('he is not breathing');
      expect(result, isNotNull);
      expect(result!.protocolId, equals('cardiac_arrest'));
    });
  });

  group('Safety Regression: scenarios.json', () {
    test(
        'Every query in scenarios.json is either red-flag or classified emergencyMedical',
        () {
      final file = File('assets/eval/scenarios.json');
      expect(file.existsSync(), isTrue);

      final scenarios = json.decode(file.readAsStringSync()) as List<dynamic>;
      expect(scenarios.length, greaterThanOrEqualTo(40));

      final rfEngine = RedFlagEngine();
      int redFlagCount = 0;
      int medicalCount = 0;

      for (final s in scenarios) {
        final query = s['query'] as String;
        final id = s['id'] as String;

        final rf = rfEngine.evaluate(query);
        if (rf != null) {
          redFlagCount++;
        } else {
          final intent = classify(query);
          expect(
            intent,
            equals(QueryIntent.emergencyMedical),
            reason:
                'Scenario $id with query "$query" must be classified emergencyMedical, but was $intent',
          );
          medicalCount++;
        }
      }

      expect(redFlagCount + medicalCount, equals(scenarios.length));
    });
  });

  group('Local Reply Text Tests', () {
    test(
        'appHelp identity / capability returns concise text with emergency number',
        () {
      final reply = QueryIntentClassifier.getLocalReply(
        'who are you',
        QueryIntent.appHelp,
        emergencyNumber: '112',
      );
      expect(reply, contains("I'm CarePulse, an offline first-aid assistant"));
      expect(reply, contains('call 112'));
      expect(reply.split(' ').length, lessThanOrEqualTo(60));
    });

    test('appHelp greeting returns greeting prompt with emergency number', () {
      final reply = QueryIntentClassifier.getLocalReply(
        'hello',
        QueryIntent.appHelp,
        emergencyNumber: '911',
      );
      expect(reply, startsWith('Hello!'));
      expect(reply, contains('call 911'));
      expect(reply.split(' ').length, lessThanOrEqualTo(60));
    });

    test('appHelp thanks returns warm closure', () {
      final reply = QueryIntentClassifier.getLocalReply(
        'thanks',
        QueryIntent.appHelp,
        emergencyNumber: '112',
      );
      expect(reply, equals("You're welcome. Stay safe."));
    });

    test('outOfScope returns first-aid boundary message with emergency number',
        () {
      final reply = QueryIntentClassifier.getLocalReply(
        'what is the weather',
        QueryIntent.outOfScope,
        emergencyNumber: '999',
      );
      expect(reply, contains('I can help with first aid and emergencies.'));
      expect(reply, contains('call 999'));
      expect(reply.split(' ').length, lessThanOrEqualTo(60));
    });
  });
}
