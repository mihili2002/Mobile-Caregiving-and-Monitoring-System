import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../models/user_model.dart';
import '../../services/user_service.dart';

class ElderProfilePage extends StatefulWidget {
  final AppUser user;

  const ElderProfilePage({super.key, required this.user});

  @override
  State<ElderProfilePage> createState() => _ElderProfilePageState();
}

class _ElderProfilePageState extends State<ElderProfilePage> {
  final UserService _userService = UserService();

  late Future<Map<String, dynamic>?> _elderDataFuture;
  late Future<Map<String, Map<String, double>>> _emotionFuture;

  static const String baseUrl = "http://127.0.0.1:8000";

  @override
  void initState() {
    super.initState();

    _elderDataFuture = _userService.getElderProfile(widget.user.uid);
    _emotionFuture = _fetchWeeklyEmotionPercentages(widget.user.uid);
  }

  // =========================
  // (LOGIC UNCHANGED)
  // =========================
  Future<Map<String, Map<String, double>>> _fetchWeeklyEmotionPercentages(
      String uid) async {
    try {
      final chatUri = Uri.parse(
        "$baseUrl/chatbot/emotions?elder_uid=$uid&days=30&limit=1000",
      );

      final journalUri = Uri.parse(
        "$baseUrl/chatbot/journals/emotion-trend?elder_uid=$uid&days=30",
      );

      final headers = await _userService.getAuthHeaders();

      final responses = await Future.wait([
        http.get(chatUri, headers: headers),
        http.get(journalUri, headers: headers),
      ]);

      if (responses[0].statusCode != 200 ||
          responses[1].statusCode != 200) {
        throw Exception("Server error");
      }

      final chatItems =
          (jsonDecode(responses[0].body)["items"] ?? []) as List;
      final journalItems =
          (jsonDecode(responses[1].body)["items"] ?? []) as List;

      final allItems = [...chatItems, ...journalItems];

      Map<String, Map<String, int>> weeklyCounts = {};

      for (final it in allItems) {
        final emotionRaw = (it["emotion"] ?? "").toString();
        final emotion = _normalize(emotionRaw);

        DateTime time;
        try {
          time = DateTime.parse(
            it["createdAt"] ??
                it["created_at"] ??
                it["timestamp"] ??
                DateTime.now().toIso8601String(),
          );
        } catch (_) {
          continue;
        }

        final weekKey = _getWeekKey(time);

        weeklyCounts.putIfAbsent(weekKey, () => {});
        weeklyCounts[weekKey]![emotion] =
            (weeklyCounts[weekKey]![emotion] ?? 0) + 1;
      }

      Map<String, Map<String, double>> result = {};

      weeklyCounts.forEach((week, emotions) {
        final total = emotions.values.fold<int>(0, (a, b) => a + b);

        result[week] = emotions.map((k, v) {
          return MapEntry(k, (v / total) * 100);
        });
      });

      return result;
    } catch (e) {
      debugPrint("Weekly emotion error: $e");
      return {};
    }
  }

  String _getWeekKey(DateTime date) {
    final monday =
        date.subtract(Duration(days: date.weekday - 1));
    final sunday = monday.add(const Duration(days: 6));

    return "${monday.day}/${monday.month} - ${sunday.day}/${sunday.month}";
  }

  String _normalize(String emotion) {
    if (emotion.isEmpty) return 'neutral';

    final key = emotion.trim().toUpperCase();

    if (key == 'Q1') return 'happy';
    if (key == 'Q2') return 'angry';
    if (key == 'Q3') return 'sad';
    if (key == 'Q4') return 'calm';

    final lower = key.toLowerCase();

    if (lower.contains('happy') || lower.contains('joy')) return 'happy';
    if (lower.contains('angry')) return 'angry';
    if (lower.contains('fear')) return 'fear';
    if (lower.contains('sad')) return 'sad';
    if (lower.contains('calm') || lower.contains('neutral')) return 'calm';
    if (lower.contains('surprise')) return 'surprise';
    if (lower.contains('disgust')) return 'disgust';

    return 'neutral';
  }

  String _label(String key) {
    switch (key) {
      case "happy":
        return "Happy";
      case "sad":
        return "Sad";
      case "angry":
        return "Angry";
      case "fear":
        return "Fear";
      case "calm":
        return "Calm";
      case "surprise":
        return "Surprise";
      case "disgust":
        return "Disgust";
      default:
        return "Neutral";
    }
  }

  // =========================
  // UI
  // =========================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        title: const Text("Elder Profile"),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 16),

            // =========================
            // HEADER CARD (IMPROVED)
            // =========================
            FutureBuilder<Map<String, dynamic>?>(
              future: _elderDataFuture,
              builder: (context, snapshot) {
                final elderData = snapshot.data;

                final name = widget.user.name ?? "N/A";
                final age = elderData?['age']?.toString() ?? "Not set";

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Colors.green, Colors.teal],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        )
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Row(
                        children: [
                          const CircleAvatar(
                            radius: 32,
                            backgroundColor: Colors.white,
                            child: Icon(Icons.person,
                                color: Colors.green, size: 32),
                          ),
                          const SizedBox(width: 15),
                          Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                "Age: $age years",
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          )
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 20),

            // =========================
            // WEEKLY EMOTION REPORT (IMPROVED UI)
            // =========================
            FutureBuilder<Map<String, Map<String, double>>>(
              future: _emotionFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(),
                  );
                }

                final data = snapshot.data ?? {};

                if (data.isEmpty) {
                  return const Text("No emotion data available");
                }

                return Column(
                  children: data.entries.map((week) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      child: Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.1),
                                  borderRadius:
                                      BorderRadius.circular(10),
                                ),
                                child: Text(
                                  "📅 Week: ${week.key}",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: Colors.green,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),

                              ...week.value.entries.map((e) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 6),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment
                                                .spaceBetween,
                                        children: [
                                          Text(
                                            _label(e.key),
                                            style: const TextStyle(
                                              fontWeight:
                                                  FontWeight.w600,
                                            ),
                                          ),
                                          Text(
                                            "${e.value.toStringAsFixed(1)}%",
                                            style: const TextStyle(
                                              fontWeight:
                                                  FontWeight.bold,
                                              color: Colors.green,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      ClipRRect(
                                        borderRadius:
                                            BorderRadius.circular(10),
                                        child: LinearProgressIndicator(
                                          minHeight: 8,
                                          value: e.value / 100,
                                          backgroundColor:
                                              Colors.grey[300],
                                          color: Colors.green,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}