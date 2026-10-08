import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../core/constants/app_constants.dart';
import '../services/model_download_service.dart';
import '../services/triage_engine_service.dart';
import '../services/profile_service.dart';
import '../services/document_service.dart';

enum AppSetupStage {
  checking,
  downloadRequired,
  downloading,
  readyToLoad,
  loadingEngine,
  ready,
  error,
}

class TriageController extends ChangeNotifier {
  final ModelDownloadService _downloadService = ModelDownloadService();
  final TriageEngineService _engineService = TriageEngineService();

  AppSetupStage _stage = AppSetupStage.checking;
  CancelToken? _cancelToken;

  double _downloadProgress = 0.0;
  double _downloadedMB = 0.0;
  double _totalMB = AppConstants.estimatedModelSizeMb;

  bool _isGenerating = false;
  String _streamedResponse = '';
  String _currentQuery = '';

  int _ttftMs = 0;
  double _tokensPerSec = 0.0;
  double _ramUsageMb = 0.0;
  String? _errorMessage;

  UserProfile? _userProfile;
  final ProfileService _profileService = ProfileService();
  final DocumentService _documentService = DocumentService();
  UploadedDocument? _uploadedDocument;

  StreamSubscription<String>? _generationSubscription;

  // Getters
  AppSetupStage get stage => _stage;
  bool get isChecking => _stage == AppSetupStage.checking;
  bool get isDownloading => _stage == AppSetupStage.downloading;
  bool get isDownloadRequired => _stage == AppSetupStage.downloadRequired;
  bool get isLoadingEngine => _stage == AppSetupStage.loadingEngine;
  bool get isReady => _stage == AppSetupStage.ready;
  bool get hasError => _stage == AppSetupStage.error;

  double get downloadProgress => _downloadProgress;
  double get downloadedMB => _downloadedMB;
  double get totalMB => _totalMB;

  bool get isGenerating => _isGenerating;
  String get streamedResponse => _streamedResponse;
  String get currentQuery => _currentQuery;

  int get ttftMs => _ttftMs;
  double get tokensPerSec => _tokensPerSec;
  double get ramUsageMb => _ramUsageMb;
  String? get errorMessage => _errorMessage;

  UploadedDocument? get uploadedDocument => _uploadedDocument;

  bool get isOffline => true; // Always 100% offline after model exists

  TriageController() {
    checkModelStatus();
  }

  Future<void> pickDocument() async {
    final doc = await _documentService.pickAndParseDocument();
    if (doc != null) {
      _uploadedDocument = doc;
      notifyListeners();
    }
  }

  void clearDocument() {
    _uploadedDocument = null;
    notifyListeners();
  }

  /// Checks whether the model exists on-device and is ready.
  Future<void> checkModelStatus() async {
    _stage = AppSetupStage.checking;
    _errorMessage = null;
    notifyListeners();

    try {
      final ready = await _downloadService.isModelReady();
      if (ready) {
        await loadEngine();
      } else {
        _stage = AppSetupStage.downloadRequired;
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = 'Failed to verify model status: $e';
      _stage = AppSetupStage.downloadRequired;
      notifyListeners();
    }
  }

  /// Starts downloading model weights via chunked HTTP stream.
  Future<void> startModelDownload() async {
    if (_stage == AppSetupStage.downloading) return;

    _stage = AppSetupStage.downloading;
    _downloadProgress = 0.0;
    _downloadedMB = 0.0;
    _totalMB = AppConstants.estimatedModelSizeMb;
    _errorMessage = null;
    _cancelToken = CancelToken();
    notifyListeners();

    try {
      await _downloadService.downloadModel(
        cancelToken: _cancelToken,
        onProgress: (progress, downloaded, total) {
          _downloadProgress = progress;
          _downloadedMB = downloaded;
          _totalMB = total;
          notifyListeners();
        },
      );

      _stage = AppSetupStage.readyToLoad;
      notifyListeners();
      await loadEngine();
    } catch (e) {
      if (CancelToken.isCancel(e as DioException)) {
        _errorMessage = 'Download cancelled by user.';
      } else {
        _errorMessage = 'Model download failed: ${e.toString()}';
      }
      _stage = AppSetupStage.error;
      notifyListeners();
    } finally {
      _cancelToken = null;
    }
  }

  /// Cancels an ongoing model download.
  void cancelDownload() {
    if (_cancelToken != null && !_cancelToken!.isCancelled) {
      _cancelToken!.cancel('User cancelled download');
    }
  }

  /// Initializes the llama.cpp engine with the downloaded model.
  Future<void> loadEngine() async {
    _stage = AppSetupStage.loadingEngine;
    _errorMessage = null;
    notifyListeners();

    try {
      final modelPath = await _downloadService.getModelPath();
      await _engineService.initializeEngine(modelPath);
      _stage = AppSetupStage.ready;
      _ramUsageMb = _engineService.getEstimatedRamUsageMB();
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to load Llama engine: $e';
      _stage = AppSetupStage.error;
      notifyListeners();
    }
  }

  /// Submits an emergency query and streams triage advice in real time.
  Future<void> submitEmergencyQuery(String query) async {
    if (query.trim().isEmpty || _isGenerating || !isReady) return;

    _currentQuery = query.trim();
    _streamedResponse = '';
    _isGenerating = true;
    _ttftMs = 0;
    _tokensPerSec = 0.0;
    _errorMessage = null;
    notifyListeners();

    try {
      _userProfile = await _profileService.loadProfile();
      
      String fullQuery = _currentQuery;
      if (_uploadedDocument != null) {
        fullQuery += '\n\n[USER UPLOADED MEDICAL RECORD]:\n${_uploadedDocument!.content}';
      }

      final stream = _engineService.generateTriage(
        fullQuery,
        profile: _userProfile,
        onTelemetryUpdate: (telemetry) {
          _ttftMs = telemetry.ttftMs;
          _tokensPerSec = telemetry.tokensPerSec;
          _ramUsageMb = telemetry.ramUsageMb;
          notifyListeners();
        },
      );

      await for (final token in stream) {
        _streamedResponse += token;
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = 'Triage generation error: $e';
    } finally {
      _isGenerating = false;
      _ramUsageMb = _engineService.getEstimatedRamUsageMB();
      notifyListeners();
    }
  }

  /// Clears the currently streamed response card.
  void clearResponse() {
    _streamedResponse = '';
    _currentQuery = '';
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _generationSubscription?.cancel();
    _engineService.dispose();
    super.dispose();
  }
}
