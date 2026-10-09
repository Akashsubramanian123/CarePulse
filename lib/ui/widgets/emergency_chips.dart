import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import 'glass_card.dart';

class EmergencyChips extends StatelessWidget {
  final Function(EmergencyPreset preset) onPresetSelected;
  final bool isDisabled;

  const EmergencyChips({
    super.key,
    required this.onPresetSelected,
    this.isDisabled = false,
  });

  IconData _getPresetIcon(String iconName) {
    switch (iconName) {
      case 'water_drop':
        return Icons.water_drop_rounded;
      case 'local_fire_department':
        return Icons.local_fire_department_rounded;
      case 'air':
        return Icons.air_rounded;
      case 'wb_sunny':
        return Icons.wb_sunny_rounded;
      case 'warning_amber':
        return Icons.warning_amber_rounded;
      default:
        return Icons.medical_services_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final glass = Theme.of(context).extension<CarePulseGlass>()!;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.bolt_rounded, size: 16, color: glass.accentMint),
            const SizedBox(width: 4),
            Text(
              'QUICK EMERGENCY TRIGGERS',
              style: TextStyle(
                color: glass.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent: 84, // height ~84
          ),
          itemCount: emergencyPresets.length,
          itemBuilder: (context, index) {
            final preset = emergencyPresets[index];
            return Opacity(
              opacity: isDisabled ? 0.5 : 1.0,
              child: GlassCard(
                borderRadius: 24,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                onTap: isDisabled ? null : () => onPresetSelected(preset),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: glass.iconTintGradient,
                        border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
                      ),
                      child: Icon(
                        _getPresetIcon(preset.iconName),
                        size: 20,
                        color: glass.accentMint,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        preset.title,
                        style: TextStyle(
                          color: glass.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
