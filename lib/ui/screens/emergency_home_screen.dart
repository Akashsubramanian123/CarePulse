import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../state/triage_controller.dart';
import '../widgets/emergency_chips.dart';
import '../widgets/streaming_response_card.dart';
import '../widgets/telemetry_bar.dart';
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

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<TriageController>();

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.medical_services_rounded, color: AppColors.tealPrimary, size: 24),
            SizedBox(width: 8),
            Text(
              AppConstants.appName,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person, color: AppColors.tealPrimary),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
            },
          ),
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.safeGreen.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.safeGreen.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: const [
                Icon(Icons.circle, size: 8, color: AppColors.safeGreen),
                SizedBox(width: 6),
                Text(
                  'Offline • AI Ready',
                  style: TextStyle(
                    color: AppColors.safeGreen,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Top Telemetry Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TelemetryBar(
                ttftMs: controller.ttftMs,
                tokensPerSec: controller.tokensPerSec,
                ramUsageMb: controller.ramUsageMb,
                isOffline: controller.isOffline,
                isGenerating: controller.isGenerating,
              ),
            ),

            // Scrollable Content Area
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
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
                  ],
                ),
              ),
            ),

            // Bottom Input Bar
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.darkSurface,
                border: const Border(
                  top: BorderSide(color: AppColors.darkSurfaceBorder, width: 1),
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x1A000000),
                    blurRadius: 16,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Text Field Input
                  Expanded(
                    child: SizedBox(
                      height: 56,
                      child: TextField(
                        controller: _textController,
                        focusNode: _focusNode,
                        enabled: !controller.isGenerating,
                        style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Describe emergency situation...',
                          hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                          filled: true,
                          fillColor: AppColors.darkSurfaceCard,
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          prefixIcon: const Icon(
                            Icons.emergency_rounded,
                            color: AppColors.tealPrimary,
                            size: 20,
                          ),
                          suffixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_textController.text.isNotEmpty && !controller.isGenerating)
                                IconButton(
                                  icon: const Icon(Icons.clear_rounded, size: 18),
                                  color: AppColors.textMuted,
                                  onPressed: () {
                                    _textController.clear();
                                    setState(() {});
                                  },
                                ),
                              IconButton(
                                icon: Icon(_isListening ? Icons.mic : Icons.mic_none, size: 22),
                                color: _isListening ? AppColors.coralEmergency : AppColors.textMuted,
                                onPressed: _listen,
                              ),
                            ],
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: const BorderSide(color: AppColors.darkSurfaceBorder),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: const BorderSide(color: AppColors.darkSurfaceBorder),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: const BorderSide(color: AppColors.tealAccent, width: 2),
                          ),
                        ),
                        onChanged: (_) => setState(() {}),
                        onSubmitted: (_) => _submitQuery(controller),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Emergency Submit Button
                  SizedBox(
                    height: 56,
                    width: 56,
                    child: ElevatedButton(
                      onPressed: controller.isGenerating
                          ? null
                          : () => _submitQuery(controller),
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        backgroundColor: AppColors.coralEmergency,
                        disabledBackgroundColor: AppColors.darkSurfaceBorder,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        elevation: 0,
                      ),
                      child: controller.isGenerating
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(
                              Icons.send_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
