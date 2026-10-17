import '../models/protocol.dart';
import 'protocol_repository.dart';

class ScoredProtocol {
  final Protocol protocol;
  final double score;

  const ScoredProtocol(this.protocol, this.score);
}

class ProtocolRetriever {
  final ProtocolRepository repository;
  final double minScoreThreshold;

  static const Set<String> _stopWords = {
    'a',
    'an',
    'the',
    'and',
    'or',
    'but',
    'is',
    'are',
    'was',
    'were',
    'in',
    'on',
    'at',
    'to',
    'for',
    'of',
    'with',
    'by',
    'from',
    'about',
    'he',
    'she',
    'it',
    'they',
    'i',
    'me',
    'him',
    'them',
    'us',
    'we',
    'you',
    'my',
    'his',
    'her',
    'their',
    'its',
    'our',
    'your',
    'has',
    'have',
    'had',
    'do',
    'does',
    'did',
    'be',
    'been',
    'being',
    'that',
    'this',
    'there',
    'what',
    'not',
    'no',
    'well',
    'help',
    'please',
  };

  const ProtocolRetriever(
    this.repository, {
    this.minScoreThreshold = 2.5,
  });

  /// Returns the top k protocols matching the query above the minimum score threshold.
  List<Protocol> topMatches(String query, {int k = 2}) {
    final scored = scoreProtocols(query);
    final filtered = scored.where((s) => s.score >= minScoreThreshold).toList();
    filtered.sort((a, b) => b.score.compareTo(a.score));

    return filtered.take(k).map((s) => s.protocol).toList();
  }

