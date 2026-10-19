import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:carepulse/core/theme/app_theme.dart';
import 'package:carepulse/services/model_download_service.dart';
import 'package:carepulse/services/protocol_repository.dart';
import 'package:carepulse/state/triage_controller.dart';
import 'package:carepulse/ui/screens/main_shell.dart';

class FakeModelDownloadService extends ModelDownloadService {
  @override
  Future<bool> isModelReady() async => false;

  @override
  Future<bool> hasUnverifiedModel() async => false;

  @override
  Future<int> getPartialBytes() async => 0;

  @override
  Future<bool> hasPartialDownload() async => false;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({'onboarding_v1_seen': true});
  });

  testWidgets('MainShell displays 4 tabs and switches between them',
      (WidgetTester tester) async {
    final file = File('assets/protocols/protocols.json');
    final jsonStr = file.readAsStringSync();
    final repo = ProtocolRepository();
    repo.loadFromJsonString(jsonStr);

    final controller = TriageController(
      downloadService: FakeModelDownloadService(),
      protocolRepository: repo,
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<TriageController>.value(
        value: controller,
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const MainShell(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify 4 tab destinations exist
    expect(find.text('Assistant'), findsWidgets);
    expect(find.text('Guides'), findsOneWidget);
    expect(find.text('CPR'), findsOneWidget);
    expect(find.text('SOS'), findsOneWidget);

    // Switch to Guides tab
    await tester.tap(find.text('Guides'));
    await tester.pumpAndSettle();
    expect(find.text('First-Aid Guides'), findsOneWidget);

    // Switch to CPR tab
    await tester.tap(find.text('CPR'));
    await tester.pumpAndSettle();
    expect(find.text('CPR Metronome'), findsOneWidget);

    // Switch to SOS tab
    await tester.tap(find.text('SOS'));
    await tester.pumpAndSettle();
    expect(find.text('Emergency SOS'), findsOneWidget);

    // Switch back to Assistant tab
    await tester.tap(find.text('Assistant'));
    await tester.pumpAndSettle();
    expect(find.text("What's happening?"), findsOneWidget);
  });
}
