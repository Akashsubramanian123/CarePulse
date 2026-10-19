import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../services/medical_id_store.dart';
import '../../services/profile_service.dart';
import '../../state/triage_controller.dart';
import '../widgets/glass_card.dart';
import 'quick_profile_screen.dart';

class WalkthroughScreen extends StatefulWidget {
  final SharedPreferences? prefs;
  final MedicalIdStore? medicalIdStore;
  final ProfileService? profileService;
  final TriageController? triageController;

  const WalkthroughScreen({
    super.key,
    this.prefs,
    this.medicalIdStore,
    this.profileService,
    this.triageController,
  });

  @override
  State<WalkthroughScreen> createState() => _WalkthroughScreenState();
}

class _WalkthroughScreenState extends State<WalkthroughScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  static const int _totalSlides = 6;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _markSeenAndClose() async {
    final prefs = widget.prefs ?? await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_v2_seen', true);
    if (mounted) {
      Navigator.pop(context);
    }
  }

  void _nextPage() {
    if (_currentPage < _totalSlides - 1) {
      _goToPage(_currentPage + 1);
    } else {
      _markSeenAndClose();
    }
  }

  void _prevPage() {
    if (_currentPage > 0) {
      _goToPage(_currentPage - 1);
    }
  }

  void _goToPage(int page) {
    final disableAnimations =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (disableAnimations) {
      _pageController.jumpToPage(page);
    } else {
      _pageController.animateToPage(
        page,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _openQuickProfile() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuickProfileScreen(
          medicalIdStore: widget.medicalIdStore,
          profileService: widget.profileService,
        ),
      ),
    );
    // After returning, advance to the final slide (AI model)
    if (mounted) {
      _goToPage(5);
    }
  }

  @override
  Widget build(BuildContext context) {
    final glass = Theme.of(context).extension<CarePulseGlass>()!;
    TriageController? triage = widget.triageController;
    if (triage == null) {
      try {
        triage = Provider.of<TriageController?>(context);
      } catch (_) {
        try {
          triage = Provider.of<TriageController>(context);
        } catch (_) {}
      }
    }
    final modelSize = (triage != null && triage.totalMB > 0)
        ? '${triage.totalMB.toInt()}MB'
        : '${AppConstants.estimatedModelSizeMb.toInt()}MB';

    return PopScope(
      onPopInvokedWithResult: (didPop, result) async {
        final prefs = widget.prefs ?? await SharedPreferences.getInstance();
        await prefs.setBool('onboarding_v2_seen', true);
      },
      child: GlassScaffold(
        title: 'CarePulse Tour',
        actions: [
          Semantics(
            label: 'Skip walkthrough',
            button: true,
            child: TextButton(
              key: const Key('walkthrough_skip_button'),
              onPressed: _markSeenAndClose,
              child: Text(
                'Skip',
                style: TextStyle(
                  color: glass.textSecondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
        body: Column(
          children: [
            // Slide views
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (page) => setState(() => _currentPage = page),
                physics: const BouncingScrollPhysics(),
                children: [
                  // Slide 1: Welcome
                  _buildSlide(
                    glass: glass,
                    icon: Icons.health_and_safety_rounded,
                    title: 'First aid that works offline',
                    subtitle:
                        'Emergency rules, guides, CPR metronome, and SOS need no internet.',
                    pageIndex: 0,
                  ),
                  // Slide 2: Assistant
                  _buildSlide(
                    glass: glass,
                    icon: Icons.chat_bubble_outline_rounded,
                    title: 'Instant Emergency Assistant',
                    subtitle:
                        'Describe what\'s happening or tap a quick trigger. Use the mic to speak.',
                    pageIndex: 1,
                  ),
                  // Slide 3: Guides and CPR
                  _buildSlide(
                    glass: glass,
                    icon: Icons.favorite_rounded,
                    title: 'Guides and CPR',
                    subtitle:
                        'Step-by-step guides, and a CPR metronome to keep the pace.',
                    pageIndex: 2,
                  ),
                  // Slide 4: SOS
                  _buildSlide(
                    glass: glass,
                    icon: Icons.sos_rounded,
                    title: 'Emergency SOS',
                    subtitle:
                        'Send your location and details to your contacts by SMS. Opens in your messaging app.',
                    pageIndex: 3,
                  ),
                  // Slide 5: Medical ID
                  _buildSlide(
                    glass: glass,
                    icon: Icons.badge_rounded,
                    title: 'Medical ID',
                    subtitle:
                        'Add allergies, blood group and a contact. Stored only on this device.',
                    pageIndex: 4,
                    customActions: [
                      const SizedBox(height: 16),
                      ElevatedButton(
                        key: const Key('walkthrough_fill_profile_button'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: glass.accentMint,
                          foregroundColor: Colors.black87,
                          minimumSize: const Size(0, 48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: _openQuickProfile,
                        child: const Text(
                          'Fill it in now',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        key: const Key('walkthrough_skip_profile_button'),
                        style: TextButton.styleFrom(
                          foregroundColor: glass.textSecondary,
                          minimumSize: const Size(0, 44),
                        ),
                        onPressed: () => _goToPage(5),
                        child: const Text('Skip for now'),
                      ),
                    ],
                  ),
                  // Slide 6: AI Model
                  _buildSlide(
                    glass: glass,
                    icon: Icons.cloud_download_rounded,
                    title: 'Offline AI Model',
                    subtitle:
                        'AI answers need a one-time $modelSize download. Wi-Fi recommended.',
                    pageIndex: 5,
                    customActions: [
                      const SizedBox(height: 16),
                      ElevatedButton(
                        key: const Key('walkthrough_download_now_button'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: glass.accentMint,
                          foregroundColor: Colors.black87,
                          minimumSize: const Size(0, 48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () {
                          triage?.startModelDownload();
                          _markSeenAndClose();
                        },
                        child: const Text(
                          'Download now',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        key: const Key('walkthrough_download_later_button'),
                        style: TextButton.styleFrom(
                          foregroundColor: glass.textSecondary,
                          minimumSize: const Size(0, 44),
                        ),
                        onPressed: _markSeenAndClose,
                        child: const Text('Later'),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Bottom Bar: Back button, Page Dots, Next button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Back button
                  SizedBox(
                    width: 80,
                    height: 44,
                    child: _currentPage > 0
                        ? TextButton(
                            key: const Key('walkthrough_back_button'),
                            onPressed: _prevPage,
                            child: Text(
                              'Back',
                              style: TextStyle(
                                color: glass.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),

                  // Page dots
                  Semantics(
                    label: 'Slide ${_currentPage + 1} of $_totalSlides',
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(_totalSlides, (index) {
                        final isActive = index == _currentPage;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: isActive ? 20 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: isActive
                                ? glass.accentMint
                                : glass.glassBorderColor.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        );
                      }),
                    ),
                  ),

                  // Next button
                  SizedBox(
                    width: 80,
                    height: 44,
                    child: _currentPage < _totalSlides - 1
                        ? TextButton(
                            key: const Key('walkthrough_next_button'),
                            onPressed: _nextPage,
                            child: Text(
                              'Next',
                              style: TextStyle(
                                color: glass.accentMint,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlide({
    required CarePulseGlass glass,
    required IconData icon,
    required String title,
    required String subtitle,
    required int pageIndex,
    List<Widget>? customActions,
  }) {
    return Semantics(
      label: 'Walkthrough slide ${pageIndex + 1}: $title. $subtitle',
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GlassCard(
                padding: const EdgeInsets.all(28),
                borderRadius: 24,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        gradient: glass.iconTintGradient,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: glass.accentMint, size: 36),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: glass.textPrimary,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        color: glass.textSecondary,
                        height: 1.4,
                      ),
                    ),
                    if (customActions != null) ...customActions,
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
