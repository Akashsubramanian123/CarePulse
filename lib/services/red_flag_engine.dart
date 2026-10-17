class RedFlagResult {
  final String protocolId;
  final String matchedReason;
  final String triggerPhrase;

  const RedFlagResult({
    required this.protocolId,
    required this.matchedReason,
    required this.triggerPhrase,
  });
}

class RedFlagEngine {
  static const List<String> _negationTokens = [
    'not',
    'no',
    'never',
    'without',
    "isn't",
    "isnt",
    "aren't",
    "arent",
    "wasn't",
    "wasnt",
    "doesn't",
    "doesnt",
    "didn't",
    "didnt",
    'stopped',
    'stopped',
    'clear',
    'free',
    'resolved',
    'none',
  ];

  /// Evaluates the input text against red-flag clinical rules.
  /// Returns a RedFlagResult if a critical rule is triggered, or null otherwise.
  RedFlagResult? evaluate(String text) {
    if (text.trim().isEmpty) return null;

    final normalized = _normalize(text);
    if (normalized.isEmpty) return null;

    // Check each red flag rule in clinical priority order
    return _checkCardiacArrest(normalized, text) ??
        _checkUnresponsive(normalized, text) ??
        _checkSevereBleeding(normalized, text) ??
        _checkChoking(normalized, text) ??
        _checkSeizure(normalized, text) ??
        _checkStroke(normalized, text) ??
        _checkAnaphylaxis(normalized, text) ??
        _checkChestPain(normalized, text) ??
        _checkDrowning(normalized, text) ??
        _checkElectricShock(normalized, text) ??
        _checkPoisoning(normalized, text) ??
        _checkHeatstroke(normalized, text) ??
        _checkSnakebite(normalized, text);
  }

