import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../core/constants/app_constants.dart';

typedef DownloadProgressCallback = void Function(
  double progress,
  double downloadedMB,
  double totalMB,
);

class ModelDownloadService {
  final Dio _dio = Dio();

  /// Returns the absolute path where the GGUF model file should reside.
  Future<String> getModelPath() async {
    final docsDir = await getApplicationDocumentsDirectory();
    return p.join(docsDir.path, AppConstants.modelFileName);
  }

  /// Returns the absolute path for the temporary download file.
  Future<String> _getTempModelPath() async {
    final docsDir = await getApplicationDocumentsDirectory();
    return p.join(docsDir.path, AppConstants.tempModelFileName);
  }

  /// Checks if the GGUF model exists and meets the minimum size requirement (> 700 MB).
  Future<bool> isModelReady() async {
    try {
      final modelPath = await getModelPath();
      final file = File(modelPath);
      if (!await file.exists()) {
        return false;
      }
      final length = await file.length();
      return length >= AppConstants.minModelSizeBytes;
    } catch (_) {
      return false;
    }
  }

  /// Gets the existing file size in MBs if present.
  Future<double> getExistingModelSizeMB() async {
    try {
      final modelPath = await getModelPath();
      final file = File(modelPath);
      if (await file.exists()) {
        final length = await file.length();
        return length / (1024 * 1024);
      }
    } catch (_) {}
    return 0.0;
  }

  /// Downloads the model weights with progress telemetry and atomic file rename.
  Future<void> downloadModel({
    required DownloadProgressCallback onProgress,
    CancelToken? cancelToken,
  }) async {
    final tempPath = await _getTempModelPath();
    final finalPath = await getModelPath();

    final tempFile = File(tempPath);
    if (await tempFile.exists()) {
      await tempFile.delete();
    }

    try {
      await _dio.download(
        AppConstants.modelUrl,
        tempPath,
        cancelToken: cancelToken,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            final double progress = received / total;
            final double downloadedMB = received / (1024 * 1024);
            final double totalMB = total / (1024 * 1024);
            onProgress(progress, downloadedMB, totalMB);
          } else {
            final double downloadedMB = received / (1024 * 1024);
            onProgress(0.0, downloadedMB, AppConstants.estimatedModelSizeMb);
          }
        },
        options: Options(
          responseType: ResponseType.stream,
          followRedirects: true,
          headers: {
            'Accept-Encoding': 'identity',
          },
        ),
      );

      // Verify downloaded temp file
      final downloadedFile = File(tempPath);
      if (!await downloadedFile.exists()) {
        throw Exception('Downloaded temporary file not found');
      }

      final fileLength = await downloadedFile.length();
      if (fileLength < AppConstants.minModelSizeBytes) {
        await downloadedFile.delete();
        throw Exception(
            'Downloaded model file size ($fileLength bytes) is less than required threshold (${AppConstants.minModelSizeBytes} bytes)');
      }

      // Atomic rename from .tmp to .gguf
      final finalFile = File(finalPath);
      if (await finalFile.exists()) {
        await finalFile.delete();
      }
      await downloadedFile.rename(finalPath);
    } catch (e) {
      // Clean up incomplete temp file if download was aborted or failed
      if (await tempFile.exists()) {
        try {
          await tempFile.delete();
        } catch (_) {}
      }
      rethrow;
    }
  }

  /// Deletes existing downloaded model if needed.
  Future<void> deleteModel() async {
    final modelPath = await getModelPath();
    final file = File(modelPath);
    if (await file.exists()) {
      await file.delete();
    }
    final tempPath = await _getTempModelPath();
    final tempFile = File(tempPath);
    if (await tempFile.exists()) {
      await tempFile.delete();
    }
  }
}