  /// Calculates a match score for all protocols against the query.
  List<ScoredProtocol> scoreProtocols(String query) {
    final protocols = repository.allProtocols;
    if (protocols.isEmpty) return const [];

    final normalizedQuery = query.toLowerCase();
    final tokens = _tokenize(normalizedQuery);
    if (tokens.isEmpty) return const [];

    final results = <ScoredProtocol>[];

    final isAwakeOrConscious = normalizedQuery.contains('awake') ||
        normalizedQuery.contains('conscious') ||
        normalizedQuery.contains('alert') ||
        normalizedQuery.contains('talking') ||
        normalizedQuery.contains('speaking') ||
        normalizedQuery.contains('crying') ||
        normalizedQuery.contains('standing') ||
        normalizedQuery.contains('walking');

    final hasNormalBreathing = normalizedQuery.contains('breathing normally') ||
        normalizedQuery.contains('normal breathing') ||
        normalizedQuery.contains('breathing fine') ||
        normalizedQuery.contains('breathing okay') ||
        normalizedQuery.contains('breathing well');

    final hasAnaphylaxisSigns = normalizedQuery.contains('throat closing') ||
        normalizedQuery.contains('swelling throat') ||
        normalizedQuery.contains('epipen') ||
        normalizedQuery.contains('tongue swelling') ||
        normalizedQuery.contains('lip swelling');

    for (final protocol in protocols) {
      // Clinical exclusion: an awake/conscious person is not unconscious
      if (protocol.id == 'unconscious_breathing' && isAwakeOrConscious) {
        continue;
      }

      // Clinical exclusion: verified normal breathing excludes cardiac arrest
      if (protocol.id == 'cardiac_arrest' && hasNormalBreathing) {
        continue;
      }

      double score = 0.0;

      // 1. Exact phrase matches in keywords, synonyms, title
      final titleNorm = protocol.title.toLowerCase();
      if (normalizedQuery.contains(titleNorm)) {
        score += 8.0;
      }

      for (final kw in protocol.keywords) {
        final kwNorm = kw.toLowerCase();
        if (kwNorm.contains(' ') && normalizedQuery.contains(kwNorm)) {
          score += 6.0;
        }
      }

      for (final syn in protocol.synonyms) {
        final synNorm = syn.toLowerCase();
        if (synNorm.contains(' ') && normalizedQuery.contains(synNorm)) {
          score += 6.0;
        }
      }

      // 2. Token overlap scoring
      final titleTokens = _tokenize(titleNorm);
      final kwTokens = protocol.keywords.expand(_tokenize).toSet();
      final synTokens = protocol.synonyms.expand(_tokenize).toSet();

      for (final token in tokens) {
        // Title token match
        if (titleTokens.contains(token)) {
          score += 4.0;
        } else if (titleTokens.any((t) => _isFuzzyMatch(t, token))) {
          score += 2.0;
        }

        // Keyword token match
        if (kwTokens.contains(token)) {
          score += 3.0;
        } else if (kwTokens.any((k) => _isFuzzyMatch(k, token))) {
          score += 1.5;
        }

        // Synonym token match
        if (synTokens.contains(token)) {
          score += 2.5;
        } else if (synTokens.any((s) => _isFuzzyMatch(s, token))) {
          score += 1.0;
        }
      }

      // 3. Clinical domain and condition-specific boosts
      final hasChokingSigns = normalizedQuery.contains('chok') ||
          normalizedQuery.contains('airway') ||
          normalizedQuery.contains('cough') ||
          normalizedQuery.contains('throat') ||
          normalizedQuery.contains('gag') ||
          normalizedQuery.contains('cannot breathe') ||
          normalizedQuery.contains('toy') ||
          normalizedQuery.contains('grape');

      if (protocol.id == 'choking_child') {
        if (hasChokingSigns &&
            (normalizedQuery.contains('child') ||
                normalizedQuery.contains('kid') ||
                normalizedQuery.contains('toddler') ||
                normalizedQuery.contains('chld'))) {
          score += 10.0;
        }
        if (normalizedQuery.contains('infant') ||
            normalizedQuery.contains('baby')) {
          score -= 5.0;
        }
      } else if (protocol.id == 'choking_infant') {
        if (hasChokingSigns &&
            (normalizedQuery.contains('infant') ||
                normalizedQuery.contains('baby') ||
                normalizedQuery.contains('newborn'))) {
          score += 10.0;
        }
        if (normalizedQuery.contains('child') ||
            normalizedQuery.contains('toddler') ||
            normalizedQuery.contains('kid')) {
          score -= 5.0;
        }
      } else if (protocol.id == 'snakebite') {
        if (normalizedQuery.contains('snak') ||
            normalizedQuery.contains('snake') ||
            normalizedQuery.contains('viper') ||
            normalizedQuery.contains('cobra') ||
            normalizedQuery.contains('fang')) {
          score += 12.0;
        }
      } else if (protocol.id == 'nosebleed') {
        if (normalizedQuery.contains('nose') ||
            normalizedQuery.contains('nasal')) {
          score += 8.0;
        }
      } else if (protocol.id == 'eye_injury') {
        if (normalizedQuery.contains('eye') ||
            normalizedQuery.contains('eyes') ||
            normalizedQuery.contains('cornea')) {
          score += 10.0;
        }
      } else if (protocol.id == 'fainting') {
        if (normalizedQuery.contains('faint') ||
            normalizedQuery.contains('syncope') ||
            normalizedQuery.contains('passed out briefly')) {
          score += 8.0;
        }
      } else if (protocol.id == 'drowning') {
        if (normalizedQuery.contains('pool') ||
            normalizedQuery.contains('drown') ||
            (normalizedQuery.contains('water') &&
                (normalizedQuery.contains('pulled') ||
                    normalizedQuery.contains('submerged')))) {
          score += 15.0;
        }
      } else if (protocol.id == 'electric_shock') {
        if (normalizedQuery.contains('shock') ||
            normalizedQuery.contains('outlet') ||
            normalizedQuery.contains('socket') ||
            normalizedQuery.contains('voltage') ||
            normalizedQuery.contains('electrocute')) {
          score += 10.0;
        }
      } else if (protocol.id == 'poisoning') {
        if (normalizedQuery.contains('bleach') ||
            normalizedQuery.contains('cleaner') ||
            normalizedQuery.contains('poison') ||
            normalizedQuery.contains('toxic') ||
            (normalizedQuery.contains('swallowed') &&
                (normalizedQuery.contains('pills') ||
                    normalizedQuery.contains('bottle')))) {
          score += 10.0;
        }
      } else if (protocol.id == 'anaphylaxis') {
        if (hasAnaphylaxisSigns) {
          score += 10.0;
        }
      } else if (protocol.id == 'bites_and_stings') {
        if (normalizedQuery.contains('wasp') ||
            normalizedQuery.contains('bee') ||
            normalizedQuery.contains('hornet') ||
            normalizedQuery.contains('stung') ||
            normalizedQuery.contains('sting') ||
            normalizedQuery.contains('bug') ||
            normalizedQuery.contains('insect') ||
            normalizedQuery.contains('spider')) {
          if (!hasAnaphylaxisSigns) {
            score += 10.0;
          }
        }
      } else if (protocol.id == 'fracture') {
        if (normalizedQuery.contains('ankle') ||
            normalizedQuery.contains('bone') ||
            normalizedQuery.contains('fracture') ||
            normalizedQuery.contains('sprain') ||
            normalizedQuery.contains('twisted') ||
            normalizedQuery.contains('dislocation')) {
          score += 8.0;
        }
      } else if (protocol.id == 'heatstroke') {
        if (normalizedQuery.contains('heat') ||
            normalizedQuery.contains('sun') ||
            normalizedQuery.contains('hot weather')) {
          score += 5.0;
        }
      } else if (protocol.id == 'bleeding') {
        if ((normalizedQuery.contains('cut') ||
                normalizedQuery.contains('laceration') ||
                normalizedQuery.contains('gash') ||
                normalizedQuery.contains('wound') ||
                normalizedQuery.contains('blood') ||
                normalizedQuery.contains('bleeding')) &&
            !normalizedQuery.contains('nose')) {
          score += 6.0;
        }
      } else if (protocol.id == 'cardiac_arrest') {
        if (normalizedQuery.contains('gasping') ||
            normalizedQuery.contains('snorting') ||
            normalizedQuery.contains('no pulse') ||
            normalizedQuery.contains('not breathing')) {
          score += 8.0;
        }
      }

      if (score > 0) {
        results.add(ScoredProtocol(protocol, score));
      }
    }

    return results;
  }

