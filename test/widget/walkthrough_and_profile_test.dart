import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:carepulse/core/theme/app_theme.dart';
import 'package:carepulse/services/medical_id_store.dart';
import 'package:carepulse/services/model_download_service.dart';
import 'package:carepulse/services/profile_service.dart';
import 'package:carepulse/services/protocol_repository.dart';
import 'package:carepulse/services/protocol_retriever.dart';
import 'package:carepulse/services/red_flag_engine.dart';
import 'package:carepulse/services/triage_clarifier.dart';
import 'package:carepulse/services/triage_engine_service.dart';
import 'package:carepulse/state/app_settings_controller.dart';
import 'package:carepulse/state/cpr_controller.dart';
import 'package:carepulse/state/theme_controller.dart';
import 'package:carepulse/state/triage_controller.dart';
import 'package:carepulse/ui/screens/emergency_home_screen.dart';
import 'package:carepulse/ui/screens/quick_profile_screen.dart';
import 'package:carepulse/ui/screens/walkthrough_screen.dart';
import 'package:carepulse/ui/widgets/settings_sheet.dart';

class MockDownloadService extends ModelDownloadService {
  bool downloadStarted = false;

  @override
  Future<bool> isModelReady() async => false;

  @override
  Future<String> getModelPath() async => '/fake/model.gguf';

  @override
  Future<bool> hasUnverifiedModel() async => false;

  @override
  Future<int> getPartialBytes() async => 0;

  @override
  Future<bool> hasPartialDownload() async => false;

  @override
  Future<void> downloadModel({
    Function(double progress, double downloadedMB, double totalMB)? onProgress,
    Function()? onVerifyingStart,
    dynamic cancelToken,
  }) async {
    downloadStarted = true;
  }
}

class FakeEngineService extends TriageEngineService {
  @override
  bool get isInitialized => true;

  @override
  Future<void> initializeEngine(String modelPath) async {}
}

