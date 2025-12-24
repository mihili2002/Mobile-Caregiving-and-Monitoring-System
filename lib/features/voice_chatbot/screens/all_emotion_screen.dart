import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class AllEmotionsScreen extends StatefulWidget {
  final String baseUrl;
  final int days;
  const AllEmotionsScreen({
    super.key,
    required this.baseUrl,
    this.days = 7,
  });

  @override
  State<AllEmotionsScreen> createState() => _AllEmotionsScreenState();
}

class _AllEmotionsScreenState extends State<AllEmotionsScreen> {
  bool _loading = true;
  String? _error;
  List<dynamic> _items = [];

  // Brown theme (match your app)
  static const _brown900 = Color(0xFF3E2723);
  static const _brown700 = Color(0xFF5D4037);
  static const _brown200 = Color(0xFFD7CCC8);
  static const _cream = Color(0xFFF7F3EF);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final url = Uri.parse(
        "${widget.baseUrl}/chatbot/emotions?days=${widget.days}&limit=500",
      );
      final res = await http.get(url);

      if (res.statusCode != 200) {
        setState(() {
          _error = "Server error: ${res.statusCode}";
          _loading = false;
        });
        return;
      }

      final data = jsonDecode(res.body);
      setState(() {
        _items = (data["items"] ?? []) as List<dynamic>;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = "Error: $e";
        _loading = false;
      });
    }
  }

  String _safe(dynamic v) => v == null ? "" : v.toString();

  // ✅ Emotion -> Color mapping
  Color _emotionColor(String emotion) {
    switch (emotion.toLowerCase()) {
      case "joy":
      case "happy":
        return Colors.green.shade400;

      case "sad":
      case "sadness":
        return Colors.blue.shade400;

      case "anger":
      case "angry":
        return Colors.red.shade400;

      case "fear":
      case "anxiety":
        return Colors.deepPurple.shade400;

      case "surprise":
        return Colors.orange.shade400;

      case "disgust":
        return Colors.brown.shade400;

      case "neutral":
        return Colors.grey.shade500;

      default:
        return Colors.grey.shade400;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _cream,
      appBar: AppBar(
        backgroundColor: _brown900,
        title: Text("All Emotions (last ${widget.days} days)"),
        actions: [
          IconButton(
            tooltip: "Refresh",
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (_error != null)
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(_error!),
                  ),
                )
              : _items.isEmpty
                  ? const Center(child: Text("No emotions found"))
                  : ListView.separated(
                      padding: const EdgeInsets.all(14),
                      itemCount: _items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) {
                        final it = _items[i] as Map<String, dynamic>;
                        final emotion = _safe(it["emotion"]);
                        final intent = _safe(it["intent"]);
                        final text = _safe(it["text"]);
                        final time = _safe(it["displayTime"] ?? it["createdAtIso"]);

                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: _brown200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Chip(
                                    label: Text(
                                      emotion.isEmpty ? "unknown" : emotion,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                    backgroundColor: _emotionColor(emotion),
                                  ),
                                  const SizedBox(width: 8),

                                  // ✅ Show intent only if it exists
                                  if (intent.isNotEmpty)
                                    Expanded(
                                      child: Text(
                                        intent,
                                        style: TextStyle(
                                          color: _brown700.withOpacity(0.9),
                                          fontWeight: FontWeight.w700,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                time,
                                style: TextStyle(
                                  color: _brown700.withOpacity(0.75),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                text,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
    );
  }
}
