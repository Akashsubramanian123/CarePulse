import 'package:carepulse/core/constants/app_constants.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Model Size & Constants Tests', () {
    test('formatMb(807694464) returns "808 MB"', () {
      expect(formatMb(807694464), equals('808 MB'));
      expect(AppConstants.formatMb(807694464), equals('808 MB'));
    });

    test('formatMb of a small value like 1500000 returns "1.5 MB"', () {
      expect(formatMb(1500000), equals('1.5 MB'));
      expect(AppConstants.formatMb(1500000), equals('1.5 MB'));
    });

    test('estimatedModelSizeMb is within 0.5 of 808', () {
      expect((AppConstants.estimatedModelSizeMb - 808).abs(), lessThan(0.5));
    });

    test('minModelSizeBytes < modelSizeBytes', () {
      expect(
        AppConstants.minModelSizeBytes,
        lessThan(AppConstants.modelSizeBytes),
      );
    });

    test('modelSha256 is 64 lowercase hex characters', () {
      expect(AppConstants.modelSha256.length, equals(64));
      expect(
        RegExp(r'^[0-9a-f]{64}$').hasMatch(AppConstants.modelSha256),
        isTrue,
      );
    });
  });
}
