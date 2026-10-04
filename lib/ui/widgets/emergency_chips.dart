import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            Icon(Icons.bolt_rounded, size: 16, color: AppColors.tealAccent),
            SizedBox(width: 4),
            Text(
              'QUICK EMERGENCY TRIGGERS',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: emergencyPresets.map((preset) {
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: SizedBox(
                  height: 50,
                  child: ActionChip(
                    elevation: 0,
                    pressElevation: 2,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    avatar: Icon(
                      _getPresetIcon(preset.iconName),
                      size: 18,
                      color: isDisabled ? AppColors.textMuted : AppColors.tealPrimary,
                    ),
                    label: Text(
                      preset.title,
                      style: TextStyle(
                        color: isDisabled ? AppColors.textMuted : AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    backgroundColor: AppColors.darkSurfaceCard,
                    side: BorderSide(
                      color: isDisabled
                          ? AppColors.darkSurfaceBorder
                          : AppColors.tealPrimary.withValues(alpha: 0.5),
                      width: 1,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    onPressed: isDisabled ? null : () => onPresetSelected(preset),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

