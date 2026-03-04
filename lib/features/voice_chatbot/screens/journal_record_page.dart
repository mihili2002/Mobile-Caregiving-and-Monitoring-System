import 'dart:io' show File;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'my_diaries_page.dart';

import 'package:flutter_tts/flutter_tts.dart';
import 'package:path_provider/path_provider.dart';
import 'emotion_graph_page.dart';
class JournalRecordPage extends StatefulWidget {
  final String elderId;
  const JournalRecordPage({super.key, required this.elderId});

  @override
  State<JournalRecordPage> createState() => _JournalRecordPageState();
}

// ─────────────────────────────────────────────
// App state machine
// ─────────────────────────────────────────────
enum _PageMode { journal, question }

enum _RecordingState { idle, recording, processing, speaking, done, error }

class _JournalRecordPageState extends State<JournalRecordPage>
    with SingleTickerProviderStateMixin {
  // ── core ──────────────────────────────────
  final Record _recorder = Record();
  final FlutterTts _tts = FlutterTts();

  _PageMode _mode = _PageMode.journal;
  _RecordingState _recState = _RecordingState.idle;

  // ── audio file handles ─────────────────────
  String? _filePath; // mobile
  String? _webBlobUrl; // web

  // ── Q&A display ───────────────────────────
  String? _questionText;
  String? _answerText;
  String? _errorMessage;

  // ── animation ─────────────────────────────
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  // ── API ───────────────────────────────────
  final String _apiBaseUrl =
      kIsWeb ? 'http://localhost:8000' : 'http://10.0.2.2:8000';

  // ─────────────────────────────────────────
  // Life-cycle
  // ─────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _setupTts();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 1.0, end: 1.18).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _recorder.dispose();
    _tts.stop();
    _pulseCtrl.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────
  // TTS setup
  // ─────────────────────────────────────────
  Future<void> _setupTts() async {
    await _tts.setSpeechRate(0.42);
    await _tts.setPitch(1.0);
    await _tts.setLanguage('en-US');

    _tts.setCompletionHandler(() {
      if (mounted) {
        setState(() => _recState = _RecordingState.done);
      }
    });
  }

  Future<void> _speak(String text) async {
    if (text.trim().isEmpty) return;
    await _tts.stop();
    setState(() => _recState = _RecordingState.speaking);
    await _tts.speak(text);
  }

  Future<void> _stopSpeaking() async {
    await _tts.stop();
    if (mounted) setState(() => _recState = _RecordingState.done);
  }

  // ─────────────────────────────────────────
  // Recording
  // ─────────────────────────────────────────
  Future<void> _startRecording() async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      _setError('Microphone permission not granted.');
      return;
    }

    await _tts.stop();
    _clearResults();

    if (kIsWeb) {
      await _recorder.start();
    } else {
      final dir = await getApplicationDocumentsDirectory();
      final ts = DateTime.now().millisecondsSinceEpoch;
      final prefix = _mode == _PageMode.question ? 'question' : 'journal';
      final path = '${dir.path}/${prefix}_${widget.elderId}_$ts.m4a';

      await _recorder.start(
        path: path,
        bitRate: 128000,
        samplingRate: 16000,
      );
      _filePath = path;
    }

    setState(() => _recState = _RecordingState.recording);
  }

  Future<void> _stopRecording() async {
    final result = await _recorder.stop();

    if (kIsWeb) {
      _webBlobUrl = result;
    } else {
      _filePath = result;
    }

    setState(() => _recState = _RecordingState.idle);

    // In question mode, immediately submit after stopping
    if (_mode == _PageMode.question) {
      await _askFromJournals();
    }
  }

  // ─────────────────────────────────────────
  // Upload helper
  // ─────────────────────────────────────────
  Future<Map<String, dynamic>> _upload({
    required String endpoint,
    File? mobileFile,
    Uint8List? webBytes,
    String filename = 'audio.webm',
    Map<String, String>? fields,
  }) async {
    final token =
        await FirebaseAuth.instance.currentUser?.getIdToken(true);
    if (token == null) throw Exception('Not logged in');

    final uri = Uri.parse('$_apiBaseUrl$endpoint');
    final req = http.MultipartRequest('POST', uri);
    req.headers['Authorization'] = 'Bearer $token';

    if (fields != null) req.fields.addAll(fields);

    if (kIsWeb) {
      if (webBytes == null) throw Exception('No audio data (web)');
      req.files.add(
          http.MultipartFile.fromBytes('audio', webBytes, filename: filename));
    } else {
      if (mobileFile == null) throw Exception('No audio file (mobile)');
      req.files
          .add(await http.MultipartFile.fromPath('audio', mobileFile.path));
    }

    final res = await req.send();
    final body = await res.stream.bytesToString();

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Server error ${res.statusCode}: $body');
    }

    return body.isEmpty ? {} : (jsonDecode(body) as Map<String, dynamic>);
  }

  Future<Uint8List> _blobToBytes(String blobUrl) async {
    final res = await http.get(Uri.parse(blobUrl));
    if (res.statusCode != 200) {
      throw Exception('Failed to read audio blob');
    }
    return res.bodyBytes;
  }

  // ─────────────────────────────────────────
  // QUESTION MODE — core action
  // ─────────────────────────────────────────
  Future<void> _askFromJournals() async {
    setState(() {
      _recState = _RecordingState.processing;
      _errorMessage = null;
    });

    try {
      Map<String, dynamic> result;
      final ts = DateTime.now().millisecondsSinceEpoch;

      if (kIsWeb) {
        if (_webBlobUrl == null || _webBlobUrl!.isEmpty) {
          _setError('No recording found. Please record again.');
          return;
        }
        final bytes = await _blobToBytes(_webBlobUrl!);
        result = await _upload(
          endpoint: '/chatbot/journals/ask',
          webBytes: bytes,
          filename: 'question_$ts.webm',
          fields: {'elder_uid': widget.elderId},
        );
      } else {
        if (_filePath == null || _filePath!.isEmpty) {
          _setError('No recording found. Please record again.');
          return;
        }
        final f = File(_filePath!);
        if (!await f.exists()) {
          _setError('Audio file missing. Please record again.');
          return;
        }
        result = await _upload(
          endpoint: '/chatbot/journals/ask',
          mobileFile: f,
          fields: {'elder_uid': widget.elderId},
        );
      }

      final questionText = (result['question_text'] ?? '').toString().trim();
      final replyText = (result['reply_text'] ?? '').toString().trim();

      setState(() {
        _questionText = questionText.isEmpty ? null : questionText;
        _answerText = replyText.isEmpty ? 'No answer found in journals.' : replyText;
      });

      print("SERVER RESPONSE FULL: $result");
      print("QUESTION TEXT: $questionText");
      print("REPLY TEXT: $replyText");

      await _speak(_answerText!);
    } catch (e) {
      _setError('Failed: $e');
    }
  }

  // ─────────────────────────────────────────
  // JOURNAL MODE — save
  // ─────────────────────────────────────────
  Future<void> _saveJournal() async {
    setState(() {
      _recState = _RecordingState.processing;
      _errorMessage = null;
    });

    try {
      Map<String, dynamic> result;
      final ts = DateTime.now().millisecondsSinceEpoch;

      if (kIsWeb) {
        if (_webBlobUrl == null || _webBlobUrl!.isEmpty) {
          _setError('Nothing to save. Please record first.');
          return;
        }
        final bytes = await _blobToBytes(_webBlobUrl!);
        result = await _upload(
          endpoint: '/chatbot/journals/upload',
          webBytes: bytes,
          filename: 'journal_$ts.webm',
        );
      } else {
        if (_filePath == null || _filePath!.isEmpty) {
          _setError('Nothing to save. Please record first.');
          return;
        }
        final f = File(_filePath!);
        if (!await f.exists()) {
          _setError('Audio file not found. Please record again.');
          return;
        }
        result = await _upload(
          endpoint: '/chatbot/journals/upload',
          mobileFile: f,
        );
      }

      setState(() {
        _recState = _RecordingState.done;
        _filePath = null;
        _webBlobUrl = null;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Journal saved successfully ✅'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      _setError('Save failed: $e');
    }
  }

  // ─────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────
  void _setError(String msg) {
    if (mounted) {
      setState(() {
        _recState = _RecordingState.error;
        _errorMessage = msg;
      });
    }
  }

  void _clearResults() {
    _questionText = null;
    _answerText = null;
    _errorMessage = null;
    _filePath = null;
    _webBlobUrl = null;
  }

  void _resetPage() {
    _tts.stop();
    _clearResults();
    setState(() => _recState = _RecordingState.idle);
  }

  bool get _isRecording => _recState == _RecordingState.recording;
  bool get _isProcessing => _recState == _RecordingState.processing;
  bool get _isSpeaking => _recState == _RecordingState.speaking;
  bool get _hasRecording =>
      (kIsWeb ? _webBlobUrl : _filePath) != null;

  // ─────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Voice Journal'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
        actions: [
          IconButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => MyDiariesPage(
                  elderId: widget.elderId,
                  apiBaseUrl: _apiBaseUrl,
                ),
              ),
            ),
            icon: const Icon(Icons.menu_book_outlined),
            tooltip: 'My Diaries',
          ),

          IconButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => EmotionGraphPage(
                  elderId: widget.elderId,
                  apiBaseUrl: _apiBaseUrl,
                ),
              ),
            ),
            icon: const Icon(Icons.insights_outlined),
            tooltip: 'Emotion Graph',
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            children: [
              // ── Mode Switcher ──────────────────────
              _ModeSwitcher(
                mode: _mode,
                enabled: !_isRecording && !_isProcessing,
                onChanged: (m) {
                  _resetPage();
                  setState(() => _mode = m);
                },
              ),

              const SizedBox(height: 24),

              // ── Status / Result Card ───────────────
              Expanded(
                child: _StatusCard(
                  mode: _mode,
                  recState: _recState,
                  questionText: _questionText,
                  answerText: _answerText,
                  errorMessage: _errorMessage,
                  hasRecording: _hasRecording,
                  onReplay: _answerText != null
                      ? () => _speak(_answerText!)
                      : null,
                  onStopSpeaking: _isSpeaking ? _stopSpeaking : null,
                ),
              ),

              const SizedBox(height: 24),

              // ── Mic Button ────────────────────────
              _MicButton(
                isRecording: _isRecording,
                isProcessing: _isProcessing,
                isSpeaking: _isSpeaking,
                pulseAnim: _pulseAnim,
                primaryColor: scheme.primary,
                mode: _mode,
                onTap: _isProcessing || _isSpeaking
                    ? null
                    : (_isRecording ? _stopRecording : _startRecording),
              ),

              const SizedBox(height: 8),

              // ── Hint text ─────────────────────────
              Text(
                _micHint,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.black.withOpacity(0.45),
                  height: 1.4,
                ),
              ),

              const SizedBox(height: 20),

              // ── Bottom action row ─────────────────
              _BottomActions(
                mode: _mode,
                recState: _recState,
                hasRecording: _hasRecording,
                onCancel: _resetPage,
                onSave: _mode == _PageMode.journal && _hasRecording && !_isProcessing
                    ? _saveJournal
                    : null,
                onReset: _recState == _RecordingState.done ||
                        _recState == _RecordingState.error
                    ? _resetPage
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String get _micHint {
    if (_isProcessing) return 'Analysing your question…';
    if (_isSpeaking) return 'Speaking answer…\nTap stop to pause.';
    if (_isRecording) {
      return _mode == _PageMode.question
          ? 'Listening… Tap to stop when done.'
          : 'Recording… Tap to stop when done.';
    }
    if (_recState == _RecordingState.done) {
      return _mode == _PageMode.question
          ? 'Tap the mic to ask another question.'
          : 'Saved! Tap the mic to record again.';
    }
    return _mode == _PageMode.question
        ? 'Tap the mic and ask your question.\nI will search your journals.'
        : 'Tap the mic to start recording your journal.';
  }
}

