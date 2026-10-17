import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/benchmark_result.dart';

class BenchmarkStore {
  static const String _storageKey = 'carepulse_benchmark_runs';
  static const int maxStoredRuns = 20;

  Future<List<BenchmarkRun>> getRuns() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList(_storageKey) ?? [];
    return jsonList
        .map((item) {
          try {
            return BenchmarkRun.fromJson(
                json.decode(item) as Map<String, dynamic>);
          } catch (_) {
            return null;
          }
        })
        .whereType<BenchmarkRun>()
        .toList();
  }

  Future<void> saveRun(BenchmarkRun run) async {
    final prefs = await SharedPreferences.getInstance();
    final existingRuns = await getRuns();

    // Replace if id matches (e.g. manual score update), otherwise prepend
    final updated = [
      run,
      ...existingRuns.where((r) => r.id != run.id),
    ];

    if (updated.length > maxStoredRuns) {
      updated.removeRange(maxStoredRuns, updated.length);
    }

    final jsonList = updated.map((r) => json.encode(r.toJson())).toList();
    await prefs.setStringList(_storageKey, jsonList);
  }

  Future<void> clearRuns() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }
}
