import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'history_qa_screen.dart';

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
  List<Map<String, dynamic>> _messages = [];

  static const green = Color(0xFF00BBA7);
  static const greenDark = Color(0xFF009E8D);
  static const mintBg = Color(0xFFF2FBF7);
  static const botBubble = Colors.white;
  static const elderBubble = Color(0xFFDDF7F3);

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  bool _isBot(String sender) => sender.toLowerCase() == "bot";

  String _labelForSender(String sender) {
    return _isBot(sender) ? "Bot" : "Elder";
  }

  Future<void> _loadHistory() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = "";
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (!mounted) return;
        setState(() {
          _error = "Not logged in";
          _loading = false;
        });
        return;
      }

      final token = await user.getIdToken();

      final uri = Uri.parse(
        "${widget.baseUrl}/chatbot/sessions/${widget.sessionId}/messages?limit=500",
      );

      debugPrint("Loading history: $uri");

      final res = await http.get(
        uri,
        headers: {
          "Authorization": "Bearer $token",
        },
      ).timeout(const Duration(seconds: 15));

      debugPrint("History status: ${res.statusCode}");

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final raw = (data["items"] as List?) ?? [];

        final parsed = <Map<String, dynamic>>[];
        for (final m in raw) {
          if (m is Map) {
            parsed.add(m.map((k, v) => MapEntry(k.toString(), v)));
          }
        }

        if (!mounted) return;
        setState(() {
          _messages = parsed;
          _loading = false;
        });
      } else {
        if (!mounted) return;
        setState(() {
          _error = "Failed to load history (${res.statusCode})";
          _loading = false;
        });
      }
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _error = "History request timed out";
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = "Error loading history: $e";
        _loading = false;
      });
    }
  }

  String _formatDateTime(String raw) {
    if (raw.trim().isEmpty) return "";

    try {
      final dt = DateTime.parse(raw).toLocal();

      final day = dt.day.toString().padLeft(2, '0');
      final month = dt.month.toString().padLeft(2, '0');
      final year = dt.year.toString();

      int hour = dt.hour;
      final minute = dt.minute.toString().padLeft(2, '0');
      final ampm = hour >= 12 ? "PM" : "AM";

      hour = hour % 12;
      if (hour == 0) hour = 12;

      return "$day/$month/$year  $hour:$minute $ampm";
    } catch (_) {
      return raw;
    }
  }

  Widget _buildMetaChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          color: Colors.grey.shade700,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> m) {
    final sender = (m["sender"] ?? "").toString();
    final text = (m["text"] ?? "").toString().trim();
    final emotion = (m["emotion"] ?? "").toString().trim();
    final intent = (m["intent"] ?? "").toString().trim();
    final rawTs = ((m["createdAtIso"] ?? m["displayTime"] ?? "")).toString();
    final ts = _formatDateTime(rawTs);

    final isBot = _isBot(sender);
    final label = _labelForSender(sender);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Align(
        alignment: isBot ? Alignment.centerLeft : Alignment.centerRight,
        child: Column(
          crossAxisAlignment:
              isBot ? CrossAxisAlignment.start : CrossAxisAlignment.end,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isBot ? Colors.white : greenDark.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isBot ? greenDark : greenDark,
                  ),
                ),
              ),
            ),
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.80,
              ),
              decoration: BoxDecoration(
                color: isBot ? botBubble : elderBubble,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isBot ? 6 : 18),
                  bottomRight: Radius.circular(isBot ? 18 : 6),
                ),
                border: Border.all(
                  color: isBot
                      ? Colors.grey.shade200
                      : greenDark.withOpacity(0.18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment:
                    isBot ? CrossAxisAlignment.start : CrossAxisAlignment.end,
                children: [
                  Text(
                    text.isEmpty ? "-" : text,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.45,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    alignment:
                        isBot ? WrapAlignment.start : WrapAlignment.end,
                    children: [
                      if (ts.isNotEmpty) _buildMetaChip(ts),
                      if (emotion.isNotEmpty) _buildMetaChip("Emotion: $emotion"),
                      if (intent.isNotEmpty) _buildMetaChip("Intent: $intent"),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            _error,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15),
          ),
        ),
      );
    }

    if (_messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline, size: 42, color: Colors.grey.shade500),
            const SizedBox(height: 12),
            Text(
              "No messages found",
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 24),
      itemCount: _messages.length,
      itemBuilder: (_, i) => _buildMessageBubble(_messages[i]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: mintBg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: greenDark,
        title: const Text("Chat History"),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadHistory,
          ),
          IconButton(
            icon: const Icon(Icons.question_answer),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => HistoryQAScreen(
                    baseUrl: widget.baseUrl,
                    sessionId: widget.sessionId,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: greenDark,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Text(
              "Session: ${widget.sessionId}",
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }
}