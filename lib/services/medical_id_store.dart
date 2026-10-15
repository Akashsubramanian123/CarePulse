import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/medical_id.dart';

class MedicalIdStore {
  static const String _key = 'carepulse_medical_id';
  final SharedPreferences? _prefs;

  MedicalIdStore([this._prefs]);

  Future<SharedPreferences> _getPrefs() async {
    return _prefs ?? await SharedPreferences.getInstance();
  }

  Future<MedicalId> loadMedicalId() async {
    try {
      final prefs = await _getPrefs();
      final jsonStr = prefs.getString(_key);
      if (jsonStr == null || jsonStr.isEmpty) {
        return const MedicalId();
      }
      final decoded = json.decode(jsonStr) as Map<String, dynamic>;
      return MedicalId.fromJson(decoded);
    } catch (_) {
      return const MedicalId();
    }
  }

  Future<bool> saveMedicalId(MedicalId medicalId) async {
    try {
      final prefs = await _getPrefs();
      final jsonStr = json.encode(medicalId.toJson());
      return await prefs.setString(_key, jsonStr);
    } catch (_) {
      return false;
    }
  }
}
