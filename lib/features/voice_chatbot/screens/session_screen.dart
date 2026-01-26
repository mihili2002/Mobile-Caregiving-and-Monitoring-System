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

  // ---------- Green theme ----------
  static const _green900 = Color(0xFF0B3D2E); // deep evergreen
  static const _green700 = Color(0xFF1B6B52); // primary green
  static const _green200 = Color(0xFFCFE8D8); // light mint border
  static const _mint = Color(0xFFF2FBF6); // background

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

      final uri = Uri.parse("${widget.baseUrl}/chatbot/sessions?limit=50");
      final res = await http.get(
        uri,
        headers: {"Authorization": "Bearer $token"},
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final raw = (data["sessions"] as List?) ?? [];

        final parsed = <Map<String, dynamic>>[];
        for (final s in raw) {
          if (s is Map) {
            parsed.add(s.map((k, v) => MapEntry(k.toString(), v)));
          }
        }

        if (!mounted) return;
        setState(() {
          _sessions = parsed;
          _loading = false;
        });
      } else {
        if (!mounted) return;
        setState(() {
          _error = "Failed to load sessions (${res.statusCode})";
          _loading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = "Error: $e";
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _mint,
      appBar: AppBar(
        backgroundColor: _green900,
        title: const Text("All Chat Sessions"),
        actions: [
          IconButton(
            tooltip: "Refresh",
            icon: const Icon(Icons.refresh),
            onPressed: _loadSessions,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      _error,
                      style: TextStyle(
                        color: _green900.withOpacity(0.9),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: _sessions.length,
                  separatorBuilder: (_, __) =>
                      Divider(color: _green200.withOpacity(0.9)),
                  itemBuilder: (_, i) {
                    final s = _sessions[i];
                    final id = (s["session_id"] ?? "").toString();

                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _green200),
                      ),
                      child: ListTile(
                        title: Text(
                          "Session: $id",
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: _green900.withOpacity(0.92),
                          ),
                        ),
                        subtitle: Text(
                          "Tap to view history",
                          style: TextStyle(
                            color: _green700.withOpacity(0.85),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        trailing: Icon(
                          Icons.chevron_right,
                          color: _green700,
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
