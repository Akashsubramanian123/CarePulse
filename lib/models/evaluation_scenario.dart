class EvaluationScenario {
  final String id;
  final String category;
  final String query;
  final String expectedProtocolId;
  final bool expectedRedFlag;
  final List<List<String>> keyActions;
  final List<String> forbiddenPhrases;
  final String notes;

  const EvaluationScenario({
    required this.id,
    required this.category,
    required this.query,
    required this.expectedProtocolId,
    required this.expectedRedFlag,
    required this.keyActions,
    required this.forbiddenPhrases,
    required this.notes,
  });

  factory EvaluationScenario.fromJson(Map<String, dynamic> json) {
    return EvaluationScenario(
      id: json['id'] as String,
      category: json['category'] as String,
      query: json['query'] as String,
      expectedProtocolId: json['expectedProtocolId'] as String,
      expectedRedFlag: json['expectedRedFlag'] as bool,
      keyActions: (json['keyActions'] as List<dynamic>)
          .map((inner) =>
              (inner as List<dynamic>).map((e) => e.toString()).toList())
          .toList(),
      forbiddenPhrases: (json['forbiddenPhrases'] as List<dynamic>)
          .map((e) => e.toString())
          .toList(),
      notes: json['notes'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'category': category,
        'query': query,
        'expectedProtocolId': expectedProtocolId,
        'expectedRedFlag': expectedRedFlag,
        'keyActions': keyActions,
        'forbiddenPhrases': forbiddenPhrases,
        'notes': notes,
      };
}
