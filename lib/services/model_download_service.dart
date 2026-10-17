import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../core/constants/app_constants.dart';

typedef DownloadProgressCallback = void Function(
  double progress,
  double downloadedMB,
  double totalMB,
);

class DownloadCorruptedException implements Exception {
  final String message;
  const DownloadCorruptedException(
      [this.message = 'Download was corrupted. Tap to download again.']);
  @override
  String toString() => message;
}

class ModelDownloadService {
  final String modelUrl;
  final Future<Directory> Function() directoryProvider;
  final String expectedSha256;
  final int expectedSizeBytes;
  final Dio _dio;

  ModelDownloadService({
    String? modelUrl,
    Future<Directory> Function()? directoryProvider,
    String? expectedSha256,
    int? expectedSizeBytes,
    Dio? dio,
  })  : modelUrl = modelUrl ?? AppConstants.modelUrl,
        directoryProvider = directoryProvider ?? _defaultDirectoryProvider,
        expectedSha256 = expectedSha256 ?? AppConstants.modelSha256,
        expectedSizeBytes = expectedSizeBytes ?? AppConstants.modelSizeBytes,
        _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 30),
                receiveTimeout: const Duration(seconds: 60),
                sendTimeout: const Duration(seconds: 30),
              ),
            );

  static Future<Directory> _defaultDirectoryProvider() async {
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      return Directory.systemTemp;
    }
    try {
      return await getApplicationDocumentsDirectory();
    } catch (_) {
      return Directory.systemTemp;
    }
  }

  Future<String> getModelPath() async {
    final dir = await directoryProvider();
    return p.join(dir.path, AppConstants.modelFileName);
  }

  Future<String> _getTempModelPath() async {
    final dir = await directoryProvider();
    return p.join(dir.path, AppConstants.tempModelFileName);
  }

  Future<String> _getSidecarPath() async {
    final dir = await directoryProvider();
    return p.join(dir.path, '${AppConstants.tempModelFileName}.json');
  }

  Future<String> _getVerifiedMarkerPath() async {
    final dir = await directoryProvider();
    return p.join(dir.path, '${AppConstants.modelFileName}.verified');
  }

  /// Checks if the verified marker exists and matches the current model file on disk.
  Future<bool> hasValidVerifiedMarker() async {
    try {
      final modelPath = await getModelPath();
      final modelFile = File(modelPath);
      if (!await modelFile.exists()) return false;

      final markerPath = await _getVerifiedMarkerPath();
      final markerFile = File(markerPath);
      if (!await markerFile.exists()) return false;

      final markerJson = json.decode(await markerFile.readAsString());
      final int markerSize = markerJson['size'] as int? ?? 0;
      final int markerLastModified = markerJson['lastModified'] as int? ?? 0;
      final String markerSha = markerJson['sha'] as String? ?? '';

      final stat = await modelFile.stat();
      if (stat.size != markerSize ||
          stat.modified.millisecondsSinceEpoch != markerLastModified) {
        return false;
      }

      if (expectedSha256.isNotEmpty &&
          markerSha.isNotEmpty &&
          markerSha != expectedSha256) {
        return false;
      }

      final minRequired = expectedSizeBytes > 0
          ? expectedSizeBytes
          : AppConstants.minModelSizeBytes;
      return stat.size >= minRequired;
    } catch (_) {
      return false;
    }
  }

  /// Checks if a model exists on-device that has not been verified with a marker yet.
  Future<bool> hasUnverifiedModel() async {
    try {
      final modelPath = await getModelPath();
      final modelFile = File(modelPath);
      if (!await modelFile.exists()) return false;

      final hasValid = await hasValidVerifiedMarker();
      if (hasValid) return false;

      final size = await modelFile.length();
      final minRequired = expectedSizeBytes > 0
          ? expectedSizeBytes
          : AppConstants.minModelSizeBytes;
      return size >= minRequired;
    } catch (_) {
      return false;
    }
  }

  /// Checks if the model is ready to use (verified marker or verified existing file).
  Future<bool> isModelReady() async {
    return await hasValidVerifiedMarker();
  }

  /// Returns the number of bytes in any existing partial download (.tmp).
  Future<int> getPartialBytes() async {
    try {
      final tempPath = await _getTempModelPath();
      final tempFile = File(tempPath);
      if (await tempFile.exists()) {
        return await tempFile.length();
      }
    } catch (_) {}
    return 0;
  }

  /// Checks if a partial download exists.
  Future<bool> hasPartialDownload() async {
    final bytes = await getPartialBytes();
    return bytes > 0;
  }

  /// Deletes the partial download and sidecar JSON.
  Future<void> deletePartialDownload() async {
    try {
      final tempPath = await _getTempModelPath();
      final tempFile = File(tempPath);
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
    } catch (_) {}

    try {
      final sidecarPath = await _getSidecarPath();
      final sidecarFile = File(sidecarPath);
      if (await sidecarFile.exists()) {
        await sidecarFile.delete();
      }
    } catch (_) {}
  }

  /// Deletes the complete model, verified marker, and any partial download.
  Future<void> deleteModel() async {
    try {
      final modelPath = await getModelPath();
      final file = File(modelPath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}

    try {
      final markerPath = await _getVerifiedMarkerPath();
      final markerFile = File(markerPath);
      if (await markerFile.exists()) {
        await markerFile.delete();
      }
    } catch (_) {}

    await deletePartialDownload();
  }

  /// Computes the SHA-256 of [filePath] inside Isolate.run with streamed I/O.
  static Future<String> computeSha256(String filePath) async {
    return await Isolate.run(() async {
      final file = File(filePath);
      final stream = file.openRead();
      final digest = await sha256.bind(stream).first;
      return digest.toString();
    });
  }

  /// Verifies a file against [expectedSha256], and writes the .verified marker.
  Future<void> _verifyAndFinalize(File tempFile, String finalPath) async {
    final tempPath = tempFile.path;
    final fileLength = await tempFile.length();

    final minRequired = expectedSizeBytes > 0
        ? expectedSizeBytes
        : AppConstants.minModelSizeBytes;
    if (fileLength < minRequired) {
      await deletePartialDownload();
      throw DownloadCorruptedException(
          'Downloaded model file ($fileLength bytes) is smaller than minimum required ($minRequired bytes).');
    }

    // Verify SHA-256 in background isolate
    if (expectedSha256.isNotEmpty) {
      final computedSha = await computeSha256(tempPath);
      if (computedSha.toLowerCase() != expectedSha256.toLowerCase()) {
        await deletePartialDownload();
        throw const DownloadCorruptedException();
      }
    }

    // Atomic rename to final path
    final finalFile = File(finalPath);
    if (await finalFile.exists()) {
      await finalFile.delete();
    }
    await tempFile.rename(finalPath);

    // Delete sidecar
    try {
      final sidecarFile = File(await _getSidecarPath());
      if (await sidecarFile.exists()) {
        await sidecarFile.delete();
      }
    } catch (_) {}

    // Write .verified marker
    await writeVerifiedMarker(finalFile);
  }

  /// Verifies an existing unverified model file and writes marker if valid.
  Future<bool> verifyExistingModel() async {
    final modelPath = await getModelPath();
    final modelFile = File(modelPath);
    if (!await modelFile.exists()) return false;

    if (expectedSha256.isNotEmpty) {
      final computedSha = await computeSha256(modelPath);
      if (computedSha.toLowerCase() != expectedSha256.toLowerCase()) {
        await modelFile.delete();
        throw const DownloadCorruptedException();
      }
    }

    await writeVerifiedMarker(modelFile);
    return true;
  }

  /// Writes .verified marker with sha, size, and lastModified.
  Future<void> writeVerifiedMarker(File finalFile) async {
    final markerPath = await _getVerifiedMarkerPath();
    final stat = await finalFile.stat();
    String sha = expectedSha256;
    if (sha.isEmpty) {
      sha = await computeSha256(finalFile.path);
    }

    final markerData = {
      'sha': sha,
      'size': stat.size,
      'lastModified': stat.modified.millisecondsSinceEpoch,
    };
    await File(markerPath).writeAsString(json.encode(markerData));
  }

  /// Reads sidecar JSON metadata if available.
  Future<Map<String, dynamic>?> _readSidecar() async {
    try {
      final sidecarPath = await _getSidecarPath();
      final file = File(sidecarPath);
      if (await file.exists()) {
        return json.decode(await file.readAsString()) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  /// Writes sidecar JSON metadata.
  Future<void> _writeSidecar({String? etag, int? totalSize}) async {
    try {
      final sidecarPath = await _getSidecarPath();
      final data = <String, dynamic>{};
      if (etag != null) data['etag'] = etag;
      if (totalSize != null) data['totalSize'] = totalSize;
      await File(sidecarPath).writeAsString(json.encode(data));
    } catch (_) {}
  }

  /// Downloads the model with support for resuming, range headers,
  /// 206 append, 200 truncate/restart, 416 handling, and up to 3 retries.
  Future<void> downloadModel({
    required DownloadProgressCallback onProgress,
    CancelToken? cancelToken,
    void Function()? onVerifyingStart,
  }) async {
    const int maxRetries = 3;
    int retryCount = 0;

    while (true) {
      try {
        await _performStreamDownload(
          onProgress: onProgress,
          cancelToken: cancelToken,
          onVerifyingStart: onVerifyingStart,
        );
        return;
      } catch (e) {
        if (e is DownloadCorruptedException) {
          rethrow;
        }

        if (cancelToken != null && cancelToken.isCancelled) {
          // User paused/cancelled: keep partial download intact
          rethrow;
        }

        retryCount++;
        if (retryCount > maxRetries) {
          rethrow;
        }

        // Exponential backoff: 2s, 4s, 8s
        final delaySeconds = 2 * (1 << (retryCount - 1));
        await Future.delayed(Duration(seconds: delaySeconds));
      }
    }
  }

  Future<void> _performStreamDownload({
    required DownloadProgressCallback onProgress,
    CancelToken? cancelToken,
    void Function()? onVerifyingStart,
  }) async {
    final tempPath = await _getTempModelPath();
    final finalPath = await getModelPath();
    final tempFile = File(tempPath);

    int partialLength = 0;
    if (await tempFile.exists()) {
      partialLength = await tempFile.length();
    }

    final sidecar = await _readSidecar();
    final String? cachedEtag = sidecar?['etag'] as String?;
    final int? cachedTotal = sidecar?['totalSize'] as int?;

    // Build headers
    final headers = <String, dynamic>{
      'Accept-Encoding': 'identity',
    };
    if (partialLength > 0) {
      headers['Range'] = 'bytes=$partialLength-';
      if (cachedEtag != null && cachedEtag.isNotEmpty) {
        headers['If-Range'] = cachedEtag;
      }
    }

    Response<ResponseBody> response;
    try {
      response = await _dio.get<ResponseBody>(
        modelUrl,
        options: Options(
          responseType: ResponseType.stream,
          followRedirects: true,
          headers: headers,
          validateStatus: (status) =>
              status != null &&
              ((status >= 200 && status < 300) || status == 416),
        ),
        cancelToken: cancelToken,
      );
    } catch (e) {
      rethrow;
    }

    final statusCode = response.statusCode ?? 200;

    // Handle 416 Range Not Satisfiable
    if (statusCode == 416) {
      final expected =
          expectedSizeBytes > 0 ? expectedSizeBytes : (cachedTotal ?? 0);
      if (expected > 0 && partialLength == expected) {
        onVerifyingStart?.call();
        await _verifyAndFinalize(tempFile, finalPath);
        return;
      } else {
        // Restart from scratch
        await deletePartialDownload();
        return _performStreamDownload(
          onProgress: onProgress,
          cancelToken: cancelToken,
          onVerifyingStart: onVerifyingStart,
        );
      }
    }

    final serverEtag = response.headers.value('etag') ??
        response.headers.value('x-linked-etag') ??
        cachedEtag;

    int totalBytes = 0;
    bool isAppend = false;

    if (statusCode == 206) {
      // 206 -> Append to existing partial
      isAppend = true;
      final contentRange = response.headers.value('content-range');
      if (contentRange != null && contentRange.contains('/')) {
        final totalStr = contentRange.split('/').last.trim();
        totalBytes = int.tryParse(totalStr) ?? 0;
      }
      if (totalBytes <= 0) {
        final cl =
            int.tryParse(response.headers.value('content-length') ?? '0') ?? 0;
        totalBytes = partialLength + cl;
      }
    } else {
      // 200 -> Server ignored Range or fresh start; truncate and restart from zero
      isAppend = false;
      partialLength = 0;
      final cl =
          int.tryParse(response.headers.value('content-length') ?? '0') ?? 0;
      totalBytes =
          cl > 0 ? cl : (expectedSizeBytes > 0 ? expectedSizeBytes : 0);
    }

    if (totalBytes <= 0 && cachedTotal != null && cachedTotal > 0) {
      totalBytes = cachedTotal;
    } else if (totalBytes <= 0 && expectedSizeBytes > 0) {
      totalBytes = expectedSizeBytes;
    }

    // Save sidecar with current ETag and total size
    await _writeSidecar(etag: serverEtag, totalSize: totalBytes);

    // Open file for writing/appending
    final fileSink = tempFile.openWrite(
      mode: isAppend ? FileMode.append : FileMode.write,
    );

    int receivedSinceStart = 0;

    try {
      final stream = response.data!.stream;
      await for (final chunk in stream) {
        if (cancelToken != null && cancelToken.isCancelled) {
          throw DioException(
            requestOptions: response.requestOptions,
            type: DioExceptionType.cancel,
            message: 'Download cancelled by user',
          );
        }

        fileSink.add(chunk);
        receivedSinceStart += chunk.length;

        final currentTotalReceived = partialLength + receivedSinceStart;
        final double progress = totalBytes > 0
            ? (currentTotalReceived / totalBytes).clamp(0.0, 1.0)
            : 0.0;
        final double downloadedMB = currentTotalReceived / (1024 * 1024);
        final double totalMB = totalBytes > 0
            ? (totalBytes / (1024 * 1024))
            : AppConstants.estimatedModelSizeMb;

        onProgress(progress, downloadedMB, totalMB);
      }

      await fileSink.flush();
      await fileSink.close();

      if (cancelToken != null && cancelToken.isCancelled) {
        throw DioException(
          requestOptions: response.requestOptions,
          type: DioExceptionType.cancel,
          message: 'Download cancelled by user',
        );
      }
    } catch (e) {
      try {
        await fileSink.flush();
        await fileSink.close();
      } catch (_) {}
      rethrow;
    }

    // Verify stage
    onVerifyingStart?.call();
    await _verifyAndFinalize(tempFile, finalPath);
  }
}
