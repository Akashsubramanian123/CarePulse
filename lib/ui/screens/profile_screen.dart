import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../services/profile_service.dart';
import '../widgets/glass_card.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ProfileService _profileService = ProfileService();

  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _conditionsController = TextEditingController();
  final _allergiesController = TextEditingController();
  final _medicationsController = TextEditingController();

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _conditionsController.dispose();
    _allergiesController.dispose();
    _medicationsController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final profile = await _profileService.loadProfile();
    if (mounted) {
      setState(() {
        _nameController.text = profile.name;
        _ageController.text = profile.age > 0 ? profile.age.toString() : '';
        _conditionsController.text = profile.conditions;
        _allergiesController.text = profile.allergies;
        _medicationsController.text = profile.medications;
        _isLoading = false;
      });
    }
  }

  Future<void> _saveProfile() async {
    final profile = UserProfile(
      name: _nameController.text,
      age: int.tryParse(_ageController.text) ?? 0,
      conditions: _conditionsController.text,
      allergies: _allergiesController.text,
      medications: _medicationsController.text,
    );
    await _profileService.saveProfile(profile);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile Saved!')),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final glass = Theme.of(context).extension<CarePulseGlass>()!;

    if (_isLoading) {
      return GlassScaffold(
        body: Center(
          child: CircularProgressIndicator(color: glass.accentMint),
        ),
      );
    }

    return GlassScaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: glass.accentMint),
        title: Text(
          'Medical Profile',
          style: TextStyle(
            color: glass.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        actions: [
          SizedBox(
            width: 48,
            height: 48,
            child: IconButton(
              icon: Icon(Icons.save_rounded, color: glass.accentMint),
              tooltip: 'Save Profile',
              onPressed: _saveProfile,
            ),
          ),
        ],
      ),
      body: ShaderMask(
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
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GlassCard(
                padding: const EdgeInsets.all(14),
                borderRadius: 16,
                child: Row(
                  children: [
                    Icon(Icons.shield_outlined,
                        color: glass.accentMint, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'This data is stored 100% locally on your device and injected directly into the offline AI model during an emergency.',
                        style: TextStyle(
                          color: glass.textSecondary,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _buildField('Name', _nameController, glass: glass),
              _buildField('Age', _ageController, isNumber: true, glass: glass),
              _buildField('Pre-existing Conditions', _conditionsController,
                  maxLines: 3, glass: glass),
              _buildField('Allergies', _allergiesController,
                  maxLines: 3, glass: glass),
              _buildField('Current Medications', _medicationsController,
                  maxLines: 3, glass: glass),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField(
    String label,
    TextEditingController controller, {
    required CarePulseGlass glass,
    bool isNumber = false,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: glass.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            keyboardType: isNumber ? TextInputType.number : TextInputType.text,
            maxLines: maxLines,
            style: TextStyle(color: glass.textPrimary, fontSize: 14),
            decoration: InputDecoration(
              floatingLabelBehavior: FloatingLabelBehavior.always,
              contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              filled: true,
              fillColor: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0x1AFFFFFF)
                  : const Color(0x0A000000),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: glass.glassBorderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: glass.glassBorderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: glass.accentMint, width: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
