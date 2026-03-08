// lib/features/voice_chatbot/screens/chat_screen.dart
// ✅ UPDATED: session_id is now ALWAYS the elderUid (so caregiver + elder see same emotions)
// ✅ UPDATED: Removed History + Emotions buttons (and their imports)

import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';

import '../widgets/chat_message.dart';
import 'session_screen.dart';
import 'all_emotion_screen.dart';
import 'api.dart';
import '../../../services/routine_understanding_service.dart';

class ChatScreen extends StatefulWidget {
  // ✅ REQUIRED: elder UID must be passed from Elder dashboard or caregiver dashboard
  final String elderUid;

  const ChatScreen({
    super.key,
    required this.elderUid,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<ChatMessage> _messages = [];
  final TextEditingController _textController = TextEditingController();

  late stt.SpeechToText _speech;
  bool _isListening = false;
  String _recognizedText = '';

  final FlutterTts _tts = FlutterTts();
  bool _ttsEnabled = true;

  // ✅ IMPORTANT: session id = elderUid (same key everywhere)
  late final String _sessionId;
  final RoutineUnderstandingService _routineService = RoutineUnderstandingService();

  // ⚠️ Chrome/Web: 127.0.0.1
  // Android Emulator: 10.0.2.2
  // Real device: your PC LAN IP, e.g. 192.168.1.5
  final String _baseUrl = 'http://127.0.0.1:8000';

  // ---------- Green theme colors ----------
  static const _green900 = Color(0xFF1B5E20);
  static const _green800 = Color(0xFF2E7D32);
  static const _green700 = Color(0xFF388E3C);
  static const _green200 = Color(0xFFC8E6C9);
  static const _mint = Color(0xFFF1F8E9);

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _initTts();

    // ✅ session is fixed to elderUid
    _sessionId = widget.elderUid.trim();

    debugPrint("CHAT SCREEN elderUid/session_id = $_sessionId");
  }

  Future<void> _initTts() async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.45);
  }

  Future<void> _speak(String text) async {
    if (!_ttsEnabled || text.isEmpty) return;
    await _tts.stop();
    await _tts.speak(text);
  }

  Future<void> _startListening() async {
    final available = await _speech.initialize();
    if (!available) return;

    setState(() {
      _isListening = true;
      _recognizedText = '';
    });

    _speech.listen(
      onResult: (result) =>
          setState(() => _recognizedText = result.recognizedWords),
    );
  }

  void _stopListening() {
    _speech.stop();
    setState(() => _isListening = false);

    if (_recognizedText.isNotEmpty) {
      _sendMessage(_recognizedText);
    }
  }

  Future<void> _openQaDialog() async {
    final TextEditingController qaController = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text("Ask the Bot (Mood Q&A)"),
          content: TextField(
            controller: qaController,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: "Example: Summarize my mood yesterday",
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _sendMessage("Summarize my mood yesterday");
              },
              child: const Text("Yesterday Mood"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                final q = qaController.text.trim();
                Navigator.pop(ctx);
                if (q.isNotEmpty) _sendMessage(q);
              },
              child: const Text("Ask"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _sendMessage(String text) async {
    if (_sessionId.isEmpty) {
      debugPrint("elderUid/session_id is empty");
      return;
    }
    if (text.trim().isEmpty) return;

    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true));
      _textController.clear();
    });

    try {
      final api = Api(_baseUrl);

      final data = await api.postJson("/chatbot/chat", {
        "message": text,
        "session_id": _sessionId, // ✅ always elderUid
      });

      final reply = data["reply"] ?? "No reply";
      final emotion = data["emotion"] ?? "unknown";
      final intent = data["intent"] ?? "none";

      if (!mounted) return;
      setState(() {
        _messages.add(ChatMessage(
          text: reply,
          isUser: false,
          emotion: emotion,
          intent: intent,
        ));
      });

      // Passive conversational evidence extraction
      await _routineService.processSpeechInput(_sessionId, text, backendIntent: intent);

      await _speak(reply);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add(ChatMessage(text: "Error: $e", isUser: false));
      });
    }
  }

  @override
  void dispose() {
    _speech.stop();
    _tts.stop();
    _textController.dispose();
    super.dispose();
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: _green900,
      title: const Text(
        'Voice Chatbot',
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
      actions: [
        IconButton(
          tooltip: "Q & A",
          icon: const Icon(Icons.question_answer),
          onPressed: _openQaDialog,
        ),

        IconButton(
          tooltip: "All Sessions",
          icon: const Icon(Icons.list_alt),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SessionsScreen(baseUrl: _baseUrl),
              ),
            );
          },
        ),

        // ✅ Keep only this emotions page (charts screen)
        IconButton(
          tooltip: "All Emotions (Weekly)",
          icon: const Icon(Icons.calendar_month),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AllEmotionsScreen(
                  baseUrl: _baseUrl,
                  elderUid: _sessionId,
                  days: 7,
                ),
              ),
            );
          },
        ),

        IconButton(
          tooltip: _ttsEnabled ? "Mute" : "Unmute",
          icon: Icon(_ttsEnabled ? Icons.volume_up : Icons.volume_off),
          onPressed: () async {
            setState(() => _ttsEnabled = !_ttsEnabled);
            await _tts.stop();
          },
        ),
      ],
    );
  }

  Widget _buildHeaderHint() {
    final text = _isListening
        ? "Listening… speak now"
        : "Ask anything about caregiving. Tap mic for voice.";

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.85),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _green200.withOpacity(0.8)),
        boxShadow: [
          BoxShadow(
            blurRadius: 18,
            spreadRadius: 1,
            offset: const Offset(0, 8),
            color: Colors.black.withOpacity(0.06),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: _isListening ? Colors.redAccent : _green700,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: _green900.withOpacity(0.9),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (_recognizedText.isNotEmpty && _isListening) ...[
            const SizedBox(width: 10),
            const Icon(Icons.graphic_eq, size: 20),
          ],
        ],
      ),
    );
  }

  Widget _buildChatList() {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.88),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _green200.withOpacity(0.9)),
          boxShadow: [
            BoxShadow(
              blurRadius: 24,
              spreadRadius: 0,
              offset: const Offset(0, 10),
              color: Colors.black.withOpacity(0.06),
            ),
          ],
        ),
        child: _messages.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    "Start a conversation.\nTry: “I feel stressed today.”",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _green800.withOpacity(0.85),
                      height: 1.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                itemCount: _messages.length,
                itemBuilder: (_, i) => _StyledBubble(
                  msg: _messages[i],
                  green900: _green900,
                  green700: _green700,
                  green200: _green200,
                ),
              ),
      ),
    );
  }

  Widget _buildInputBar() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.92),
          border: Border(
            top: BorderSide(color: _green200.withOpacity(0.8)),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _textController,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(_textController.text),
                decoration: InputDecoration(
                  hintText: _isListening ? "Listening…" : "Type your message…",
                  hintStyle: TextStyle(color: _green700.withOpacity(0.55)),
                  filled: true,
                  fillColor: _mint,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: _green200),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: _green700, width: 1.4),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            _RoundIconButton(
              tooltip: "Send",
              color: _green700,
              icon: Icons.send_rounded,
              onTap: () => _sendMessage(_textController.text),
            ),
            const SizedBox(width: 10),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              child: _RoundIconButton(
                tooltip: _isListening ? "Stop" : "Mic",
                color: _isListening ? Colors.redAccent : _green900,
                icon: _isListening ? Icons.stop_circle : Icons.mic,
                onTap: _isListening ? _stopListening : _startListening,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      backgroundColor: _mint,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              _green900.withOpacity(0.18),
              _mint,
            ],
          ),
        ),
        child: Column(
          children: [
            _buildHeaderHint(),
            _buildChatList(),
            _buildInputBar(),
          ],
        ),
      ),
    );
  }
}

// ----------------- UI widgets -----------------

class _RoundIconButton extends StatelessWidget {
  final String tooltip;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  const _RoundIconButton({
    required this.tooltip,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Tooltip(
          message: tooltip,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Icon(icon, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class _StyledBubble extends StatelessWidget {
  final ChatMessage msg;
  final Color green900;
  final Color green700;
  final Color green200;

  const _StyledBubble({
    required this.msg,
    required this.green900,
    required this.green700,
    required this.green200,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = msg.isUser;

    final bubbleColor = isUser ? green700 : Colors.white;
    final textColor = isUser ? Colors.white : green900;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18),
                topRight: const Radius.circular(18),
                bottomLeft: Radius.circular(isUser ? 18 : 4),
                bottomRight: Radius.circular(isUser ? 4 : 18),
              ),
              border: Border.all(
                color: isUser ? Colors.transparent : green200.withOpacity(0.85),
              ),
            ),
            child: Text(
              msg.text,
              style: TextStyle(
                color: textColor,
                fontSize: 14.5,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
