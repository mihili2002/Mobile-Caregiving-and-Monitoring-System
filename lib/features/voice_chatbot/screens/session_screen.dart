import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'history_screen.dart';

class SessionsScreen extends StatefulWidget {
  final String baseUrl;
  const SessionsScreen({super.key, required this.baseUrl});

  @override
  State<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends State<SessionsScreen> {
  bool _loading = true;
  String _error = "";
  List<Map<String, dynamic>> _sessions = [];

  static const _brown900 = Color(0xFF3E2723);
  static const _brown200 = Color(0xFFD7CCC8);
  static const _cream = Color(0xFFF7F3EF);

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    setState(() {
      _loading = true;
      _error = "";
    });

    try {
      final uri = Uri.parse("${widget.baseUrl}/chatbot/sessions?limit=50");
      final res = await http.get(uri);

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final raw = (data["sessions"] as List?) ?? [];

        final parsed = <Map<String, dynamic>>[];
        for (final s in raw) {
          if (s is Map) {
            parsed.add(s.map((k, v) => MapEntry(k.toString(), v)));
          }
        }

        setState(() {
          _sessions = parsed;
          _loading = false;
        });
      } else {
        setState(() {
          _error = "Failed to load sessions (${res.statusCode})";
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
        title: const Text("All Chat Sessions"),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadSessions),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
              ? Center(child: Text(_error))
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: _sessions.length,
                  separatorBuilder: (_, __) =>
                      Divider(color: _brown200.withOpacity(0.8)),
                  itemBuilder: (_, i) {
                    final s = _sessions[i];
                    final id = (s["session_id"] ?? "").toString();

                    return ListTile(
                      title: Text(
                        "Session: $id",
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: const Text("Tap to view history"),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => HistoryScreen(
                              baseUrl: widget.baseUrl,
                              sessionId: id,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
    );
  }
}
