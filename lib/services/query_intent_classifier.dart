enum QueryIntent {
  emergencyMedical,
  appHelp,
  outOfScope,
}

/// Pure classification function for incoming queries.
QueryIntent classify(String text) => QueryIntentClassifier.classify(text);

class QueryIntentClassifier {
  static const Set<String> _emergencyCriticalTerms = {
    'help',
    'emergency',
    'urgent',
    'urgently',
    'ambulance',
    'paramedic',
    'hospital',
    'save me',
    'call 112',
    'call 911',
    'call 999',
  };

  static const Set<String> _thirdPersonReferences = {
    'he',
    'she',
    'someone',
    'somebody',
    'baby',
    'child',
    'kid',
    'man',
    'woman',
    'mother',
    'father',
    'mom',
    'dad',
    'friend',
    'brother',
    'sister',
    'patient',
    'infant',
    'toddler',
    'person',
    'guy',
    'girl',
    'boy',
    'grandpa',
    'grandma',
    'grandmother',
    'grandfather',
    'son',
    'daughter',
    'wife',
    'husband',
    'partner',
  };

  /// Core lexicon of medical terms, symptoms, injuries, and emergency keywords.
  static const Set<String> _medicalLexiconWords = {
    'pain',
    'painful',
    'pains',
    'hurt',
    'hurts',
    'hurting',
    'injured',
    'injuries',
    'injury',
    'bleeding',
    'bleeds',
    'bleed',
    'blood',
    'bloody',
    'burn',
    'burned',
    'burning',
    'burns',
    'bite',
    'bitten',
    'bites',
    'sting',
    'stung',
    'stings',
    'swollen',
    'swelling',
    'swells',
    'broken',
    'break',
    'fracture',
    'fractured',
    'fractures',
    'faint',
    'fainted',
    'fainting',
    'faints',
    'dizzy',
    'dizziness',
    'vomit',
    'vomited',
    'vomiting',
    'vomits',
    'nausea',
    'nauseous',
    'fever',
    'feverish',
    'seizure',
    'seizures',
    'unconscious',
    'breathing',
    'breathe',
    'breath',
    'choking',
    'choke',
    'choked',
    'chokes',
    'poison',
    'poisoned',
    'poisoning',
    'poisons',
    'swallowed',
    'swallow',
    'allergic',
    'allergy',
    'allergies',
    'rash',
    'rashes',
    'chest',
    'head',
    'headache',
    'fell',
    'fall',
    'falling',
    'falls',
    'accident',
    'collapsed',
    'collapse',
    'collapsing',
    'collapses',
    'drown',
    'drowned',
    'drowning',
    'drowns',
    'shock',
    'shocked',
    'sick',
    'sickness',
    'unwell',
    'ill',
    'illness',
    'weak',
    'weakness',
    'pale',
    'paleness',
    'confused',
    'confusion',
    'strange',
    'wound',
    'wounds',
    'cut',
    'cuts',
    'gash',
    'artery',
    'hemorrhage',
    'laceration',
    'scald',
    'scalds',
    'heat',
    'thermal',
    'blister',
    'blisters',
    'airway',
    'gagging',
    'throat',
    'snakebite',
    'snake',
    'viper',
    'venom',
    'wasp',
    'bee',
    'hornet',
    'insect',
    'spider',
    'scorpion',
    'cardiac',
    'arrest',
    'pulse',
    'heartbeat',
    'cpr',
    'stroke',
    'drooping',
    'slurred',
    'numb',
    'numbness',
    'tingling',
    'seizing',
    'convulsion',
    'convulsions',
    'fit',
    'fits',
    'shaking',
    'tremor',
    'shivering',
    'chills',
    'hypothermia',
    'freezing',
    'frostbite',
    'heatstroke',
    'sunstroke',
    'hyperthermia',
    'bleach',
    'chemical',
    'pills',
    'overdose',
    'epipen',
    'anaphylaxis',
    'nosebleed',
    'epistaxis',
    'syncope',
    'passed out',
    'blacked out',
    'unresponsive',
    'asphyxiation',
    'electrocuted',
    'electrocution',
    'tourniquet',
    'bandage',
    'splint',
    'concussion',
    'sprain',
    'dislocation',
  };

  /// Multi-word medical / emergency phrases.
  static const List<String> _medicalPhrases = [
    'spurting blood',
    'cannot breathe',
    'unable to breathe',
    'trouble breathing',
    'shortness of breath',
    'difficulty breathing',
    'hard to breathe',
    'heart attack',
    'chest pain',
    'chest pressure',
    'clutching throat',
    'electric shock',
    'high voltage',
    'passed out',
    'blacked out',
    'not breathing',
    'no pulse',
    'loss of consciousness',
    'swallowed chemical',
    'drain cleaner',
    'face drooping',
    'slurred speech',
    'recovery position',
    'abdominal thrusts',
    'back blows',
    'rescue breaths',
    'deep cut',
    'heavy bleeding',
    'bone break',
    'broken bone',
    'broken leg',
    'broken arm',
    'hot oil burn',
    'boiling water',
    'severe bleeding',
    'severe pain',
    'stomach pain',
    'abdominal pain',
    'eye injury',
    'object in eye',
    'chemical in eye',
  ];

