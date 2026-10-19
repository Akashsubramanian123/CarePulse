import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/emergency_config.dart';
import '../../core/theme/app_theme.dart';
import '../../models/medical_id.dart';
import '../../services/medical_id_store.dart';
import '../../services/sos_service.dart';
import '../../state/app_settings_controller.dart';
import '../widgets/glass_card.dart';
import 'medical_id_screen.dart';

class SosScreen extends StatefulWidget {
  final MedicalIdStore? store;
  final SosService? sosService;

  const SosScreen({super.key, this.store, this.sosService});

  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen> {
  late final MedicalIdStore _store;
  late final SosService _sosService;

  MedicalId _medicalId = const MedicalId();
  bool _isLoading = true;
  bool _isFetchingLocation = false;

  @override
  void initState() {
    super.initState();
    _store = widget.store ?? MedicalIdStore();
    _sosService = widget.sosService ?? SosService();
    _loadData();
  }

  Future<void> _loadData() async {
    final id = await _store.loadMedicalId();
    if (mounted) {
      setState(() {
        _medicalId = id;
        _isLoading = false;
      });
    }
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

  Future<void> _callContact(String phone) async {
    final sanitized = EmergencyContact.sanitizePhone(phone);
    if (sanitized.isEmpty) return;

    final uri = Uri(scheme: 'tel', path: sanitized);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to call $sanitized.')),
        );
      }
    }
  }

  Future<void> _onSendSosPressed() async {
    final validContacts =
        _medicalId.contacts.where((c) => c.phone.isNotEmpty).toList();
    if (validContacts.isEmpty) {
      _showNoContactsDialog();
      return;
    }

    setState(() => _isFetchingLocation = true);

    try {
      final pos = await _sosService.getCurrentLocation();
      final message = SosService.buildEmergencyMessage(
        position: pos,
        bloodGroup: _medicalId.bloodGroup,
        allergies: _medicalId.allergies,
        conditions: _medicalId.conditions,
      );

      if (mounted) {
        setState(() => _isFetchingLocation = false);
        _showSosPreviewSheet(message, validContacts);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isFetchingLocation = false);
        final fallbackMsg = SosService.buildEmergencyMessage(
          position: null,
          bloodGroup: _medicalId.bloodGroup,
          allergies: _medicalId.allergies,
          conditions: _medicalId.conditions,
        );
        _showSosPreviewSheet(fallbackMsg, validContacts);
      }
    }
  }

  void _showNoContactsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('No Emergency Contacts'),
        content: const Text(
          'Please add at least one emergency contact in your Medical ID to send an SOS alert.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => MedicalIdScreen(store: _store)),
              ).then((_) => _loadData());
            },
            child: const Text('Add Contacts'),
          ),
        ],
      ),
    );
  }

  void _showSosPreviewSheet(
      String initialMessage, List<EmergencyContact> contacts) {
    final textController = TextEditingController(text: initialMessage);
    final glass = Theme.of(context).extension<CarePulseGlass>()!;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            left: 16,
            right: 16,
            top: 20,
          ),
          decoration: BoxDecoration(
            color: Theme.of(ctx).brightness == Brightness.dark
                ? const Color(0xFF1B242D)
                : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.sms_rounded, color: Color(0xFFE05A4F)),
                      const SizedBox(width: 8),
                      Text(
                        'Confirm Emergency SOS',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: glass.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Recipients: ${contacts.map((c) => "${c.name} (${c.phone})").join(", ")}',
                style: TextStyle(fontSize: 13, color: glass.textSecondary),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: textController,
                maxLines: 4,
                style: TextStyle(color: glass.textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'Emergency Message',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16)),
                  filled: true,
                  fillColor: Colors.black.withValues(alpha: 0.05),
                ),
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: () async {
                  Navigator.pop(ctx);
                  final numbers = contacts.map((c) => c.phone).toList();
                  final success = await _sosService.launchSmsComposer(
                    phoneNumbers: numbers,
                    message: textController.text,
                  );
                  if (!success && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                            'Failed to open SMS composer. Please check permissions or device settings.'),
                      ),
                    );
                  }
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: glass.emergencyGradient,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.open_in_new_rounded, color: Colors.white),
                      SizedBox(width: 10),
                      Text(
                        'Open SMS App',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final glass = Theme.of(context).extension<CarePulseGlass>()!;
    final settings = context.watch<AppSettingsController?>();
    final emergencyNum = settings?.emergencyNumber ?? emergencyNumber;

    return GlassScaffold(
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: glass.accentMint))
          : ShaderMask(
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
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Large Send SOS Action Button
                    InkWell(
                      onTap: _isFetchingLocation ? null : _onSendSosPressed,
                      borderRadius: BorderRadius.circular(28),
                      child: Container(
                        height: 84,
                        decoration: BoxDecoration(
                          gradient: glass.emergencyGradient,
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFE05A4F)
                                  .withValues(alpha: 0.4),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Center(
                          child: _isFetchingLocation
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: Colors.white,
                                      ),
                                    ),
                                    SizedBox(width: 14),
                                    Text(
                                      'Acquiring GPS fix...',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: const [
                                    Icon(Icons.emergency_share_rounded,
                                        color: Colors.white, size: 28),
                                    SizedBox(width: 10),
                                    Flexible(
                                      child: Text(
                                        'SEND SOS ALERT',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 0.8,
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
                    const SizedBox(height: 14),

                    // Direct Call Emergency Banner
                    InkWell(
                      onTap: () => _callEmergency(emergencyNum),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 14, horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: glass.glassBorderColor),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.phone_rounded,
                                color: glass.accentMint, size: 22),
                            const SizedBox(width: 10),
                            Text(
                              'Call $emergencyNum',
                              style: TextStyle(
                                color: glass.textPrimary,
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Medical ID Quick Entry Card
                    GlassCard(
                      key: const Key('sos_medical_id_button'),
                      borderRadius: 20,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => MedicalIdScreen(store: _store)),
                        ).then((_) => _loadData());
                      },
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: glass.accentMint.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.badge_rounded,
                                color: glass.accentMint, size: 24),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Medical ID',
                                  style: TextStyle(
                                    color: glass.textPrimary,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Allergies, blood group, contacts',
                                  style: TextStyle(
                                    color: glass.textSecondary,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right_rounded,
                              color: glass.textSecondary, size: 24),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Emergency Contacts Header
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Emergency Contacts',
                            style: TextStyle(
                              color: glass.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      MedicalIdScreen(store: _store)),
                            ).then((_) => _loadData());
                          },
                          child: Text(
                            _medicalId.contacts.isEmpty ? 'Add' : 'Manage',
                            style: TextStyle(
                                color: glass.accentMint,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Contact Cards or Add Prompt
                    if (_medicalId.contacts.isEmpty)
                      GlassCard(
                        padding: const EdgeInsets.all(16),
                        borderRadius: 20,
                        child: Column(
                          children: [
                            Icon(Icons.person_add_rounded,
                                size: 36, color: glass.accentMint),
                            const SizedBox(height: 10),
                            Text(
                              'No Emergency Contacts Added',
                              style: TextStyle(
                                color: glass.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Add up to 3 contacts so CarePulse can notify them instantly via SMS with your GPS location and medical profile.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: glass.textSecondary, fontSize: 13),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: glass.accentMint,
                                foregroundColor: Colors.black87,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16)),
                              ),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          MedicalIdScreen(store: _store)),
                                ).then((_) => _loadData());
                              },
                              child: const Text('Add Emergency Contacts',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      )
                    else
                      for (final contact in _medicalId.contacts)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10.0),
                          child: GlassCard(
                            padding: const EdgeInsets.all(14),
                            borderRadius: 18,
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor:
                                      glass.accentMint.withValues(alpha: 0.15),
                                  child: Icon(Icons.person_rounded,
                                      color: glass.accentMint),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        contact.name,
                                        style: TextStyle(
                                          color: glass.textPrimary,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                      Text(
                                        '${contact.relation.isNotEmpty ? "${contact.relation} • " : ""}${contact.phone}',
                                        style: TextStyle(
                                            color: glass.textSecondary,
                                            fontSize: 13),
                                      ),
                                    ],
                                  ),
                                ),
                                // Per-contact Call Button (>= 48x48 tap target)
                                SizedBox(
                                  width: 48,
                                  height: 48,
                                  child: IconButton(
                                    icon: const Icon(Icons.call_rounded,
                                        size: 22),
                                    color: const Color(0xFF6BAA8E),
                                    tooltip: 'Call ${contact.name}',
                                    onPressed: () =>
                                        _callContact(contact.phone),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                    const SizedBox(height: 20),

                    // Medical Card Summary for First Responders
                    Text(
                      'Medical Card (For First Responders)',
                      style: TextStyle(
                        color: glass.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),

                    GlassCard(
                      padding: const EdgeInsets.all(18),
                      borderRadius: 22,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  _medicalId.name.isEmpty
                                      ? 'Name: Not provided'
                                      : _medicalId.name,
                                  style: TextStyle(
                                    color: glass.textPrimary,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              if (_medicalId.bloodGroup.isNotEmpty) ...[
                                Builder(
                                  builder: (context) {
                                    final isDark =
                                        Theme.of(context).brightness ==
                                            Brightness.dark;
                                    final chipTextColor = isDark
                                        ? const Color(0xFFFFB4AB)
                                        : const Color(0xFFB3362C);
                                    final chipBgColor = isDark
                                        ? const Color(0xFF410E0B)
                                        : const Color(0xFFFFEBEE);
                                    final chipBorderColor = isDark
                                        ? const Color(0xFF93000A)
                                        : const Color(0xFFF2B8B5);

                                    return Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: chipBgColor,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: chipBorderColor,
                                          width: 1,
                                        ),
                                      ),
                                      child: Text(
                                        'Blood: ${_medicalId.bloodGroup}',
                                        style: TextStyle(
                                          color: chipTextColor,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildSummaryRow(
                              'Allergies',
                              _medicalId.allergies.isEmpty
                                  ? 'None recorded'
                                  : _medicalId.allergies,
                              glass),
                          _buildSummaryRow(
                              'Conditions',
                              _medicalId.conditions.isEmpty
                                  ? 'None recorded'
                                  : _medicalId.conditions,
                              glass),
                          _buildSummaryRow(
                              'Medications',
                              _medicalId.medications.isEmpty
                                  ? 'None recorded'
                                  : _medicalId.medications,
                              glass),
                          if (_medicalId.notes.isNotEmpty)
                            _buildSummaryRow('Notes', _medicalId.notes, glass),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSummaryRow(String label, String value, CarePulseGlass glass) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              '$label:',
              style: TextStyle(
                  color: glass.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: glass.textPrimary, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
