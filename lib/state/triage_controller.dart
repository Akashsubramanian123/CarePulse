import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../core/constants/app_constants.dart';
import '../models/history_entry.dart';
import '../models/protocol.dart';
import '../models/triage_question.dart';
import '../services/document_service.dart';
import '../services/history_store.dart';
import '../services/model_download_service.dart';
import '../services/profile_service.dart';
import '../services/protocol_repository.dart';
import '../services/protocol_retriever.dart';
import '../services/red_flag_engine.dart';
import '../services/triage_clarifier.dart';
import '../services/triage_engine_service.dart';
import 'app_settings_controller.dart';

enum AppSetupStage {
  checking,
  downloadRequired,
  downloading,
  verifying,
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
  final HistoryStore _historyStore;
  final TriageClarifier _triageClarifier;
  AppSettingsController? _settingsController;
  Protocol? _selectedProtocol;

  TriageQuestion? _pendingQuestion;
  String? _clarificationNote;
  bool _hasClarifiedForCurrentQuery = false;

  AppSetupStage _stage = AppSetupStage.checking;
  CancelToken? _cancelToken;
  int _partialBytes = 0;

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
  Completer<void>? _generationCompleter;
  bool _wasStopped = false;

  // Getters
  AppSetupStage get stage => _stage;
  bool get isChecking => _stage == AppSetupStage.checking;
  bool get isDownloading => _stage == AppSetupStage.downloading;
  bool get isVerifying => _stage == AppSetupStage.verifying;
  bool get isDownloadRequired => _stage == AppSetupStage.downloadRequired;
  bool get isLoadingEngine => _stage == AppSetupStage.loadingEngine;
  bool get isReady => _stage == AppSetupStage.ready;
  bool get hasError => _stage == AppSetupStage.error;

  int get partialBytes => _partialBytes;
  double get downloadProgress => _downloadProgress;
  double get downloadedMB => _downloadedMB;
  double get totalMB => _totalMB;

  bool get isGenerating => _isGenerating;
  bool get wasStopped => _wasStopped;
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
  TriageClarifier get triageClarifier => _triageClarifier;
  Protocol? get selectedProtocol => _selectedProtocol;
  HistoryStore get historyStore => _historyStore;
  AppSettingsController? get settingsController => _settingsController;

  TriageQuestion? get pendingQuestion => _pendingQuestion;
  String? get clarificationNote => _clarificationNote;