  static const List<String> _identityPhrases = [
    'who are you',
    'what are you',
    'what is carepulse',
    'who made you',
    'are you a doctor',
    'are you doctor',
    'are you real doctor',
  ];

  static const List<String> _capabilityPhrases = [
    'what can you do',
    'how do you work',
    'how does this work',
    'how does carepulse work',
    'do you need internet',
    'are you offline',
    'can you work offline',
    'can you work without internet',
    'how to use',
    'how do i use',
  ];

  static const List<String> _greetingPhrases = [
    'good morning',
    'good afternoon',
    'good evening',
    'good day',
    'hi there',
    'hello there',
    'hey there',
  ];

  static const Set<String> _greetingWords = {
    'hi',
    'hello',
    'hey',
    'greetings',
    'howdy',
  };

  static const Set<String> _thanksByeWords = {
    'thanks',
    'thank',
    'thx',
    'bye',
    'goodbye',
    'ok',
    'okay',
    'alright',
  };

  /// Normalizes input text by lowering case, removing punctuation, and collapsing whitespace.
  static String normalize(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r"[^\w\s']"), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Classifies a query into [QueryIntent.emergencyMedical], [QueryIntent.appHelp], or [QueryIntent.outOfScope].
  static QueryIntent classify(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return QueryIntent.outOfScope;

    final norm = normalize(trimmed);
    if (norm.isEmpty) return QueryIntent.outOfScope;

    final words =
        norm.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

    // 1. Critical safety emergency override: "help", "help me", "emergency", "urgent" MUST NEVER be appHelp
    for (final term in _emergencyCriticalTerms) {
      if (term.contains(' ')) {
        if (norm.contains(term)) return QueryIntent.emergencyMedical;
      } else {
        if (words.contains(term)) return QueryIntent.emergencyMedical;
      }
    }

    // 2. Check medical phrases
    for (final phrase in _medicalPhrases) {
      if (norm.contains(phrase)) {
        return QueryIntent.emergencyMedical;
      }
    }

    // 3. Check medical lexicon words
    for (final word in words) {
      if (_medicalLexiconWords.contains(word)) {
        return QueryIntent.emergencyMedical;
      }
    }

    // 4. Third-person reference with 3 or more words
    if (words.length >= 3) {
      final hasThirdPerson =
          words.any((w) => _thirdPersonReferences.contains(w));
      if (hasThirdPerson) {
        return QueryIntent.emergencyMedical;
      }
    }

    // 5. Check appHelp patterns
    // 5a. Identity
    for (final phrase in _identityPhrases) {
      if (norm.contains(phrase)) {
        return QueryIntent.appHelp;
      }
    }

    // 5b. Capability / Usage
    for (final phrase in _capabilityPhrases) {
      if (norm.contains(phrase)) {
        return QueryIntent.appHelp;
      }
    }

    // 5c. Multi-word greetings
    for (final phrase in _greetingPhrases) {
      if (norm.contains(phrase)) {
        return QueryIntent.appHelp;
      }
    }

    // 5d. Single word greetings (or short greetings like "hi CarePulse")
    if (words.isNotEmpty && _greetingWords.contains(words.first)) {
      if (words.length <= 4) {
        return QueryIntent.appHelp;
      }
    }

    // 5e. Thanks / Bye / Ok
    if (norm == 'thank you' ||
        norm == 'thank you very much' ||
        norm == 'thanks a lot') {
      return QueryIntent.appHelp;
    }
    if (words.isNotEmpty &&
        words.every((w) =>
            _thanksByeWords.contains(w) || w == 'you' || w == 'carepulse')) {
      return QueryIntent.appHelp;
    }

    // 6. Otherwise outOfScope
    return QueryIntent.outOfScope;
  }

  /// Generates the standard local reply for appHelp or outOfScope queries.
  static String getLocalReply(
    String query,
    QueryIntent intent, {
    String emergencyNumber = '112',
  }) {
    final norm = normalize(query);
    final words =
        norm.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

    if (intent == QueryIntent.appHelp) {
      // Thanks / bye / ok
      if (norm == 'thank you' ||
          norm == 'thank you very much' ||
          norm == 'thanks a lot' ||
          (words.isNotEmpty &&
              words.every((w) =>
                  _thanksByeWords.contains(w) ||
                  w == 'you' ||
                  w == 'carepulse'))) {
        return "You're welcome. Stay safe.";
      }

      // Greeting
      final isGreeting = _greetingPhrases.any((p) => norm.contains(p)) ||
          (words.isNotEmpty && _greetingWords.contains(words.first));
      if (isGreeting) {
        return "Hello! I'm CarePulse, an offline first-aid assistant that runs on your phone. "
            "Describe what's happening, for example 'someone is choking', or tap a quick trigger. "
            "I'm not a doctor. In a serious emergency call $emergencyNumber.";
      }

      // Identity / capability
      return "I'm CarePulse, an offline first-aid assistant that runs on your phone. "
          "Describe what's happening, for example 'someone is choking', or tap a quick trigger. "
          "I'm not a doctor. In a serious emergency call $emergencyNumber.";
    }

    // outOfScope
    return "I can help with first aid and emergencies. "
        "Describe what's happening, for example 'someone fell and is bleeding'. "
        "If someone needs urgent help, call $emergencyNumber.";
  }
}
