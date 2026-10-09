import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import 'glass_card.dart';

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
    this.isGenerating = false,
  });

  @override
  Widget build(BuildContext context) {
    final glass = Theme.of(context).extension<CarePulseGlass>()!;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildMetricItem(
          context,
          glass,
          icon: Icons.speed_rounded,
          label: 'Speed',
          value: isGenerating ? '${tokensPerSec.toStringAsFixed(1)} t/s' : '--',
        ),
        _buildMetricItem(
          context,
          glass,
          icon: Icons.memory_rounded,
          label: 'RAM',
          value: ramUsageMb > 0 ? '${ramUsageMb.toStringAsFixed(0)} MB' : '--',
        ),
        _buildMetricItem(
          context,
          glass,
          icon: Icons.timer_rounded,
          label: 'TTFT',
          value: ttftMs > 0 ? '${ttftMs}ms' : '--',
        ),
      ],
    );
  }

  Widget _buildMetricItem(BuildContext context, CarePulseGlass glass, {required IconData icon, required String label, required String value}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: glass.textSecondary),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: glass.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: glass.textSecondary,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
