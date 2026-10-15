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

    for (final protocol in protocols) {
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

      if (score > 0) {
        results.add(ScoredProtocol(protocol, score));
      }
    }

    return results;
  }

  static bool _isFuzzyMatch(String target, String token) {
    if (token.length < 4 || target.length < 4) return false;
    return target.startsWith(token) || token.startsWith(target);
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
