import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/emergency_config.dart';
import '../../core/theme/app_theme.dart';
import '../../models/protocol.dart';
import '../../state/app_settings_controller.dart';
import '../../state/triage_controller.dart';
import '../widgets/glass_card.dart';
import 'protocol_detail_screen.dart';

class GuidesScreen extends StatefulWidget {
  const GuidesScreen({super.key});

  @override
  State<GuidesScreen> createState() => _GuidesScreenState();
}

class _GuidesScreenState extends State<GuidesScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Protocol> _allProtocols = [];
  List<Protocol> _filteredProtocols = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProtocols();
  }

  Future<void> _loadProtocols() async {
    final controller = context.read<TriageController>();
    List<Protocol> protocols = controller.protocolRepository.allProtocols;
    if (protocols.isEmpty) {
      try {
        protocols = await controller.protocolRepository.loadProtocols();
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        _allProtocols = protocols;
        _filteredProtocols = protocols;
        _isLoading = false;
      });
    }
  }

  void _onSearchChanged(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) {
      setState(() => _filteredProtocols = _allProtocols);
      return;
    }

    setState(() {
      _filteredProtocols = _allProtocols.where((p) {
        final titleMatch = p.title.toLowerCase().contains(q);
        final keywordMatch = p.keywords.any((k) => k.toLowerCase().contains(q));
        final synonymMatch = p.synonyms.any((s) => s.toLowerCase().contains(q));
        return titleMatch || keywordMatch || synonymMatch;
      }).toList();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
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
              content: Text(
                  'Failed to open dialer. Please dial $numToCall manually.')),
        );
      }
    }
  }

  IconData _getIconForProtocol(Protocol protocol) {
    switch (protocol.id) {
      case 'bleeding':
        return Icons.water_drop_rounded;
      case 'burns':
        return Icons.local_fire_department_rounded;
      case 'choking':
      case 'choking_child':
      case 'choking_infant':
        return Icons.air_rounded;
      case 'heatstroke':
        return Icons.wb_sunny_rounded;
      case 'snakebite':
        return Icons.warning_amber_rounded;
      case 'seizure':
        return Icons.cyclone_rounded;
      case 'unconscious_breathing':
        return Icons.hotel_rounded;
      case 'cardiac_arrest':
        return Icons.favorite_rounded;
      case 'chest_pain':
        return Icons.healing_rounded;
      case 'stroke':
        return Icons.psychology_rounded;
      case 'fracture':
        return Icons.accessibility_rounded;
      case 'drowning':
        return Icons.pool_rounded;
      case 'electric_shock':
        return Icons.bolt_rounded;
      case 'poisoning':
        return Icons.science_rounded;
      case 'anaphylaxis':
        return Icons.coronavirus_rounded;
      case 'nosebleed':
        return Icons.masks_rounded;
      case 'fainting':
        return Icons.airline_seat_flat_rounded;
      case 'eye_injury':
        return Icons.visibility_rounded;
      case 'hypothermia':
        return Icons.ac_unit_rounded;
      case 'bites_and_stings':
        return Icons.pest_control_rounded;
      default:
        return Icons.medical_services_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final glass = Theme.of(context).extension<CarePulseGlass>()!;
    final settings = context.watch<AppSettingsController?>();
    final emergencyNum = settings?.emergencyNumber ?? emergencyNumber;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'First-Aid Guides',
          style: TextStyle(
            color: glass.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        actions: [
          // Small reachable Call action on every tab
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: SizedBox(
              height: 48,
              child: TextButton.icon(
                onPressed: () => _callEmergency(emergencyNum),
                style: TextButton.styleFrom(
                  backgroundColor:
                      const Color(0xFFE05A4F).withValues(alpha: 0.18),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: const BorderSide(color: Color(0xFFE05A4F), width: 1),
                  ),
                ),
                icon:
                    const Icon(Icons.phone, color: Color(0xFFE05A4F), size: 16),
                label: Text(
                  'Call $emergencyNum',
                  style: const TextStyle(
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
      body: GradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              // Search Bar
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: GlassCard(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  borderRadius: 20,
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    style: TextStyle(color: glass.textPrimary, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Search guides, symptoms, injuries...',
                      hintStyle:
                          TextStyle(color: glass.textSecondary, fontSize: 13),
                      border: InputBorder.none,
                      prefixIcon: Icon(Icons.search_rounded,
                          color: glass.accentMint, size: 22),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? SizedBox(
                              width: 48,
                              height: 48,
                              child: IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 18),
                                color: glass.textSecondary,
                                onPressed: () {
                                  _searchController.clear();
                                  _onSearchChanged('');
                                },
                              ),
                            )
                          : null,
                    ),
                  ),
                ),
              ),

              // Protocol List
              Expanded(
                child: _isLoading
                    ? Center(
                        child:
                            CircularProgressIndicator(color: glass.accentMint))
                    : _filteredProtocols.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Text(
                                'No protocols matching "${_searchController.text}".',
                                style: TextStyle(
                                    color: glass.textSecondary, fontSize: 14),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                            physics: const AlwaysScrollableScrollPhysics(
                                parent: BouncingScrollPhysics()),
                            itemCount: _filteredProtocols.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final protocol = _filteredProtocols[index];
                              return GlassCard(
                                borderRadius: 18,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 12),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ProtocolDetailScreen(
                                          protocol: protocol),
                                    ),
                                  );
                                },
                                child: Row(
                                  children: [
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        gradient: protocol.callEmergency
                                            ? glass.emergencyGradient
                                            : glass.iconTintGradient,
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Icon(
                                        _getIconForProtocol(protocol),
                                        color: protocol.callEmergency
                                            ? Colors.white
                                            : glass.accentMint,
                                        size: 22,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  protocol.title,
                                                  style: TextStyle(
                                                    color: glass.textPrimary,
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                              if (protocol.callEmergency)
                                                Container(
                                                  margin: const EdgeInsets.only(
                                                      left: 6),
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 6,
                                                      vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color:
                                                        const Color(0xFFE05A4F)
                                                            .withValues(
                                                                alpha: 0.2),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8),
                                                    border: Border.all(
                                                        color: const Color(
                                                            0xFFE05A4F),
                                                        width: 0.8),
                                                  ),
                                                  child: Text(
                                                    'CALL $emergencyNum',
                                                    style: const TextStyle(
                                                      color: Color(0xFFE05A4F),
                                                      fontSize: 9,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            protocol.immediate,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: glass.textSecondary,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Icon(
                                      Icons.chevron_right_rounded,
                                      color: glass.textSecondary,
                                      size: 20,
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
