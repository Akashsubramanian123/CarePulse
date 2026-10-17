import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/history_entry.dart';

/// Service for managing locally stored first-aid query history.
class HistoryStore {
  static const String _prefKey = 'carepulse_query_history';
  static const int maxEntries = 50;

  final SharedPreferences? _prefs;

  HistoryStore({SharedPreferences? prefs}) : _prefs = prefs;

  Future<SharedPreferences> _getPrefs() async {
    return _prefs ?? await SharedPreferences.getInstance();
  }

  /// Loads query history entries, newest first.
  Future<List<HistoryEntry>> loadEntries() async {
    final prefs = await _getPrefs();
    final rawJson = prefs.getString(_prefKey);
    if (rawJson == null || rawJson.isEmpty) {
      return [];
    }

    try {
      final List<dynamic> decoded = jsonDecode(rawJson) as List<dynamic>;
      final entries = decoded
          .map((item) => HistoryEntry.fromJson(item as Map<String, dynamic>))
          .toList();
      // Ensure newest first order
      entries.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return entries;
    } catch (_) {
      return [];
    }
  }

  /// Saves a new entry, prepending it to the list and capping at [maxEntries].
  Future<void> saveEntry(HistoryEntry entry) async {
    final current = await loadEntries();

    // Remove existing if duplicate id exists
    current.removeWhere((e) => e.id == entry.id);

    // Prepend new entry (newest first)
    current.insert(0, entry);

    // Enforce max cap of 50
    final capped =
        current.length > maxEntries ? current.sublist(0, maxEntries) : current;

    final prefs = await _getPrefs();
    final encoded = jsonEncode(capped.map((e) => e.toJson()).toList());
    await prefs.setString(_prefKey, encoded);
  }

  /// Deletes a specific history entry by id.
  Future<void> deleteEntry(String id) async {
    final current = await loadEntries();
    final initialLen = current.length;
    current.removeWhere((e) => e.id == id);

    if (current.length != initialLen) {
      final prefs = await _getPrefs();
      final encoded = jsonEncode(current.map((e) => e.toJson()).toList());
      await prefs.setString(_prefKey, encoded);
    }
  }

  /// Clears all stored query history.
  Future<void> clearAll() async {
    final prefs = await _getPrefs();
    await prefs.remove(_prefKey);
  }
}
