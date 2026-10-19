import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/emergency_config.dart';
import '../../core/theme/app_theme.dart';
import '../../services/tts_service.dart';
import '../../state/app_settings_controller.dart';
import '../../state/theme_controller.dart';
import '../widgets/glass_card.dart';
import '../widgets/settings_sheet.dart';
import 'cpr_screen.dart';
import 'emergency_home_screen.dart';
import 'guides_screen.dart';
import 'sos_screen.dart';

class MainShell extends StatefulWidget {
  final int initialIndex;

  const MainShell({super.key, this.initialIndex = 0});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  void _onTabSelected(int index) {
    if (_currentIndex != index) {
      // Stop speech on tab change
      TtsService().stop();
      setState(() {
        _currentIndex = index;
      });
    }
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

  IconData _getThemeIcon(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return Icons.light_mode_rounded;
      case ThemeMode.dark:
        return Icons.dark_mode_rounded;
      case ThemeMode.system:
        return Icons.brightness_auto_rounded;
    }
  }

  String _getScreenTitle(int index) {
    switch (index) {
      case 0:
        return 'CarePulse';
      case 1:
        return 'First-Aid Guides';
      case 2:
        return 'CPR Metronome';
      case 3:
        return 'Emergency SOS';
      default:
        return 'CarePulse';
    }
  }

  @override
  Widget build(BuildContext context) {
    final glass = Theme.of(context).extension<CarePulseGlass>()!;

    AppSettingsController? settingsCtrl;
    try {
      settingsCtrl = context.watch<AppSettingsController>();
    } catch (_) {
      settingsCtrl = null;
    }

    ThemeController? themeCtrl;
    try {
      themeCtrl = context.watch<ThemeController>();
    } catch (_) {
      themeCtrl = null;
    }

    final currentMode =
        settingsCtrl?.themeMode ?? themeCtrl?.themeMode ?? ThemeMode.system;
    final emergencyNum = settingsCtrl?.emergencyNumber ?? emergencyNumber;

    return NotificationListener<TabSwitchNotification>(
      onNotification: (notification) {
        _onTabSelected(notification.tabIndex);
        return true;
      },
      child: GlassScaffold(
        topBar: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              // Screen Title
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _getScreenTitle(_currentIndex),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: glass.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                    ),
                  ),
                ),
              ),
              // Theme toggle IconButton (48x48)
              SizedBox(
                width: 48,
                height: 48,
                child: IconButton(
                  key: const ValueKey('quick_theme_toggle_button'),
                  tooltip: 'Cycle theme: light -> dark -> system',
                  icon: Icon(
                    _getThemeIcon(currentMode),
                    color: glass.accentMint,
                    size: 22,
                  ),
                  onPressed: () {
                    if (settingsCtrl != null) {
                      settingsCtrl.cycleTheme();
                    } else {
                      themeCtrl?.cycleTheme();
                    }
                  },
                ),
              ),
              // Settings gear IconButton (48x48)
              SizedBox(
                width: 48,
                height: 48,
                child: IconButton(
                  key: const ValueKey('main_shell_settings_button'),
                  tooltip: 'Settings',
                  icon: Icon(
                    Icons.settings_outlined,
                    color: glass.accentMint,
                    size: 22,
                  ),
                  onPressed: () => showCarePulseSettingsSheet(context),
                ),
              ),
              const SizedBox(width: 4),
              // Compact Call pill (height 40, tap area >= 48, emergency gradient, white bold text)
              SizedBox(
                key: const ValueKey('main_shell_call_112_button'),
                height: 48,
                child: Center(
                  child: InkWell(
                    key: const Key('topbar_call'),
                    onTap: () => _callEmergency(emergencyNum),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      height: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        gradient: glass.emergencyGradient,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color:
                                const Color(0xFFC7382E).withValues(alpha: 0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.phone,
                              color: Colors.white, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            'Call $emergencyNum',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        body: IndexedStack(
          index: _currentIndex,
          children: const [
            AssistantTabRouter(),
            GuidesScreen(),
            CprScreen(),
            SosScreen(),
          ],
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF0F1E2A).withValues(alpha: 0.85)
                : Colors.white.withValues(alpha: 0.85),
            border: Border(
              top: BorderSide(
                color: glass.glassBorderColor,
                width: 0.8,
              ),
            ),
          ),
          child: NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: _onTabSelected,
            backgroundColor: Colors.transparent,
            elevation: 0,
            indicatorColor: glass.accentMint.withValues(alpha: 0.25),
            destinations: [
              NavigationDestination(
                icon: Icon(Icons.health_and_safety_outlined,
                    color: glass.textSecondary),
                selectedIcon: Icon(Icons.health_and_safety_rounded,
                    color: glass.accentMint),
                label: 'Assistant',
              ),
              NavigationDestination(
                icon:
                    Icon(Icons.menu_book_outlined, color: glass.textSecondary),
                selectedIcon:
                    Icon(Icons.menu_book_rounded, color: glass.accentMint),
                label: 'Guides',
              ),
              NavigationDestination(
                icon: Icon(Icons.favorite_outline_rounded,
                    color: glass.textSecondary),
                selectedIcon: Icon(Icons.favorite_rounded,
                    color: const Color(0xFFC7382E)),
                label: 'CPR',
              ),
              NavigationDestination(
                icon:
                    Icon(Icons.emergency_outlined, color: glass.textSecondary),
                selectedIcon: Icon(Icons.emergency_rounded,
                    color: const Color(0xFFC7382E)),
                label: 'SOS',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TabSwitchNotification extends Notification {
  final int tabIndex;
  const TabSwitchNotification(this.tabIndex);
}

class AssistantTabRouter extends StatelessWidget {
  const AssistantTabRouter({super.key});

  @override
  Widget build(BuildContext context) {
    return const EmergencyHomeScreen();
  }
}
