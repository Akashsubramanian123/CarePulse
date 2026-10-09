import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../services/profile_service.dart';

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

  Future<void> _loadProfile() async {
    final profile = await _profileService.loadProfile();
    setState(() {
      _nameController.text = profile.name;
      _ageController.text = profile.age > 0 ? profile.age.toString() : '';
      _conditionsController.text = profile.conditions;
      _allergiesController.text = profile.allergies;
      _medicationsController.text = profile.medications;
      _isLoading = false;
    });
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
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.darkBackground,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      appBar: AppBar(
        title: const Text('Medical Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveProfile,
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              "This data is stored 100% locally on your device and injected directly into the offline AI model during an emergency.",
              style: TextStyle(color: AppColors.textMuted),
            ),
            const SizedBox(height: 20),
            _buildField("Name", _nameController),
            _buildField("Age", _ageController, isNumber: true),
            _buildField("Pre-existing Conditions", _conditionsController, maxLines: 3),
            _buildField("Allergies", _allergiesController, maxLines: 3),
            _buildField("Current Medications", _medicationsController, maxLines: 3),
          ],
        ),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController controller, {bool isNumber = false, int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        maxLines: maxLines,
        style: const TextStyle(color: AppColors.textPrimary),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: AppColors.textMuted),
          filled: true,
          fillColor: AppColors.darkSurfaceCard,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}
