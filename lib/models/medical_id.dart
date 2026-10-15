class EmergencyContact {
  final String name;
  final String phone;
  final String relation;

  const EmergencyContact({
    required this.name,
    required this.phone,
    required this.relation,
  });

  /// Sanitizes phone numbers to only digits and leading '+'.
  static String sanitizePhone(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';
    final hasLeadingPlus = trimmed.startsWith('+');
    final digitsOnly = trimmed.replaceAll(RegExp(r'\D'), '');
    return hasLeadingPlus ? '+$digitsOnly' : digitsOnly;
  }

  factory EmergencyContact.fromJson(Map<String, dynamic> json) {
    return EmergencyContact(
      name: (json['name'] as String? ?? '').trim(),
      phone: sanitizePhone(json['phone'] as String? ?? ''),
      relation: (json['relation'] as String? ?? '').trim(),
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'phone': sanitizePhone(phone),
        'relation': relation,
      };
}

class MedicalId {
  final String name;
  final String ageOrDob;
  final String bloodGroup;
  final String allergies;
  final String conditions;
  final String medications;
  final String notes;
  final List<EmergencyContact> contacts;

  const MedicalId({
    this.name = '',
    this.ageOrDob = '',
    this.bloodGroup = '',
    this.allergies = '',
    this.conditions = '',
    this.medications = '',
    this.notes = '',
    this.contacts = const [],
  });

  factory MedicalId.fromJson(Map<String, dynamic> json) {
    final rawContacts = json['contacts'] as List<dynamic>? ?? [];
    final parsedContacts = rawContacts
        .take(3)
        .map((e) => EmergencyContact.fromJson(e as Map<String, dynamic>))
        .toList();

    return MedicalId(
      name: (json['name'] as String? ?? '').trim(),
      ageOrDob: (json['ageOrDob'] as String? ?? '').trim(),
      bloodGroup: (json['bloodGroup'] as String? ?? '').trim(),
      allergies: (json['allergies'] as String? ?? '').trim(),
      conditions: (json['conditions'] as String? ?? '').trim(),
      medications: (json['medications'] as String? ?? '').trim(),
      notes: (json['notes'] as String? ?? '').trim(),
      contacts: parsedContacts,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'ageOrDob': ageOrDob,
        'bloodGroup': bloodGroup,
        'allergies': allergies,
        'conditions': conditions,
        'medications': medications,
        'notes': notes,
        'contacts': contacts.take(3).map((c) => c.toJson()).toList(),
      };

  MedicalId copyWith({
    String? name,
    String? ageOrDob,
    String? bloodGroup,
    String? allergies,
    String? conditions,
    String? medications,
    String? notes,
    List<EmergencyContact>? contacts,
  }) {
    return MedicalId(
      name: name ?? this.name,
      ageOrDob: ageOrDob ?? this.ageOrDob,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      allergies: allergies ?? this.allergies,
      conditions: conditions ?? this.conditions,
      medications: medications ?? this.medications,
      notes: notes ?? this.notes,
      contacts: (contacts ?? this.contacts).take(3).toList(),
    );
  }
}
