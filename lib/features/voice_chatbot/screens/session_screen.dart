import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'history_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

  static const _green900 = Color(0xFF00A693);
  static const _green200 = Color(0xFFA7DCCB);
  static const _mint = Color(0xFFF2FBF7);

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
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _error = "Not logged in";
          _loading = false;
        });
        return;
      }

      final token = await user.getIdToken();
      final uri =
          Uri.parse("${widget.baseUrl}/chatbot/sessions?limit=50");

      final res = await http.get(
        uri,
        headers: {"Authorization": "Bearer $token"},
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final raw = (data["items"] as List?) ?? [];

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
          _error = "Failed (${res.statusCode})";
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

  Future<void> _deleteSession(String sessionId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete session?"),
        content: const Text(
            "This will permanently delete this chat session."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final token = await user.getIdToken();
    final uri = Uri.parse(
        "${widget.baseUrl}/chatbot/sessions/$sessionId");

    final res = await http.delete(
      uri,
      headers: {"Authorization": "Bearer $token"},
    );

    if (res.statusCode == 200) {
      setState(() {
        _sessions.removeWhere(
            (s) => s["session_id"] == sessionId);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Session deleted")),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Delete failed (${res.statusCode})")),
      );
    }
  }

  String _safeStr(dynamic v) => (v ?? "").toString();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _mint,
      appBar: AppBar(
        backgroundColor: _green900,
        title: const Text("All Chat Sessions"),
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadSessions),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
              ? Center(child: Text(_error))
              : _sessions.isEmpty
                  ? const Center(child: Text("No sessions yet"))
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _sessions.length,
                      itemBuilder: (_, i) {
                        final s = _sessions[i];
                        final id = _safeStr(s["session_id"]);
                        final lastMsg = _safeStr(s["lastMessage"]);

                        return Card(
                          child: ListTile(
                            title: Text("Session: $id"),
                            subtitle: Text(
                              lastMsg.isNotEmpty
                                  ? lastMsg
                                  : "Tap to view history",
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon:
                                      const Icon(Icons.delete_outline),
                                  color: Colors.red,
                                  onPressed: () =>
                                      _deleteSession(id),
                                ),
                                const Icon(Icons.chevron_right),
                              ],
                            ),
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
                          ),
                        );
                      },
                    ),
    );
  }
}