// ══════════════════════════════════════════════
// WIDGETS
// ══════════════════════════════════════════════

class _ModeSwitcher extends StatelessWidget {
  final _PageMode mode;
  final bool enabled;
  final ValueChanged<_PageMode> onChanged;

  const _ModeSwitcher({
    required this.mode,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withOpacity(0.07)),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          _ModeTab(
            label: 'Journal',
            icon: Icons.edit_note_outlined,
            selected: mode == _PageMode.journal,
            enabled: enabled,
            onTap: () => onChanged(_PageMode.journal),
          ),
          _ModeTab(
            label: 'Ask Journals',
            icon: Icons.record_voice_over_outlined,
            selected: mode == _PageMode.question,
            enabled: enabled,
            onTap: () => onChanged(_PageMode.question),
          ),
        ],
      ),
    );
  }
}

class _ModeTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const _ModeTab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? Theme.of(context).colorScheme.primary
        : Colors.black45;

    return Expanded(
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? Theme.of(context).colorScheme.primary.withOpacity(0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight:
                      selected ? FontWeight.w600 : FontWeight.w400,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Status / Answer card ──────────────────────
class _StatusCard extends StatelessWidget {
  final _PageMode mode;
  final _RecordingState recState;
  final String? questionText;
  final String? answerText;
  final String? errorMessage;
  final bool hasRecording;
  final VoidCallback? onReplay;
  final VoidCallback? onStopSpeaking;

  const _StatusCard({
    required this.mode,
    required this.recState,
    required this.questionText,
    required this.answerText,
    required this.errorMessage,
    required this.hasRecording,
    this.onReplay,
    this.onStopSpeaking,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: _cardContent(context),
        ),
      ),
    );
  }

  Widget _cardContent(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    // ── Error ──
    if (recState == _RecordingState.error && errorMessage != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 20),
            const SizedBox(width: 8),
            const Text('Something went wrong',
                style: TextStyle(
                    fontWeight: FontWeight.w600, color: Colors.red)),
          ]),
          const SizedBox(height: 8),
          Text(errorMessage!, style: const TextStyle(fontSize: 14, height: 1.4)),
        ],
      );
    }

    // ── Processing ──
    if (recState == _RecordingState.processing) {
      return const Center(
        child: Column(
          children: [
            SizedBox(height: 16),
            CircularProgressIndicator(strokeWidth: 2.5),
            SizedBox(height: 16),
            Text('Searching through your journals…',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: Colors.black54)),
            SizedBox(height: 16),
          ],
        ),
      );
    }

    // ── Q&A result ──
    if (answerText != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (questionText != null) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.person_outline,
                    size: 18, color: Colors.black45),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    questionText!,
                    style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black54,
                        fontStyle: FontStyle.italic),
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.auto_awesome, size: 18, color: primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  answerText!,
                  style: const TextStyle(
                      fontSize: 16, height: 1.55, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              if (onStopSpeaking != null)
                OutlinedButton.icon(
                  onPressed: onStopSpeaking,
                  icon: const Icon(Icons.stop_circle_outlined, size: 18),
                  label: const Text('Stop'),
                  style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red),
                ),
              if (onReplay != null && onStopSpeaking == null)
                OutlinedButton.icon(
                  onPressed: onReplay,
                  icon: const Icon(Icons.replay, size: 18),
                  label: const Text('Replay'),
                ),
            ],
          ),
        ],
      );
    }

    // ── Recording active ──
    if (recState == _RecordingState.recording) {
      return Center(
        child: Column(
          children: [
            const SizedBox(height: 16),
            Icon(Icons.hearing, size: 42, color: primary.withOpacity(0.7)),
            const SizedBox(height: 12),
            Text(
              mode == _PageMode.question
                  ? 'I\'m listening…\nSpeak your question clearly.'
                  : 'Recording your journal…\nSpeak naturally.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, height: 1.5),
            ),
            const SizedBox(height: 16),
          ],
        ),
      );
    }

    // ── Default: idle / done ──
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 16),
          Icon(
            mode == _PageMode.question
                ? Icons.record_voice_over_outlined
                : Icons.mic_none_outlined,
            size: 48,
            color: Colors.black26,
          ),
          const SizedBox(height: 12),
          Text(
            mode == _PageMode.question
                ? 'Ask a question about your past journals.\nFor example: "How did I feel last week?"'
                : 'Record a new journal entry.\nTap the mic below to start.',
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 15, height: 1.55, color: Colors.black54),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ── Mic button ────────────────────────────────
class _MicButton extends StatelessWidget {
  final bool isRecording;
  final bool isProcessing;
  final bool isSpeaking;
  final Animation<double> pulseAnim;
  final Color primaryColor;
  final _PageMode mode;
  final VoidCallback? onTap;

