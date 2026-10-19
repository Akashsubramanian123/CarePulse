import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../models/history_entry.dart';
import '../../services/history_store.dart';
import '../../services/tts_service.dart';
import '../../state/triage_controller.dart';
import '../widgets/glass_card.dart';
import '../widgets/streaming_response_card.dart';

/// Screen displaying locally saved triage query history.
class HistoryScreen extends StatefulWidget {
  final HistoryStore? historyStore;

  const HistoryScreen({super.key, this.historyStore});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late final HistoryStore _store;
  List<HistoryEntry> _entries = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _store = widget.historyStore ?? HistoryStore();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final list = await _store.loadEntries();
    if (mounted) {
      setState(() {
        _entries = list;
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteEntry(String id) async {
    await _store.deleteEntry(id);
    await _loadHistory();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Query deleted from history'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _confirmClearAll(CarePulseGlass glass) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: glass.glassBorderColor),
        ),
        title: Text(
          'Clear All History?',
          style: TextStyle(
            color: glass.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Are you sure you want to delete all saved emergency queries? This action cannot be undone.',
          style: TextStyle(color: glass.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: glass.textSecondary),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE05A4F),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _store.clearAll();
      await _loadHistory();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All query history cleared'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  String _formatDate(DateTime dt) {
    final y = dt.year.toString();
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $h:$min';
  }

  @override
  Widget build(BuildContext context) {
    final glass = Theme.of(context).extension<CarePulseGlass>()!;

    final errorColor = Theme.of(context).colorScheme.error;

    return GlassScaffold(
      title: 'Query History',
      actions: [
        if (_entries.isNotEmpty)
          SizedBox(
            height: 48,
            child: TextButton.icon(
              key: const ValueKey('history_clear_all_button'),
              icon: const Icon(Icons.delete_sweep_rounded, size: 20),
              label: const Text('Clear all'),
              style: TextButton.styleFrom(
                foregroundColor: errorColor,
                minimumSize: const Size(48, 48),
              ),
              onPressed: () => _confirmClearAll(glass),
            ),
          ),
        const SizedBox(width: 8),
      ],
      body: Column(
        children: [
          // Reassurance privacy banner
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: GlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              borderRadius: 16,
              child: Row(
                children: [
                  Icon(Icons.shield_outlined,
                      size: 18, color: glass.accentMint),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'History stays on this device.',
                      style: TextStyle(
                        color: glass.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Content Area
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(color: glass.accentMint))
                : _entries.isEmpty
                    ? _buildEmptyState(glass)
                    : ShaderMask(
                        shaderCallback: (Rect bounds) {
                          return const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0xFF000000),
                              Color(0xFF000000),
                              Color(0xFF000000),
                              Colors.transparent,
                            ],
                            stops: [0.0, 0.88, 0.96, 1.0],
                          ).createShader(bounds);
                        },
                        blendMode: BlendMode.dstIn,
                        child: _buildHistoryList(glass),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(CarePulseGlass glass) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: glass.iconTintGradient,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.25),
                  width: 1,
                ),
              ),
              child: Icon(
                Icons.history_rounded,
                size: 48,
                color: glass.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No queries saved yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: glass.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'History stays on this device.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: glass.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryList(CarePulseGlass glass) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _entries.length,
      itemBuilder: (context, index) {
        final entry = _entries[index];
        final errorColor = Theme.of(context).colorScheme.error;

        return Dismissible(
          key: ValueKey('history_item_${entry.id}'),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFE05A4F).withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(Icons.delete_rounded, color: Colors.white),
          ),
          onDismissed: (_) => _deleteEntry(entry.id),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: GlassCard(
              borderRadius: 18,
              padding: const EdgeInsets.all(14),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => HistoryDetailScreen(entry: entry),
                  ),
                );
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Date & Time
                      Row(
                        children: [
                          Icon(Icons.access_time_rounded,
                              size: 14, color: glass.textSecondary),
                          const SizedBox(width: 5),
                          Text(
                            _formatDate(entry.timestamp),
                            style: TextStyle(
                              fontSize: 12,
                              color: glass.textSecondary,
                            ),
                          ),
                        ],
                      ),

                      // Delete button (>= 48x48)
                      SizedBox(
                        width: 48,
                        height: 48,
                        child: IconButton(
                          key: ValueKey('delete_history_${entry.id}'),
                          icon: Icon(
                            Icons.delete_outline_rounded,
                            size: 20,
                            color: errorColor,
                          ),
                          tooltip: 'Delete query',
                          onPressed: () => _deleteEntry(entry.id),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Query
                  Text(
                    entry.query,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: glass.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Source Chip
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: glass.accentMint.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: glass.accentMint.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          entry.answerSource == AnswerSource.verifiedProtocol
                              ? Icons.verified_user_rounded
                              : (entry.answerSource ==
                                      AnswerSource.aiGuidedByProtocol
                                  ? Icons.auto_awesome_rounded
                                  : Icons.info_outline_rounded),
                          size: 13,
                          color: glass.accentMint,
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            entry.answerSource.label,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: glass.accentMint,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Read-only view for a past query history entry.
class HistoryDetailScreen extends StatefulWidget {
  final HistoryEntry entry;

  const HistoryDetailScreen({super.key, required this.entry});

  @override
  State<HistoryDetailScreen> createState() => _HistoryDetailScreenState();
}

class _HistoryDetailScreenState extends State<HistoryDetailScreen> {
  final TtsService _tts = TtsService();
  bool _isSpeaking = false;

  @override
  void initState() {
    super.initState();
    _tts.isSpeakingNotifier.addListener(_onTtsChanged);
  }

  void _onTtsChanged() {
    if (mounted) {
      setState(() => _isSpeaking = _tts.isSpeaking);
    }
  }

  @override
  void dispose() {
    _tts.isSpeakingNotifier.removeListener(_onTtsChanged);
    _tts.stop();
    super.dispose();
  }

  void _toggleSpeak() {
    if (_isSpeaking) {
      _tts.stop();
    } else {
      _tts.speak(widget.entry.response);
    }
  }

  @override
  Widget build(BuildContext context) {
    final glass = Theme.of(context).extension<CarePulseGlass>()!;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Query Details',
          style: TextStyle(
            color: glass.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(gradient: glass.backgroundGradient),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Prominent Read Aloud Action Button (>= 48x48)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: SizedBox(
                    height: 52,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isSpeaking
                            ? const Color(0xFFE05A4F)
                            : glass.accentMint,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      icon: Icon(
                        _isSpeaking
                            ? Icons.stop_circle_rounded
                            : Icons.volume_up_rounded,
                        size: 22,
                      ),
                      label: Text(
                        _isSpeaking
                            ? 'Stop Reading Guidance'
                            : 'Read Guidance Aloud',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onPressed: _toggleSpeak,
                    ),
                  ),
                ),

                // Reused Read-only Streaming Response Card
                StreamingResponseCard(
                  query: widget.entry.query,
                  responseText: widget.entry.response,
                  isGenerating: false,
                  wasStopped: false,
                  sourceLabel: widget.entry.answerSource.label,
                  onSpeak: _toggleSpeak,
                  isSpeaking: _isSpeaking,
                  onStopSpeaking: () => _tts.stop(),
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
