import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../models/medical_id.dart';
import '../../services/medical_id_store.dart';
import '../widgets/glass_card.dart';

class MedicalIdScreen extends StatefulWidget {
  final MedicalIdStore? store;

  const MedicalIdScreen({super.key, this.store});

  @override
  State<MedicalIdScreen> createState() => _MedicalIdScreenState();
}

class _MedicalIdScreenState extends State<MedicalIdScreen> {
  late final MedicalIdStore _store;
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _bloodGroupController = TextEditingController();
  final _allergiesController = TextEditingController();
  final _conditionsController = TextEditingController();
  final _medicationsController = TextEditingController();
  final _notesController = TextEditingController();

  final List<TextEditingController> _contactNameControllers = [];
  final List<TextEditingController> _contactPhoneControllers = [];
  final List<TextEditingController> _contactRelationControllers = [];

  bool _isEditing = false;
  bool _isLoading = true;
  MedicalId _currentMedicalId = const MedicalId();

  @override
  void initState() {
    super.initState();
    _store = widget.store ?? MedicalIdStore();
    _initContactControllers();
    _loadData();
  }

  void _initContactControllers() {
    for (int i = 0; i < 3; i++) {
      _contactNameControllers.add(TextEditingController());
      _contactPhoneControllers.add(TextEditingController());
      _contactRelationControllers.add(TextEditingController());
    }
  }

  Future<void> _loadData() async {
    final id = await _store.loadMedicalId();
    if (mounted) {
      setState(() {
        _currentMedicalId = id;
        _populateFields(id);
        _isLoading = false;
        // If data is empty, start in edit mode
        if (id.name.isEmpty && id.bloodGroup.isEmpty && id.contacts.isEmpty) {
          _isEditing = true;
        }
      });
    }
  }

