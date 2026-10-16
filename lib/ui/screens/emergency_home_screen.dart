import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/emergency_config.dart';
import '../../core/theme/app_theme.dart';
import '../../services/tts_service.dart';
import '../../services/voice_input_service.dart';
import '../../state/theme_controller.dart';
import '../../state/triage_controller.dart';
import '../widgets/emergency_chips.dart';
import '../widgets/glass_card.dart';
import '../widgets/streaming_response_card.dart';
import '../widgets/telemetry_bar.dart';
import 'profile_screen.dart';

class EmergencyHomeScreen extends StatefulWidget {
  const EmergencyHomeScreen({super.key});

  @override
  State<EmergencyHomeScreen> createState() => _EmergencyHomeScreenState();
}

class _EmergencyHomeScreenState extends State<EmergencyHomeScreen> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  final VoiceInputService _voiceService = VoiceInputService();
  final TtsService _tts = TtsService();

  bool _isListening = false;
  bool _isSpeaking = false;
  bool _telemetryExpanded = false;
  bool _voiceCloudNote = false;
  bool _autoReadAloud = false;
  String _lastSpokenResponse = '';

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _tts.isSpeakingNotifier.addListener(_onTtsStateChanged);
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _autoReadAloud = prefs.getBool('carepulse_auto_read_aloud') ?? false;
      });
    }
  }

  Future<void> _saveAutoReadAloud(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('carepulse_auto_read_aloud', value);
    if (mounted) {
      setState(() {
        _autoReadAloud = value;
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
  }

  void _toggleSpeak(String text) {
    if (_isSpeaking) {
      _tts.stop();
    } else {
      _tts.speak(text);
    }
  }

  Future<void> _callEmergency() async {
    final uri = Uri(scheme: 'tel', path: emergencyNumber);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        throw Exception('Could not launch $uri');
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to open dialer. Please dial 112 manually.'),
          ),
        );
      }
    }
  }

  void _openSettingsSheet(CarePulseGlass glass) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final isDark = Theme.of(ctx).brightness == Brightness.dark;
            ThemeController? themeController;
            try {
              themeController = ctx.watch<ThemeController>();
            } catch (_) {
              try {
                themeController = Provider.of<ThemeController>(context);
              } catch (_) {
                themeController = null;
              }
            }

            return Material(
              color: isDark ? const Color(0xFF1B242D) : Colors.white,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(28)),
              clipBehavior: Clip.antiAlias,
              child: Container(
                padding: const EdgeInsets.all(20),
                child: SafeArea(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Settings & About',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: glass.textPrimary,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded),
                              onPressed: () => Navigator.pop(ctx),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Theme',
                          style: TextStyle(
                            color: glass.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        if (themeController != null)
                          SegmentedButton<ThemeMode>(
                            key: const ValueKey(
                                'settings_theme_segmented_button'),
                            segments: const [
                              ButtonSegment<ThemeMode>(
                                value: ThemeMode.system,
                                icon: Icon(Icons.brightness_auto_rounded,
                                    size: 18),
                                label: Text('System'),
                              ),
                              ButtonSegment<ThemeMode>(
                                value: ThemeMode.light,
                                icon: Icon(Icons.light_mode_rounded, size: 18),
                                label: Text('Light'),
                              ),
                              ButtonSegment<ThemeMode>(
                                value: ThemeMode.dark,
                                icon: Icon(Icons.dark_mode_rounded, size: 18),
                                label: Text('Dark'),
                              ),
                            ],
                            selected: {themeController.themeMode},
                            onSelectionChanged: (Set<ThemeMode> newSelection) {
                              if (newSelection.isNotEmpty) {
                                themeController!
                                    .setThemeMode(newSelection.first);
                                setSheetState(() {});
                              }
                            },
                            style: ButtonStyle(
                              minimumSize:
                                  WidgetStateProperty.all(const Size(0, 48)),
                              visualDensity: VisualDensity.standard,
                              tapTargetSize: MaterialTapTargetSize.padded,
                              backgroundColor:
                                  WidgetStateProperty.resolveWith((states) {
                                if (states.contains(WidgetState.selected)) {
                                  return glass.accentMint
                                      .withValues(alpha: 0.22);
                                }
                                return Colors.transparent;
                              }),
                              foregroundColor:
                                  WidgetStateProperty.resolveWith((states) {
                                if (states.contains(WidgetState.selected)) {
                                  return glass.accentMint;
                                }
                                return glass.textPrimary;
                              }),
                              side: WidgetStateProperty.all(
                                BorderSide(
                                    color: glass.glassBorderColor, width: 1.0),
                              ),
                            ),
                          ),
                        const SizedBox(height: 14),
                        const Divider(height: 1),
                        const SizedBox(height: 8),
                        SwitchListTile(
                          title: Text(
                            'Read answers aloud automatically',
                            style: TextStyle(
                              color: glass.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            'Speaks out emergency steps as soon as generated',
                            style: TextStyle(
                                color: glass.textSecondary, fontSize: 12),
                          ),
                          value: _autoReadAloud,
                          activeThumbColor: glass.accentMint,
                          contentPadding: EdgeInsets.zero,
                          onChanged: (val) {
                            setSheetState(() => _autoReadAloud = val);
                            _saveAutoReadAloud(val);
                          },
                        ),
                        const Divider(height: 24),
                        Text(
                          'About CarePulse',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: glass.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'CarePulse provides first-aid guidance only and is not a substitute for professional medical care. In a serious emergency, call your local emergency number ($emergencyNumber).',
                          style: TextStyle(
                            color: glass.textSecondary,
                            fontSize: 13,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<TriageController>();
    final glass = Theme.of(context).extension<CarePulseGlass>()!;

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

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          borderRadius: 24,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.medical_services_rounded,
                  color: glass.accentMint, size: 20),
              const SizedBox(width: 8),
              Text(
                AppConstants.appName,
                style: TextStyle(
                  color: glass.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
        ),
        actions: [
          // Settings Sheet Action (Feature 4)
          SizedBox(
            width: 48,
            height: 48,
            child: IconButton(
              icon: Icon(Icons.settings_outlined, color: glass.accentMint),
              tooltip: 'Settings',
              onPressed: () => _openSettingsSheet(glass),
            ),
          ),
          SizedBox(
            width: 48,
            height: 48,
            child: IconButton(
              icon: Icon(Icons.person, color: glass.accentMint),
              tooltip: 'Profile',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                );
              },
            ),
          ),
          Container(
            margin: const EdgeInsets.only(right: 12),
            child: GlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              borderRadius: 20,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.circle, size: 8, color: glass.successDot),
                  const SizedBox(width: 6),
                  Text(
                    'Offline • AI Ready',
                    style: TextStyle(
                      color: glass.textPrimary,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: GradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              // Scrollable Content Area
              Expanded(
                child: SingleChildScrollView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics()),
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
                              children: const [
                                Icon(Icons.warning_rounded,
                                    color: Colors.white, size: 28),
                                SizedBox(width: 10),
                                Flexible(
                                  child: Text(
                                    'CRITICAL RED FLAG · CALL 112 NOW',
                                    style: TextStyle(
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
                          onTap: _callEmergency,
                          borderRadius: BorderRadius.circular(24),
                          child: Container(
                            height: 64,
                            decoration: BoxDecoration(
                              gradient: glass.emergencyGradient,
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(Icons.phone,
                                    color: Colors.white, size: 26),
                                SizedBox(width: 12),
                                Text(
                                  'Call emergency · 112',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
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
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Performance',
                                    style: TextStyle(
                                        color: glass.textPrimary,
                                        fontWeight: FontWeight.bold)),
                                Row(
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
                      StreamingResponseCard(
                        query: controller.currentQuery,
                        responseText: controller.streamedResponse,
                        isGenerating: controller.isGenerating,
                        sourceLabel: controller.answerSource?.label,
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

              // Subtle note if cloud fallback is used
              if (_voiceCloudNote)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Text(
                    'Voice may need internet on this device',
                    style: TextStyle(color: glass.accentMint, fontSize: 12),
                    textAlign: TextAlign.center,
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
                            enabled: !controller.isGenerating,
                            style: TextStyle(
                                color: glass.textPrimary, fontSize: 14),
                            decoration: InputDecoration(
                              hintText: 'Describe what happened...',
                              hintStyle: TextStyle(
                                  color: glass.textSecondary, fontSize: 13),
                              filled: false,
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 16),
                              prefixIcon: Icon(
                                Icons.emergency_rounded,
                                color: glass.accentMint,
                                size: 20,
                              ),
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
                                  // Mic Button with VoiceInputService
                                  SizedBox(
                                    width: 48,
                                    height: 48,
                                    child: IconButton(
                                      icon: Icon(
                                        _isListening
                                            ? Icons.mic
                                            : Icons.mic_none,
                                        size: 22,
                                      ),
                                      color: _isListening
                                          ? const Color(0xFFE05A4F)
                                          : glass.accentMint,
                                      tooltip: _isListening
                                          ? 'Stop listening'
                                          : 'Speak emergency scenario',
                                      onPressed: _toggleListening,
                                    ),
                                  ),
                                  SizedBox(
                                    width: 48,
                                    height: 48,
                                    child: IconButton(
                                      icon: const Icon(Icons.attach_file,
                                          size: 20),
                                      color: glass.textSecondary,
                                      tooltip: 'Attach record',
                                      onPressed: () =>
                                          controller.pickDocument(),
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
                            color: Colors.white.withValues(alpha: 0.4),
                            width: 1),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(24),
                          onTap: controller.isGenerating
                              ? null
                              : () => _submitQuery(controller),
                          child: controller.isGenerating
                              ? const Center(
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  ),
                                )
                              : const Icon(
                                  Icons.send_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
