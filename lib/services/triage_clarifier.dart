import '../core/constants/app_constants.dart';
import '../models/triage_question.dart';
import 'protocol_retriever.dart';
import 'red_flag_engine.dart';

/// Rule-based triage clarifier for vague or low-confidence emergency queries.
class TriageClarifier {
  static const String unresponsiveProtocolId = 'unconscious_breathing';
  static const String cardiacArrestProtocolId = 'cardiac_arrest';
  static const String emergencyClarificationNote =
      'Treating this as an emergency because the answer was No or Not sure.';
  static const String normalObservationContext =
      'Person is awake and breathing normally.';

  final ProtocolRetriever _protocolRetriever;
  final RedFlagEngine _redFlagEngine;

  const TriageClarifier({
    required ProtocolRetriever protocolRetriever,
    required RedFlagEngine redFlagEngine,
  })  : _protocolRetriever = protocolRetriever,
        _redFlagEngine = redFlagEngine;

  /// Determines whether follow-up clarifying questions should be asked for [query].
  bool shouldAskClarification(
    String query, {
    bool alreadyClarified = false,
  }) {
    final trimmed = query.trim();
    if (trimmed.isEmpty || alreadyClarified) return false;

    // 1. Never ask if red flag engine matches
    if (_redFlagEngine.evaluate(trimmed) != null) {
      return false;
    }

    // 2. Never ask for clear presets
    final lower = trimmed.toLowerCase();
    for (final preset in emergencyPresets) {
      if (preset.query.toLowerCase() == lower ||
          preset.title.toLowerCase() == lower) {
        return false;
      }
    }

    // 3. Never ask for clear matches above retriever confidence threshold
    final scored = _protocolRetriever.scoreProtocols(trimmed);
    final bool hasClearMatch = scored.isNotEmpty &&
        scored.first.score >= _protocolRetriever.minScoreThreshold;

    if (hasClearMatch) {
      return false;
    }

    // 4. Ask if retriever top score is below threshold OR query is shorter than 4 words
    final words =
        trimmed.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    final bool isShort = words < 4;

    return !hasClearMatch || isShort;
  }

  /// Returns the first question in the clarification flow.
  TriageQuestion get firstQuestion => TriageQuestion.awake;

  /// Returns the next question, or null if the questionnaire ends.
  TriageQuestion? nextQuestion(TriageQuestion current, TriageAnswer answer) {
    if (current.id == TriageQuestion.awake.id) {
      if (answer == TriageAnswer.yes) {
        return TriageQuestion.breathing;
      }
      return null;
    }
    return null;
  }
}
