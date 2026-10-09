import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../state/triage_controller.dart';
import '../widgets/emergency_chips.dart';
import '../widgets/streaming_response_card.dart';
import '../widgets/telemetry_bar.dart';
import '../widgets/glass_card.dart';
import 'profile_screen.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class EmergencyHomeScreen extends StatefulWidget {
  const EmergencyHomeScreen({super.key});

  @override
  State<EmergencyHomeScreen> createState() => _EmergencyHomeScreenState();
}

class _EmergencyHomeScreenState extends State<EmergencyHomeScreen> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  bool _telemetryExpanded = false;

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  void _initSpeech() async {
    await _speech.initialize();
  }

  void _listen() async {
    if (!_isListening) {
      bool available = await _speech.initialize();
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          onResult: (val) => setState(() {
            _textController.text = val.recognizedWords;
          }),
        );
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submitQuery(TriageController controller, [String? presetText]) {
    final queryText = presetText ?? _textController.text;
    if (queryText.trim().isEmpty || controller.isGenerating) return;

    if (presetText != null) {
      _textController.text = presetText;
    }

    _focusNode.unfocus();
    controller.submitEmergencyQuery(queryText);
  }

  Future<void> _callEmergency() async {
    final uri = Uri(scheme: 'tel', path: '112');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        throw Exception('Could not launch $uri');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to open dialer. Please dial 112 manually.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<TriageController>();
    final glass = Theme.of(context).extension<CarePulseGlass>()!;

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
              Icon(Icons.medical_services_rounded, color: glass.accentMint, size: 20),
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
          IconButton(
            icon: Icon(Icons.person, color: glass.accentMint),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
            },
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
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Emergency Call Button
                      InkWell(
                        onTap: _callEmergency,
                        borderRadius: BorderRadius.circular(24),
                        child: Container(
                          height: 68,
                          decoration: BoxDecoration(
                            gradient: glass.emergencyGradient,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.phone, color: Colors.white, size: 26),
                              SizedBox(width: 12),
                              Text(
                                "Call emergency · 112",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Performance Chevron
                      GlassCard(
                        borderRadius: 24,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                                Text("Performance", style: TextStyle(color: glass.textPrimary, fontWeight: FontWeight.bold)),
                                Row(
                                  children: [
                                    Text("Tap to expand", style: TextStyle(color: glass.textSecondary, fontSize: 12)),
                                    Icon(_telemetryExpanded ? Icons.expand_less : Icons.expand_more, color: glass.textSecondary, size: 16),
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
                      Text("What's happening?", style: TextStyle(color: glass.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),

                      // Quick-Trigger Emergency Chips
                      EmergencyChips(
                        isDisabled: controller.isGenerating,
                        onPresetSelected: (preset) {
                          _submitQuery(controller, preset.query);
                        },
                      ),

                      const SizedBox(height: 16),

                      // Streaming Response Card
                      StreamingResponseCard(
                        query: controller.currentQuery,
                        responseText: controller.streamedResponse,
                        isGenerating: controller.isGenerating,
                        onClear: () {
                          _textController.clear();
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
                              Icon(Icons.description, color: glass.accentMint, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  controller.uploadedDocument!.fileName,
                                  style: TextStyle(color: glass.textPrimary, fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.close, size: 18, color: glass.textSecondary),
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
                            style: TextStyle(color: glass.textPrimary, fontSize: 14),
                            decoration: InputDecoration(
                              hintText: 'Describe what happened...',
                              hintStyle: TextStyle(color: glass.textSecondary, fontSize: 13),
                              filled: false,
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                              prefixIcon: Icon(
                                Icons.emergency_rounded,
                                color: glass.accentMint,
                                size: 20,
                              ),
                              suffixIcon: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (_textController.text.isNotEmpty && !controller.isGenerating)
                                    IconButton(
                                      icon: const Icon(Icons.clear_rounded, size: 18),
                                      color: glass.textSecondary,
                                      onPressed: () {
                                        _textController.clear();
                                        setState(() {});
                                      },
                                    ),
                                  IconButton(
                                    icon: Icon(_isListening ? Icons.mic : Icons.mic_none, size: 22),
                                    color: _isListening ? glass.successDot : glass.textSecondary,
                                    onPressed: _listen,
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.attach_file, size: 22),
                                    color: glass.textSecondary,
                                    onPressed: () => controller.pickDocument(),
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

                    // Emergency Submit Button
                    Container(
                      height: 58,
                      width: 58,
                      decoration: BoxDecoration(
                        gradient: glass.primaryActionGradient,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white.withOpacity(0.4), width: 1),
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
