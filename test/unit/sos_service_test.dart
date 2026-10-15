import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:carepulse/services/sos_service.dart';

void main() {
  group('SosService Unit Tests', () {
    test('Builds emergency message with location and medical details', () {
      final position = Position(
        latitude: 37.774929,
        longitude: -122.419416,
        timestamp: DateTime.now(),
        accuracy: 12.4,
        altitude: 10.0,
        altitudeAccuracy: 1.0,
        heading: 0.0,
        headingAccuracy: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
      );

      final msg = SosService.buildEmergencyMessage(
        position: position,
        bloodGroup: 'B+',
        allergies: 'Penicillin',
        conditions: 'Asthma',
      );

      expect(msg, contains('EMERGENCY! I need help.'));
      expect(
          msg,
          contains(
              'Location: https://maps.google.com/?q=37.774929,-122.419416 (accuracy ~12m).'));
      expect(msg, contains('Blood group: B+.'));
      expect(msg, contains('Allergies: Penicillin.'));
      expect(msg, contains('Conditions: Asthma.'));
      expect(msg, contains('Sent from CarePulse.'));
    });

    test('Builds emergency message without location when null', () {
      final msg = SosService.buildEmergencyMessage(
        position: null,
        bloodGroup: 'O-',
      );

      expect(msg, contains('EMERGENCY! I need help.'));
      expect(msg, contains('Location: unavailable.'));
      expect(msg, contains('Blood group: O-.'));
      expect(msg, contains('Sent from CarePulse.'));
    });

    test('Omits empty or null fields in emergency message', () {
      final msg = SosService.buildEmergencyMessage(
        position: null,
        bloodGroup: '',
        allergies: '   ',
        conditions: null,
      );

      expect(
          msg,
          equals(
              'EMERGENCY! I need help. Location: unavailable. Sent from CarePulse.'));
      expect(msg, isNot(contains('Blood group:')));
      expect(msg, isNot(contains('Allergies:')));
      expect(msg, isNot(contains('Conditions:')));
    });

    test('SMS URI has %20 and no "+" for spaces', () {
      const body = 'EMERGENCY! I need help.';
      final uriStr = SosService.buildSmsUriString(
        phoneNumbers: ['+1234567890'],
        body: body,
        isIos: false,
      );

      expect(uriStr, contains('%20'));
      expect(uriStr, isNot(contains('+I+need')));
      expect(uriStr, isNot(contains('+need+help')));
    });

    test('Uses correct separator and body param per platform', () {
      final numbers = ['+1111111', '+2222222'];
      const body = 'Test message';

      // Android format: sms:recipients?body=...
      final androidUri = SosService.buildSmsUriString(
        phoneNumbers: numbers,
        body: body,
        isIos: false,
      );
      expect(androidUri, startsWith('sms:+1111111,+2222222?body='));

      // iOS format: sms:recipients&body=...
      final iosUri = SosService.buildSmsUriString(
        phoneNumbers: numbers,
        body: body,
        isIos: true,
      );
      expect(iosUri, startsWith('sms:+1111111,+2222222&body='));
    });
  });
}
