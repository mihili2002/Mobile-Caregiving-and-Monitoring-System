import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:audioplayers/audioplayers.dart';

class MyDiariesPage extends StatefulWidget {
  final String elderId; // currently not used by backend, but kept for UI/future
  final String apiBaseUrl;

  const MyDiariesPage({
    super.key,
    required this.elderId,
    required this.apiBaseUrl,
  });

  @override
  State<MyDiariesPage> createState() => _MyDiariesPageState();
}

class _MyDiariesPageState extends State<MyDiariesPage> {
  bool _loading = true;
  String? _error;

  List<Map<String, dynamic>> _items = [];

  // ✅ Search
  String _q = "";
  final TextEditingController _searchCtrl = TextEditingController();

  // ✅ Expand/collapse transcript
  final Set<String> _expanded = {};

  // ✅ Expand/collapse emotion
  final Set<String> _emotionExpanded = {};

  // ✅ Audio player
  final AudioPlayer _player = AudioPlayer();
  String? _playingUrl;
  bool _isPlaying = false;

  @override
  void dispose() {
    _player.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadJournals() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken(true);
      if (token == null) throw Exception("User not logged in (no Firebase token)");

      final uri = Uri.parse("${widget.apiBaseUrl}/chatbot/journals?limit=200");
      final res = await http.get(
        uri,
        headers: {"Authorization": "Bearer $token"},
      );

      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw Exception("Failed: ${res.statusCode} ${res.body}");
      }

      final jsonMap = jsonDecode(res.body) as Map<String, dynamic>;
      final list = (jsonMap["items"] as List<dynamic>? ?? [])
          .map((e) => (e as Map).cast<String, dynamic>())
          .toList();

