import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class TelemetryBar extends StatelessWidget {
  final int ttftMs;
  final double tokensPerSec;
  final double ramUsageMb;
  final bool isOffline;
  final bool isGenerating;

  const TelemetryBar({
    super.key,
    required this.ttftMs,
    required this.tokensPerSec,
    required this.ramUsageMb,
    required this.isOffline,
    required this.isGenerating,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.darkSurface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.darkSurfaceBorder),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(0, 4),
          )
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Offline Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isOffline
                    ? AppColors.tealPrimary.withValues(alpha: 0.2)
                    : AppColors.crimsonPrimary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isOffline ? AppColors.tealAccent : AppColors.crimsonLight,
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isOffline ? AppColors.tealAccent : AppColors.crimsonLight,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isOffline ? 'OFFLINE ACTIVE' : 'ONLINE',
                    style: TextStyle(
                      color: isOffline ? AppColors.tealLight : AppColors.crimsonLight,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // TTFT Metric
            _TelemetryPill(
              icon: Icons.timer_outlined,
              label: 'TTFT',
              value: ttftMs > 0 ? '$ttftMs ms' : '-- ms',
              color: isGenerating ? AppColors.warningAmber : AppColors.textSecondary,
            ),
            const SizedBox(width: 8),

            // Tok/s Metric
            _TelemetryPill(
              icon: Icons.speed_rounded,
              label: 'Speed',
              value: tokensPerSec > 0
                  ? '${tokensPerSec.toStringAsFixed(1)} tok/s'
                  : '-- tok/s',
              color: tokensPerSec > 0 ? AppColors.tealAccent : AppColors.textSecondary,
            ),
            const SizedBox(width: 8),

            // RAM Metric
            _TelemetryPill(
              icon: Icons.memory_rounded,
              label: 'RAM',
              value: ramUsageMb > 0
                  ? '${ramUsageMb.toStringAsFixed(0)} MB'
                  : '-- MB',
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _TelemetryPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _TelemetryPill({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.darkSurfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.darkSurfaceBorder.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            '$label: ',
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
