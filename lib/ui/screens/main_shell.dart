import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/emergency_config.dart';
import '../../core/theme/app_theme.dart';
import '../../services/tts_service.dart';
import '../../state/theme_controller.dart';
import '../../state/triage_controller.dart';
import 'cpr_screen.dart';
import 'emergency_home_screen.dart';
import 'guides_screen.dart';
import 'model_setup_screen.dart';
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
                'Failed to open dialer. Please dial $emergencyNumber manually.'),
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

  @override
  Widget build(BuildContext context) {
    final glass = Theme.of(context).extension<CarePulseGlass>()!;

    ThemeController? themeCtrl;
    try {
      themeCtrl = context.watch<ThemeController>();
    } catch (_) {
      themeCtrl = null;
    }

    final currentMode = themeCtrl?.themeMode ?? ThemeMode.system;

    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          // Quick theme toggle button (sun/moon) cycling light -> dark -> system
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
                themeCtrl?.cycleTheme();
              },
            ),
          ),
          const SizedBox(width: 4),
          // Small reachable Call 112 action button
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: SizedBox(
              height: 48,
              child: TextButton.icon(
                key: const ValueKey('main_shell_call_112_button'),
                onPressed: _callEmergency,
                style: TextButton.styleFrom(
                  backgroundColor:
                      const Color(0xFFE05A4F).withValues(alpha: 0.18),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: const BorderSide(color: Color(0xFFE05A4F), width: 1),
                  ),
                ),
                icon:
                    const Icon(Icons.phone, color: Color(0xFFE05A4F), size: 16),
                label: const Text(
                  '112',
                  style: TextStyle(
                    color: Color(0xFFE05A4F),
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
        ],
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
              ? const Color(0xFF121A22).withValues(alpha: 0.85)
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
              icon: Icon(Icons.menu_book_outlined, color: glass.textSecondary),
              selectedIcon:
                  Icon(Icons.menu_book_rounded, color: glass.accentMint),
              label: 'Guides',
            ),
            NavigationDestination(
              icon: Icon(Icons.favorite_outline_rounded,
                  color: glass.textSecondary),
              selectedIcon:
                  Icon(Icons.favorite_rounded, color: const Color(0xFFE05A4F)),
              label: 'CPR',
            ),
            NavigationDestination(
              icon: Icon(Icons.emergency_outlined, color: glass.textSecondary),
              selectedIcon:
                  Icon(Icons.emergency_rounded, color: const Color(0xFFE05A4F)),
              label: 'SOS',
            ),
          ],
        ),
      ),
    );
  }
}

class AssistantTabRouter extends StatelessWidget {
  const AssistantTabRouter({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<TriageController>();

    if (controller.isReady) {
      return const EmergencyHomeScreen();
    } else {
      return const ModelSetupScreen();
    }
  }
}