  const _MicButton({
    required this.isRecording,
    required this.isProcessing,
    required this.isSpeaking,
    required this.pulseAnim,
    required this.primaryColor,
    required this.mode,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color bgColor = primaryColor;
    IconData icon = Icons.mic;

    if (isRecording) {
      bgColor = Colors.red;
      icon = Icons.stop;
    } else if (isProcessing) {
      bgColor = Colors.grey.shade400;
      icon = Icons.hourglass_top;
    } else if (isSpeaking) {
      bgColor = Colors.orange.shade600;
      icon = Icons.volume_up;
    }

    Widget btn = GestureDetector(
      onTap: onTap,
      child: Container(
        width: 130,
        height: 130,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: bgColor,
          boxShadow: [
            BoxShadow(
              color: bgColor.withOpacity(0.40),
              blurRadius: 28,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 56),
      ),
    );

    if (isRecording) {
      return AnimatedBuilder(
        animation: pulseAnim,
        builder: (_, child) =>
            Transform.scale(scale: pulseAnim.value, child: child),
        child: btn,
      );
    }

    return btn;
  }
}

// ── Bottom action row ─────────────────────────
class _BottomActions extends StatelessWidget {
  final _PageMode mode;
  final _RecordingState recState;
  final bool hasRecording;
  final VoidCallback onCancel;
  final VoidCallback? onSave;
  final VoidCallback? onReset;

  const _BottomActions({
    required this.mode,
    required this.recState,
    required this.hasRecording,
    required this.onCancel,
    this.onSave,
    this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    // In question mode the answer auto-plays; only show Reset or Cancel
    if (mode == _PageMode.question) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: onCancel,
              child: const Text('Cancel'),
            ),
          ),
          if (onReset != null) ...[
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: onReset,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Ask Again'),
              ),
            ),
          ],
        ],
      );
    }

    // Journal mode
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: onCancel,
            child: const Text('Cancel'),
          ),
        ),
        if (onSave != null) ...[
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: onSave,
              icon: const Icon(Icons.save_outlined, size: 18),
              label: const Text('Save Journal'),
            ),
          ),
        ],
      ],
    );
  }
}