  void _populateFields(MedicalId id) {
    _nameController.text = id.name;
    _ageController.text = id.ageOrDob;
    _bloodGroupController.text = id.bloodGroup;
    _allergiesController.text = id.allergies;
    _conditionsController.text = id.conditions;
    _medicationsController.text = id.medications;
    _notesController.text = id.notes;

    for (int i = 0; i < 3; i++) {
      if (i < id.contacts.length) {
        _contactNameControllers[i].text = id.contacts[i].name;
        _contactPhoneControllers[i].text = id.contacts[i].phone;
        _contactRelationControllers[i].text = id.contacts[i].relation;
      } else {
        _contactNameControllers[i].clear();
        _contactPhoneControllers[i].clear();
        _contactRelationControllers[i].clear();
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _bloodGroupController.dispose();
    _allergiesController.dispose();
    _conditionsController.dispose();
    _medicationsController.dispose();
    _notesController.dispose();

    for (int i = 0; i < 3; i++) {
      _contactNameControllers[i].dispose();
      _contactPhoneControllers[i].dispose();
      _contactRelationControllers[i].dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final contacts = <EmergencyContact>[];
    for (int i = 0; i < 3; i++) {
      final name = _contactNameControllers[i].text.trim();
      final phone = EmergencyContact.sanitizePhone(_contactPhoneControllers[i].text);
      final rel = _contactRelationControllers[i].text.trim();

      if (name.isNotEmpty || phone.isNotEmpty) {
        contacts.add(EmergencyContact(name: name, phone: phone, relation: rel));
      }
    }

    final newMedicalId = MedicalId(
      name: _nameController.text.trim(),
      ageOrDob: _ageController.text.trim(),
      bloodGroup: _bloodGroupController.text.trim(),
      allergies: _allergiesController.text.trim(),
      conditions: _conditionsController.text.trim(),
      medications: _medicationsController.text.trim(),
      notes: _notesController.text.trim(),
      contacts: contacts,
    );

    final success = await _store.saveMedicalId(newMedicalId);
    if (mounted) {
      if (success) {
        setState(() {
          _currentMedicalId = newMedicalId;
          _isEditing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Medical ID saved successfully.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save Medical ID.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final glass = Theme.of(context).extension<CarePulseGlass>()!;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Medical ID',
          style: TextStyle(
            color: glass.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        actions: [
          if (!_isLoading)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: SizedBox(
                height: 48,
                child: TextButton.icon(
                  onPressed: () {
                    if (_isEditing) {
                      _save();
                    } else {
                      setState(() {
                        _populateFields(_currentMedicalId);
                        _isEditing = true;
                      });
                    }
                  },
                  icon: Icon(_isEditing ? Icons.check_rounded : Icons.edit_rounded,
                      color: glass.accentMint, size: 20),
                  label: Text(
                    _isEditing ? 'Save' : 'Edit',
                    style: TextStyle(
                      color: glass.accentMint,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: GradientBackground(
        child: SafeArea(
          child: _isLoading
              ? Center(child: CircularProgressIndicator(color: glass.accentMint))
              : SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: _isEditing ? _buildEditForm(glass) : _buildMedicalCardView(glass),
                ),
        ),
      ),
    );
  }

  Widget _buildMedicalCardView(CarePulseGlass glass) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Main Medical Card
        GlassCard(
          padding: const EdgeInsets.all(20),
          borderRadius: 24,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: glass.primaryActionGradient,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.badge_rounded, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _currentMedicalId.name.isEmpty ? 'Anonymous User' : _currentMedicalId.name,
                          style: TextStyle(
                            color: glass.textPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_currentMedicalId.ageOrDob.isNotEmpty)
                          Text(
                            'Age / DOB: ${_currentMedicalId.ageOrDob}',
                            style: TextStyle(color: glass.textSecondary, fontSize: 13),
                          ),
                      ],
                    ),
                  ),
                  if (_currentMedicalId.bloodGroup.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE05A4F).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE05A4F), width: 1),
                      ),
                      child: Text(
                        _currentMedicalId.bloodGroup,
                        style: const TextStyle(
                          color: Color(0xFFE05A4F),
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(color: Colors.white24, height: 1),
              const SizedBox(height: 16),

              _buildCardItem('Allergies', _currentMedicalId.allergies, glass, icon: Icons.warning_amber_rounded),
              _buildCardItem('Medical Conditions', _currentMedicalId.conditions, glass, icon: Icons.healing_rounded),
              _buildCardItem('Medications', _currentMedicalId.medications, glass, icon: Icons.medication_rounded),
              _buildCardItem('Important Notes', _currentMedicalId.notes, glass, icon: Icons.note_rounded),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Emergency Contacts Section
        Text(
          'Emergency Contacts',
          style: TextStyle(
            color: glass.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),

        if (_currentMedicalId.contacts.isEmpty)
          GlassCard(
            padding: const EdgeInsets.all(16),
            borderRadius: 18,
            child: Row(
              children: [
                Icon(Icons.contact_phone_outlined, color: glass.accentMint, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'No emergency contacts added yet.',
                    style: TextStyle(color: glass.textSecondary, fontSize: 13),
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() => _isEditing = true),
                  child: Text('Add Now', style: TextStyle(color: glass.accentMint)),
                ),
              ],
            ),
          )
        else
          for (final contact in _currentMedicalId.contacts)
            Padding(
              padding: const EdgeInsets.only(bottom: 10.0),
              child: GlassCard(
                padding: const EdgeInsets.all(14),
                borderRadius: 18,
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: glass.accentMint.withValues(alpha: 0.15),
                      child: Icon(Icons.person_rounded, color: glass.accentMint),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            contact.name,
                            style: TextStyle(color: glass.textPrimary, fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          Text(
                            '${contact.relation.isNotEmpty ? "${contact.relation} • " : ""}${contact.phone}',
                            style: TextStyle(color: glass.textSecondary, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildCardItem(String label, String value, CarePulseGlass glass, {required IconData icon}) {
    if (value.trim().isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 14.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: glass.accentMint),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: glass.textSecondary, fontSize: 11, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(color: glass.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditForm(CarePulseGlass glass) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GlassCard(
            padding: const EdgeInsets.all(16),
            borderRadius: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Personal Details', style: TextStyle(color: glass.accentMint, fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 12),
                _buildFormField(
                  controller: _nameController,
                  label: 'Full Name',
                  hint: 'e.g. John Doe',
                  glass: glass,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildFormField(
                        controller: _ageController,
                        label: 'Age or DOB',
                        hint: 'e.g. 34 or 1990-05-12',
                        glass: glass,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildFormField(
                        controller: _bloodGroupController,
                        label: 'Blood Group',
                        hint: 'e.g. O+, A-, B+',
                        glass: glass,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          GlassCard(
            padding: const EdgeInsets.all(16),
            borderRadius: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Medical Information', style: TextStyle(color: glass.accentMint, fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 12),
                _buildFormField(
                  controller: _allergiesController,
                  label: 'Allergies',
                  hint: 'e.g. Penicillin, Peanuts, Bee stings',
                  glass: glass,
                ),
                const SizedBox(height: 12),
                _buildFormField(
                  controller: _conditionsController,
                  label: 'Chronic Conditions',
                  hint: 'e.g. Asthma, Diabetes, Hypertension',
                  glass: glass,
                ),
                const SizedBox(height: 12),
                _buildFormField(
                  controller: _medicationsController,
                  label: 'Current Medications',
                  hint: 'e.g. Metformin, Albuterol inhaler',
                  glass: glass,
                ),
                const SizedBox(height: 12),
                _buildFormField(
                  controller: _notesController,
                  label: 'Important Notes',
                  hint: 'e.g. Organ donor, Pacemaker implanted',
                  glass: glass,
                  maxLines: 2,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 3 Emergency Contacts
          GlassCard(
            padding: const EdgeInsets.all(16),
            borderRadius: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Emergency Contacts (Up to 3)', style: TextStyle(color: glass.accentMint, fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 12),
                for (int i = 0; i < 3; i++) ...[
                  Text('Contact ${i + 1}', style: TextStyle(color: glass.textSecondary, fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 6),
                  _buildFormField(
                    controller: _contactNameControllers[i],
                    label: 'Name',
                    hint: 'e.g. Jane Doe',
                    glass: glass,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: _buildFormField(
                          controller: _contactPhoneControllers[i],
                          label: 'Phone',
                          hint: '+1234567890',
                          glass: glass,
                          keyboardType: TextInputType.phone,
                          validator: (value) {
                            if (value != null && value.trim().isNotEmpty) {
                              final sanitized = EmergencyContact.sanitizePhone(value);
                              if (sanitized.length < 3) {
                                return 'Enter valid phone number';
                              }
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: _buildFormField(
                          controller: _contactRelationControllers[i],
                          label: 'Relation',
                          hint: 'Spouse/Parent',
                          glass: glass,
                        ),
                      ),
                    ],
                  ),
                  if (i < 2) const Divider(color: Colors.white24, height: 24),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Save Button
          InkWell(
            onTap: _save,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              height: 54,
              decoration: BoxDecoration(
                gradient: glass.primaryActionGradient,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Center(
                child: Text(
                  'Save Medical ID',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildFormField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required CarePulseGlass glass,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      style: TextStyle(color: glass.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: glass.textSecondary, fontSize: 12),
        hintText: hint,
        hintStyle: TextStyle(color: glass.textSecondary.withValues(alpha: 0.6), fontSize: 13),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.05),
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}
