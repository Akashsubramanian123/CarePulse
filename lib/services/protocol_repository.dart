import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/protocol.dart';

class ProtocolRepository {
  static const String _defaultAssetPath = 'assets/protocols/protocols.json';

  List<Protocol>? _cachedProtocols;
  final String assetPath;

  ProtocolRepository({this.assetPath = _defaultAssetPath});

  /// Allows supplying in-memory protocols directly (ideal for unit testing).
  ProtocolRepository.fromList(List<Protocol> protocols, {this.assetPath = _defaultAssetPath}) {
    _cachedProtocols = List.unmodifiable(protocols);
  }

  /// Returns whether protocols have already been loaded into memory.
  bool get isLoaded => _cachedProtocols != null;

  /// Returns cached protocols or empty list if not yet loaded.
  List<Protocol> get allProtocols => _cachedProtocols ?? const [];

  /// Loads protocols from JSON asset and caches them.
  Future<List<Protocol>> loadProtocols({AssetBundle? bundle}) async {
    if (_cachedProtocols != null) {
      return _cachedProtocols!;
    }

    final activeBundle = bundle ?? rootBundle;
    final jsonString = await activeBundle.loadString(assetPath);
    return loadFromJsonString(jsonString);
  }

  /// Parses and caches protocols from a raw JSON string.
  List<Protocol> loadFromJsonString(String jsonString) {
    final List<dynamic> decoded = json.decode(jsonString) as List<dynamic>;
    final protocols = decoded
        .map((item) => Protocol.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
    _cachedProtocols = protocols;
    return protocols;
  }

  /// Finds a protocol by its ID.
  Protocol? getById(String id) {
    if (_cachedProtocols == null) return null;
    for (final p in _cachedProtocols!) {
      if (p.id == id) return p;
    }
    return null;
  }
}
