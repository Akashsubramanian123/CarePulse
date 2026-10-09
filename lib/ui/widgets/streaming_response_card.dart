import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';
import 'glass_card.dart';

class StreamingResponseCard extends StatelessWidget {
  final String query;
  final String responseText;
  final bool isGenerating;
  final VoidCallback onClear;

  const StreamingResponseCard({
    super.key,
    required this.query,
    required this.responseText,
    required this.isGenerating,
    required this.onClear,
  });

  List<String>? _parseSteps(String text) {
    if (isGenerating) return null; // Wait until stream is done to parse cleanly
    
    // Attempt basic parsing of "1. ... 2. ... 3. ..."
    final parts = text.split(RegExp(r'\n?[123]\.\s+'));
    // Usually parts[0] is empty or intro text. The steps should be parts 1, 2, 3
    if (parts.length >= 4) {
      return [
        parts[1].trim(),
        parts[2].trim(),
        parts[3].trim(),
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
                border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
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
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      gradient: glass.iconTintGradient,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
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
                  Text(
                    isGenerating ? 'PREPARING GUIDANCE...' : 'EMERGENCY GUIDANCE',
                    style: TextStyle(
                      color: isGenerating ? glass.accentMint : glass.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
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
                              content: Text('Triage response copied to clipboard'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                    ),
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
          const SizedBox(height: 12),
          Container(height: 1, color: glass.glassBorderColor),
          const SizedBox(height: 16),

          // User Emergency Query Box
          if (query.isNotEmpty)
            GlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              borderRadius: 16,
              tint: glass.textSecondary.withOpacity(0.1),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, size: 16, color: glass.textSecondary),
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
                _buildStepCard(context, glass, '1', 'IMMEDIATE ACTION', parsedSteps[0]),
                const SizedBox(height: 12),
                _buildStepCard(context, glass, '2', 'CRITICAL PRECAUTION', parsedSteps[1]),
                const SizedBox(height: 12),
                _buildStepCard(context, glass, '3', 'MONITOR & STABILIZE', parsedSteps[2]),
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
            "First-aid guidance only. Call emergency services for serious situations.",
            style: TextStyle(
              color: glass.textSecondary,
              fontSize: 11,
            ),
            textAlign: TextAlign.center,
          )
        ],
      ),
    );
  }

  Widget _buildStepCard(BuildContext context, CarePulseGlass glass, String number, String label, String text) {
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
              border: Border.all(color: Colors.white.withOpacity(0.4), width: 1),
            ),
            alignment: Alignment.center,
            child: Text(
              number,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
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