  static String _stem(String word) {
    if (word.endsWith('ies') && word.length > 4) {
      return '${word.substring(0, word.length - 3)}y';
    }
    if (word.endsWith('es') && word.length > 3) {
      return word.substring(0, word.length - 2);
    }
    if (word.endsWith('s') && !word.endsWith('ss') && word.length > 2) {
      return word.substring(0, word.length - 1);
    }
    if (word.endsWith('ing') && word.length > 5) {
      return word.substring(0, word.length - 3);
    }
    if (word.endsWith('ed') && word.length > 4) {
      return word.substring(0, word.length - 2);
    }
    return word;
  }

  static bool _isFuzzyMatch(String target, String token) {
    if (target == token) return true;
    if (target == '${token}s' ||
        token == '${target}s' ||
        target == '${token}es' ||
        token == '${target}es') {
      return true;
    }
    final stemTarget = _stem(target);
    final stemToken = _stem(token);
    if (stemTarget == stemToken) return true;
    if (stemTarget.length >= 3 && stemToken.length >= 3) {
      if (stemTarget.startsWith(stemToken) ||
          stemToken.startsWith(stemTarget)) {
        return true;
      }
    }
    if (target.length >= 4 && token.length >= 4) {
      return target.startsWith(token) || token.startsWith(target);
    }
    return false;
  }

  static List<String> _tokenize(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty && !_stopWords.contains(t))
        .toList();
  }
}
