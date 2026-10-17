import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';
import 'glass_card.dart';

class StreamingResponseCard extends StatelessWidget {
  final String query;
  final String responseText;
  final bool isGenerating;
  final VoidCallback? onClear;
  final String? sourceLabel;
  final VoidCallback? onSpeak;
  final bool isSpeaking;
  final VoidCallback? onStopSpeaking;
  final bool wasStopped;
  final String? clarificationNote;

  const StreamingResponseCard({
    super.key,
    required this.query,
    required this.responseText,
    required this.isGenerating,
    this.onClear,
    this.sourceLabel,
    this.onSpeak,
    this.isSpeaking = false,
    this.onStopSpeaking,
    this.wasStopped = false,
    this.clarificationNote,
  });

  List<String>? _parseSteps(String text) {
    if (isGenerating) return null; // Wait until stream is done to parse cleanly

    // Attempt basic parsing of "1. ... 2. ... 3. ..."
    final parts = text.split(RegExp(r'\n?[123]\.\s+'));
    // Usually parts[0] is empty or intro text. The steps should be parts 1, 2, 3
    if (parts.length >= 4) {
      String step1 = parts[1].trim();
      String step2 = parts[2].trim();
      String step3 = parts[3].trim();

      step1 = step1.replaceFirst(
          RegExp(r'^(IMMEDIATE ACTION:?|IMMEDIATE:?)\s*', caseSensitive: false),
          '');
      step2 = step2.replaceFirst(
          RegExp(r'^(CRITICAL PRECAUTION:?|PRECAUTION:?)\s*',
              caseSensitive: false),
          '');
      step3 = step3.replaceFirst(
          RegExp(r'^(MONITOR & STABILIZE:?|MONITOR:?)\s*',
              caseSensitive: false),
          '');

      return [
        step1.trim(),
        step2.trim(),
        step3.trim(),
      ];
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final glass = Theme.of(context).extension<CarePulseGlass>()!;

    if (query.isEmpty && responseText.isEmpty && !isGenerating) {
      return GlassCard(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: glass.iconTintGradient,
                shape: BoxShape.circle,
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3), width: 1),
              ),
              child: Icon(
                Icons.health_and_safety_rounded,
                size: 40,
                color: glass.accentMint,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Ready to help, even offline',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: glass.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Select a quick preset above or type an emergency scenario below to receive instant 3-step action guidance.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: glass.textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ),
      );
    }

    final parsedSteps = _parseSteps(responseText);

    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        gradient: glass.iconTintGradient,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.3),
                            width: 1),
                      ),
                      child: Icon(
                        isGenerating
                            ? Icons.psychology_rounded
                            : Icons.medical_information_rounded,
                        color: glass.accentMint,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        isGenerating
                            ? 'PREPARING GUIDANCE...'
                            : 'EMERGENCY GUIDANCE',
                        style: TextStyle(
                          color: isGenerating
                              ? glass.accentMint
                              : glass.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Text-to-speech button
                  if (onSpeak != null && responseText.isNotEmpty)
                    SizedBox(
                      width: 48,
                      height: 48,
                      child: IconButton(
                        icon: Icon(
                          isSpeaking
                              ? Icons.stop_circle_rounded
                              : Icons.volume_up_rounded,
                          size: 22,
                        ),
                        color: isSpeaking
                            ? const Color(0xFFE05A4F)
                            : glass.accentMint,
                        tooltip:
                            isSpeaking ? 'Stop reading' : 'Read guidance aloud',
                        onPressed:
                            isSpeaking ? (onStopSpeaking ?? onSpeak) : onSpeak,
                      ),
                    ),
                  if (responseText.isNotEmpty)
                    SizedBox(
                      width: 48,
                      height: 48,
                      child: IconButton(
                        icon: const Icon(Icons.copy_rounded, size: 18),
                        color: glass.textSecondary,
                        tooltip: 'Copy Guidance',
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: responseText));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content:
                                  Text('Triage response copied to clipboard'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                    ),
                  if (onClear != null)
                    SizedBox(
                      width: 48,
                      height: 48,
                      child: IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        color: glass.textSecondary,
                        tooltip: 'Clear',
                        onPressed: onClear,
                      ),
                    ),
                ],
              ),
            ],
          ),

          // Source Chip
          if (sourceLabel != null && responseText.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: glass.accentMint.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: glass.accentMint.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    sourceLabel!.contains('Verified')
                        ? Icons.verified_user_rounded
                        : (sourceLabel!.contains('guided')
                            ? Icons.auto_awesome_rounded
                            : Icons.info_outline_rounded),
                    size: 14,
                    color: glass.accentMint,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      sourceLabel!,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: glass.accentMint,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Quiet Stopped Indicator Note
          if (wasStopped) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: glass.textSecondary.withValues(alpha: 0.25)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.stop_rounded,
                    size: 13,
                    color: glass.textSecondary,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'Stopped',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: glass.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Clarification emergency escalation note
          if (clarificationNote != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFE05A4F).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFFE05A4F).withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded,
                      size: 14, color: Color(0xFFE05A4F)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      clarificationNote!,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFE05A4F),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 12),
          Container(height: 1, color: glass.glassBorderColor),
          const SizedBox(height: 16),

          // User Emergency Query Box
          if (query.isNotEmpty)
            GlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              borderRadius: 16,
              tint: glass.textSecondary.withValues(alpha: 0.1),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      size: 16, color: glass.textSecondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Query: "$query"',
                      style: TextStyle(
                        color: glass.textSecondary,
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 16),

          // Live Streamed Content
          if (responseText.isEmpty && isGenerating)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
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
                    'Preparing guidance...',
                    style: TextStyle(
                      color: glass.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            )
          else if (parsedSteps != null)
            Column(
              children: [
                _buildStepCard(
                    context, glass, '1', 'IMMEDIATE ACTION', parsedSteps[0]),
                const SizedBox(height: 12),
                _buildStepCard(
                    context, glass, '2', 'CRITICAL PRECAUTION', parsedSteps[1]),
                const SizedBox(height: 12),
                _buildStepCard(
                    context, glass, '3', 'MONITOR & STABILIZE', parsedSteps[2]),
              ],
            )
          else
            SelectableText(
              responseText.isEmpty ? 'No response generated.' : responseText,
              style: TextStyle(
                color: glass.textPrimary,
                fontSize: 18,
                height: 1.6,
                fontWeight: FontWeight.w400,
              ),
            ),

          if (isGenerating && responseText.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: glass.accentMint,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Preparing guidance...',
                    style: TextStyle(
                      color: glass.accentMint,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 24),
          Text(
            'First-aid guidance only. Call emergency services for serious situations.',
            style: TextStyle(
              color: glass.textSecondary,
              fontSize: 11,
            ),
            textAlign: TextAlign.center,
          ),
        ],
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
                    fontSize: 18,
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
