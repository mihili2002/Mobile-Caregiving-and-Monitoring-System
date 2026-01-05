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

  // GREEN THEME
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
      backgroundColor: _mint,
      appBar: AppBar(
        backgroundColor: _green900,
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
                      Divider(color: _green200.withOpacity(0.8)),
                  itemBuilder: (_, i) {
                    final s = _sessions[i];
                    final id = (s["session_id"] ?? "").toString();

                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _green200.withOpacity(0.85)),
                        boxShadow: [
                          BoxShadow(
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                            color: Colors.black.withOpacity(0.04),
                          )
                        ],
                      ),
                      child: ListTile(
                        title: Text(
                          "Session: $id",
                          style: const TextStyle(fontWeight: FontWeight.w800),
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
                      ),
                    );
                  },
                ),
    );
  }
}
