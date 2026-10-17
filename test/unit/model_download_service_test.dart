import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carepulse/services/model_download_service.dart';

void main() {
  late Directory tempDir;
  HttpServer? server;
  late String serverBaseUrl;

  final testPayload = utf8.encode(
      'CarePulse test offline neural model payload - byte sequence 0123456789abcdefghijklmnopqrstuvwxyz');
  final expectedHash = sha256.convert(testPayload).toString();
  final totalBytes = testPayload.length;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('carepulse_dl_test_');
  });

  tearDown(() async {
    try {
      await server?.close(force: true);
      server = null;
    } catch (_) {}
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {}
  });

  Future<void> startServer(FutureOr<void> Function(HttpRequest) handler) async {
    final s = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server = s;
    serverBaseUrl = 'http://${s.address.host}:${s.port}';
    s.listen((request) async {
      try {
        await handler(request);
      } catch (_) {}
    });
  }

  test('Fresh full download creates verified file and .verified marker',
      () async {
    await startServer((request) {
      request.response.headers.set('Content-Type', 'application/octet-stream');
      request.response.headers.set('Content-Length', totalBytes);
      request.response.headers.set('ETag', '"tag-1"');
      request.response.add(testPayload);
      request.response.close();
    });

    final service = ModelDownloadService(
      modelUrl: '$serverBaseUrl/model.gguf',
      directoryProvider: () async => tempDir,
      expectedSha256: expectedHash,
      expectedSizeBytes: totalBytes,
    );

    double lastProgress = 0.0;
    await service.downloadModel(
      onProgress: (progress, downloaded, total) {
        lastProgress = progress;
      },
    );

    expect(lastProgress, equals(1.0));
    final modelPath = await service.getModelPath();
    expect(File(modelPath).existsSync(), isTrue);
    expect(File(modelPath).readAsBytesSync(), equals(testPayload));

    // Marker verified
    expect(await service.hasValidVerifiedMarker(), isTrue);
  });

  test('Resume with 206 appends to existing partial download', () async {
    final splitIndex = totalBytes ~/ 2;
    final firstPart = testPayload.sublist(0, splitIndex);
    final secondPart = testPayload.sublist(splitIndex);

    // Pre-populate partial download (.tmp) and sidecar
    final tempPath = '${tempDir.path}/Llama-3.2-1B-Instruct-Q4_K_M.gguf.tmp';
    final sidecarPath = '$tempPath.json';
    File(tempPath).writeAsBytesSync(firstPart);
    File(sidecarPath).writeAsStringSync(
        json.encode({'etag': '"tag-resume"', 'totalSize': totalBytes}));

    bool rangeHeaderFound = false;

    await startServer((request) {
      final range = request.headers.value('range');
      if (range == 'bytes=$splitIndex-') {
        rangeHeaderFound = true;
        request.response.statusCode = HttpStatus.partialContent; // 206
        request.response.headers.set(
            'Content-Range', 'bytes $splitIndex-${totalBytes - 1}/$totalBytes');
        request.response.headers.set('Content-Length', secondPart.length);
        request.response.headers.set('ETag', '"tag-resume"');
        request.response.add(secondPart);
        request.response.close();
      } else {
        request.response.statusCode = HttpStatus.badRequest;
        request.response.close();
      }
    });

    final service = ModelDownloadService(
      modelUrl: '$serverBaseUrl/model.gguf',
      directoryProvider: () async => tempDir,
      expectedSha256: expectedHash,
      expectedSizeBytes: totalBytes,
    );

    await service.downloadModel(
      onProgress: (progress, downloaded, total) {},
    );

    expect(rangeHeaderFound, isTrue);
    final modelPath = await service.getModelPath();
    expect(File(modelPath).readAsBytesSync(), equals(testPayload));
    expect(await service.hasValidVerifiedMarker(), isTrue);
  });

  test('Server ignoring Range with 200 truncates and restarts clean', () async {
    // Partial file has corrupted initial bytes
    final tempPath = '${tempDir.path}/Llama-3.2-1B-Instruct-Q4_K_M.gguf.tmp';
    File(tempPath).writeAsBytesSync([0, 1, 2, 3, 4]);

    await startServer((request) {
      // Ignore Range and send full 200
      request.response.statusCode = HttpStatus.ok; // 200
      request.response.headers.set('Content-Length', totalBytes);
      request.response.headers.set('ETag', '"tag-fresh"');
      request.response.add(testPayload);
      request.response.close();
    });

    final service = ModelDownloadService(
      modelUrl: '$serverBaseUrl/model.gguf',
      directoryProvider: () async => tempDir,
      expectedSha256: expectedHash,
      expectedSizeBytes: totalBytes,
    );

    await service.downloadModel(
      onProgress: (progress, downloaded, total) {},
    );

    final modelPath = await service.getModelPath();
    expect(File(modelPath).readAsBytesSync(), equals(testPayload));
  });

  test('ETag change restarts clean from beginning', () async {
    final tempPath = '${tempDir.path}/Llama-3.2-1B-Instruct-Q4_K_M.gguf.tmp';
    final sidecarPath = '$tempPath.json';
    File(tempPath).writeAsBytesSync([99, 98, 97]);
    File(sidecarPath).writeAsStringSync(
        json.encode({'etag': '"old-etag"', 'totalSize': totalBytes}));

    await startServer((request) {
      final ifRange = request.headers.value('if-range');
      if (ifRange != '"new-etag"') {
        // If-Range mismatch -> send 200 with full body
        request.response.statusCode = HttpStatus.ok;
        request.response.headers.set('Content-Length', totalBytes);
        request.response.headers.set('ETag', '"new-etag"');
        request.response.add(testPayload);
        request.response.close();
      }
    });

    final service = ModelDownloadService(
      modelUrl: '$serverBaseUrl/model.gguf',
      directoryProvider: () async => tempDir,
      expectedSha256: expectedHash,
      expectedSizeBytes: totalBytes,
    );

    await service.downloadModel(
      onProgress: (progress, downloaded, total) {},
    );

    final modelPath = await service.getModelPath();
    expect(File(modelPath).readAsBytesSync(), equals(testPayload));
  });

  test('Mid-stream disconnect triggers auto-retry and resumes cleanly',
      () async {
    final splitIndex = totalBytes ~/ 2;
    int attempt = 0;

    await startServer((request) async {
      attempt++;
      if (attempt == 1) {
        // First attempt: detach raw socket, send partial bytes then destroy socket abruptly
        final socket = await request.response.detachSocket(writeHeaders: false);
        final rawHeaders = 'HTTP/1.1 200 OK\r\n'
            'Content-Length: $totalBytes\r\n'
            'ETag: "tag-retry"\r\n'
            'Content-Type: application/octet-stream\r\n\r\n';
        socket.write(rawHeaders);
        socket.add(testPayload.sublist(0, splitIndex));
        await socket.flush();
        socket.destroy();
      } else {
        // Second attempt: receive Range bytes=$splitIndex- and complete
        final range = request.headers.value('range');
        expect(range, equals('bytes=$splitIndex-'));
        request.response.statusCode = HttpStatus.partialContent;
        request.response.headers.set(
            'Content-Range', 'bytes $splitIndex-${totalBytes - 1}/$totalBytes');
        request.response.headers.set('Content-Length', totalBytes - splitIndex);
        request.response.headers.set('ETag', '"tag-retry"');
        request.response.add(testPayload.sublist(splitIndex));
        await request.response.close();
      }
    });

    final service = ModelDownloadService(
      modelUrl: '$serverBaseUrl/model.gguf',
      directoryProvider: () async => tempDir,
      expectedSha256: expectedHash,
      expectedSizeBytes: totalBytes,
    );

    await service.downloadModel(
      onProgress: (progress, downloaded, total) {},
    );

    expect(attempt, greaterThanOrEqualTo(2));
    final modelPath = await service.getModelPath();
    expect(File(modelPath).readAsBytesSync(), equals(testPayload));
  });

  test(
      '416 handling: if partial equals expected size goes straight to verification',
      () async {
    final tempPath = '${tempDir.path}/Llama-3.2-1B-Instruct-Q4_K_M.gguf.tmp';
    File(tempPath).writeAsBytesSync(testPayload);

    await startServer((request) {
      request.response.statusCode = 416; // Range Not Satisfiable
      request.response.close();
    });

    final service = ModelDownloadService(
      modelUrl: '$serverBaseUrl/model.gguf',
      directoryProvider: () async => tempDir,
      expectedSha256: expectedHash,
      expectedSizeBytes: totalBytes,
    );

    await service.downloadModel(
      onProgress: (progress, downloaded, total) {},
    );

    final modelPath = await service.getModelPath();
    expect(File(modelPath).existsSync(), isTrue);
    expect(File(modelPath).readAsBytesSync(), equals(testPayload));
  });

  test(
      'Checksum mismatch deletes corrupted download and throws DownloadCorruptedException',
      () async {
    await startServer((request) {
      final corrupted = List<int>.filled(totalBytes, 42);
      request.response.headers.set('Content-Length', corrupted.length);
      request.response.add(corrupted);
      request.response.close();
    });

    final service = ModelDownloadService(
      modelUrl: '$serverBaseUrl/model.gguf',
      directoryProvider: () async => tempDir,
      expectedSha256: expectedHash,
      expectedSizeBytes: totalBytes,
    );

    expect(
      () => service.downloadModel(onProgress: (p, d, t) {}),
      throwsA(isA<DownloadCorruptedException>()),
    );
  });

  test('Marker logic trusts valid marker and detects invalidation', () async {
    final modelPath = '${tempDir.path}/Llama-3.2-1B-Instruct-Q4_K_M.gguf';
    final modelFile = File(modelPath);
    modelFile.writeAsBytesSync(testPayload);

    final service = ModelDownloadService(
      directoryProvider: () async => tempDir,
      expectedSha256: expectedHash,
      expectedSizeBytes: totalBytes,
    );

    // No marker yet -> unverified
    expect(await service.hasValidVerifiedMarker(), isFalse);
    expect(await service.hasUnverifiedModel(), isTrue);

    // Verify existing model writes marker
    final verified = await service.verifyExistingModel();
    expect(verified, isTrue);
    expect(await service.hasValidVerifiedMarker(), isTrue);

    // Tampering with file invalidates marker
    await Future<void>.delayed(const Duration(milliseconds: 10));
    modelFile.writeAsBytesSync([...testPayload, 42]);
    expect(await service.hasValidVerifiedMarker(), isFalse);
  });

  test('Pause keeps partial download and sidecar intact', () async {
    final cancelToken = CancelToken();

    await startServer((request) async {
      request.response.headers.set('Content-Length', totalBytes);
      request.response.headers.set('ETag', '"tag-pause"');
      request.response.add(testPayload.sublist(0, 10));
      await request.response.flush();
      // Keep connection open so client can cancel cleanly
      await Future<void>.delayed(const Duration(milliseconds: 500));
      try {
        request.response.add(testPayload.sublist(10));
        await request.response.close();
      } catch (_) {}
    });

    final service = ModelDownloadService(
      modelUrl: '$serverBaseUrl/model.gguf',
      directoryProvider: () async => tempDir,
      expectedSha256: expectedHash,
      expectedSizeBytes: totalBytes,
    );

    try {
      await service.downloadModel(
        cancelToken: cancelToken,
        onProgress: (progress, downloaded, total) {
          if (downloaded > 0 && !cancelToken.isCancelled) {
            cancelToken.cancel('pause');
          }
        },
      );
    } catch (_) {}

    expect(await service.hasPartialDownload(), isTrue);
    expect(await service.getPartialBytes(), greaterThanOrEqualTo(10));
  });

  test('Delete partial download removes .tmp and sidecar JSON', () async {
    final tempPath = '${tempDir.path}/Llama-3.2-1B-Instruct-Q4_K_M.gguf.tmp';
    final sidecarPath = '$tempPath.json';
    File(tempPath).writeAsBytesSync([1, 2, 3]);
    File(sidecarPath).writeAsStringSync('{"etag":"123"}');

    final service = ModelDownloadService(
      directoryProvider: () async => tempDir,
    );

    expect(await service.hasPartialDownload(), isTrue);
    await service.deletePartialDownload();
    expect(await service.hasPartialDownload(), isFalse);
    expect(File(tempPath).existsSync(), isFalse);
    expect(File(sidecarPath).existsSync(), isFalse);
  });
}
