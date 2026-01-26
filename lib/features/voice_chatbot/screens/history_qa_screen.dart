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

  // ---------- Green theme ----------
  static const _green900 = Color(0xFF0B3D2E); // deep evergreen
  static const _green700 = Color(0xFF1B6B52); // primary green
  static const _green200 = Color(0xFFCFE8D8); // light mint border
  static const _mint = Color(0xFFF2FBF6); // background

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
        if (!mounted) return;
        setState(() {
          _error = "Server error (${res.statusCode}): ${res.body}";
          _loading = false;
        });
        return;
      }

      final data = jsonDecode(res.body);
      if (!mounted) return;
      setState(() {
        _answer = (data["answer"] ?? "").toString();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
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
      backgroundColor: _mint,
      appBar: AppBar(
        backgroundColor: _green900,
        title: const Text("Ask about this chat"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Session: ${widget.sessionId}",
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: _green900.withOpacity(0.92),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _q,
              minLines: 1,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: "Ask a question from your saved chats",
                labelStyle: TextStyle(color: _green700.withOpacity(0.9)),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: _green200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _green700, width: 1.4),
                ),
              ),
              onSubmitted: (_) => _ask(),
            ),
            const SizedBox(height: 10),
         SizedBox(
  width: double.infinity,
  child: ElevatedButton(
    onPressed: _loading ? null : _ask,
    style: ElevatedButton.styleFrom(
      backgroundColor: _green900, // choose one (green900 or green700)
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
    child: _loading
        ? const SizedBox(
            height: 18,
            width: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          )
        : const Text(
            "Ask",
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
  ),
),

            const SizedBox(height: 12),
            if (_error.isNotEmpty)
              Text(
                _error,
                style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
              ),
            if (_answer.isNotEmpty)
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _green200),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      _answer,
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.35,
                        color: _green900.withOpacity(0.92),
                        fontWeight: FontWeight.w600,
                      ),
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
