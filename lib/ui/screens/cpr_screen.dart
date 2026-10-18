import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/emergency_config.dart';
import '../../core/theme/app_theme.dart';
import '../../state/app_settings_controller.dart';
import '../../state/cpr_controller.dart';
import '../widgets/glass_card.dart';

class CprScreen extends StatefulWidget {
  final CprController? controller;

  const CprScreen({super.key, this.controller});

  @override
  State<CprScreen> createState() => _CprScreenState();
}

class _CprScreenState extends State<CprScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static bool _checklistExpanded = true;

  late final CprController _cprController;
  late final AnimationController _pulseController;
  late final Animation<double> _scaleAnimation;

  int _selectedAgeCategory = 0; // 0: Adult, 1: Child, 2: Infant

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _cprController = widget.controller ?? CprController();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOutCubic),
    );

    _cprController.onBeatFired = () {
      if (mounted) {
        _pulseController.forward(from: 0.0).then((_) {
          if (mounted) _pulseController.reverse();
        });
      }
    };
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _cprController.pause();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cprController.stop();
    _pulseController.dispose();
    if (widget.controller == null) {
      _cprController.dispose();
    }
    super.dispose();
  }

  Future<void> _callEmergency([String? targetNumber]) async {
    final settings =
        context.mounted ? context.read<AppSettingsController?>() : null;
    final numToCall =
        targetNumber ?? settings?.emergencyNumber ?? emergencyNumber;
    final uri = Uri(scheme: 'tel', path: numToCall);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Failed to open dialer. Please dial $numToCall manually.'),
          ),
        );
      }
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final glass = Theme.of(context).extension<CarePulseGlass>()!;
    final settings = context.watch<AppSettingsController?>();
    final emergencyNum = settings?.emergencyNumber ?? emergencyNumber;

    return GlassScaffold(
      body: AnimatedBuilder(
        animation: _cprController,
        builder: (context, _) {
          return Column(
            children: [
              Expanded(
                child: ShaderMask(
                  shaderCallback: (Rect bounds) {
                    return const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFF000000),
                        Color(0xFF000000),
                        Color(0xFF000000),
                        Colors.transparent,
                      ],
                      stops: [0.0, 0.88, 0.96, 1.0],
                    ).createShader(bounds);
                  },
                  blendMode: BlendMode.dstIn,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics()),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 1. Collapsible Safety Checklist Banner
                        _buildSafetyChecklist(glass, emergencyNum),
                        const SizedBox(height: 16),

                        // 2. Metronome Card with Pulsing Circle
                        _buildMetronomeCard(glass),
                        const SizedBox(height: 16),

                        // 3. Category Info Cards (Adult, Child, Infant)
                        _buildCategorySelector(glass),
                        const SizedBox(height: 12),
                        _buildCategoryInfoCard(glass),
                      ],
                    ),
                  ),
                ),
              ),

              // Pinned Start / Pause / Stop bottom bar
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF0F171D).withValues(alpha: 0.85)
                      : Colors.white.withValues(alpha: 0.85),
                  border: Border(
                    top: BorderSide(color: glass.glassBorderColor),
                  ),
                ),
                child: _buildControls(glass),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSafetyChecklist(CarePulseGlass glass, String emergencyNum) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      borderRadius: 22,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _checklistExpanded = !_checklistExpanded;
              });
            },
            borderRadius: BorderRadius.circular(12),
            child: Row(
              children: [
                Icon(Icons.checklist_rounded,
                    color: glass.accentMint, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Safety & Assessment Checklist',
                    style: TextStyle(
                      color: glass.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Icon(
                  _checklistExpanded
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  color: glass.textSecondary,
                  size: 22,
                ),
              ],
            ),
          ),
          if (_checklistExpanded) ...[
            const SizedBox(height: 10),
            _buildChecklistItem(
                '1. Check scene safety (hazards, traffic, electricity)', glass),
            _buildChecklistItem(
                '2. Tap shoulders firmly and shout loudly', glass),
            _buildChecklistItem(
                '3. Look for normal breathing (max 10 seconds)', glass),
            _buildChecklistItem(
                '4. Shout for help and call $emergencyNum immediately', glass),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _callEmergency(emergencyNum),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFC7382E),
                  side: const BorderSide(color: Color(0xFFC7382E)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  minimumSize: const Size(double.infinity, 48),
                ),
                icon: const Icon(Icons.phone_in_talk_rounded, size: 18),
                label: Text('Call $emergencyNum Now',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChecklistItem(String text, CarePulseGlass glass) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Text(
        text,
        style: TextStyle(
          color: glass.textSecondary,
          fontSize: 13,
          height: 1.4,
        ),
      ),
    );
  }

  Widget _buildMetronomeCard(CarePulseGlass glass) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final idleGradient = isDark
        ? const LinearGradient(
            colors: [Color(0xFF164E59), Color(0xFF1E6774)],
          )
        : const LinearGradient(
            colors: [Color(0xFF14545E), Color(0xFF1B6875)],
          );

    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      borderRadius: 28,
      child: Column(
        children: [
          // BPM Control and Mute toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // BPM Adjustment
              Expanded(
                child: Row(
                  children: [
                    SizedBox(
                      width: 48,
                      height: 48,
                      child: IconButton(
                        icon: const Icon(Icons.remove_circle_outline_rounded),
                        color: glass.accentMint,
                        tooltip: 'Decrease BPM',
                        onPressed: () =>
                            _cprController.setBpm(_cprController.bpm - 2),
                      ),
                    ),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '${_cprController.bpm} BPM',
                          style: TextStyle(
                            color: glass.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 48,
                      height: 48,
                      child: IconButton(
                        icon: const Icon(Icons.add_circle_outline_rounded),
                        color: glass.accentMint,
                        tooltip: 'Increase BPM',
                        onPressed: () =>
                            _cprController.setBpm(_cprController.bpm + 2),
                      ),
                    ),
                  ],
                ),
              ),

              // Sound/Voice Mute Toggle (>= 48x48)
              SizedBox(
                width: 48,
                height: 48,
                child: IconButton(
                  icon: Icon(
                    _cprController.isMuted
                        ? Icons.volume_off_rounded
                        : Icons.volume_up_rounded,
                    color: _cprController.isMuted
                        ? const Color(0xFFC7382E)
                        : glass.accentMint,
                  ),
                  tooltip:
                      _cprController.isMuted ? 'Unmute audio' : 'Mute audio',
                  onPressed: () => _cprController.toggleMute(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Large Pulsing Compression Circle
          ScaleTransition(
            scale: _scaleAnimation,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: _cprController.isRunning
                    ? glass.emergencyGradient
                    : idleGradient,
                boxShadow: [
                  BoxShadow(
                    color: (_cprController.isRunning
                            ? const Color(0xFFC7382E)
                            : glass.accentMint)
                        .withValues(alpha: 0.35),
                    blurRadius: 36,
                    spreadRadius: _cprController.isRunning ? 6 : 0,
                  ),
                ],
              ),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.favorite_rounded,
                          color: Colors.white,
                          size: _cprController.isRunning ? 38 : 32,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_cprController.compressionCount}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          'COMPRESSIONS',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Stats: Cycle and Elapsed Time
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('CYCLE (30x)',
                          style: TextStyle(
                              color: glass.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Cycle ${_cprController.currentCycle}',
                        style: TextStyle(
                            color: glass.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 32, color: glass.glassBorderColor),
              Expanded(
                child: Column(
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('ELAPSED',
                          style: TextStyle(
                              color: glass.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        _formatDuration(_cprController.elapsedTime),
                        style: TextStyle(
                            color: glass.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildControls(CarePulseGlass glass) {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: InkWell(
            onTap: () {
              if (_cprController.isRunning) {
                _cprController.pause();
              } else {
                _cprController.start();
              }
            },
            borderRadius: BorderRadius.circular(20),
            child: Container(
              height: 56,
              decoration: BoxDecoration(
                gradient: _cprController.isRunning
                    ? const LinearGradient(
                        colors: [Color(0xFFC7382E), Color(0xFFB52B4D)])
                    : glass.primaryActionGradient,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: (_cprController.isRunning
                            ? const Color(0xFFC7382E)
                            : glass.accentMint)
                        .withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _cprController.isRunning
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      _cprController.isRunning ? 'Pause CPR' : 'Start CPR',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_cprController.compressionCount > 0 ||
            _cprController.isRunning) ...[
          const SizedBox(width: 12),
          SizedBox(
            width: 56,
            height: 56,
            child: OutlinedButton(
              onPressed: () => _cprController.stop(),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFC7382E),
                side: const BorderSide(color: Color(0xFFC7382E), width: 1.5),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                padding: EdgeInsets.zero,
              ),
              child: const Icon(Icons.stop_rounded, size: 28),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCategorySelector(CarePulseGlass glass) {
    final categories = ['Adult', 'Child (1-8 yrs)', 'Infant (< 1 yr)'];

    return Row(
      children: [
        for (int i = 0; i < 3; i++)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: i < 2 ? 8.0 : 0.0),
              child: InkWell(
                onTap: () => setState(() => _selectedAgeCategory = i),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: _selectedAgeCategory == i
                        ? glass.accentMint
                        : Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _selectedAgeCategory == i
                          ? glass.accentMint
                          : glass.glassBorderColor,
                    ),
                  ),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      categories[i],
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _selectedAgeCategory == i
                            ? Colors.white
                            : glass.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCategoryInfoCard(CarePulseGlass glass) {
    String title;
    String technique;
    String depth;
    String breaths;

    if (_selectedAgeCategory == 0) {
      title = 'Adult Resuscitation';
      technique = 'Hands-only: Two hands interlaced in center of chest.';
      depth = 'Push 5 to 6 cm deep (2 - 2.4 inches).';
      breaths = 'If trained: 30 compressions then 2 rescue breaths.';
    } else if (_selectedAgeCategory == 1) {
      title = 'Child Resuscitation';
      technique = 'One or two hands in center of breastbone.';
      depth = 'Push about 5 cm deep (one third of chest depth).';
      breaths = 'Deliver 2 gentle breaths after every 30 pushes.';
    } else {
      title = 'Infant Resuscitation';
      technique = 'Two fingers in center of chest below nipple line.';
      depth = 'Push about 4 cm deep (one third of chest depth).';
      breaths = 'Cover nose and mouth with your mouth; gentle puffs.';
    }

    return GlassCard(
      padding: const EdgeInsets.all(16),
      borderRadius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  color: glass.accentMint,
                  fontWeight: FontWeight.bold,
                  fontSize: 16)),
          const SizedBox(height: 8),
          Text(technique,
              style: TextStyle(
                  color: glass.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(depth,
              style: TextStyle(color: glass.textSecondary, fontSize: 13)),
          const SizedBox(height: 4),
          Text(breaths,
              style: TextStyle(color: glass.textSecondary, fontSize: 13)),
        ],
      ),
    );
  }
}
