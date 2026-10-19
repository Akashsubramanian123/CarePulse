import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/emergency_config.dart';
import '../../core/theme/app_theme.dart';
import '../../services/tts_service.dart';
import '../../services/voice_input_service.dart';
import '../../models/triage_question.dart';
import '../../state/app_settings_controller.dart';
import '../../state/triage_controller.dart';
import '../widgets/emergency_chips.dart';
import '../widgets/glass_card.dart';
import '../widgets/streaming_response_card.dart';
import '../widgets/telemetry_bar.dart';
import '../../models/medical_id.dart';
import '../../services/medical_id_store.dart';
import 'main_shell.dart';
import 'model_setup_screen.dart';
import 'profile_screen.dart';
import 'quick_profile_screen.dart';
import 'walkthrough_screen.dart';

class EmergencyHomeScreen extends StatefulWidget {
  final MedicalIdStore? medicalIdStore;

  const EmergencyHomeScreen({super.key, this.medicalIdStore});

  @override
  State<EmergencyHomeScreen> createState() => _EmergencyHomeScreenState();
}

class _EmergencyHomeScreenState extends State<EmergencyHomeScreen> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  final VoiceInputService _voiceService = VoiceInputService();
  final TtsService _tts = TtsService();

  late final MedicalIdStore _medicalIdStore;
  bool _profilePromptDismissed = false;
  bool _hasMedicalIdContent = true;

  bool _isListening = false;
  bool _isSpeaking = false;
  bool _telemetryExpanded = false;
  bool _voiceCloudNote = false;
  bool _autoReadAloud = false;
  String _lastSpokenResponse = '';

  @override
  void initState() {
    super.initState();
    _medicalIdStore = widget.medicalIdStore ?? MedicalIdStore();
    _loadSettings();
    _refreshMedicalIdStatus();
    _tts.isSpeakingNotifier.addListener(_onTtsStateChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkFirstLaunchOnboarding();
    });
  }

  Future<void> _checkFirstLaunchOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool('onboarding_v2_seen') ?? false;
    if (!seen && mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => WalkthroughScreen(
            medicalIdStore: _medicalIdStore,
          ),
        ),
      );
      if (mounted) {
        _refreshMedicalIdStatus();
      }
    }
  }

  Future<void> _refreshMedicalIdStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dismissed = prefs.getBool('profile_prompt_dismissed') ?? false;
      final medId = await _medicalIdStore.loadMedicalId();
      final hasContent = _hasAnyMedicalIdContent(medId);
      if (mounted) {
        setState(() {
          _profilePromptDismissed = dismissed;
          _hasMedicalIdContent = hasContent;
        });
      }
    } catch (_) {}
  }

  bool _hasAnyMedicalIdContent(MedicalId id) {
    return id.name.trim().isNotEmpty ||
        id.ageOrDob.trim().isNotEmpty ||
        id.bloodGroup.trim().isNotEmpty ||
        id.allergies.trim().isNotEmpty ||
        id.conditions.trim().isNotEmpty ||
        id.medications.trim().isNotEmpty ||
        id.notes.trim().isNotEmpty ||
        id.contacts.isNotEmpty;
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _autoReadAloud = prefs.getBool('carepulse_auto_read_aloud') ?? false;
      });
    }
  }

  void _onTtsStateChanged() {
    if (mounted) {
      setState(() {
        _isSpeaking = _tts.isSpeaking;
      });
    }
  }

  @override
  void dispose() {
    _tts.isSpeakingNotifier.removeListener(_onTtsStateChanged);
    _tts.stop();
    _voiceService.stopListening();
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _toggleListening() async {
    if (_isListening) {
      setState(() => _isListening = false);
      await _voiceService.stopListening();
    } else {
      final success = await _voiceService.startListening(
        onResult: (text, isFinal) {
          if (mounted) {
            setState(() {
              _textController.text = text;
              if (isFinal) {
                _isListening = false;
              }
            });
          }
        },
        onError: (err) {
          if (mounted) {
            setState(() => _isListening = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Speech error: $err')),
            );
          }
        },
        onFallbackToCloud: () {
          if (mounted) {
            setState(() => _voiceCloudNote = true);
          }
        },
      );

      if (mounted) {
        setState(() => _isListening = success);
      }
    }
  }

  void _submitQuery(TriageController controller, [String? presetText]) {
    final queryText = presetText ?? _textController.text;
    if (queryText.trim().isEmpty || controller.isGenerating) return;

    if (presetText != null) {
      _textController.text = presetText;
    }

    _focusNode.unfocus();
    _voiceService.stopListening();
    setState(() => _isListening = false);

    controller.submitEmergencyQuery(queryText);
    _scrollTo(_responseCardKey);
  }

  void _toggleSpeak(String text) {
    if (_isSpeaking) {
      _tts.stop();
    } else {
      _tts.speak(text);
    }
  }

  Future<void> _callEmergency([String? targetNumber]) async {
    final settings =
        Provider.of<AppSettingsController?>(context, listen: false);
    final number = targetNumber ?? settings?.emergencyNumber ?? emergencyNumber;
    final uri = Uri(scheme: 'tel', path: number);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        throw Exception('Could not launch $uri');
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Failed to open dialer. Please dial $number manually.'),
          ),
        );
      }
    }
  }

  void _scrollTo(GlobalKey key) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final targetContext = key.currentContext;
      if (targetContext != null) {
        Scrollable.ensureVisible(
          targetContext,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutQuad,
          alignment: 0.05,
        );
      }
    });
  }

  final GlobalKey _responseCardKey = GlobalKey();
  final GlobalKey _clarificationCardKey = GlobalKey();
  final ScrollController _scrollController = ScrollController();
  String? _lastQuestionText;
  bool _lastCallEmergencyNow = false;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<TriageController>();
    final glass = Theme.of(context).extension<CarePulseGlass>()!;
    AppSettingsController? settingsController;
    try {
      settingsController = context.watch<AppSettingsController>();
    } catch (_) {}
    final settings = settingsController ?? AppSettingsController();

    // Auto-scroll when clarifying question appears or red-flag triggers
    if (controller.pendingQuestion != null &&
        controller.pendingQuestion?.text != _lastQuestionText) {
      _lastQuestionText = controller.pendingQuestion?.text;
      _scrollTo(_clarificationCardKey);
    } else if (controller.callEmergencyNow && !_lastCallEmergencyNow) {
      _lastCallEmergencyNow = true;
      _scrollTo(_responseCardKey);
    }

    // Auto-read aloud trigger when generation completes
    if (_autoReadAloud &&
        !controller.isGenerating &&
        controller.streamedResponse.isNotEmpty &&
        controller.streamedResponse != _lastSpokenResponse) {
      _lastSpokenResponse = controller.streamedResponse;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _tts.speak(controller.streamedResponse);
      });
    }

    return GlassScaffold(
      body: Column(
        children: [
          // Status row under top bar: Status pill on the left, Profile button on the right
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStatusPill(context, controller, glass),
                SizedBox(
                  width: 48,
                  height: 48,
                  child: IconButton(
                    key: const Key('assistant_profile_button'),
                    tooltip: 'Medical profile',
                    icon: Icon(Icons.person_outline_rounded,
                        color: glass.textPrimary),
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ProfileScreen(),
                        ),
                      );
                      if (mounted) {
                        _refreshMedicalIdStatus();
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          // Sticky banner directly under status row whenever model is not ready
          _buildStickyBanner(context, controller, glass),
          // Scrollable Content Area with soft fade at bottom edge
          Expanded(
            child: ShaderMask(
              shaderCallback: (Rect bounds) {
                return const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF000000),
                    Color(0xFF000000),
                    Color(0xFF000000),
                    Colors.transparent,
                  ],
                  stops: [0.0, 0.90, 0.96, 1.0],
                ).createShader(bounds);
              },
              blendMode: BlendMode.dstIn,
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 8,
                  bottom: 24,
                ),
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Prominent Call 112 Banner when red flag triggers
                    if (controller.callEmergencyNow) ...[
                      InkWell(
                        onTap: _callEmergency,
                        borderRadius: BorderRadius.circular(24),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 16),
                          decoration: BoxDecoration(
                            gradient: glass.emergencyGradient,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFE05A4F)
                                    .withValues(alpha: 0.5),
                                blurRadius: 22,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.warning_rounded,
                                  color: Colors.white, size: 28),
                              const SizedBox(width: 10),
                              Flexible(
                                child: Text(
                                  'CRITICAL RED FLAG · CALL ${settings.emergencyNumber} NOW',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ] else ...[
                      // Standard Emergency Call Button
                      InkWell(
                        onTap: () => _callEmergency(settings.emergencyNumber),
                        borderRadius: BorderRadius.circular(24),
                        child: Container(
                          constraints: const BoxConstraints(minHeight: 56),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            gradient: glass.emergencyGradient,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.phone,
                                  color: Colors.white, size: 24),
                              const SizedBox(width: 10),
                              Flexible(
                                child: Text(
                                  'Call emergency · ${settings.emergencyNumber}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Performance Chevron
                    GlassCard(
                      borderRadius: 24,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      onTap: () {
                        setState(() {
                          _telemetryExpanded = !_telemetryExpanded;
                        });
                      },
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text('Performance',
                                    style: TextStyle(
                                        color: glass.textPrimary,
                                        fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(width: 8),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('Tap to expand',
                                      style: TextStyle(
                                          color: glass.textSecondary,
                                          fontSize: 12)),
                                  Icon(
                                    _telemetryExpanded
                                        ? Icons.expand_less
                                        : Icons.expand_more,
                                    color: glass.textSecondary,
                                    size: 16,
                                  ),
                                ],
                              ),
                            ],
                          ),
                          AnimatedSize(
                            duration: const Duration(milliseconds: 300),
                            child: _telemetryExpanded
                                ? Padding(
                                    padding: const EdgeInsets.only(top: 12.0),
                                    child: TelemetryBar(
                                      ttftMs: controller.ttftMs,
                                      tokensPerSec: controller.tokensPerSec,
                                      ramUsageMb: controller.ramUsageMb,
                                      isOffline: controller.isOffline,
                                      isGenerating: controller.isGenerating,
                                    ),
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ],
                      ),
                    ),

                    if (!_profilePromptDismissed && !_hasMedicalIdContent) ...[
                      const SizedBox(height: 16),
                      _buildCompleteProfileCard(context, glass),
                    ],

                    const SizedBox(height: 24),
                    Text("What's happening?",
                        style: TextStyle(
                            color: glass.textPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),

                    // Quick-Trigger Emergency Chips
                    EmergencyChips(
                      isDisabled: controller.isGenerating,
                      onPresetSelected: (preset) {
                        _submitQuery(controller, preset.query);
                      },
                    ),

                    const SizedBox(height: 16),

                    // Streaming Response Card with Source Chip and TTS Read-aloud
                    KeyedSubtree(
                      key: _responseCardKey,
                      child: StreamingResponseCard(
                        query: controller.currentQuery,
                        responseText: controller.streamedResponse,
                        isGenerating: controller.isGenerating,
                        wasStopped: controller.wasStopped,
                        clarificationNote: controller.clarificationNote,
                        sourceLabel: controller.answerSource?.label,
                        isModelReady: controller.isReady,
                        isDownloading: controller.isDownloading,
                        downloadProgress: controller.downloadProgress,
                        onDownload: () => controller.startModelDownload(),
                        onOpenGuides: () =>
                            const TabSwitchNotification(1).dispatch(context),
                        errorMessage: controller.errorMessage,
                        onRetry: () => controller.retryLastQuery(),
                        onSpeak: () =>
                            _toggleSpeak(controller.streamedResponse),
                        isSpeaking: _isSpeaking,
                        onStopSpeaking: () => _tts.stop(),
                        onClear: () {
                          _textController.clear();
                          _tts.stop();
                          controller.clearResponse();
                        },
                      ),
                    ),

                    const SizedBox(height: 16),
                    if (controller.uploadedDocument != null)
                      GlassCard(
                        padding: const EdgeInsets.all(12),
                        borderRadius: 12,
                        child: Row(
                          children: [
                            Icon(Icons.description,
                                color: glass.accentMint, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                controller.uploadedDocument!.fileName,
                                style: TextStyle(
                                    color: glass.textPrimary, fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.close,
                                  size: 18, color: glass.textSecondary),
                              onPressed: controller.clearDocument,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      ),
                    if (controller.uploadedDocument != null)
                      const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),

          // Subtle note if cloud fallback is used
          if (_voiceCloudNote)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(
                'Voice may need internet on this device',
                style: TextStyle(color: glass.accentMint, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),

          // Clarifying Question Card (Feature 4)
          if (controller.pendingQuestion != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: KeyedSubtree(
                key: _clarificationCardKey,
                child: GlassCard(
                  key: const Key('triage_clarification_card'),
                  padding: const EdgeInsets.all(16),
                  borderRadius: 20,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.help_outline_rounded,
                              color: glass.accentMint, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              controller.pendingQuestion!.text,
                              style: TextStyle(
                                color: glass.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 48,
                              child: ElevatedButton(
                                key: const ValueKey('triage_answer_yes'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: glass.accentMint,
                                  foregroundColor: Colors.black87,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  minimumSize: const Size(0, 48),
                                ),
                                onPressed: () => controller
                                    .answerClarifyingQuestion(TriageAnswer.yes),
                                child: const Text('Yes',
                                    style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: SizedBox(
                              height: 48,
                              child: ElevatedButton(
                                key: const ValueKey('triage_answer_no'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFC7382E),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  minimumSize: const Size(0, 48),
                                ),
                                onPressed: () => controller
                                    .answerClarifyingQuestion(TriageAnswer.no),
                                child: const Text('No',
                                    style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: SizedBox(
                              height: 48,
                              child: ElevatedButton(
                                key: const ValueKey('triage_answer_not_sure'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: glass.glassBorderColor
                                      .withValues(alpha: 0.2),
                                  foregroundColor: glass.textPrimary,
                                  side:
                                      BorderSide(color: glass.glassBorderColor),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  minimumSize: const Size(0, 48),
                                ),
                                onPressed: () =>
                                    controller.answerClarifyingQuestion(
                                        TriageAnswer.notSure),
                                child: const Text('Not sure',
                                    style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Center(
                        child: SizedBox(
                          height: 48,
                          child: TextButton(
                            key: const ValueKey('triage_answer_skip'),
                            style: TextButton.styleFrom(
                              foregroundColor: glass.textSecondary,
                              minimumSize: const Size(48, 48),
                            ),
                            onPressed: () => controller
                                .answerClarifyingQuestion(TriageAnswer.skip),
                            child: const Text(
                              'Skip',
                              style: TextStyle(
                                fontSize: 13,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Bottom Input Bar
          Container(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Text Field Input
                Expanded(
                  child: GlassCard(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    borderRadius: 22,
                    child: SizedBox(
                      height: 58,
                      child: TextField(
                        controller: _textController,
                        focusNode: _focusNode,
                        maxLines: 1,
                        enabled: !controller.isGenerating,
                        style:
                            TextStyle(color: glass.textPrimary, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'What happened?',
                          hintStyle: TextStyle(
                            color: glass.textSecondary,
                            fontSize: 13,
                            overflow: TextOverflow.ellipsis,
                          ),
                          filled: false,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 16),
                          suffixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_textController.text.isNotEmpty &&
                                  !controller.isGenerating)
                                SizedBox(
                                  width: 48,
                                  height: 48,
                                  child: IconButton(
                                    icon: const Icon(Icons.clear_rounded,
                                        size: 18),
                                    color: glass.textSecondary,
                                    onPressed: () {
                                      _textController.clear();
                                      setState(() {});
                                    },
                                  ),
                                ),
                              // Mic Button with VoiceInputService (>= 48x48)
                              SizedBox(
                                width: 48,
                                height: 48,
                                child: IconButton(
                                  icon: Icon(
                                    _isListening ? Icons.mic : Icons.mic_none,
                                    size: 22,
                                  ),
                                  color: _isListening
                                      ? const Color(0xFFC7382E)
                                      : glass.accentMint,
                                  tooltip: _isListening
                                      ? 'Stop listening'
                                      : 'Speak emergency scenario',
                                  onPressed: _toggleListening,
                                ),
                              ),
                              // Attach Button (>= 48x48)
                              SizedBox(
                                width: 48,
                                height: 48,
                                child: IconButton(
                                  icon: const Icon(Icons.attach_file, size: 20),
                                  color: glass.textSecondary,
                                  tooltip: 'Attach record',
                                  onPressed: () => controller.pickDocument(),
                                ),
                              ),
                            ],
                          ),
                        ),
                        onChanged: (_) => setState(() {}),
                        onSubmitted: (_) => _submitQuery(controller),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Emergency Submit Button (>= 48x48)
                Container(
                  height: 58,
                  width: 58,
                  decoration: BoxDecoration(
                    gradient: glass.primaryActionGradient,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.4), width: 1),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      key: const ValueKey('emergency_submit_button'),
                      borderRadius: BorderRadius.circular(24),
                      onTap: controller.isGenerating
                          ? () => controller.stopGeneration()
                          : () => _submitQuery(controller),
                      child: Semantics(
                        label: controller.isGenerating ? 'Stop' : 'Send',
                        button: true,
                        child: Center(
                          child: Icon(
                            controller.isGenerating
                                ? Icons.stop_rounded
                                : Icons.send_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompleteProfileCard(BuildContext context, CarePulseGlass glass) {
    return GlassCard(
      key: const Key('complete_profile_card'),
      borderRadius: 20,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: glass.iconTintGradient,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.badge_outlined,
                    color: glass.accentMint, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Add your Medical ID so SOS can include allergies and blood group',
                  style: TextStyle(
                    color: glass.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              ElevatedButton(
                key: const Key('complete_profile_add_now_button'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: glass.accentMint,
                  foregroundColor: Colors.black87,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => QuickProfileScreen(
                        medicalIdStore: _medicalIdStore,
                      ),
                    ),
                  );
                  if (mounted) {
                    _refreshMedicalIdStatus();
                  }
                },
                child: const Text('Add now'),
              ),
              TextButton(
                key: const Key('complete_profile_dismiss_button'),
                style: TextButton.styleFrom(
                  foregroundColor: glass.textSecondary,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                onPressed: () async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('profile_prompt_dismissed', true);
                  if (mounted) {
                    setState(() {
                      _profilePromptDismissed = true;
                    });
                  }
                },
                child: const Text('Dismiss'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusPill(
      BuildContext context, TriageController controller, CarePulseGlass glass) {
    Color dotColor;
    String label;

    if (controller.isReady) {
      dotColor = glass.successDot;
      label = 'Offline · AI ready';
    } else if (controller.isDownloading) {
      dotColor = const Color(0xFF009688); // teal
      label = 'Downloading ${(controller.downloadProgress * 100).toInt()}%';
    } else if (controller.isVerifying) {
      dotColor = const Color(0xFF42A5F5); // blue
      label = 'Verifying...';
    } else if (controller.hasError) {
      dotColor = Theme.of(context).colorScheme.error;
      label = 'Model error';
    } else {
      // isDownloadRequired or checking
      dotColor = const Color(0xFFFFB300); // amber
      label = 'AI model not downloaded';
    }

    return Flexible(
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        borderRadius: 20,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.circle, size: 8, color: dotColor),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  color: glass.textPrimary,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStickyBanner(
      BuildContext context, TriageController controller, CarePulseGlass glass) {
    if (controller.isReady) {
      return const SizedBox.shrink();
    }

    final modelSize = controller.totalMB > 0
        ? '${controller.totalMB.toInt()}MB'
        : '${AppConstants.estimatedModelSizeMb.toInt()}MB';

    Widget content;

    if (controller.isDownloading) {
      final percent = (controller.downloadProgress * 100).toInt();
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Downloading AI model ($percent%)',
                  style: TextStyle(
                    color: glass.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ModelSetupScreen(),
                    ),
                  );
                },
                child: const Text('Details'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: controller.downloadProgress > 0
                  ? controller.downloadProgress
                  : null,
              backgroundColor: glass.glassBorderColor.withValues(alpha: 0.3),
              valueColor: AlwaysStoppedAnimation<Color>(glass.accentMint),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '${controller.downloadedMB.toStringAsFixed(1)} / ${controller.totalMB.toStringAsFixed(1)} MB',
                style: TextStyle(
                  color: glass.textSecondary,
                  fontSize: 12,
                ),
              ),
              const Spacer(),
              ElevatedButton(
                key: const Key('sticky_banner_pause_button'),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      glass.glassBorderColor.withValues(alpha: 0.25),
                  foregroundColor: glass.textPrimary,
                  minimumSize: const Size(0, 36),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () => controller.pauseModelDownload(),
                child: const Text('Pause', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ],
      );
    } else if (controller.isVerifying) {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(glass.accentMint),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Verifying download...',
                      style: TextStyle(
                        color: glass.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ModelSetupScreen(),
                    ),
                  );
                },
                child: const Text('Details'),
              ),
            ],
          ),
        ],
      );
    } else if (controller.hasError) {
      final msg = controller.errorMessage ??
          'Model download failed. Please check connection.';
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.error_outline_rounded,
                  color: Theme.of(context).colorScheme.error, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  msg,
                  style: TextStyle(
                    color: glass.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ModelSetupScreen(),
                    ),
                  );
                },
                child: const Text('Details'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            key: const Key('sticky_banner_retry_button'),
            style: ElevatedButton.styleFrom(
              backgroundColor: glass.accentMint,
              foregroundColor: Colors.black87,
              minimumSize: const Size(0, 36),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => controller.startModelDownload(),
            child: const Text('Retry',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      );
    } else {
      // Needs download (or checking)
      final hasPartial = controller.partialBytes > 0;
      final percent = (controller.downloadProgress * 100).toInt();
      final buttonLabel =
          hasPartial ? 'Resume download ($percent%)' : 'Download AI model';

      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  'AI answers need a one-time $modelSize download. Emergency rules, Guides, CPR and SOS already work offline.',
                  style: TextStyle(
                    color: glass.textPrimary,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ModelSetupScreen(),
                    ),
                  );
                },
                child: const Text('Details'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            key: const Key('sticky_banner_download_button'),
            style: ElevatedButton.styleFrom(
              backgroundColor: glass.accentMint,
              foregroundColor: Colors.black87,
              minimumSize: const Size(0, 36),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => controller.startModelDownload(),
            child: Text(buttonLabel,
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: GlassCard(
        key: const Key('assistant_sticky_banner'),
        borderRadius: 16,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        tint: const Color(0xFFFFB300).withValues(alpha: 0.12),
        child: content,
      ),
    );
  }
}
