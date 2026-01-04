import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

class HistoryQAScreen extends StatefulWidget {
  final String baseUrl;
  final String sessionId;

  const HistoryQAScreen({
    super.key,
    required this.baseUrl,
    required this.sessionId,
  });

  @override
  State<HistoryQAScreen> createState() => _HistoryQAScreenState();
}

class _HistoryQAScreenState extends State<HistoryQAScreen> {
  final _q = TextEditingController();
  bool _loading = false;
  String _answer = "";
  String _error = "";

  // theme (same palette idea)
  static const _brown900 = Color(0xFF3E2723);
  static const _cream = Color(0xFFF7F3EF);

  Future<void> _ask() async {
    final question = _q.text.trim();
    if (question.isEmpty) return;

    setState(() {
      _loading = true;
      _error = "";
      _answer = "";
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("Not logged in");

      final token = await user.getIdToken();

      final uri = Uri.parse("${widget.baseUrl}/chatbot/history_qa");

      final res = await http.post(
        uri,
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "session_id": widget.sessionId,
          "question": question,
          "max_messages": 40,
        }),
      );

      if (res.statusCode != 200) {
        setState(() {
          _error = "Server error (${res.statusCode}): ${res.body}";
          _loading = false;
        });
        return;
      }

      final data = jsonDecode(res.body);
      setState(() {
        _answer = (data["answer"] ?? "").toString();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = "Error: $e";
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _cream,
      appBar: AppBar(
        backgroundColor: _brown900,
        title: const Text("Ask about this chat"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Session: ${widget.sessionId}",
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _q,
              minLines: 1,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: "Ask a question from your saved chats",
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _ask(),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _ask,
                child: _loading
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text("Ask"),
              ),
            ),
            const SizedBox(height: 12),
            if (_error.isNotEmpty)
              Text(_error, style: const TextStyle(color: Colors.red)),
            if (_answer.isNotEmpty)
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      _answer,
                      style: const TextStyle(fontSize: 15, height: 1.35),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
