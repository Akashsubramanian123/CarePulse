import 'package:flutter_test/flutter_test.dart';
import 'package:carepulse/services/red_flag_engine.dart';

void main() {
  group('RedFlagEngine Unit Tests', () {
    late RedFlagEngine engine;

    setUp(() {
      engine = RedFlagEngine();
    });

    test('Positives correctly trigger red flag protocols', () {
      final notBreathing = engine.evaluate('he is not breathing');
      expect(notBreathing, isNotNull);
      expect(notBreathing!.protocolId, equals('cardiac_arrest'));

      final unresponsive = engine.evaluate('she collapsed and is unresponsive');
      expect(unresponsive, isNotNull);
      expect(unresponsive!.protocolId, equals('unconscious_breathing'));

      final bleeding = engine.evaluate('blood is spurting from his leg');
      expect(bleeding, isNotNull);
      expect(bleeding!.protocolId, equals('bleeding'));

      final chestPain = engine.evaluate('my father has chest pain and sweating');
      expect(chestPain, isNotNull);
      expect(chestPain!.protocolId, equals('chest_pain'));

      final choking = engine.evaluate('child choking cannot cough');
      expect(choking, isNotNull);
      expect(choking!.protocolId, anyOf(equals('choking'), equals('choking_child')));

      final snakebite = engine.evaluate('snake bit my foot');
      expect(snakebite, isNotNull);
      expect(snakebite!.protocolId, equals('snakebite'));

      final stroke = engine.evaluate('face drooping and slurred speech');
      expect(stroke, isNotNull);
      expect(stroke!.protocolId, equals('stroke'));
    });

    test('Negations and minor issues do not trigger red flags', () {
      expect(engine.evaluate('he is breathing normally'), isNull);
      expect(engine.evaluate('not bleeding'), isNull);
      expect(engine.evaluate('small paper cut'), isNull);
      expect(engine.evaluate('she is conscious and talking'), isNull);
      expect(engine.evaluate('no chest pain'), isNull);
    });

    test('Does not crash on empty or gibberish input', () {
      expect(engine.evaluate(''), isNull);
      expect(engine.evaluate('   '), isNull);
      expect(engine.evaluate('qwertyuiop asdfghjkl zxcvbnm'), isNull);
      expect(engine.evaluate('1234567890 !@#\$%^&*()'), isNull);
    });
  });
}
