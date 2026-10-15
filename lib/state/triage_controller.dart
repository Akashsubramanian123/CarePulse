import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../core/constants/app_constants.dart';
import '../services/document_service.dart';
import '../services/model_download_service.dart';
import '../services/profile_service.dart';
import '../services/protocol_repository.dart';
import '../services/protocol_retriever.dart';
import '../services/red_flag_engine.dart';
import '../services/triage_engine_service.dart';

enum AppSetupStage {
  checking,
  downloadRequired,
  downloading,
  readyToLoad,
  loadingEngine,
  ready,
  error,
}

enum AnswerSource {
  verifiedProtocol,
  aiGuidedByProtocol,
  aiGenerated,
}

extension AnswerSourceExtension on AnswerSource {
  String get label {
    switch (this) {
      case AnswerSource.verifiedProtocol:
        return 'Verified protocol';
      case AnswerSource.aiGuidedByProtocol:
        return 'AI, guided by verified protocol';
      case AnswerSource.aiGenerated:
        return 'AI-generated. Use judgment, call help if serious.';
    }
  }
}

class TriageController extends ChangeNotifier {
  final ModelDownloadService _downloadService;
  final TriageEngineService _engineService;
  final ProfileService _profileService;
  final DocumentService _documentService;
  final ProtocolRepository _protocolRepository;
  final ProtocolRetriever _protocolRetriever;
  final RedFlagEngine _redFlagEngine;

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

  AnswerSource? _answerSource;
  bool _callEmergencyNow = false;

  UserProfile? _userProfile;
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

  AnswerSource? get answerSource => _answerSource;
  bool get callEmergencyNow => _callEmergencyNow;

  ProtocolRepository get protocolRepository => _protocolRepository;
  ProtocolRetriever get protocolRetriever => _protocolRetriever;
  RedFlagEngine get redFlagEngine => _redFlagEngine;

  UploadedDocument? get uploadedDocument => _uploadedDocument;

  bool get isOffline => true; // Always 100% offline after model exists

  TriageController({
    ModelDownloadService? downloadService,
    TriageEngineService? engineService,
    ProfileService? profileService,
    DocumentService? documentService,
    ProtocolRepository? protocolRepository,
    ProtocolRetriever? protocolRetriever,
    RedFlagEngine? redFlagEngine,
  })  : _downloadService = downloadService ?? ModelDownloadService(),
        _engineService = engineService ?? TriageEngineService(),
        _profileService = profileService ?? ProfileService(),
        _documentService = documentService ?? DocumentService(),
        _protocolRepository = protocolRepository ?? ProtocolRepository(),
        _protocolRetriever = protocolRetriever ??
            ProtocolRetriever(protocolRepository ?? ProtocolRepository()),
        _redFlagEngine = redFlagEngine ?? RedFlagEngine() {
    checkModelStatus();
  }

  Future<void> _ensureProtocolsLoaded() async {
    if (!_protocolRepository.isLoaded) {
      try {
        await _protocolRepository.loadProtocols();
      } catch (_) {}
    }
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
      if (e is DioException && CancelToken.isCancel(e)) {
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
    final trimmed = query.trim();
    if (trimmed.isEmpty || _isGenerating) return;

    _callEmergencyNow = false;
    _errorMessage = null;

    // Feature 1: Red-flag check BEFORE the !isReady guard
    final redFlag = _redFlagEngine.evaluate(trimmed);
    if (redFlag != null) {
      _currentQuery = trimmed;
      _isGenerating = false;
      _answerSource = AnswerSource.verifiedProtocol;
      _callEmergencyNow = true;

      await _ensureProtocolsLoaded();
      final protocol = _protocolRepository.getById(redFlag.protocolId);
      if (protocol != null) {
        _streamedResponse = protocol.toFormattedSteps();
      } else {
        _streamedResponse =
            '1. IMMEDIATE ACTION: Call 112 immediately. Seek emergency assistance.\n2. CRITICAL PRECAUTION: Keep the person still and calm. Do not leave them unattended.\n3. MONITOR & STABILIZE: Continuously monitor breathing and pulse until emergency medical services arrive.';
      }
      notifyListeners();
      return;
    }

    // If no red flag matched and model is not ready, show friendly message pointing to Guides & download
    if (!isReady) {
      _currentQuery = trimmed;
      _isGenerating = false;
      _answerSource = null;
      _streamedResponse =
          'The offline AI model is not downloaded yet. Please explore the Guides tab for verified first-aid procedures, or download the model below to enable offline AI triage.';
      notifyListeners();
      return;
    }

    _currentQuery = trimmed;
    _streamedResponse = '';
    _isGenerating = true;
    _ttftMs = 0;
    _tokensPerSec = 0.0;
    _errorMessage = null;
    notifyListeners();

    try {
      _userProfile = await _profileService.loadProfile();
      await _ensureProtocolsLoaded();

      // Feature 2: Protocol retrieval for context
      final matches = _protocolRetriever.topMatches(trimmed, k: 1);
      String? protocolContext;
      if (matches.isNotEmpty) {
        _answerSource = AnswerSource.aiGuidedByProtocol;
        protocolContext = matches.first.toCompactContext(maxChars: 1200);
      } else {
        _answerSource = AnswerSource.aiGenerated;
      }

      String fullQuery = _currentQuery;
      if (_uploadedDocument != null) {
        fullQuery +=
            '\n\n[USER UPLOADED MEDICAL RECORD]:\n${_uploadedDocument!.content}';
      }

      final stream = _engineService.generateTriage(
        fullQuery,
        context: protocolContext,
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
    _answerSource = null;
    _callEmergencyNow = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _generationSubscription?.cancel();
    _engineService.dispose();
    super.dispose();
  }
}
