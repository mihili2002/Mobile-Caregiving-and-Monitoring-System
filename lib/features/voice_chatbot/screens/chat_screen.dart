import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:http/http.dart' as http;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../widgets/chat_message.dart';

import 'history_screen.dart';
import 'emotions_screen.dart';
import 'session_screen.dart'; // must contain SessionsScreen
//import 'all_emotions_screen.dart';
//import 'package:mobile_caregiving_and_monitoring_system/features/voice_chatbot/screens/all_emotions_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

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

  // Persisted session id (shared preferences)
  String _sessionId = "";

  // ⚠️ Chrome/Web: 127.0.0.1
  // Android Emulator: 10.0.2.2
  final String _baseUrl = 'http://127.0.0.1:8000';

  // ---------- Brown theme colors ----------
  static const _brown900 = Color(0xFF3E2723);
  static const _brown800 = Color(0xFF4E342E);
  static const _brown700 = Color(0xFF5D4037);
  static const _brown200 = Color(0xFFD7CCC8);
  static const _cream = Color(0xFFF7F3EF);

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _initTts();
    _initSession();
  }

  Future<void> _initSession() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString("session_id");

    if (saved != null && saved.isNotEmpty) {
      setState(() => _sessionId = saved);
    } else {
      final newId = DateTime.now().millisecondsSinceEpoch.toString();
      await prefs.setString("session_id", newId);
      setState(() => _sessionId = newId);
    }

    debugPrint("SESSION ID: $_sessionId");
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

  Future<void> _sendMessage(String text) async {
    if (_sessionId.isEmpty) {
      debugPrint("Session not ready yet");
      return;
    }
    if (text.trim().isEmpty) return;

    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true));
      _textController.clear();
    });

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/chatbot/chat'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'message': text,
          'session_id': _sessionId,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        final reply = data['reply'] ?? 'No reply';
        final emotion = data['emotion'] ?? 'unknown';
        final intent = data['intent'] ?? 'none';

        setState(() {
          _messages.add(ChatMessage(
            text: reply,
            isUser: false,
            emotion: emotion,
            intent: intent,
          ));
        });

        await _speak(reply);
      } else {
        setState(() {
          _messages.add(ChatMessage(
            text: 'Server error ${response.statusCode}',
            isUser: false,
          ));
        });
      }
    } catch (e) {
      setState(() {
        _messages.add(ChatMessage(text: 'Error: $e', isUser: false));
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
      backgroundColor: _brown900,
      title: const Text(
        'Voice Chatbot',
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
      actions: [
        // ✅ All Sessions
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

        // ✅ Weekly Emotions (FIXED: inside actions)
    //    IconButton(
        //  tooltip: "Weekly Emotions",
       //   icon: const Icon(Icons.calendar_month),
        //  onPressed: () {
         //   Navigator.push(
         //     context,
           //   MaterialPageRoute(
             //   builder: (_) => AllEmotionsScreen(baseUrl: _baseUrl, days: 7),
         //     ),
         //   );
       //   },
      //  ),

        // ✅ Chat History for current session
        IconButton(
          tooltip: "History",
          icon: const Icon(Icons.history),
          onPressed: () {
            if (_sessionId.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Session is not ready yet.")),
              );
              return;
            }

            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => HistoryScreen(
                  baseUrl: _baseUrl,
                  sessionId: _sessionId,
                ),
              ),
            );
          },
        ),

        // ✅ Emotions for current session
        IconButton(
          tooltip: "Emotions",
          icon: const Icon(Icons.emoji_emotions),
          onPressed: () {
            if (_sessionId.isEmpty) return;
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => EmotionsScreen(
                  baseUrl: _baseUrl,
                  sessionId: _sessionId,
                ),
              ),
            );
          },
        ),

        // ✅ TTS toggle
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
        : (_sessionId.isEmpty
            ? "Preparing session… please wait"
            : "Ask anything about caregiving. Tap mic for voice.");

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.85),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _brown200.withOpacity(0.8)),
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
              color: _isListening ? Colors.redAccent : _brown700,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: _brown900.withOpacity(0.9),
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
          border: Border.all(color: _brown200.withOpacity(0.9)),
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
                      color: _brown800.withOpacity(0.85),
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
                  brown900: _brown900,
                  brown700: _brown700,
                  brown200: _brown200,
                ),
              ),
      ),
    );
  }

  Widget _buildInputBar() {
    final disabled = _sessionId.isEmpty;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.92),
          border: Border(
            top: BorderSide(color: _brown200.withOpacity(0.8)),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _textController,
                enabled: !disabled,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(_textController.text),
                decoration: InputDecoration(
                  hintText: disabled
                      ? "Preparing session…"
                      : (_isListening ? "Listening…" : "Type your message…"),
                  hintStyle: TextStyle(color: _brown700.withOpacity(0.55)),
                  filled: true,
                  fillColor: _cream,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: _brown200),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: _brown700, width: 1.4),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            _RoundIconButton(
              tooltip: "Send",
              color: disabled ? _brown200 : _brown700,
              icon: Icons.send_rounded,
              onTap: disabled ? () {} : () => _sendMessage(_textController.text),
            ),
            const SizedBox(width: 10),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              child: _RoundIconButton(
                tooltip: _isListening ? "Stop" : "Mic",
                color: disabled
                    ? _brown200
                    : (_isListening ? Colors.redAccent : _brown900),
                icon: _isListening ? Icons.stop_circle : Icons.mic,
                onTap: disabled
                    ? () {}
                    : (_isListening ? _stopListening : _startListening),
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
      backgroundColor: _cream,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              _brown900.withOpacity(0.18),
              _cream,
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
  final Color brown900;
  final Color brown700;
  final Color brown200;

  const _StyledBubble({
    required this.msg,
    required this.brown900,
    required this.brown700,
    required this.brown200,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = msg.isUser;

    final bubbleColor = isUser ? brown700 : Colors.white;
    final textColor = isUser ? Colors.white : brown900;

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
                color: isUser ? Colors.transparent : brown200.withOpacity(0.85),
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