      setState(() {
        _items = list;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _togglePlay(String url) async {
    try {
      if (url.trim().isEmpty) return;

      if (_playingUrl == url && _isPlaying) {
        await _player.pause();
        setState(() => _isPlaying = false);
        return;
      }

      await _player.stop();
      await _player.play(UrlSource(url));

      setState(() {
        _playingUrl = url;
        _isPlaying = true;
      });

      _player.onPlayerComplete.listen((_) {
        if (!mounted) return;
        setState(() {
          _isPlaying = false;
          _playingUrl = null;
        });
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Play failed: $e")),
      );
    }
  }

  String _displayTime(Map<String, dynamic> item) {
    final raw = (item["displayTime"] ?? item["createdAtIso"] ?? "").toString();
    if (raw.isEmpty) return "Unknown time";

    try {
      final dt = DateTime.parse(raw).toLocal();
      final y = dt.year.toString().padLeft(4, "0");
      final m = dt.month.toString().padLeft(2, "0");
      final d = dt.day.toString().padLeft(2, "0");
      final hh = dt.hour.toString().padLeft(2, "0");
      final mm = dt.minute.toString().padLeft(2, "0");
      return "$y-$m-$d  $hh:$mm";
    } catch (_) {
      return raw;
    }
  }

  void _toggleExpanded(String id) {
    setState(() {
      if (_expanded.contains(id)) {
        _expanded.remove(id);
      } else {
        _expanded.add(id);
      }
    });
  }

  void _toggleEmotionExpanded(String id) {
    setState(() {
      if (_emotionExpanded.contains(id)) {
        _emotionExpanded.remove(id);
      } else {
        _emotionExpanded.add(id);
      }
    });
  }

  // ✅ Helper to extract a reliable journal id for delete
  String _journalIdFromItem(Map<String, dynamic> item, int fallbackIndex) {
    final candidates = [
      item["journalId"],
      item["journal_id"],
      item["id"],
    ];
    for (final c in candidates) {
      final s = (c ?? "").toString().trim();
      if (s.isNotEmpty) return s;
    }
    // last resort: you can’t delete without a real id, but keep UI stable
    return fallbackIndex.toString();
  }

  // ✅ Confirm + delete
  Future<void> _confirmAndDelete({
    required String journalId,
    required String preview,
    required String audioUrl,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete diary?"),
        content: Text(
          preview.isNotEmpty
              ? "This will permanently delete:\n\n$preview"
              : "This will permanently delete this diary entry.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.delete, color: Colors.white),
            label: const Text("Delete", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (ok != true) return;

    await _deleteJournal(journalId: journalId, audioUrl: audioUrl);
  }

  Future<void> _deleteJournal({
    required String journalId,
    required String audioUrl,
  }) async {
    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken(true);
      if (token == null) throw Exception("User not logged in (no Firebase token)");

      // If currently playing this diary, stop playback
      if (_playingUrl == audioUrl && _isPlaying) {
        await _player.stop();
        setState(() {
          _isPlaying = false;
          _playingUrl = null;
        });
      }

      final uri = Uri.parse("${widget.apiBaseUrl}/chatbot/journals/$journalId");
      final res = await http.delete(
        uri,
        headers: {"Authorization": "Bearer $token"},
      );

      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw Exception("Delete failed: ${res.statusCode} ${res.body}");
      }

      // ✅ remove from local list immediately
      setState(() {
        _items.removeWhere((it) {
          final id = (it["journalId"] ?? it["journal_id"] ?? it["id"] ?? "").toString();
          return id == journalId;
        });

        // also clear expanded sets
        _expanded.remove(journalId);
        _emotionExpanded.remove(journalId);
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Diary deleted")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Delete failed: $e")),
      );
    }
  }

  // ✅ Pretty label + icon for emotion
  (String, IconData, Color) _emotionUi(String emotion) {
    final e = emotion.trim().toUpperCase();

    switch (e) {
      case "Q1":
        return ("Happy / Excited ", Icons.sentiment_very_satisfied,
            const Color(0xFF4CAF50));
      case "Q2":
        return ("Angry / Fearful ", Icons.flash_on, const Color(0xFFF44336));
      case "Q3":
        return ("Sad / Depressed ", Icons.sentiment_very_dissatisfied,
            const Color(0xFF3F51B5));
      case "Q4":
        return ("Calm / Relaxed ", Icons.self_improvement,
            const Color(0xFF2196F3));

      case "POSITIVE":
      case "HAPPY":
        return ("Happy ", Icons.sentiment_satisfied_alt,
            const Color(0xFF4CAF50));
      case "NEGATIVE":
      case "SAD":
        return ("Sad ", Icons.sentiment_dissatisfied, const Color(0xFF3F51B5));
      case "ANGRY":
        return ("Angry ", Icons.flash_on, const Color(0xFFF44336));
      case "NEUTRAL":
        return ("Neutral ", Icons.sentiment_neutral, const Color(0xFF607D8B));

      default:
        return (
          emotion.isEmpty ? "Analysing..." : emotion,
          Icons.psychology_outlined,
          const Color(0xFF9E9E9E)
        );
    }
  }

  String _formatConfidence(dynamic v) {
    if (v == null) return "";
    try {
      final d = (v is num) ? v.toDouble() : double.parse(v.toString());
      return "${(d * 100).toStringAsFixed(1)}%";
    } catch (_) {
      return v.toString();
    }
  }

  @override
  void initState() {
    super.initState();
    _loadJournals();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _items.where((item) {
      final preview = (item["preview"] ?? "").toString().toLowerCase();
      final transcript = (item["transcript"] ?? "").toString().toLowerCase();
      final emotion = (item["emotion"] ?? "").toString().toLowerCase();
      return _q.isEmpty ||
          preview.contains(_q) ||
          transcript.contains(_q) ||
          emotion.contains(_q);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text("My Diaries"),
        actions: [
          IconButton(
            onPressed: _loadJournals,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Text("Error: $_error"),
                  ),
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                      child: TextField(
                        controller: _searchCtrl,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.search),
                          hintText:
                              "Search diaries (sleep, pain, medicine, emotion...)",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          suffixIcon: _q.isEmpty
                              ? null
                              : IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchCtrl.clear();
                                    setState(() => _q = "");
                                  },
                                ),
                        ),
                        onChanged: (v) =>
                            setState(() => _q = v.trim().toLowerCase()),
                      ),
                    ),
                    Expanded(
                      child: filtered.isEmpty
                          ? const Center(child: Text("No diaries found."))
                          : ListView.separated(
                              padding: const EdgeInsets.all(14),
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, i) {
                                final item = filtered[i];

                                final journalId = _journalIdFromItem(item, i);
                                final preview =
                                    (item["preview"] ?? "Voice Journal")
                                        .toString();
                                final audioUrl = (item["audioUrl"] ?? "")
                                    .toString()
                                    .trim();
                                final transcript =
                                    (item["transcript"] ?? "").toString();

                                final emotion = (item["emotion"] ?? "").toString();
                                final emotionConfidence = item["emotionConfidence"];

                                final isThisPlaying =
                                    (_playingUrl == audioUrl) && _isPlaying;

                                final ext = audioUrl.contains(".")
                                    ? audioUrl.split("?").first.split(".").last
                                    : "";

                                final expanded = _expanded.contains(journalId);
                                final emotionExpanded =
                                    _emotionExpanded.contains(journalId);

                                final (emotionLabel, emotionIcon, emotionColor) =
                                    _emotionUi(emotion);
                                final confText =
                                    _formatConfidence(emotionConfidence);

                                return Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                        color: Colors.black.withOpacity(0.06)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // शीर्ष row: title + delete
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              preview,
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                          IconButton(
                                            tooltip: "Delete",
                                            icon: const Icon(Icons.delete_outline),
                                            color: Colors.red.shade600,
                                            onPressed: () => _confirmAndDelete(
                                              journalId: journalId,
                                              preview: preview,
                                              audioUrl: audioUrl,
                                            ),
                                          )
                                        ],
                                      ),

                                      const SizedBox(height: 4),
                                      Text(
                                        _displayTime(item),
                                        style: TextStyle(
                                          color: Colors.black.withOpacity(0.55),
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(height: 10),

                                      // ✅ audio row
                                      if (audioUrl.isEmpty)
                                        Text(
                                          "No audioUrl found for this entry.",
                                          style: TextStyle(
                                              color: Colors.red.shade700),
                                        )
                                      else
                                        Row(
                                          children: [
                                            ElevatedButton.icon(
                                              onPressed: () =>
                                                  _togglePlay(audioUrl),
                                              icon: Icon(isThisPlaying
                                                  ? Icons.pause
                                                  : Icons.play_arrow),
                                              label: Text(isThisPlaying
                                                  ? "Pause"
                                                  : "Play"),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                "Format: .$ext",
                                                style: TextStyle(
                                                  color: Colors.black
                                                      .withOpacity(0.55),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),

                                      // ✅ Emotion Track button
                                      const SizedBox(height: 10),
                                      Row(
                                        children: [
                                          OutlinedButton.icon(
                                            onPressed: () {
                                              if (emotion.trim().isEmpty) {
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(
                                                  const SnackBar(
                                                      content: Text(
                                                          "Emotion not available yet.")),
                                                );
                                                return;
                                              }
                                              _toggleEmotionExpanded(journalId);
                                            },
                                            icon: const Icon(Icons.insights),
                                            label: Text(emotionExpanded
                                                ? "Hide Emotion"
                                                : "Emotion Track"),
                                          ),
                                          const SizedBox(width: 10),
                                          if (emotion.trim().isNotEmpty)
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 6),
                                              decoration: BoxDecoration(
                                                color: emotionColor
                                                    .withOpacity(0.12),
                                                borderRadius:
                                                    BorderRadius.circular(999),
                                                border: Border.all(
                                                    color: emotionColor
                                                        .withOpacity(0.35)),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(emotionIcon,
                                                      size: 18,
                                                      color: emotionColor),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    emotionLabel,
                                                    style: TextStyle(
                                                      color: emotionColor,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                        ],
                                      ),

                                      // ✅ Emotion details (expand)
                                      if (emotionExpanded &&
                                          emotion.trim().isNotEmpty) ...[
                                        const SizedBox(height: 10),
                                        Text(
                                          "Detected emotion: $emotionLabel",
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            color:
                                                Colors.black.withOpacity(0.85),
                                          ),
                                        ),
                                        if (confText.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            "Confidence: $confText",
                                            style: TextStyle(
                                              color:
                                                  Colors.black.withOpacity(0.65),
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ],

                                      // ✅ Transcript section
                                      if (transcript.isNotEmpty) ...[
                                        const SizedBox(height: 12),
                                        InkWell(
                                          onTap: () =>
                                              _toggleExpanded(journalId),
                                          child: Row(
                                            children: [
                                              Icon(
                                                expanded
                                                    ? Icons.expand_less
                                                    : Icons.expand_more,
                                                color: Colors.black
                                                    .withOpacity(0.6),
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                expanded
                                                    ? "Hide transcript"
                                                    : "Show transcript",
                                                style: TextStyle(
                                                  color: Colors.black
                                                      .withOpacity(0.75),
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (expanded) ...[
                                          const SizedBox(height: 8),
                                          Text(
                                            transcript,
                                            style: TextStyle(
                                              color: Colors.black
                                                  .withOpacity(0.78),
                                              height: 1.35,
                                            ),
                                          ),
                                        ],
                                      ] else ...[
                                        const SizedBox(height: 12),
                                        Text(
                                          "Transcript not available yet.",
                                          style: TextStyle(
                                            color:
                                                Colors.black.withOpacity(0.55),
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],

                                      if (kIsWeb) ...[
                                        const SizedBox(height: 8),
                                        Text(
                                          "Web: ${widget.apiBaseUrl}",
                                          style: TextStyle(
                                            color:
                                                Colors.black.withOpacity(0.35),
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
    );
  }
}