  void updateSettings(AppSettingsController? settings) {
    _settingsController = settings;
  }

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
    HistoryStore? historyStore,
    AppSettingsController? settingsController,
    TriageClarifier? triageClarifier,
  })  : _downloadService = downloadService ?? ModelDownloadService(),
        _engineService = engineService ?? TriageEngineService(),
        _profileService = profileService ?? ProfileService(),
        _documentService = documentService ?? DocumentService(),
        _protocolRepository = protocolRepository ?? ProtocolRepository(),
        _protocolRetriever = protocolRetriever ??
            ProtocolRetriever(protocolRepository ?? ProtocolRepository()),
        _redFlagEngine = redFlagEngine ?? RedFlagEngine(),
        _historyStore = historyStore ?? HistoryStore(),
        _triageClarifier = triageClarifier ??
            TriageClarifier(
              protocolRetriever: protocolRetriever ??
                  ProtocolRetriever(protocolRepository ?? ProtocolRepository()),
              redFlagEngine: redFlagEngine ?? RedFlagEngine(),
            ),
        _settingsController = settingsController {
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
        return;
      }

      // Check if unverified model exists (e.g. downloaded before verification feature)
      if (await _downloadService.hasUnverifiedModel()) {
        _stage = AppSetupStage.verifying;
        notifyListeners();
        final verified = await _downloadService.verifyExistingModel();
        if (verified) {
          await loadEngine();
          return;
        }
      }

      // Check for partial download (.tmp)
      _partialBytes = await _downloadService.getPartialBytes();
      if (_partialBytes > 0) {
        final total = AppConstants.modelSizeBytes > 0
            ? AppConstants.modelSizeBytes
            : (AppConstants.estimatedModelSizeMb * 1024 * 1024).round();
        _downloadProgress = (_partialBytes / total).clamp(0.0, 1.0);
        _downloadedMB = _partialBytes / (1024 * 1024);
        _totalMB = total / (1024 * 1024);
      }
      _stage = AppSetupStage.downloadRequired;
      notifyListeners();
    } catch (e) {
      if (e is DownloadCorruptedException) {
        _errorMessage = 'Download was corrupted. Tap to download again.';
      } else {
        _errorMessage = 'Failed to verify model status: $e';
      }
      _stage = AppSetupStage.error;
      notifyListeners();
    }
  }

  /// Starts downloading model weights via chunked HTTP stream.
  Future<void> startModelDownload() async {
    if (_stage == AppSetupStage.downloading ||
        _stage == AppSetupStage.verifying) {
      return;
    }

    _stage = AppSetupStage.downloading;
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
          _partialBytes = (downloaded * 1024 * 1024).round();
          notifyListeners();
        },
        onVerifyingStart: () {
          _stage = AppSetupStage.verifying;
          notifyListeners();
        },
      );

      _partialBytes = 0;
      _stage = AppSetupStage.readyToLoad;
      notifyListeners();
      await loadEngine();
    } catch (e) {
      if (e is DownloadCorruptedException) {
        _errorMessage = 'Download was corrupted. Tap to download again.';
        _partialBytes = 0;
        _downloadProgress = 0.0;
        _downloadedMB = 0.0;
        _stage = AppSetupStage.error;
      } else if (e is DioException && CancelToken.isCancel(e)) {
        _errorMessage = null;
        _partialBytes = await _downloadService.getPartialBytes();
        _stage = AppSetupStage.downloadRequired;
      } else {
        _errorMessage = 'Model download failed: ${e.toString()}';
        _partialBytes = await _downloadService.getPartialBytes();
        _stage = AppSetupStage.error;
      }
      notifyListeners();
    } finally {
      _cancelToken = null;
    }
  }

  /// Pauses an ongoing model download, keeping partial bytes.
  void pauseModelDownload() {
    cancelDownload();
  }

  /// Cancels an ongoing model download.
  void cancelDownload() {
    if (_cancelToken != null && !_cancelToken!.isCancelled) {
      _cancelToken!.cancel('User paused download');
    }
  }

  /// Deletes the partial download and resets progress.
  Future<void> deletePartialDownload() async {
    await _downloadService.deletePartialDownload();
    _partialBytes = 0;
    _downloadProgress = 0.0;
    _downloadedMB = 0.0;
    _stage = AppSetupStage.downloadRequired;
    _errorMessage = null;
    notifyListeners();
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

    if (_currentQuery != trimmed) {
      _hasClarifiedForCurrentQuery = false;
    }

    _callEmergencyNow = false;
    _errorMessage = null;
    _wasStopped = false;
    _clarificationNote = null;
    _pendingQuestion = null;

    // Feature 1: Red-flag check BEFORE the !isReady guard
    final redFlag = _redFlagEngine.evaluate(trimmed);
    if (redFlag != null) {
      _currentQuery = trimmed;
      _isGenerating = false;
      _answerSource = AnswerSource.verifiedProtocol;
      _callEmergencyNow = true;

      await _ensureProtocolsLoaded();
      final protocol = _protocolRepository.getById(redFlag.protocolId);
      _selectedProtocol = protocol;
      if (protocol != null) {
        _streamedResponse = protocol.toFormattedSteps();
      } else {
        _streamedResponse =
            '1. IMMEDIATE ACTION: Call 112 immediately. Seek emergency assistance.\n2. CRITICAL PRECAUTION: Keep the person still and calm. Do not leave them unattended.\n3. MONITOR & STABILIZE: Continuously monitor breathing and pulse until emergency medical services arrive.';
      }
      notifyListeners();
      await _maybeSaveHistory();
      return;
    }

    // Feature 4: Clarification triage check for vague / low-confidence non-red-flag queries
    if (_triageClarifier.shouldAskClarification(
      trimmed,
      alreadyClarified: _hasClarifiedForCurrentQuery,
    )) {
      _currentQuery = trimmed;
      _pendingQuestion = _triageClarifier.firstQuestion;
      _isGenerating = false;
      _streamedResponse = '';
      _answerSource = null;
      notifyListeners();
      return;
    }

    await _executeNormalTriageFlow(trimmed);
  }

  /// Answers the currently pending clarifying question (Yes, No, Not sure, Skip).
  Future<void> answerClarifyingQuestion(TriageAnswer answer) async {
    if (_pendingQuestion == null) return;
    final current = _pendingQuestion!;

    if (answer == TriageAnswer.skip) {
      _pendingQuestion = null;
      _hasClarifiedForCurrentQuery = true;
      notifyListeners();
      await _executeNormalTriageFlow(_currentQuery);
      return;
    }

    if (current.id == TriageQuestion.awake.id) {
      if (answer == TriageAnswer.no || answer == TriageAnswer.notSure) {
        _pendingQuestion = null;
        _hasClarifiedForCurrentQuery = true;
        _answerSource = AnswerSource.verifiedProtocol;
        _callEmergencyNow = true;
        _clarificationNote = TriageClarifier.emergencyClarificationNote;

        await _ensureProtocolsLoaded();
        final protocol =
            _protocolRepository.getById(TriageClarifier.unresponsiveProtocolId);
        _selectedProtocol = protocol;
        if (protocol != null) {
          _streamedResponse = protocol.toFormattedSteps();
        } else {
          _streamedResponse =
              '1. IMMEDIATE ACTION: Call 112 immediately. Seek emergency assistance.\n2. CRITICAL PRECAUTION: Keep the person still and calm. Do not leave them unattended.\n3. MONITOR & STABILIZE: Continuously monitor breathing and pulse until emergency medical services arrive.';
        }
        notifyListeners();
        await _maybeSaveHistory();
        return;
      } else if (answer == TriageAnswer.yes) {
        _pendingQuestion = TriageQuestion.breathing;
        notifyListeners();
        return;
      }
    } else if (current.id == TriageQuestion.breathing.id) {
      if (answer == TriageAnswer.no || answer == TriageAnswer.notSure) {
        _pendingQuestion = null;
        _hasClarifiedForCurrentQuery = true;
        _answerSource = AnswerSource.verifiedProtocol;
        _callEmergencyNow = true;
        _clarificationNote = TriageClarifier.emergencyClarificationNote;

        await _ensureProtocolsLoaded();
        final protocol = _protocolRepository
            .getById(TriageClarifier.cardiacArrestProtocolId);
        _selectedProtocol = protocol;
        if (protocol != null) {
          _streamedResponse = protocol.toFormattedSteps();
        } else {
          _streamedResponse =
              '1. IMMEDIATE ACTION: Call 112 immediately. Seek emergency assistance.\n2. CRITICAL PRECAUTION: Keep the person still and calm. Do not leave them unattended.\n3. MONITOR & STABILIZE: Continuously monitor breathing and pulse until emergency medical services arrive.';
        }
        notifyListeners();
        await _maybeSaveHistory();
        return;
      } else if (answer == TriageAnswer.yes) {
        _pendingQuestion = null;
        _hasClarifiedForCurrentQuery = true;
        notifyListeners();
        await _executeNormalTriageFlow(
          _currentQuery,
          additionalContext: TriageClarifier.normalObservationContext,
        );
        return;
      }
    }
  }

  Future<void> _executeNormalTriageFlow(String queryText,
      {String? additionalContext}) async {
    // If no red flag matched and model is not ready, show friendly message pointing to Guides & download
    if (!isReady) {
      _currentQuery = queryText;
      _isGenerating = false;
      _answerSource = null;
      _streamedResponse =
          'The offline AI model is not downloaded yet. Please explore the Guides tab for verified first-aid procedures, or download the model below to enable offline AI triage.';
      notifyListeners();
      return;
    }

    _currentQuery = queryText;
    _streamedResponse = '';
    _isGenerating = true;
    _ttftMs = 0;
    _tokensPerSec = 0.0;
    _errorMessage = null;
    notifyListeners();

    try {
      _userProfile = await _profileService.loadProfile();
      if (!_isGenerating || _wasStopped) return;
      await _ensureProtocolsLoaded();
      if (!_isGenerating || _wasStopped) return;

      // Protocol retrieval for context
      final matches = _protocolRetriever.topMatches(queryText, k: 1);
      String? protocolContext;
      if (matches.isNotEmpty) {
        _answerSource = AnswerSource.aiGuidedByProtocol;
        _selectedProtocol = matches.first;
        protocolContext = matches.first.toCompactContext(maxChars: 1200);
      } else {
        _answerSource = AnswerSource.aiGenerated;
        _selectedProtocol = null;
      }

      final fullContext = additionalContext != null
          ? (protocolContext != null
              ? '$additionalContext\n\n$protocolContext'
              : additionalContext)
          : protocolContext;

      String fullQuery = _currentQuery;
      if (_uploadedDocument != null) {
        fullQuery +=
            '\n\n[USER UPLOADED MEDICAL RECORD]:\n${_uploadedDocument!.content}';
      }

      final stream = _engineService.generateTriage(
        fullQuery,
        context: fullContext,
        profile: _userProfile,
        onTelemetryUpdate: (telemetry) {
          _ttftMs = telemetry.ttftMs;
          _tokensPerSec = telemetry.tokensPerSec;
          _ramUsageMb = telemetry.ramUsageMb;
          notifyListeners();
        },
      );

      _generationSubscription?.cancel();
      if (_generationCompleter != null && !_generationCompleter!.isCompleted) {
        _generationCompleter!.complete();
      }
      final completer = Completer<void>();
      _generationCompleter = completer;

      _generationSubscription = stream.listen(
        (token) {
          _streamedResponse += token;
          notifyListeners();
        },
        onError: (e) {
          _errorMessage = 'Triage generation error: $e';
          if (!completer.isCompleted) completer.complete();
        },
        onDone: () {
          if (!completer.isCompleted) completer.complete();
        },
        cancelOnError: true,
      );

      await completer.future;
    } catch (e) {
      _errorMessage = 'Triage generation error: $e';
    } finally {
      _isGenerating = false;
      _generationSubscription = null;
      _generationCompleter = null;
      _ramUsageMb = _engineService.getEstimatedRamUsageMB();
      notifyListeners();
      if (!_wasStopped || _streamedResponse.trim().isNotEmpty) {
        await _maybeSaveHistory();
      }
    }
  }

  /// Cancels in-flight generation, keeps partial text, and sets wasStopped flag.
  Future<void> stopGeneration() async {
    if (!_isGenerating) return;

    _isGenerating = false;
    _wasStopped = true;
    notifyListeners();

    try {
      await _engineService.stopGeneration();
    } catch (_) {}

    final sub = _generationSubscription;
    _generationSubscription = null;
    if (sub != null) {
      try {
        await sub.cancel();
      } catch (_) {}
    }

    if (_generationCompleter != null && !_generationCompleter!.isCompleted) {
      _generationCompleter!.complete();
    }
    _generationCompleter = null;

    _ramUsageMb = _engineService.getEstimatedRamUsageMB();
    notifyListeners();
  }

  /// Clears the currently streamed response card.
  void clearResponse() {
    _streamedResponse = '';
    _currentQuery = '';
    _errorMessage = null;
    _answerSource = null;
    _callEmergencyNow = false;
    _wasStopped = false;
    _selectedProtocol = null;
    _pendingQuestion = null;
    _clarificationNote = null;
    _hasClarifiedForCurrentQuery = false;
    notifyListeners();
  }

  Future<void> _maybeSaveHistory() async {
    final shouldSave = _settingsController?.saveHistory ?? true;
    if (!shouldSave) return;
    if (_streamedResponse.trim().isEmpty) return;
    if (_answerSource == null) return;
    if (_currentQuery.trim().isEmpty) return;

    try {
      final entry = HistoryEntry(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        timestamp: DateTime.now(),
        query: _currentQuery,
        response: _streamedResponse,
        answerSource: _answerSource!,
        protocolId: _selectedProtocol?.id,
      );
      await _historyStore.saveEntry(entry);
    } catch (_) {}
  }

  @override
  void dispose() {
    _generationSubscription?.cancel();
    _engineService.dispose();
    super.dispose();
  }
}
