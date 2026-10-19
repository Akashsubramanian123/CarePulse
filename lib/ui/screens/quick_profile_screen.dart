import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../models/medical_id.dart';
import '../../services/medical_id_store.dart';
import '../../services/profile_service.dart';
import '../widgets/glass_card.dart';

class QuickProfileScreen extends StatefulWidget {
  final MedicalIdStore? medicalIdStore;
  final ProfileService? profileService;

  const QuickProfileScreen({
    super.key,
    this.medicalIdStore,
    this.profileService,
  });

  @override
  State<QuickProfileScreen> createState() => _QuickProfileScreenState();
}

class _QuickProfileScreenState extends State<QuickProfileScreen> {
  late final MedicalIdStore _medicalIdStore;
  late final ProfileService _profileService;

  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  String _selectedBloodGroup = '';
  final _allergiesController = TextEditingController();
  final _conditionsController = TextEditingController();
  final _medicationsController = TextEditingController();

  final _contactNameController = TextEditingController();
  final _contactPhoneController = TextEditingController();
  final _contactRelationController = TextEditingController();

  static const List<String> _bloodGroups = [
    '',
    'A+',
    'A-',
    'B+',
    'B-',
    'AB+',
    'AB-',
    'O+',
    'O-',
  ];

  MedicalId _existingMedicalId = const MedicalId();
  UserProfile _existingUserProfile = UserProfile();

  @override
  void initState() {
    super.initState();
    _medicalIdStore = widget.medicalIdStore ?? MedicalIdStore();
    _profileService = widget.profileService ?? ProfileService();
    _prefillFromExisting();
  }

