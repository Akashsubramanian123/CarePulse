import 'package:flutter_test/flutter_test.dart';
import 'package:carepulse/models/medical_id.dart';

void main() {
  group('MedicalId Unit Tests', () {
    test('Phone sanitization keeps only digits and leading plus', () {
      expect(EmergencyContact.sanitizePhone('+1 (555) 123-4567'), equals('+15551234567'));
      expect(EmergencyContact.sanitizePhone('  080-1234-5678  '), equals('08012345678'));
      expect(EmergencyContact.sanitizePhone('+91 98765 43210'), equals('+919876543210'));
      expect(EmergencyContact.sanitizePhone('abc-def'), equals(''));
      expect(EmergencyContact.sanitizePhone(''), equals(''));
    });

    test('MedicalId JSON round trip serialization preserves all data', () {
      const original = MedicalId(
        name: 'Jane Doe',
        ageOrDob: '1992-04-18',
        bloodGroup: 'O+',
        allergies: 'Penicillin, Peanuts',
        conditions: 'Asthma',
        medications: 'Albuterol inhaler',
        notes: 'Carries EpiPen',
        contacts: [
          EmergencyContact(name: 'John Doe', phone: '+15551234567', relation: 'Spouse'),
          EmergencyContact(name: 'Mary Doe', phone: '+15559876543', relation: 'Mother'),
        ],
      );

      final json = original.toJson();
      final reconstructed = MedicalId.fromJson(json);

      expect(reconstructed.name, equals(original.name));
      expect(reconstructed.ageOrDob, equals(original.ageOrDob));
      expect(reconstructed.bloodGroup, equals(original.bloodGroup));
      expect(reconstructed.allergies, equals(original.allergies));
      expect(reconstructed.conditions, equals(original.conditions));
      expect(reconstructed.medications, equals(original.medications));
      expect(reconstructed.notes, equals(original.notes));
      expect(reconstructed.contacts.length, equals(2));
      expect(reconstructed.contacts[0].name, equals('John Doe'));
      expect(reconstructed.contacts[0].phone, equals('+15551234567'));
      expect(reconstructed.contacts[0].relation, equals('Spouse'));
      expect(reconstructed.contacts[1].name, equals('Mary Doe'));
    });

    test('Caps emergency contacts to a maximum of 3', () {
      final jsonWith5Contacts = {
        'name': 'Test User',
        'contacts': [
          {'name': 'C1', 'phone': '111', 'relation': 'Friend'},
          {'name': 'C2', 'phone': '222', 'relation': 'Friend'},
          {'name': 'C3', 'phone': '333', 'relation': 'Friend'},
          {'name': 'C4', 'phone': '444', 'relation': 'Friend'},
          {'name': 'C5', 'phone': '555', 'relation': 'Friend'},
        ],
      };

      final parsed = MedicalId.fromJson(jsonWith5Contacts);
      expect(parsed.contacts.length, equals(3));
      expect(parsed.contacts.map((c) => c.name).toList(), equals(['C1', 'C2', 'C3']));

      final copied = parsed.copyWith(contacts: [
        const EmergencyContact(name: 'A', phone: '1', relation: 'R'),
        const EmergencyContact(name: 'B', phone: '2', relation: 'R'),
        const EmergencyContact(name: 'C', phone: '3', relation: 'R'),
        const EmergencyContact(name: 'D', phone: '4', relation: 'R'),
      ]);
      expect(copied.contacts.length, equals(3));
    });
  });
}
