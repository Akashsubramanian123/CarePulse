import '../state/triage_controller.dart';

/// Represents a locally saved triage query and its response.
class HistoryEntry {
  final String id;
  final DateTime timestamp;
  final String query;
  final String response;
  final AnswerSource answerSource;
  final String? protocolId;

  const HistoryEntry({
    required this.id,
    required this.timestamp,
    required this.query,
    required this.response,
    required this.answerSource,
    this.protocolId,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'query': query,
      'response': response,
      'answerSource': answerSource.name,
      'protocolId': protocolId,
    };
  }

  factory HistoryEntry.fromJson(Map<String, dynamic> json) {
    final sourceName = json['answerSource'] as String?;
    AnswerSource source = AnswerSource.aiGenerated;
    if (sourceName != null) {
      for (final val in AnswerSource.values) {
        if (val.name == sourceName) {
          source = val;
          break;
        }
      }
    }

    return HistoryEntry(
      id: json['id'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      query: json['query'] as String,
      response: json['response'] as String,
      answerSource: source,
      protocolId: json['protocolId'] as String?,
    );
  }
}