  Future<void> _prefillFromExisting() async {
    final medId = await _medicalIdStore.loadMedicalId();
    final profile = await _profileService.loadProfile();

    if (mounted) {
      setState(() {
        _existingMedicalId = medId;
        _existingUserProfile = profile;

        // Prefill name
        final name = medId.name.isNotEmpty ? medId.name : profile.name;
        _nameController.text = name;

        // Prefill age
        if (medId.ageOrDob.isNotEmpty) {
          _ageController.text = medId.ageOrDob;
        } else if (profile.age > 0) {
          _ageController.text = profile.age.toString();
        }

        // Prefill blood group
        if (_bloodGroups.contains(medId.bloodGroup)) {
          _selectedBloodGroup = medId.bloodGroup;
        }

        // Prefill medical details
        _allergiesController.text =
            medId.allergies.isNotEmpty ? medId.allergies : profile.allergies;
        _conditionsController.text =
            medId.conditions.isNotEmpty ? medId.conditions : profile.conditions;
        _medicationsController.text = medId.medications.isNotEmpty
            ? medId.medications
            : profile.medications;

        // Prefill contact if any
        if (medId.contacts.isNotEmpty) {
          _contactNameController.text = medId.contacts.first.name;
          _contactPhoneController.text = medId.contacts.first.phone;
          _contactRelationController.text = medId.contacts.first.relation;
        }
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _allergiesController.dispose();
    _conditionsController.dispose();
    _medicationsController.dispose();
    _contactNameController.dispose();
    _contactPhoneController.dispose();
    _contactRelationController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final newName = _nameController.text.trim();
    final newAge = _ageController.text.trim();
    final newBlood = _selectedBloodGroup.trim();
    final newAllergies = _allergiesController.text.trim();
    final newConditions = _conditionsController.text.trim();
    final newMedications = _medicationsController.text.trim();

    final cName = _contactNameController.text.trim();
    final cPhone =
        EmergencyContact.sanitizePhone(_contactPhoneController.text.trim());
    final cRel = _contactRelationController.text.trim();

    List<EmergencyContact> updatedContacts =
        List.from(_existingMedicalId.contacts);
    if (cName.isNotEmpty || cPhone.isNotEmpty) {
      final newContact =
          EmergencyContact(name: cName, phone: cPhone, relation: cRel);
      if (updatedContacts.isEmpty) {
        updatedContacts.add(newContact);
      } else {
        updatedContacts[0] = newContact;
      }
    }

    // Never overwrite non-empty existing values with empty ones
    final updatedMedicalId = _existingMedicalId.copyWith(
      name: newName.isNotEmpty ? newName : _existingMedicalId.name,
      ageOrDob: newAge.isNotEmpty ? newAge : _existingMedicalId.ageOrDob,
      bloodGroup:
          newBlood.isNotEmpty ? newBlood : _existingMedicalId.bloodGroup,
      allergies:
          newAllergies.isNotEmpty ? newAllergies : _existingMedicalId.allergies,
      conditions: newConditions.isNotEmpty
          ? newConditions
          : _existingMedicalId.conditions,
      medications: newMedications.isNotEmpty
          ? newMedications
          : _existingMedicalId.medications,
      contacts: updatedContacts,
    );

    final parsedAge = int.tryParse(newAge) ?? 0;
    final updatedProfile = UserProfile(
      name: newName.isNotEmpty ? newName : _existingUserProfile.name,
      age: parsedAge > 0 ? parsedAge : _existingUserProfile.age,
      conditions: newConditions.isNotEmpty
          ? newConditions
          : _existingUserProfile.conditions,
      allergies: newAllergies.isNotEmpty
          ? newAllergies
          : _existingUserProfile.allergies,
      medications: newMedications.isNotEmpty
          ? newMedications
          : _existingUserProfile.medications,
    );

    await _medicalIdStore.saveMedicalId(updatedMedicalId);
    await _profileService.saveProfile(updatedProfile);

    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  void _skip() {
    Navigator.pop(context, false);
  }

  @override
  Widget build(BuildContext context) {
    final glass = Theme.of(context).extension<CarePulseGlass>()!;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GlassScaffold(
      title: 'Quick Profile',
      actions: [
        TextButton(
          key: const Key('quick_profile_skip_button'),
          onPressed: _skip,
          child: Text(
            'Skip',
            style: TextStyle(
              color: glass.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        physics: const BouncingScrollPhysics(),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Safe Device Note
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: glass.accentMint.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: glass.accentMint.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lock_outline_rounded,
                        size: 16, color: glass.accentMint),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Stored only on this device.',
                        style: TextStyle(
                          color: glass.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Personal Details Card
              GlassCard(
                padding: const EdgeInsets.all(16),
                borderRadius: 20,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Personal Details',
                      style: TextStyle(
                        color: glass.accentMint,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      key: const Key('quick_profile_name_field'),
                      controller: _nameController,
                      style: TextStyle(color: glass.textPrimary, fontSize: 14),
                      decoration: _inputDecoration(
                        label: 'Full Name',
                        hint: 'e.g. John Doe',
                        glass: glass,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextFormField(
                            key: const Key('quick_profile_age_field'),
                            controller: _ageController,
                            keyboardType: TextInputType.number,
                            style: TextStyle(
                                color: glass.textPrimary, fontSize: 14),
                            decoration: _inputDecoration(
                              label: 'Age',
                              hint: 'e.g. 34',
                              glass: glass,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 3,
                          child: DropdownButtonFormField<String>(
                            key: const Key('quick_profile_blood_group_field'),
                            initialValue: _selectedBloodGroup,
                            dropdownColor:
                                isDark ? const Color(0xFF1B242D) : Colors.white,
                            style: TextStyle(
                                color: glass.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w600),
                            decoration: _inputDecoration(
                              label: 'Blood Group',
                              hint: 'Select',
                              glass: glass,
                            ),
                            items: _bloodGroups.map((bg) {
                              return DropdownMenuItem<String>(
                                value: bg,
                                child: Text(
                                  bg.isEmpty ? 'None' : bg,
                                  style: TextStyle(color: glass.textPrimary),
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              setState(() => _selectedBloodGroup = val ?? '');
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Medical Info Card
              GlassCard(
                padding: const EdgeInsets.all(16),
                borderRadius: 20,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Medical Info',
                      style: TextStyle(
                        color: glass.accentMint,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      key: const Key('quick_profile_allergies_field'),
                      controller: _allergiesController,
                      style: TextStyle(color: glass.textPrimary, fontSize: 14),
                      decoration: _inputDecoration(
                        label: 'Allergies',
                        hint: 'e.g. Penicillin, Peanuts',
                        glass: glass,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      key: const Key('quick_profile_conditions_field'),
                      controller: _conditionsController,
                      style: TextStyle(color: glass.textPrimary, fontSize: 14),
                      decoration: _inputDecoration(
                        label: 'Conditions',
                        hint: 'e.g. Asthma, Diabetes',
                        glass: glass,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      key: const Key('quick_profile_medications_field'),
                      controller: _medicationsController,
                      style: TextStyle(color: glass.textPrimary, fontSize: 14),
                      decoration: _inputDecoration(
                        label: 'Medications',
                        hint: 'e.g. Inhaler, Insulin',
                        glass: glass,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Emergency Contact Card
              GlassCard(
                padding: const EdgeInsets.all(16),
                borderRadius: 20,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Emergency Contact (Optional)',
                      style: TextStyle(
                        color: glass.accentMint,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      key: const Key('quick_profile_contact_name_field'),
                      controller: _contactNameController,
                      style: TextStyle(color: glass.textPrimary, fontSize: 14),
                      decoration: _inputDecoration(
                        label: 'Contact Name',
                        hint: 'e.g. Jane Doe',
                        glass: glass,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextFormField(
                            key: const Key('quick_profile_contact_phone_field'),
                            controller: _contactPhoneController,
                            keyboardType: TextInputType.phone,
                            style: TextStyle(
                                color: glass.textPrimary, fontSize: 14),
                            decoration: _inputDecoration(
                              label: 'Phone',
                              hint: '+1234567890',
                              glass: glass,
                            ),
                            validator: (value) {
                              if (value != null && value.trim().isNotEmpty) {
                                final sanitized =
                                    EmergencyContact.sanitizePhone(value);
                                if (sanitized.length < 3) {
                                  return 'Enter valid phone number';
                                }
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            key: const Key(
                                'quick_profile_contact_relation_field'),
                            controller: _contactRelationController,
                            style: TextStyle(
                                color: glass.textPrimary, fontSize: 14),
                            decoration: _inputDecoration(
                              label: 'Relation',
                              hint: 'Spouse',
                              glass: glass,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Save Button
              ElevatedButton(
                key: const Key('quick_profile_save_button'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: glass.accentMint,
                  foregroundColor: Colors.black87,
                  minimumSize: const Size(0, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: _save,
                child: const Text(
                  'Save Profile',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required String hint,
    required CarePulseGlass glass,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: TextStyle(color: glass.textSecondary, fontSize: 13),
      hintStyle: TextStyle(
        color: glass.textSecondary.withValues(alpha: 0.6),
        fontSize: 12,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: glass.glassBorderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: glass.glassBorderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: glass.accentMint, width: 1.5),
      ),
    );
  }
}
