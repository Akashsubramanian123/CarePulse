import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:carepulse/core/theme/app_theme.dart';
import 'package:carepulse/models/medical_id.dart';
import 'package:carepulse/services/medical_id_store.dart';
import 'package:carepulse/ui/screens/sos_screen.dart';

void main() {
  testWidgets('SosScreen shows add-contacts prompt when no contacts exist', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = MedicalIdStore();
    await store.saveMedicalId(const MedicalId());

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: SosScreen(store: store),
      ),
    );
    await tester.pumpAndSettle();

    // Verify empty contacts banner is shown
    expect(find.text('No Emergency Contacts Added'), findsOneWidget);
    expect(find.text('Add Emergency Contacts'), findsOneWidget);

    // Tap SEND SOS ALERT
    await tester.tap(find.text('SEND SOS ALERT'));
    await tester.pumpAndSettle();

    // Verify dialog pops up prompting to add contacts
    expect(find.text('No Emergency Contacts'), findsOneWidget);
    expect(find.text('Add Contacts'), findsOneWidget);
  });
}
