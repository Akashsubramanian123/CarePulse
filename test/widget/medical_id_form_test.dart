import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:carepulse/core/theme/app_theme.dart';
import 'package:carepulse/models/medical_id.dart';
import 'package:carepulse/services/medical_id_store.dart';
import 'package:carepulse/ui/screens/medical_id_screen.dart';

void main() {
  testWidgets(
      'MedicalIdScreen validates phone numbers and saves valid medical ID',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = MedicalIdStore();
    await store.saveMedicalId(const MedicalId());

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: MedicalIdScreen(store: store),
      ),
    );
    await tester.pumpAndSettle();

    // Since initial data was empty, it enters edit form mode
    expect(find.text('Personal Details'), findsOneWidget);

    // Find the contact phone field (hint: '+1234567890')
    final phoneFields = find.widgetWithText(TextFormField, 'Phone');
    expect(phoneFields, findsWidgets);

    // Enter invalid phone number with only letters
    await tester.enterText(phoneFields.first, 'invalid');
    await tester.pumpAndSettle();

    // Tap Save
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    // Validation error should appear
    expect(find.text('Enter valid phone number'), findsOneWidget);

    // Enter valid phone number
    await tester.enterText(phoneFields.first, '+15551234567');
    // Enter contact name
    final nameFields = find.widgetWithText(TextFormField, 'Full Name');
    await tester.enterText(nameFields, 'John Doe');
    await tester.pumpAndSettle();

    // Tap Save again
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    // Verify card view is now shown with the saved name
    expect(find.text('John Doe'), findsOneWidget);
  });
}
