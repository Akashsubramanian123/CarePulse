class Protocol {
  final String id;
  final String title;
  final List<String> keywords;
  final List<String> synonyms;
  final String immediate;
  final String precaution;
  final String monitor;
  final List<String> doNot;
  final bool callEmergency;
  final List<String> sources;
  final String? lastReviewed;
  final String? reviewedBy;
  final String? iconName;

  const Protocol({
    required this.id,
    required this.title,
    required this.keywords,
    required this.synonyms,
    required this.immediate,
    required this.precaution,
    required this.monitor,
    required this.doNot,
    required this.callEmergency,
    required this.sources,
    this.lastReviewed,
    this.reviewedBy,
    this.iconName,
  });

  factory Protocol.fromJson(Map<String, dynamic> json) {
    return Protocol(
      id: json['id'] as String,
      title: json['title'] as String,
      keywords: (json['keywords'] as List<dynamic>).map((e) => e.toString()).toList(),
      synonyms: (json['synonyms'] as List<dynamic>).map((e) => e.toString()).toList(),
      immediate: json['immediate'] as String,
      precaution: json['precaution'] as String,
      monitor: json['monitor'] as String,
      doNot: (json['doNot'] as List<dynamic>).map((e) => e.toString()).toList(),
      callEmergency: json['callEmergency'] as bool? ?? false,
      sources: (json['sources'] as List<dynamic>).map((e) => e.toString()).toList(),
      lastReviewed: json['lastReviewed'] as String?,
      reviewedBy: json['reviewedBy'] as String?,
      iconName: json['iconName'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'keywords': keywords,
      'synonyms': synonyms,
      'immediate': immediate,
      'precaution': precaution,
      'monitor': monitor,
      'doNot': doNot,
      'callEmergency': callEmergency,
      'sources': sources,
      'lastReviewed': lastReviewed,
      'reviewedBy': reviewedBy,
      if (iconName != null) 'iconName': iconName,
    };
  }

  /// Formatted 3-step representation matching the app's standard format.
  String toFormattedSteps() {
    return '1. IMMEDIATE ACTION: $immediate\n2. CRITICAL PRECAUTION: $precaution\n3. MONITOR & STABILIZE: $monitor';
  }

  /// Compact representation for LLM context injection (capped to maxChars).
  String toCompactContext({int maxChars = 1200}) {
    final buffer = StringBuffer();
    buffer.writeln('Protocol: $title');
    buffer.writeln('Immediate: $immediate');
    buffer.writeln('Precaution: $precaution');
    if (doNot.isNotEmpty) {
      buffer.writeln('Do Not: ${doNot.join('; ')}');
    }
    final text = buffer.toString().trim();
    if (text.length > maxChars) {
      return text.substring(0, maxChars);
    }
    return text;
  }
}
