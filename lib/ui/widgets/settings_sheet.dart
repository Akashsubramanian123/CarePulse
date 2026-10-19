import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/emergency_config.dart';
import '../../core/theme/app_theme.dart';
import '../../state/app_settings_controller.dart';
import '../../state/theme_controller.dart';
import '../screens/benchmark_screen.dart';
import '../screens/history_screen.dart';
import '../screens/medical_id_screen.dart';
import '../screens/profile_screen.dart';

void showCarePulseSettingsSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) {
      return const _SettingsSheetContent();
    },
  );
}

class _SettingsSheetContent extends StatefulWidget {
  const _SettingsSheetContent();

  @override
  State<_SettingsSheetContent> createState() => _SettingsSheetContentState();
}

class _SettingsSheetContentState extends State<_SettingsSheetContent> {
  bool _autoReadAloud = false;

  @override
  void initState() {
    super.initState();
    _loadAutoReadAloud();
  }

  Future<void> _loadAutoReadAloud() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _autoReadAloud = prefs.getBool('carepulse_auto_read_aloud') ?? false;
      });
    }
  }

  Future<void> _saveAutoReadAloud(bool val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('carepulse_auto_read_aloud', val);
    if (mounted) {
      setState(() {
        _autoReadAloud = val;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final glass = theme.extension<CarePulseGlass>()!;
    final isDark = theme.brightness == Brightness.dark;

    AppSettingsController? settingsController;
    try {
      settingsController = context.watch<AppSettingsController?>();
    } catch (_) {}
    if (settingsController == null) {
      try {
        settingsController = Provider.of<AppSettingsController?>(context);
      } catch (_) {}
    }
    if (settingsController == null) {
      try {
        settingsController = context.watch<ThemeController?>();
      } catch (_) {}
    }
    if (settingsController == null) {
      try {
        settingsController = Provider.of<ThemeController?>(context);
      } catch (_) {}
    }

    final currentSettings = settingsController ?? AppSettingsController();
    final surfaceColor = isDark ? const Color(0xFF1B242D) : Colors.white;
    final onSurface =
        isDark ? const Color(0xFFF1F7FA) : const Color(0xFF1F2933);
    final onSurfaceVariant =
        isDark ? const Color(0xFFB5C3CA) : const Color(0xFF52606D);

    return Material(
      color: surfaceColor,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Settings & About',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: IconButton(
                      icon: Icon(Icons.close_rounded, color: onSurface),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Theme section
              Text(
                'Theme',
                style: TextStyle(
                  color: onSurface,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<ThemeMode>(
                  key: const ValueKey('settings_theme_segmented_button'),
                  segments: const [
                    ButtonSegment<ThemeMode>(
                      value: ThemeMode.system,
                      icon: Icon(Icons.brightness_auto_rounded, size: 18),
                      label: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('System'),
                      ),
                    ),
                    ButtonSegment<ThemeMode>(
                      value: ThemeMode.light,
                      icon: Icon(Icons.light_mode_rounded, size: 18),
                      label: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('Light'),
                      ),
                    ),
                    ButtonSegment<ThemeMode>(
                      value: ThemeMode.dark,
                      icon: Icon(Icons.dark_mode_rounded, size: 18),
                      label: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('Dark'),
                      ),
                    ),
                  ],
                  selected: {currentSettings.themeMode},
                  onSelectionChanged: (Set<ThemeMode> newSelection) {
                    if (newSelection.isNotEmpty) {
                      settingsController?.setThemeMode(newSelection.first);
                      setState(() {});
                    }
                  },
                  style: ButtonStyle(
                    minimumSize: WidgetStateProperty.all(const Size(0, 48)),
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.padded,
                    backgroundColor: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.selected)) {
                        return glass.accentMint
                            .withValues(alpha: isDark ? 0.35 : 0.22);
                      }
                      return Colors.transparent;
                    }),
                    foregroundColor: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.selected)) {
                        return isDark
                            ? const Color(0xFF9FF0E3)
                            : glass.accentMint;
                      }
                      return onSurface;
                    }),
                    iconColor: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.selected)) {
                        return isDark
                            ? const Color(0xFF9FF0E3)
                            : glass.accentMint;
                      }
                      return onSurfaceVariant;
                    }),
                    side: WidgetStateProperty.all(
                      BorderSide(color: glass.glassBorderColor, width: 1.0),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Emergency Number Section
              Text(
                'Emergency Number',
                style: TextStyle(
                  color: onSurface,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: currentSettings.selectedCountry,
                dropdownColor: surfaceColor,
                borderRadius: BorderRadius.circular(16),
                elevation: 8,
                menuMaxHeight: 320,
                isExpanded: true,
                style: TextStyle(
                  color: onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  labelText: 'Region / Country',
                  labelStyle: TextStyle(color: onSurfaceVariant),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
                selectedItemBuilder: (context) {
                  return [
                    ...emergencyCountries.map(
                      (c) => Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '${c.name} (${c.number})',
                          style: TextStyle(color: onSurface),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Other / custom',
                        style: TextStyle(color: onSurface),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ];
                },
                items: [
                  ...emergencyCountries.map(
                    (c) => DropdownMenuItem(
                      value: c.name,
                      child: Text(
                        '${c.name} (${c.number})',
                        style: TextStyle(color: onSurface),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  DropdownMenuItem(
                    value: customCountryName,
                    child: Text(
                      'Other / custom',
                      style: TextStyle(color: onSurface),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
                onChanged: (newCountry) {
                  if (newCountry != null) {
                    settingsController?.setCountry(newCountry);
                    setState(() {});
                  }
                },
              ),
              if (currentSettings.selectedCountry == customCountryName) ...[
                const SizedBox(height: 10),
                TextFormField(
                  initialValue: currentSettings.emergencyNumber,
                  style: TextStyle(color: onSurface),
                  decoration: InputDecoration(
                    labelText: 'Custom Emergency Number',
                    labelStyle: TextStyle(color: onSurfaceVariant),
                    hintText: 'e.g. 911 or 112',
                    hintStyle: TextStyle(
                        color: onSurfaceVariant.withValues(alpha: 0.6)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                  ),
                  keyboardType: TextInputType.number,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  validator: (val) {
                    if (val == null || !isValidCustomEmergencyNumber(val)) {
                      return 'Digits only (2 to 6 digits)';
                    }
                    return null;
                  },
                  onChanged: (val) {
                    if (isValidCustomEmergencyNumber(val)) {
                      settingsController?.setEmergencyNumber(val,
                          country: customCountryName);
                    }
                  },
                ),
              ],
              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 8),

              // Switch 1: History
              SwitchListTile(
                title: Text(
                  'Save query history',
                  style: TextStyle(
                    color: onSurface,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  'Keep first-aid queries on this device',
                  style: TextStyle(
                    color: onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
                value: currentSettings.saveHistory,
                activeThumbColor: glass.accentMint,
                contentPadding: EdgeInsets.zero,
                onChanged: (val) {
                  settingsController?.setSaveHistory(val);
                  setState(() {});
                },
              ),

              // Switch 2: Auto Read Aloud
              SwitchListTile(
                title: Text(
                  'Read answers aloud automatically',
                  style: TextStyle(
                    color: onSurface,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  'Speaks out emergency steps as soon as generated',
                  style: TextStyle(
                    color: onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
                value: _autoReadAloud,
                activeThumbColor: glass.accentMint,
                contentPadding: EdgeInsets.zero,
                onChanged: (val) {
                  setState(() => _autoReadAloud = val);
                  _saveAutoReadAloud(val);
                },
              ),
              const Divider(height: 24),

              // Profile section
              Text(
                'Profile',
                style: TextStyle(
                  color: onSurface,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                key: const Key('settings_medical_profile_tile'),
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.account_circle_outlined,
                    color: glass.accentMint),
                title: Text(
                  'Medical profile (used by the AI)',
                  style: TextStyle(
                    color: onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  'Personal conditions, medications, age & allergies',
                  style: TextStyle(
                    color: onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
                trailing:
                    Icon(Icons.chevron_right_rounded, color: onSurfaceVariant),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ProfileScreen(),
                    ),
                  );
                },
              ),
              ListTile(
                key: const Key('settings_medical_id_tile'),
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.badge_outlined, color: glass.accentMint),
                title: Text(
                  'Medical ID (for first responders and SOS)',
                  style: TextStyle(
                    color: onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  'Emergency card with blood group, allergies, emergency contacts',
                  style: TextStyle(
                    color: onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
                trailing:
                    Icon(Icons.chevron_right_rounded, color: onSurfaceVariant),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const MedicalIdScreen(),
                    ),
                  );
                },
              ),
              const Divider(height: 24),

              // Navigation tiles
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.history_rounded, color: glass.accentMint),
                title: Text(
                  'Query History',
                  style: TextStyle(
                    color: onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  'Review past consultations',
                  style: TextStyle(
                    color: onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
                trailing:
                    Icon(Icons.chevron_right_rounded, color: onSurfaceVariant),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const HistoryScreen(),
                    ),
                  );
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading:
                    Icon(Icons.assessment_outlined, color: glass.accentMint),
                title: Text(
                  'Benchmark & Evaluation',
                  style: TextStyle(
                    color: onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  'Evaluate models & protocol accuracy',
                  style: TextStyle(
                    color: onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
                trailing:
                    Icon(Icons.chevron_right_rounded, color: onSurfaceVariant),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const BenchmarkScreen(),
                    ),
                  );
                },
              ),
              const Divider(height: 24),

              // About CarePulse
              Text(
                'About CarePulse',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'CarePulse provides first-aid guidance only and is not a substitute for professional medical care. In a serious emergency, call your local emergency number (${currentSettings.emergencyNumber}).',
                style: TextStyle(
                  color: onSurfaceVariant,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