  static String _normalize(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp(r"[^\w\s']"), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Checks if a matched phrase has a negation token immediately preceding it (within 1-3 words).
  static bool _isNegatedBefore(String text, String phrase,
      {int maxPrecedingWords = 3}) {
    final idx = text.indexOf(phrase);
    if (idx <= 0) return false;

    final precedingText = text.substring(0, idx).trim();
    final words = precedingText.split(RegExp(r'\s+'));
    final window = words.length > maxPrecedingWords
        ? words.sublist(words.length - maxPrecedingWords)
        : words;

    return window.any((w) => _negationTokens.contains(w));
  }

  // 1. Not breathing / no pulse / cardiac arrest
  RedFlagResult? _checkCardiacArrest(String norm, String raw) {
    // False positives like "breathing normally", "breathing fine"
    if (norm.contains('breathing normally') ||
        norm.contains('breathing fine') ||
        norm.contains('breathing okay') ||
        norm.contains('normal breathing') ||
        norm.contains('breathing well')) {
      return null;
    }

    final positiveTriggers = [
      'not breathing',
      'stopped breathing',
      'cant breathe',
      "can't breathe",
      'cannot breathe',
      'no pulse',
      'no heartbeat',
      'heart stopped',
      'cardiac arrest',
      'pulseless',
      'agonal gasps',
      'gasping for air stopped',
      'respiratory arrest',
    ];

    for (final trigger in positiveTriggers) {
      if (norm.contains(trigger)) {
        return RedFlagResult(
          protocolId: 'cardiac_arrest',
          matchedReason: 'Respiratory or cardiac arrest detected ($trigger)',
          triggerPhrase: trigger,
        );
      }
    }
    return null;
  }

  // 2. Unconscious / unresponsive
  RedFlagResult? _checkUnresponsive(String norm, String raw) {
    // Negation: conscious, awake, talking, alert
    if (norm.contains('is conscious') ||
        norm.contains('she is conscious') ||
        norm.contains('he is conscious') ||
        norm.contains('conscious and') ||
        norm.contains('conscious talking') ||
        norm.contains('awake and') ||
        norm.contains('talking normally') ||
        norm.contains('not unconscious') ||
        norm.contains('not unresponsive')) {
      return null;
    }

    final triggers = [
      'unresponsive',
      'unconscious',
      'passed out and wont wake',
      'passed out and cannot wake',
      'collapsed and unresponsive',
      'blacked out and unresponsive',
      'found unresponsive',
      'cannot wake',
      'wont wake up',
      'comatose',
    ];

    for (final trigger in triggers) {
      if (norm.contains(trigger) && !_isNegatedBefore(norm, trigger)) {
        return RedFlagResult(
          protocolId: 'unconscious_breathing',
          matchedReason: 'Unresponsiveness or loss of consciousness detected',
          triggerPhrase: trigger,
        );
      }
    }
    return null;
  }

  // 3. Severe or spurting bleeding
  RedFlagResult? _checkSevereBleeding(String norm, String raw) {
    if (norm.contains('not bleeding') ||
        norm.contains('no bleeding') ||
        norm.contains('stopped bleeding') ||
        norm.contains('isnt bleeding') ||
        norm.contains("isn't bleeding") ||
        norm.contains('paper cut') ||
        norm.contains('small cut') ||
        norm.contains('tiny scratch')) {
      return null;
    }

    final triggers = [
      'spurting',
      'spurt',
      'blood is spurting',
      'spurting blood',
      'severe bleeding',
      'bleeding severely',
      'heavy bleeding',
      'bleeding heavily',
      'profuse bleeding',
      'arterial bleed',
      'blood pouring',
      'gushing blood',
      'uncontrolled bleeding',
      'soaked in blood',
    ];

    for (final trigger in triggers) {
      if (norm.contains(trigger) && !_isNegatedBefore(norm, trigger)) {
        return RedFlagResult(
          protocolId: 'bleeding',
          matchedReason: 'Severe or arterial bleeding detected ($trigger)',
          triggerPhrase: trigger,
        );
      }
    }
    return null;
  }

  // 4. Choking and unable to breathe or cough
  RedFlagResult? _checkChoking(String norm, String raw) {
    if (norm.contains('not choking') ||
        norm.contains('can cough') ||
        norm.contains('coughing forcefully') ||
        norm.contains('coughing normally') ||
        norm.contains('breathing fine')) {
      return null;
    }

    final triggers = [
      'choking',
      'choke',
      'cannot cough',
      'cant cough',
      "can't cough",
      'unable to cough',
      'unable to breathe or cough',
      'food lodged in throat',
      'airway obstructed',
    ];

    for (final trigger in triggers) {
      if (norm.contains(trigger) && !_isNegatedBefore(norm, trigger)) {
        // Map pediatric vs adult if mentioned
        final isChild = norm.contains('child') ||
            norm.contains('kid') ||
            norm.contains('toddler');
        final isInfant = norm.contains('infant') ||
            norm.contains('baby') ||
            norm.contains('newborn');
        final targetId = isInfant
            ? 'choking_infant'
            : (isChild ? 'choking_child' : 'choking');

        return RedFlagResult(
          protocolId: targetId,
          matchedReason: 'Airway obstruction or choking detected',
          triggerPhrase: trigger,
        );
      }
    }
    return null;
  }

  // 5. Seizure in progress
  RedFlagResult? _checkSeizure(String norm, String raw) {
    if (norm.contains('not seizing') ||
        norm.contains('no seizure') ||
        norm.contains('shaking hands with')) {
      return null;
    }

    final triggers = [
      'seizure',
      'convulsion',
      'convulsing',
      'having a fit',
      'epileptic fit',
      'shaking and fell',
      'foaming at the mouth',
      'shaking violently',
    ];

    for (final trigger in triggers) {
      if (norm.contains(trigger) && !_isNegatedBefore(norm, trigger)) {
        return RedFlagResult(
          protocolId: 'seizure',
          matchedReason: 'Active seizure or convulsion detected',
          triggerPhrase: trigger,
        );
      }
    }
    return null;
  }

  // 6. Suspected stroke (FAST)
  RedFlagResult? _checkStroke(String norm, String raw) {
    if (norm.contains('no stroke') ||
        norm.contains('not a stroke') ||
        norm.contains('speech is normal') ||
        norm.contains('no drooping')) {
      return null;
    }

    final triggers = [
      'stroke',
      'face drooping',
      'facial drooping',
      'face droop',
      'arm weakness',
      'slurred speech',
      'slurring words',
      'cannot move one side of face',
      'loss of speech sudden',
    ];

    for (final trigger in triggers) {
      if (norm.contains(trigger) && !_isNegatedBefore(norm, trigger)) {
        return RedFlagResult(
          protocolId: 'stroke',
          matchedReason: 'Suspected stroke symptom detected ($trigger)',
          triggerPhrase: trigger,
        );
      }
    }
    return null;
  }

  // 7. Anaphylaxis
  RedFlagResult? _checkAnaphylaxis(String norm, String raw) {
    if (norm.contains('no swelling') ||
        norm.contains('not allergic') ||
        norm.contains('no allergy')) {
      return null;
    }

    final triggers = [
      'anaphylaxis',
      'anaphylactic',
      'swelling of face or throat',
      'swelling throat',
      'throat swelling',
      'swollen tongue',
      'swelling after sting',
      'epipen needed',
      'severe allergic reaction',
    ];

    for (final trigger in triggers) {
      if (norm.contains(trigger) && !_isNegatedBefore(norm, trigger)) {
        return RedFlagResult(
          protocolId: 'anaphylaxis',
          matchedReason: 'Severe allergic reaction or anaphylaxis detected',
          triggerPhrase: trigger,
        );
      }
    }
    return null;
  }

  // 8. Chest pain with sweating or arm pain
  RedFlagResult? _checkChestPain(String norm, String raw) {
    if (norm.contains('no chest pain') ||
        norm.contains('not chest pain') ||
        norm.contains('without chest pain') ||
        norm.contains('no pain in chest')) {
      return null;
    }

    final triggers = [
      'chest pain',
      'heart attack',
      'crushing chest',
      'pain radiating down arm',
      'chest pressure and sweating',
      'chest pain and sweating',
      'tightness in chest',
    ];

    for (final trigger in triggers) {
      if (norm.contains(trigger) && !_isNegatedBefore(norm, trigger)) {
        return RedFlagResult(
          protocolId: 'chest_pain',
          matchedReason: 'Cardiac emergency symptom detected ($trigger)',
          triggerPhrase: trigger,
        );
      }
    }
    return null;
  }

  // 9. Drowning
  RedFlagResult? _checkDrowning(String norm, String raw) {
    if (norm.contains('not drowning') || norm.contains('swimming normally')) {
      return null;
    }

    final triggers = [
      'drowning',
      'drowned',
      'submerged in water',
      'pulled out of pool',
      'water aspiration',
      'submersion accident',
    ];

    for (final trigger in triggers) {
      if (norm.contains(trigger) && !_isNegatedBefore(norm, trigger)) {
        return RedFlagResult(
          protocolId: 'drowning',
          matchedReason: 'Drowning or submersion emergency detected',
          triggerPhrase: trigger,
        );
      }
    }
    return null;
  }

  // 10. Electric shock
  RedFlagResult? _checkElectricShock(String norm, String raw) {
    if (norm.contains('no shock') ||
        norm.contains('static shock') ||
        norm.contains('static electricity')) {
      return null;
    }

    final triggers = [
      'electric shock',
      'electrocuted',
      'electrocution',
      'high voltage',
      'shocked by wire',
      'power line shock',
    ];

    for (final trigger in triggers) {
      if (norm.contains(trigger) && !_isNegatedBefore(norm, trigger)) {
        return RedFlagResult(
          protocolId: 'electric_shock',
          matchedReason: 'Electric shock trauma detected',
          triggerPhrase: trigger,
        );
      }
    }
    return null;
  }

  // 11. Poisoning or swallowed chemical
  RedFlagResult? _checkPoisoning(String norm, String raw) {
    if (norm.contains('not poisoned') || norm.contains('no poison')) {
      return null;
    }

    final triggers = [
      'poisoning',
      'poison',
      'swallowed bleach',
      'swallowed chemical',
      'ingested chemical',
      'drank detergent',
      'drug overdose',
      'swallowed pills overdose',
      'swallowed toxic',
    ];

    for (final trigger in triggers) {
      if (norm.contains(trigger) && !_isNegatedBefore(norm, trigger)) {
        return RedFlagResult(
          protocolId: 'poisoning',
          matchedReason: 'Poisoning or toxic ingestion detected',
          triggerPhrase: trigger,
        );
      }
    }
    return null;
  }

  // 12. Heatstroke with confusion
  RedFlagResult? _checkHeatstroke(String norm, String raw) {
    if (norm.contains('not heatstroke') || norm.contains('just warm')) {
      return null;
    }

    final triggers = [
      'heatstroke',
      'heat stroke',
      'heat exhaustion and confused',
      'collapsed in hot sun',
      'high body temperature and confusion',
      'sunstroke',
    ];

    for (final trigger in triggers) {
      if (norm.contains(trigger) && !_isNegatedBefore(norm, trigger)) {
        return RedFlagResult(
          protocolId: 'heatstroke',
          matchedReason: 'Heatstroke emergency detected',
          triggerPhrase: trigger,
        );
      }
    }
    return null;
  }

  // 13. Snakebite
  RedFlagResult? _checkSnakebite(String norm, String raw) {
    if (norm.contains('not a snake') ||
        norm.contains('no bite') ||
        norm.contains('saw a snake')) {
      return null;
    }

    final triggers = [
      'snakebite',
      'snake bite',
      'snake bit',
      'bitten by a snake',
      'viper bite',
      'cobra bite',
      'rattlesnake bite',
    ];

    for (final trigger in triggers) {
      if (norm.contains(trigger) && !_isNegatedBefore(norm, trigger)) {
        return RedFlagResult(
          protocolId: 'snakebite',
          matchedReason: 'Venomous snakebite detected',
          triggerPhrase: trigger,
        );
      }
    }
    return null;
  }
}