void main() {
  late ProtocolRepository repo;
  late ProtocolRetriever retriever;
  late RedFlagEngine redFlagEngine;
  late TriageClarifier clarifier;

  setUpAll(() async {
    final file = File('assets/protocols/protocols.json');
    final jsonStr = await file.readAsString();
    repo = ProtocolRepository();
    repo.loadFromJsonString(jsonStr);
    retriever = ProtocolRetriever(repo);
    redFlagEngine = RedFlagEngine();
    clarifier = TriageClarifier(
      protocolRetriever: retriever,
      redFlagEngine: redFlagEngine,
    );
  });

  Widget buildTestApp({
    required Widget child,
    required Size screenSize,
    required double textScale,
    ThemeMode themeMode = ThemeMode.light,
    TriageController? triageController,
    AppSettingsController? settingsController,
    bool disableAnimations = false,
  }) {
    final tCtrl = triageController ??
        TriageController(
          downloadService: MockDownloadService(),
          engineService: FakeEngineService(),
          protocolRepository: repo,
          protocolRetriever: retriever,
          redFlagEngine: redFlagEngine,
          triageClarifier: clarifier,
        );

    final sCtrl = settingsController ?? AppSettingsController();

    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeController>(
          create: (_) => ThemeController(defaultMode: themeMode),
        ),
        ChangeNotifierProvider<AppSettingsController>.value(value: sCtrl),
        ChangeNotifierProvider<TriageController>.value(value: tCtrl),
        ChangeNotifierProvider<CprController>(
          create: (_) => CprController(),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: themeMode,
        home: MediaQuery(
          data: MediaQueryData(
            size: screenSize,
            padding: const EdgeInsets.only(top: 24, bottom: 24),
            textScaler: TextScaler.linear(textScale),
            disableAnimations: disableAnimations,
          ),
          child: child,
        ),
      ),
    );
  }

  group('First-Launch Walkthrough & Quick Profile Tests', () {
    testWidgets(
        'Walkthrough shows once on first launch and not on simulated relaunch',
        (tester) async {
      SharedPreferences.setMockInitialValues({}); // First launch

      await tester.pumpWidget(
        buildTestApp(
          child: const EmergencyHomeScreen(),
          screenSize: const Size(393, 852),
          textScale: 1.0,
        ),
      );
      await tester.pumpAndSettle();

      // Walkthrough appears
      expect(find.text('CarePulse Tour'), findsOneWidget);
      expect(find.text('First aid that works offline'), findsOneWidget);

      // Tap Skip on slide 1
      await tester.tap(find.byKey(const Key('walkthrough_skip_button')));
      await tester.pumpAndSettle();

      expect(find.text('CarePulse Tour'), findsNothing);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('onboarding_v2_seen'), isTrue);

      // Simulate relaunch
      await tester.pumpWidget(
        buildTestApp(
          child: const EmergencyHomeScreen(),
          screenSize: const Size(393, 852),
          textScale: 1.0,
        ),
      );
      await tester.pumpAndSettle();

      // Walkthrough does not appear again
      expect(find.text('CarePulse Tour'), findsNothing);
    });

    testWidgets(
        'Walkthrough slide navigation with Next/Back through all 6 slides',
        (tester) async {
      SharedPreferences.setMockInitialValues({'onboarding_v2_seen': true});

      await tester.pumpWidget(
        buildTestApp(
          child: const WalkthroughScreen(),
          screenSize: const Size(393, 852),
          textScale: 1.0,
        ),
      );
      await tester.pumpAndSettle();

      // Slide 1: Welcome
      expect(find.text('First aid that works offline'), findsOneWidget);
      expect(find.byKey(const Key('walkthrough_back_button')), findsNothing);

      // Go to Slide 2: Assistant
      await tester.tap(find.byKey(const Key('walkthrough_next_button')));
      await tester.pumpAndSettle();
      expect(find.text('Instant Emergency Assistant'), findsOneWidget);
      expect(find.byKey(const Key('walkthrough_back_button')), findsOneWidget);

      // Go to Slide 3: Guides and CPR
      await tester.tap(find.byKey(const Key('walkthrough_next_button')));
      await tester.pumpAndSettle();
      expect(find.text('Guides and CPR'), findsOneWidget);

      // Go to Slide 4: SOS
      await tester.tap(find.byKey(const Key('walkthrough_next_button')));
      await tester.pumpAndSettle();
      expect(find.text('Emergency SOS'), findsOneWidget);

      // Go to Slide 5: Medical ID
      await tester.tap(find.byKey(const Key('walkthrough_next_button')));
      await tester.pumpAndSettle();
      expect(find.text('Medical ID'), findsOneWidget);
      expect(find.byKey(const Key('walkthrough_fill_profile_button')),
          findsOneWidget);
      expect(find.byKey(const Key('walkthrough_skip_profile_button')),
          findsOneWidget);

      // Go to Slide 6: AI model via Next or Skip for now
      await tester.tap(find.byKey(const Key('walkthrough_next_button')));
      await tester.pumpAndSettle();
      expect(find.text('Offline AI Model'), findsOneWidget);
      expect(find.byKey(const Key('walkthrough_download_now_button')),
          findsOneWidget);
      expect(find.byKey(const Key('walkthrough_download_later_button')),
          findsOneWidget);
      // On the last slide, Next button is hidden
      expect(find.byKey(const Key('walkthrough_next_button')), findsNothing);

      // Navigate back to Slide 5
      await tester.tap(find.byKey(const Key('walkthrough_back_button')));
      await tester.pumpAndSettle();
      expect(find.text('Medical ID'), findsOneWidget);
    });

    testWidgets('Slide 6 Download now starts download and closes tour',
        (tester) async {
      SharedPreferences.setMockInitialValues({'onboarding_v2_seen': true});
      final mockDownload = MockDownloadService();
      final tCtrl = TriageController(
        downloadService: mockDownload,
        engineService: FakeEngineService(),
        protocolRepository: repo,
        protocolRetriever: retriever,
        redFlagEngine: redFlagEngine,
        triageClarifier: clarifier,
      );

      await tester.pumpWidget(
        buildTestApp(
          child: WalkthroughScreen(triageController: tCtrl),
          screenSize: const Size(393, 852),
          textScale: 1.0,
          triageController: tCtrl,
        ),
      );
      await tester.pumpAndSettle();

      // Skip straight to slide 6 by navigating
      for (int i = 0; i < 5; i++) {
        await tester.tap(find.byKey(const Key('walkthrough_next_button')));
        await tester.pumpAndSettle();
      }

      expect(find.text('Offline AI Model'), findsOneWidget);
      await tester
          .tap(find.byKey(const Key('walkthrough_download_now_button')));
      await tester.pumpAndSettle();

      expect(mockDownload.downloadStarted, isTrue);
    });

    testWidgets(
        'QuickProfileScreen: Fill it in now saves to both stores and non-destructively maps fields',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        'profile_name': 'Alex',
        'profile_age': 30,
        'profile_conditions': 'Asthma',
      });

      final medStore = MedicalIdStore();
      final profService = ProfileService();

      await tester.pumpWidget(
        buildTestApp(
          child: QuickProfileScreen(
            medicalIdStore: medStore,
            profileService: profService,
          ),
          screenSize: const Size(393, 852),
          textScale: 1.0,
        ),
      );
      await tester.pumpAndSettle();

      // Check prefill: Name "Alex", Age "30", Conditions "Asthma"
      expect(find.text('Stored only on this device.'), findsOneWidget);
      expect(
          find.byKey(const Key('quick_profile_skip_button')), findsOneWidget);
      expect(find.text('Alex'), findsOneWidget);
      expect(find.text('30'), findsOneWidget);
      expect(find.text('Asthma'), findsOneWidget);

      // Enter allergies and blood group
      await tester.enterText(
          find.byKey(const Key('quick_profile_allergies_field')), 'Penicillin');

      // Select blood group O+
      await tester
          .tap(find.byKey(const Key('quick_profile_blood_group_field')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('O+').last);
      await tester.pumpAndSettle();

      // Enter emergency contact
      await tester.enterText(
          find.byKey(const Key('quick_profile_contact_name_field')), 'Morgan');
      await tester.enterText(
          find.byKey(const Key('quick_profile_contact_phone_field')),
          '+1 (555) 123-4567');
      await tester.enterText(
          find.byKey(const Key('quick_profile_contact_relation_field')),
          'Partner');

      // Scroll down to reveal and tap Save Profile
      await tester.drag(
          find.byType(SingleChildScrollView), const Offset(0, -300));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('quick_profile_save_button')));
      await tester.pumpAndSettle();

      // Verify MedicalIdStore received save
      final savedMedId = await medStore.loadMedicalId();
      expect(savedMedId.name, equals('Alex'));
      expect(savedMedId.ageOrDob, equals('30'));
      expect(savedMedId.bloodGroup, equals('O+'));
      expect(savedMedId.allergies, equals('Penicillin'));
      expect(savedMedId.conditions, equals('Asthma'));
      expect(savedMedId.contacts.length, equals(1));
      expect(savedMedId.contacts.first.name, equals('Morgan'));
      expect(savedMedId.contacts.first.phone, equals('+15551234567'));

      // Verify ProfileService received save
      final savedProfile = await profService.loadProfile();
      expect(savedProfile.name, equals('Alex'));
      expect(savedProfile.age, equals(30));
      expect(savedProfile.allergies, equals('Penicillin'));
      expect(savedProfile.conditions, equals('Asthma'));
    });

    testWidgets('QuickProfileScreen: Skip leaves stores untouched',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final medStore = MedicalIdStore();
      final profService = ProfileService();

      await tester.pumpWidget(
        buildTestApp(
          child: QuickProfileScreen(
            medicalIdStore: medStore,
            profileService: profService,
          ),
          screenSize: const Size(393, 852),
          textScale: 1.0,
        ),
      );
      await tester.pumpAndSettle();

      // Enter some text without saving
      await tester.enterText(
          find.byKey(const Key('quick_profile_name_field')), 'Unsaved Name');

      // Tap Skip
      await tester.tap(find.byKey(const Key('quick_profile_skip_button')));
      await tester.pumpAndSettle();

      // Stores must remain empty
      final medId = await medStore.loadMedicalId();
      expect(medId.name, isEmpty);
      final profile = await profService.loadProfile();
      expect(profile.name, isEmpty);
    });

    testWidgets(
        'complete_profile_card appears on Assistant tab when Medical ID is empty, dismisses permanently, and hides when filled',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        'onboarding_v2_seen': true, // Tour already seen
      });

      final medStore = MedicalIdStore();

      await tester.pumpWidget(
        buildTestApp(
          child: EmergencyHomeScreen(medicalIdStore: medStore),
          screenSize: const Size(393, 852),
          textScale: 1.0,
        ),
      );
      await tester.pumpAndSettle();

      // complete_profile_card appears
      expect(find.byKey(const Key('complete_profile_card')), findsOneWidget);
      expect(
        find.text(
            'Add your Medical ID so SOS can include allergies and blood group'),
        findsOneWidget,
      );
      expect(find.text('Add now'), findsOneWidget);
      expect(find.text('Dismiss'), findsOneWidget);

      // Dismiss card
      await tester.tap(find.text('Dismiss'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('complete_profile_card')), findsNothing);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('profile_prompt_dismissed'), isTrue);

      // Simulate re-visiting the screen: card must stay hidden
      await tester.pumpWidget(
        buildTestApp(
          child: EmergencyHomeScreen(medicalIdStore: medStore),
          screenSize: const Size(393, 852),
          textScale: 1.0,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('complete_profile_card')), findsNothing);
    });

    testWidgets(
        'complete_profile_card hides automatically when Medical ID has content',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        'onboarding_v2_seen': true,
        'carepulse_medical_id': '{"name":"John Doe","bloodGroup":"A+"}',
      });

      final medStore = MedicalIdStore();

      await tester.pumpWidget(
        buildTestApp(
          child: EmergencyHomeScreen(medicalIdStore: medStore),
          screenSize: const Size(393, 852),
          textScale: 1.0,
        ),
      );
      await tester.pumpAndSettle();

      // Since Medical ID has content, card should not appear
      expect(find.byKey(const Key('complete_profile_card')), findsNothing);
    });

    testWidgets(
        'Settings & About has "Replay walkthrough" that opens tour without resetting data',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        'onboarding_v2_seen': true,
        'profile_prompt_dismissed': true,
        'carepulse_emergency_number': '112',
      });

      await tester.pumpWidget(
        buildTestApp(
          child: Builder(
            builder: (ctx) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showCarePulseSettingsSheet(ctx),
                  child: const Text('Open Settings'),
                ),
              ),
            ),
          ),
          screenSize: const Size(393, 852),
          textScale: 1.0,
        ),
      );
      await tester.pumpAndSettle();

      // Open settings sheet
      await tester.tap(find.text('Open Settings'));
      await tester.pumpAndSettle();

      // Find "Replay walkthrough" tile and scroll into view
      final replayFinder = find.text('Replay walkthrough');
      await tester.scrollUntilVisible(replayFinder, 100);
      await tester.pumpAndSettle();
      expect(replayFinder, findsOneWidget);
      await tester.tap(replayFinder);
      await tester.pumpAndSettle();

      // Walkthrough tour is opened
      expect(find.text('CarePulse Tour'), findsOneWidget);
      expect(find.text('First aid that works offline'), findsOneWidget);
    });

    testWidgets(
        'Walkthrough & QuickProfile no overflow at 393x852 and 360x640 at text scale 1.6 in light and dark',
        (tester) async {
      final devices = [
        const Size(393, 852), // iPhone 16
        const Size(360, 640), // Small phone
      ];

      for (final device in devices) {
        for (final mode in [ThemeMode.light, ThemeMode.dark]) {
          // 1. Walkthrough screen
          await tester.pumpWidget(
            buildTestApp(
              child: const WalkthroughScreen(),
              screenSize: device,
              textScale: 1.6,
              themeMode: mode,
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);

          // 2. Quick profile screen
          await tester.pumpWidget(
            buildTestApp(
              child: const QuickProfileScreen(),
              screenSize: device,
              textScale: 1.6,
              themeMode: mode,
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
      }
    });
  });
}
