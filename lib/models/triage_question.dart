/// Answers to clarifying follow-up triage questions.
enum TriageAnswer {
  yes,
  no,
  notSure,
  skip,
}

/// Generic clarifying question used for initial rule-based triage.
class TriageQuestion {
  final String id;
  final String text;

  const TriageQuestion({
    required this.id,
    required this.text,
  });

  static const awake = TriageQuestion(
    id: 'awake',
    text: 'Is the person awake and responding?',
  );

  static const breathing = TriageQuestion(
    id: 'breathing',
    text: 'Is the person breathing normally?',
  );
}
