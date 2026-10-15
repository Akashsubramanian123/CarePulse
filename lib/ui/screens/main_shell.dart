import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../services/tts_service.dart';
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

  @override
  Widget build(BuildContext context) {
    final glass = Theme.of(context).extension<CarePulseGlass>()!;

    return Scaffold(
      extendBody: true,
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
