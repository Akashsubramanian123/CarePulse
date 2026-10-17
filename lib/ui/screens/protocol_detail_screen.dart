import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/emergency_config.dart';
import '../../core/theme/app_theme.dart';
import '../../models/protocol.dart';
import '../../services/tts_service.dart';
import '../widgets/glass_card.dart';

class ProtocolDetailScreen extends StatefulWidget {
  final Protocol protocol;

  const ProtocolDetailScreen({super.key, required this.protocol});

  @override
  State<ProtocolDetailScreen> createState() => _ProtocolDetailScreenState();
}

class _ProtocolDetailScreenState extends State<ProtocolDetailScreen> {
  final TtsService _tts = TtsService();
  bool _isSpeaking = false;

  @override
  void initState() {
    super.initState();
    _tts.isSpeakingNotifier.addListener(_onTtsStateChange);
  }

  void _onTtsStateChange() {
    if (mounted) {
      setState(() {
        _isSpeaking = _tts.isSpeakingNotifier.value;
      });
    }
  }

  @override
  void dispose() {
    _tts.isSpeakingNotifier.removeListener(_onTtsStateChange);
    _tts.stop();
    super.dispose();
  }

  Future<void> _callEmergency() async {
    final uri = Uri(scheme: 'tel', path: emergencyNumber);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Failed to open dialer. Please dial $emergencyNumber manually.')),
        );
      }
    }
  }

  void _toggleSpeak() {
    if (_isSpeaking) {
      _tts.stop();
    } else {
      final p = widget.protocol;
      final textToRead = '${p.title}. 1. Immediate Action: ${p.immediate}. '
          '2. Critical Precaution: ${p.precaution}. '
          '3. Monitor and Stabilize: ${p.monitor}. '
          '${p.doNot.isNotEmpty ? "Do not: ${p.doNot.join('. ')}" : ""}';
      _tts.speak(textToRead);
    }
  }

  @override
  Widget build(BuildContext context) {
    final glass = Theme.of(context).extension<CarePulseGlass>()!;
    final p = widget.protocol;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: 8.0),
          child: Center(
            child: SizedBox(
              width: 48,
              height: 48,
              child: IconButton(
                icon: Icon(Icons.arrow_back_rounded, color: glass.textPrimary),
                tooltip: 'Back',
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
        ),
        title: Text(
          p.title,
          style: TextStyle(
            color: glass.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          SizedBox(
            width: 48,
            height: 48,
            child: IconButton(
              icon: Icon(
                _isSpeaking
                    ? Icons.stop_circle_rounded
                    : Icons.volume_up_rounded,
                color: _isSpeaking ? const Color(0xFFE05A4F) : glass.accentMint,
              ),
              tooltip: _isSpeaking ? 'Stop reading' : 'Read aloud',
              onPressed: _toggleSpeak,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: GradientBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics()),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Call 112 Action Banner
                InkWell(
                  onTap: _callEmergency,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 14, horizontal: 16),
                    decoration: BoxDecoration(
                      gradient: p.callEmergency
                          ? glass.emergencyGradient
                          : glass.primaryActionGradient,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: (p.callEmergency
                                  ? const Color(0xFFE05A4F)
                                  : glass.accentMint)
                              .withValues(alpha: 0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.phone_in_talk_rounded,
                            color: Colors.white, size: 24),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            p.callEmergency
                                ? 'Call Emergency · $emergencyNumber Now'
                                : 'Call Help · $emergencyNumber',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Clinical Sources & Meta Card
                GlassCard(
                  padding: const EdgeInsets.all(14),
                  borderRadius: 18,
                  child: Row(
                    children: [
                      Icon(Icons.verified_rounded,
                          size: 20, color: glass.accentMint),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Verified sources: ${p.sources.join(', ')}',
                          style: TextStyle(
                            color: glass.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 3 Standard Emergency Steps
                _buildStepCard(
                    context, glass, '1', 'IMMEDIATE ACTION', p.immediate),
                const SizedBox(height: 12),
                _buildStepCard(
                    context, glass, '2', 'CRITICAL PRECAUTION', p.precaution),
                const SizedBox(height: 12),
                _buildStepCard(
                    context, glass, '3', 'MONITOR & STABILIZE', p.monitor),
                const SizedBox(height: 18),

                // "Do Not" Contraindications
                if (p.doNot.isNotEmpty) ...[
                  GlassCard(
                    padding: const EdgeInsets.all(16),
                    borderRadius: 20,
                    tint: const Color(0xFFE05A4F).withValues(alpha: 0.15),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.block_rounded,
                                color: Color(0xFFE05A4F), size: 22),
                            SizedBox(width: 8),
                            Text(
                              'DO NOT',
                              style: TextStyle(
                                color: Color(0xFFE05A4F),
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        for (final item in p.doNot)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('• ',
                                    style: TextStyle(
                                        color: Color(0xFFE05A4F),
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold)),
                                Expanded(
                                  child: Text(
                                    item,
                                    style: TextStyle(
                                      color: glass.textPrimary,
                                      fontSize: 14,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                ],

                // Disclaimer
                Center(
                  child: Text(
                    'CarePulse first-aid guidance is conservative and informational.\nAlways consult professional medical emergency services.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: glass.textSecondary,
                      fontSize: 11,
                    ),
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

  Widget _buildStepCard(BuildContext context, CarePulseGlass glass,
      String number, String label, String text) {
    return GlassCard(
      borderRadius: 20,
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: glass.primaryActionGradient,
              shape: BoxShape.circle,
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.4), width: 1),
            ),
            alignment: Alignment.center,
            child: Text(
              number,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: glass.accentMint,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  text,
                  style: TextStyle(
                    color: glass.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
