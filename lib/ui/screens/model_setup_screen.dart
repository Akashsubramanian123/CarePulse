import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/emergency_config.dart';
import '../../core/theme/app_theme.dart';
import '../../services/tts_service.dart';
import '../../services/voice_input_service.dart';
import '../../state/app_settings_controller.dart';
import '../../state/triage_controller.dart';
import '../widgets/emergency_chips.dart';
import '../widgets/glass_card.dart';
import '../widgets/streaming_response_card.dart';

class ModelSetupScreen extends StatefulWidget {
  const ModelSetupScreen({super.key});

  @override
  State<ModelSetupScreen> createState() => _ModelSetupScreenState();
}

class _ModelSetupScreenState extends State<ModelSetupScreen> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final VoiceInputService _voiceService = VoiceInputService();
  final TtsService _tts = TtsService();

  bool _isListening = false;
  bool _isSpeaking = false;

  @override
  void initState() {
    super.initState();
    _tts.isSpeakingNotifier.addListener(_onTtsChange);
  }

  void _onTtsChange() {
    if (mounted) {
      setState(() => _isSpeaking = _tts.isSpeaking);
    }
  }

  @override
  void dispose() {
    _tts.isSpeakingNotifier.removeListener(_onTtsChange);
    _tts.stop();
    _voiceService.stopListening();
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _callEmergency([String? targetNumber]) async {
    final settings =
        Provider.of<AppSettingsController?>(context, listen: false);
    final number = targetNumber ?? settings?.emergencyNumber ?? emergencyNumber;
    final uri = Uri(scheme: 'tel', path: number);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
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

  void _submitQuery(TriageController controller, [String? presetText]) {
    final queryText = presetText ?? _textController.text;
    if (queryText.trim().isEmpty) return;

    if (presetText != null) {
      _textController.text = presetText;
    }

    _focusNode.unfocus();
    _voiceService.stopListening();
    setState(() => _isListening = false);

    controller.submitEmergencyQuery(queryText);
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
              if (isFinal) _isListening = false;
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
      );
      if (mounted) {
        setState(() => _isListening = success);
      }
    }
  }

  void _showDeletePartialDialog(
      BuildContext context, TriageController controller) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete partial download?'),
        content: const Text(
            'This will delete the partially downloaded file and reset progress.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              controller.deletePartialDownload();
            },
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFE05A4F),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<TriageController>();
    final glass = Theme.of(context).extension<CarePulseGlass>()!;
    AppSettingsController? settingsController;
    try {
      settingsController = context.watch<AppSettingsController>();
    } catch (_) {}
    final settings = settingsController ?? AppSettingsController();

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          AppConstants.appName,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: glass.textPrimary,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: SizedBox(
              height: 48,
              child: TextButton.icon(
                onPressed: () => _callEmergency(settings.emergencyNumber),
                style: TextButton.styleFrom(
                  backgroundColor:
                      const Color(0xFFE05A4F).withValues(alpha: 0.18),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: const BorderSide(color: Color(0xFFE05A4F), width: 1),
                  ),
                ),
                icon:
                    const Icon(Icons.phone, color: Color(0xFFE05A4F), size: 16),
                label: Text(
                  'Call ${settings.emergencyNumber}',
                  style: const TextStyle(
                    color: Color(0xFFE05A4F),
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: GradientBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics()),
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Prominent Call Emergency Banner when red flag is triggered
                if (controller.callEmergencyNow) ...[
                  InkWell(
                    onTap: () => _callEmergency(settings.emergencyNumber),
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: glass.emergencyGradient,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color:
                                const Color(0xFFE05A4F).withValues(alpha: 0.5),
                            blurRadius: 20,
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
                                fontSize: 16,
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
                ],

                // Urgent First-Aid Query Input Box (Instant Red-Flag Path)
                GlassCard(
                  padding: const EdgeInsets.all(16),
                  borderRadius: 22,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.flash_on_rounded,
                              color: glass.accentMint, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Instant Red-Flag Emergency Triage',
                            style: TextStyle(
                              color: glass.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      EmergencyChips(
                        isDisabled: false,
                        onPresetSelected: (preset) =>
                            _submitQuery(controller, preset.query),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _textController,
                              focusNode: _focusNode,
                              style: TextStyle(
                                  color: glass.textPrimary, fontSize: 13),
                              decoration: InputDecoration(
                                hintText:
                                    'Describe urgent injury or symptom...',
                                hintStyle: TextStyle(
                                    color: glass.textSecondary, fontSize: 12),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16)),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 12),
                                suffixIcon: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (_textController.text.isNotEmpty)
                                      IconButton(
                                        icon: const Icon(Icons.clear_rounded,
                                            size: 16),
                                        onPressed: () {
                                          _textController.clear();
                                          setState(() {});
                                        },
                                      ),
                                    IconButton(
                                      icon: Icon(
                                          _isListening
                                              ? Icons.mic
                                              : Icons.mic_none,
                                          size: 20),
                                      color: _isListening
                                          ? const Color(0xFFE05A4F)
                                          : glass.accentMint,
                                      onPressed: _toggleListening,
                                    ),
                                  ],
                                ),
                              ),
                              onSubmitted: (_) => _submitQuery(controller),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 48,
                            height: 48,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                padding: EdgeInsets.zero,
                                backgroundColor: glass.accentMint,
                                foregroundColor: Colors.black87,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16)),
                              ),
                              onPressed: () => _submitQuery(controller),
                              child: const Icon(Icons.send_rounded, size: 18),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Response Card if query was submitted
                if (controller.streamedResponse.isNotEmpty ||
                    controller.currentQuery.isNotEmpty) ...[
                  StreamingResponseCard(
                    query: controller.currentQuery,
                    responseText: controller.streamedResponse,
                    isGenerating: false,
                    sourceLabel: controller.answerSource?.label,
                    onSpeak: () {
                      if (_isSpeaking) {
                        _tts.stop();
                      } else {
                        _tts.speak(controller.streamedResponse);
                      }
                    },
                    isSpeaking: _isSpeaking,
                    onStopSpeaking: () => _tts.stop(),
                    onClear: () {
                      _textController.clear();
                      _tts.stop();
                      controller.clearResponse();
                    },
                  ),
                  const SizedBox(height: 16),
                ],

                // AI Model Download Section
                GlassCard(
                  padding: const EdgeInsets.all(20.0),
                  borderRadius: 24,
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: glass.accentMint.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.cloud_download_rounded,
                          size: 36,
                          color: glass.accentMint,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Offline AI Model Setup',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: glass.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Download the offline AI model (${formatMb(AppConstants.modelSizeBytes)}) once while you have Wi-Fi. After this, CarePulse delivers personalized AI first-aid triage with zero internet.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: glass.textSecondary,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Progress Bar & Stats
                      if (controller.isDownloading ||
                          controller.isVerifying ||
                          controller.isLoadingEngine ||
                          (controller.isDownloadRequired &&
                              controller.partialBytes > 0)) ...[
                        Container(
                          height: 10,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.3)),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: LinearProgressIndicator(
                              value: (controller.isLoadingEngine ||
                                      controller.isVerifying)
                                  ? null
                                  : controller.downloadProgress,
                              backgroundColor: Colors.transparent,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  glass.accentMint),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              controller.isVerifying
                                  ? 'Verifying download...'
                                  : (controller.isLoadingEngine
                                      ? 'Initializing AI engine...'
                                      : (controller.isDownloading
                                          ? '${(controller.downloadProgress * 100).toStringAsFixed(1)}%'
                                          : 'Paused (${(controller.downloadProgress * 100).toStringAsFixed(1)}%)')),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: glass.accentMint,
                              ),
                            ),
                            Text(
                              '${formatMb(controller.downloadedBytes)} / ${formatMb(controller.totalBytes)}',
                              style: TextStyle(
                                  fontSize: 12, color: glass.textSecondary),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Error Banner
                      if (controller.hasError &&
                          controller.errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFFE05A4F).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFE05A4F)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline_rounded,
                                  color: Color(0xFFE05A4F), size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  controller.errorMessage!,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFFE05A4F),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Verifying Stage Indeterminate UI
                      if (controller.isVerifying)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: glass.accentMint,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Verifying download checksum...',
                                style: TextStyle(
                                  color: glass.accentMint,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        )
                      // Download / Pause / Resume / Delete Buttons (>= 48 tap target)
                      else if (controller.isDownloadRequired ||
                          controller.hasError) ...[
                        InkWell(
                          key: const ValueKey('model_download_primary_button'),
                          onTap: () => controller.startModelDownload(),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            height: 52,
                            decoration: BoxDecoration(
                              gradient: glass.primaryActionGradient,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  controller.partialBytes > 0
                                      ? Icons.play_arrow_rounded
                                      : Icons.download_rounded,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  controller.partialBytes > 0
                                      ? 'Resume download (${formatMb(controller.partialBytes)})'
                                      : 'Download Emergency AI Model',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (controller.partialBytes > 0) ...[
                          const SizedBox(height: 10),
                          SizedBox(
                            height: 48,
                            child: TextButton.icon(
                              key: const ValueKey(
                                  'delete_partial_download_button'),
                              onPressed: () =>
                                  _showDeletePartialDialog(context, controller),
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFFE05A4F),
                                minimumSize: const Size(48, 48),
                              ),
                              icon: const Icon(Icons.delete_outline_rounded,
                                  size: 18),
                              label: const Text('Delete partial download'),
                            ),
                          ),
                        ],
                      ] else if (controller.isDownloading)
                        InkWell(
                          key: const ValueKey('model_download_pause_button'),
                          onTap: () => controller.pauseModelDownload(),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            height: 52,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: glass.glassBorderColor),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.pause_circle_outline_rounded,
                                    color: glass.textPrimary),
                                const SizedBox(width: 8),
                                Text(
                                  'Pause Download',
                                  style: TextStyle(
                                    color: glass.textPrimary,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else if (controller.isLoadingEngine ||
                          controller.isChecking)
                        Center(
                          child: CircularProgressIndicator(
                              color: glass.accentMint),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
