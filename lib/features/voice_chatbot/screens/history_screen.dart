import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

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

  static const _brown900 = Color(0xFF3E2723);
  static const _cream = Color(0xFFF7F3EF);

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _loading = true;
      _error = "";
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _error = "Not logged in";
          _loading = false;
        });
        return;
      }

      final token = await user.getIdToken();

      final uri = Uri.parse(
        "${widget.baseUrl}/chatbot/history/${widget.sessionId}?days=0",
      );

      final res = await http.get(
        uri,
        headers: {"Authorization": "Bearer $token"},
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final raw = (data["messages"] as List?) ?? [];

        final parsed = <Map<String, dynamic>>[];
        for (final m in raw) {
          if (m is Map) {
            parsed.add(m.map((k, v) => MapEntry(k.toString(), v)));
          }
        }

        setState(() {
          _messages = parsed;
          _loading = false;
        });
      } else {
        setState(() {
          _error = "Failed to load history (${res.statusCode})";
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _cream,
      appBar: AppBar(
        backgroundColor: _brown900,
        title: Text("History: ${widget.sessionId}"),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadHistory),

          // ✅ NEW: Q&A button
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
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
              ? Center(child: Text(_error))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _messages.length,
                  itemBuilder: (_, i) {
                    final m = _messages[i];

                    final sender = (m["sender"] ?? "").toString();
                    final text = (m["text"] ?? "").toString();
                    final emotion = (m["emotion"] ?? "").toString();
                    final intent = (m["intent"] ?? "").toString();
                    final ts = (m["createdAtIso"] ?? "").toString();

                    final isUser = sender == "user";

                    return Align(
                      alignment:
                          isUser ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        padding: const EdgeInsets.all(12),
                        constraints: BoxConstraints(
                          maxWidth:
                              MediaQuery.of(context).size.width * 0.78,
                        ),
                        decoration: BoxDecoration(
                          color: isUser ? Colors.brown.shade200 : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          crossAxisAlignment: isUser
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.start,
                          children: [
                            Text(text, style: const TextStyle(fontSize: 15)),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (ts.isNotEmpty)
                                  Text(
                                    ts,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                if (emotion.isNotEmpty && isUser) ...[
                                  const SizedBox(width: 8),
                                  Text(
                                    "emotion: $emotion",
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ],
                                if (intent.isNotEmpty && !isUser) ...[
                                  const SizedBox(width: 8),
                                  Text(
                                    "intent: $intent",
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
