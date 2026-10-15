import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/medical_id.dart';

class SosService {
  /// Builds the emergency SOS message, omitting empty fields.
  static String buildEmergencyMessage({
    Position? position,
    String? bloodGroup,
    String? allergies,
    String? conditions,
  }) {
    final buffer = StringBuffer('EMERGENCY! I need help.');

    if (position != null) {
      final lat = position.latitude.toStringAsFixed(6);
      final lng = position.longitude.toStringAsFixed(6);
      final acc = position.accuracy.round();
      buffer.write(' Location: https://maps.google.com/?q=$lat,$lng (accuracy ~${acc}m).');
    } else {
      buffer.write(' Location: unavailable.');
    }

    if (bloodGroup != null && bloodGroup.trim().isNotEmpty) {
      buffer.write(' Blood group: ${bloodGroup.trim()}.');
    }

    if (allergies != null && allergies.trim().isNotEmpty) {
      buffer.write(' Allergies: ${allergies.trim()}.');
    }

    if (conditions != null && conditions.trim().isNotEmpty) {
      buffer.write(' Conditions: ${conditions.trim()}.');
    }

    buffer.write(' Sent from CarePulse.');
    return buffer.toString();
  }

  /// Builds a manual SMS URI string with Uri.encodeComponent to ensure %20 and no '+'.
  /// Handles platform-specific syntax: iOS uses '&body=' and Android uses '?body='.
  static String buildSmsUriString({
    required List<String> phoneNumbers,
    required String body,
    bool? isIos,
  }) {
    final useIos = isIos ?? (!kIsWeb && Platform.isIOS);
    final sanitized = phoneNumbers
        .map((p) => EmergencyContact.sanitizePhone(p))
        .where((p) => p.isNotEmpty)
        .toList();

    final recipients = sanitized.join(useIos ? ',' : ',');
    final encodedBody = Uri.encodeComponent(body);
    final bodyParam = useIos ? '&body=' : '?body=';

    return 'sms:$recipients$bodyParam$encodedBody';
  }

  /// Obtains current GPS coordinates with an 8-second timeout, falling back to last known position.
  Future<Position?> getCurrentLocation({Duration timeout = const Duration(seconds: 8)}) async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return await Geolocator.getLastKnownPosition();
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          return await Geolocator.getLastKnownPosition();
        }
      }

      try {
        return await Geolocator.getCurrentPosition(
          locationSettings: LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: timeout,
          ),
        );
      } catch (_) {
        return await Geolocator.getLastKnownPosition();
      }
    } catch (_) {
      try {
        return await Geolocator.getLastKnownPosition();
      } catch (_) {
        return null;
      }
    }
  }

  /// Launches the device SMS app for user review and confirmation before sending.
  Future<bool> launchSmsComposer({
    required List<String> phoneNumbers,
    required String message,
    bool? isIos,
  }) async {
    try {
      final uriString = buildSmsUriString(
        phoneNumbers: phoneNumbers,
        body: message,
        isIos: isIos,
      );
      final uri = Uri.parse(uriString);
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri);
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}
