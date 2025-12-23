import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class HistoryScreen extends StatefulWidget {
  final String baseUrl;
  final String sessionId;

  const HistoryScreen({
    super.key,
    required this.baseUrl,
    required this.sessionId,
  });

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  bool _loading = true;
  String _error = "";

  // Firestore messages as list
  List<Map<String, dynamic>> _messages = [];

  // ---------- Brown theme colors ----------
  static const _brown900 = Color(0xFF3E2723);
  static const _brown800 = Color(0xFF4E342E);
  static const _brown700 = Color(0xFF5D4037);
  static const _brown200 = Color(0xFFD7CCC8);
  static const _cream = Color(0xFFF7F3EF);

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  String _prettyIsoTime(String iso) {
    // Convert ISO -> friendly text without extra packages
    try {
      final dt = DateTime.parse(iso).toLocal();
      String two(int n) => n.toString().padLeft(2, "0");
      return "${dt.year}-${two(dt.month)}-${two(dt.day)}  ${two(dt.hour)}:${two(dt.minute)}";
    } catch (_) {
      return iso;
    }
  }

  Future<void> _loadHistory() async {
    if (widget.sessionId.isEmpty) {
      setState(() {
        _loading = false;
        _error = "Session not ready yet.";
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = "";
    });

    try {
      // ✅ IMPORTANT: days=0 -> fetch ALL messages (not only last 7 days)
      final uri = Uri.parse(
        "${widget.baseUrl}/chatbot/history/${widget.sessionId}?days=0",
      );

      debugPrint("HISTORY URL: $uri");

      final res = await http.get(uri);

      debugPrint("STATUS: ${res.statusCode}");
      debugPrint("BODY: ${res.body}");

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);

        final raw = data["messages"];
        final List<Map<String, dynamic>> parsed = [];

        if (raw is List) {
          for (final m in raw) {
            if (m is Map) {
              parsed.add(
                m.map((k, v) => MapEntry(k.toString(), v)),
              );
            }
          }
        }

        setState(() {
          _messages = parsed;
          _loading = false;
        });
      } else {
        setState(() {
          _error = "Failed to load history (status ${res.statusCode})";
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = "Error: $e";
        _loading = false;
      });
    }
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: _brown900,
      title: const Text(
        "Chat History",
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
      actions: [
        IconButton(
          tooltip: "Refresh",
          icon: const Icon(Icons.refresh),
          onPressed: _loadHistory,
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(18),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _brown200.withOpacity(0.9)),
          boxShadow: [
            BoxShadow(
              blurRadius: 20,
              offset: const Offset(0, 8),
              color: Colors.black.withOpacity(0.06),
            )
          ],
        ),
        child: Text(
          "No history yet.\nStart chatting and come back here.",
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _brown800.withOpacity(0.85),
            height: 1.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(18),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _brown200.withOpacity(0.9)),
        ),
        child: Text(
          _error,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.redAccent.withOpacity(0.9),
            height: 1.4,
            fontWeight: FontWeight.w700,
          ),
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
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error.isNotEmpty
                ? _buildErrorState()
                : _messages.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
                        itemCount: _messages.length,
                        itemBuilder: (_, i) => _HistoryBubble(
                          message: _messages[i],
                          brown900: _brown900,
                          brown700: _brown700,
                          brown200: _brown200,
                          prettyIsoTime: _prettyIsoTime,
                        ),
                      ),
      ),
    );
  }
}

class _HistoryBubble extends StatelessWidget {
  final Map<String, dynamic> message;
  final Color brown900;
  final Color brown700;
  final Color brown200;
  final String Function(String iso) prettyIsoTime;

  const _HistoryBubble({
    required this.message,
    required this.brown900,
    required this.brown700,
    required this.brown200,
    required this.prettyIsoTime,
  });

  @override
  Widget build(BuildContext context) {
    final sender = (message["sender"] ?? "unknown").toString();
    final text = (message["text"] ?? "").toString();

    // Prefer displayTime, fallback to createdAtIso
    final displayTime = (message["displayTime"] ?? "").toString();
    final createdAtIso = (message["createdAtIso"] ?? "").toString();

    final emotion = message["emotion"]?.toString();
    final intent = message["intent"]?.toString();

    final isUser = sender.toLowerCase() == "user";

    final bubbleColor = isUser ? brown700 : Colors.white;
    final textColor = isUser ? Colors.white : brown900;

    String timeLabel = "";
    if (displayTime.isNotEmpty) {
      timeLabel = displayTime;
    } else if (createdAtIso.isNotEmpty) {
      timeLabel = prettyIsoTime(createdAtIso);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
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
              boxShadow: [
                BoxShadow(
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                  color: Colors.black.withOpacity(0.06),
                )
              ],
            ),
            child: Column(
              crossAxisAlignment:
                  isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Text(
                  text,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 14.5,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                if (!isUser && (emotion != null || intent != null)) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (emotion != null)
                        _ChipTag(
                          label: "Emotion: $emotion",
                          brown900: brown900,
                          brown200: brown200,
                        ),
                      if (intent != null)
                        _ChipTag(
                          label: "Intent: $intent",
                          brown900: brown900,
                          brown200: brown200,
                        ),
                    ],
                  ),
                ],

                if (timeLabel.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    timeLabel,
                    style: TextStyle(
                      color: (isUser ? Colors.white : brown900)
                          .withOpacity(0.65),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChipTag extends StatelessWidget {
  final String label;
  final Color brown900;
  final Color brown200;

  const _ChipTag({
    required this.label,
    required this.brown900,
    required this.brown200,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: brown200.withOpacity(0.35),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: brown200.withOpacity(0.7)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: brown900.withOpacity(0.85),
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
