import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

class VaultDocument {
  final String id;
  final String title;
  final String content;

  VaultDocument(this.id, this.title, this.content);
}

class MedicalVaultService {
  final List<VaultDocument> _documents = [];

  List<VaultDocument> get documents => _documents;

  MedicalVaultService() {
    _loadSampleData();
  }

  Future<void> _loadSampleData() async {
    try {
      // In a real app, you would load this from the local file system using File
      // We load from assets for the demonstration
      final content = await rootBundle.loadString('sample_data/john_doe_medical_report.txt');
      addDocument('John Doe Blood Test & Clinical Notes', content);
    } catch (e) {
      debugPrint("Failed to load sample vault data: $e");
    }
  }

  Future<void> addDocument(String title, String content) async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    _documents.add(VaultDocument(id, title, content));
  }

  /// Simple Offline Keyword-Based RAG Retrieval (TF-IDF approximation)
  /// We break the documents into smaller chunks and rank them based on keyword matches
  /// with the user's query.
  String retrieveRelevantContext(String query, {int topK = 2}) {
    if (_documents.isEmpty) return "";

    final queryWords = query.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '').split(' ').where((w) => w.length > 2).toSet();
    if (queryWords.isEmpty) return "";

    List<Map<String, dynamic>> scoredChunks = [];

    for (var doc in _documents) {
      // Very basic chunking by double newlines or paragraphs
      final chunks = doc.content.split('\n\n');
      for (var chunk in chunks) {
        if (chunk.trim().isEmpty) continue;
        
        final chunkWords = chunk.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '').split(' ');
        
        // Count how many query words appear in this chunk
        int score = 0;
        for (var qw in queryWords) {
          if (chunkWords.contains(qw)) {
            score += 1;
          }
        }

        if (score > 0) {
          scoredChunks.add({
            'score': score,
            'text': chunk.trim(),
            'source': doc.title
          });
        }
      }
    }

    if (scoredChunks.isEmpty) return "";

    // Sort by score descending
    scoredChunks.sort((a, b) => b['score'].compareTo(a['score']));

    // Take top K chunks
    final topChunks = scoredChunks.take(topK).toList();

    StringBuffer contextBuilder = StringBuffer();
    contextBuilder.writeln("RELEVANT MEDICAL RECORDS (Found in user's vault):");
    for (var i = 0; i < topChunks.length; i++) {
      contextBuilder.writeln("- From [${topChunks[i]['source']}]: ${topChunks[i]['text']}");
    }

    return contextBuilder.toString();
  }
}
