import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';

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

  @override
  Widget build(BuildContext context) {
    if (query.isEmpty && responseText.isEmpty && !isGenerating) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.darkSurfaceCard.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.darkSurfaceBorder),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: AppColors.crimsonGlow,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.health_and_safety_rounded,
                size: 40,
                color: AppColors.crimsonLight,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Offline Emergency Triage Ready',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Select a quick preset above or type an emergency scenario below to receive instant 3-step action guidance.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ),
      );
    }

    return Card(
      elevation: 6,
      shadowColor: Colors.black45,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isGenerating ? AppColors.tealAccent : AppColors.darkSurfaceBorder,
          width: isGenerating ? 1.5 : 1,
        ),
      ),
      color: AppColors.darkSurfaceCard,
      child: Padding(
        padding: const EdgeInsets.all(18),
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
                        color: isGenerating
                            ? AppColors.tealPrimary.withValues(alpha: 0.2)
                            : AppColors.crimsonPrimary.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        isGenerating
                            ? Icons.psychology_rounded
                            : Icons.medical_information_rounded,
                        color: isGenerating ? AppColors.tealAccent : AppColors.crimsonLight,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      isGenerating ? 'GENERATING TRIAGE...' : 'EMERGENCY GUIDANCE',
                      style: TextStyle(
                        color: isGenerating ? AppColors.tealAccent : AppColors.textPrimary,
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
                      IconButton(
                        icon: const Icon(Icons.copy_rounded, size: 18),
                        color: AppColors.textSecondary,
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
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      color: AppColors.textSecondary,
                      tooltip: 'Clear',
                      onPressed: onClear,
                    ),
                  ],
                ),
              ],
            ),
            const Divider(color: AppColors.darkSurfaceBorder, height: 20),

            // User Emergency Query Box
            if (query.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.darkBackground.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.darkSurfaceBorder.withValues(alpha: 0.5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        size: 16, color: AppColors.warningAmber),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Query: "$query"',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Live Streamed Content
            if (responseText.isEmpty && isGenerating)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: AppColors.tealAccent,
                      ),
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Analyzing scenario & loading first-aid tokens...',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              )
            else
              SelectableText(
                responseText.isEmpty ? 'No response generated.' : responseText,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  height: 1.5,
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
                      decoration: const BoxDecoration(
                        color: AppColors.tealAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Streaming live tokens...',
                      style: TextStyle(
                        color: AppColors.tealAccent,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
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
