import 'package:shared_preferences/shared_preferences.dart';

class UserProfile {
  final String name;
  final int age;
  final String conditions;
  final String allergies;
  final String medications;

  UserProfile({
    this.name = '',
    this.age = 0,
    this.conditions = '',
    this.allergies = '',
    this.medications = '',
  });

  String get promptContext {
    if (age == 0 && conditions.isEmpty && allergies.isEmpty && medications.isEmpty) {
      return "";
    }
    return """
USER PROFILE (Use this to tailor your medical advice. DO NOT mention this profile unless relevant):
Age: ${age > 0 ? age : 'Unknown'}
Pre-existing Conditions: ${conditions.isEmpty ? 'None reported' : conditions}
Allergies: ${allergies.isEmpty ? 'None reported' : allergies}
Current Medications: ${medications.isEmpty ? 'None reported' : medications}
""";
  }
}

class ProfileService {
  static const _keyName = 'profile_name';
  static const _keyAge = 'profile_age';
  static const _keyConditions = 'profile_conditions';
  static const _keyAllergies = 'profile_allergies';
  static const _keyMedications = 'profile_medications';

  Future<UserProfile> loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    return UserProfile(
      name: prefs.getString(_keyName) ?? '',
      age: prefs.getInt(_keyAge) ?? 0,
      conditions: prefs.getString(_keyConditions) ?? '',
      allergies: prefs.getString(_keyAllergies) ?? '',
      medications: prefs.getString(_keyMedications) ?? '',
    );
  }

  Future<void> saveProfile(UserProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyName, profile.name);
    await prefs.setInt(_keyAge, profile.age);
    await prefs.setString(_keyConditions, profile.conditions);
    await prefs.setString(_keyAllergies, profile.allergies);
    await prefs.setString(_keyMedications, profile.medications);
  }
}
