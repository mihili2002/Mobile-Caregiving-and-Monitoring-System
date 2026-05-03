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
  late Future<Map<String, double>> _emotionFuture;

  //static const String baseUrl = "http://10.0.2.2:8000";
  static const String baseUrl = "http://127.0.0.1:8000";

  @override
  void initState() {
    super.initState();
    _elderDataFuture = _userService.getElderProfile(widget.user.uid);
    _emotionFuture = _fetchEmotionPercentages(widget.user.uid);
  }

  /// =========================
  /// FETCH EMOTION PERCENTAGES (FIXED)
  /// =========================
  Future<Map<String, double>> _fetchEmotionPercentages(String uid) async {
    try {
      final uri = Uri.parse(
        "$baseUrl/chatbot/emotions?elder_uid=$uid&days=7&limit=500",
      );

      final res = await http.get(
           uri,
          headers: await _userService.getAuthHeaders(),
      );

      if (res.statusCode != 200) {
        throw Exception("Server error: ${res.statusCode}");
      }

      final data = jsonDecode(res.body);

      final List items = (data["items"] ?? []) as List;

      final Map<String, int> counts = {
         "happy": 0,
         "sad": 0,
         "angry": 0,
         "fear": 0,
         "calm": 0,
         "surprise": 0,
         "disgust": 0,
         "neutral": 0,
};

      for (final it in items) {
        final raw = (it["emotion"] ?? "").toString().toLowerCase();

        final emotion = _normalize(raw);
        if (emotion.isEmpty) continue;

        counts[emotion] = (counts[emotion] ?? 0) + 1;
      }

      final total = counts.values.fold<int>(0, (a, b) => a + b);
      if (total == 0) return {};

      return counts.map((k, v) => MapEntry(k, (v / total) * 100));
    } catch (e) {
      debugPrint("Emotion fetch error: $e");
      return {};
    }
  }

  /// =========================
  /// NORMALIZE EMOTIONS (IMPORTANT FIX)
  /// =========================
  String _normalize(String emotion) {
  if (emotion.isEmpty) return 'neutral';

  final key = emotion.trim().toUpperCase();

  // 🔥 SAME Q1–Q4 LOGIC
  if (key == 'Q1') return 'happy';
  if (key == 'Q2') return 'angry';
  if (key == 'Q3') return 'sad';
  if (key == 'Q4') return 'calm';

  final lower = key.toLowerCase();

  if (lower.contains('happy') || lower.contains('joy')) return 'happy';
  if (lower.contains('angry') || lower.contains('anger')) return 'angry';
  if (lower.contains('fear') || lower.contains('anxiety')) return 'fear';
  if (lower.contains('sad')) return 'sad';
  if (lower.contains('calm') || lower.contains('neutral')) return 'calm';
  if (lower.contains('surprise')) return 'surprise';
  if (lower.contains('disgust')) return 'disgust';

  return 'neutral';
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Elder Profile"),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  /// =========================
                  /// BASIC INFO
                  /// =========================
                  FutureBuilder<Map<String, dynamic>?>(
                    future: _elderDataFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const CircularProgressIndicator();
                      }

                      final elderData = snapshot.data;
                      final age = elderData?['age']?.toString() ?? "Not set";

                      return Column(
                        children: [
                          _buildInfoCard(
                            "Full Name",
                            widget.user.name ?? "N/A",
                            Icons.person,
                          ),
                          const SizedBox(height: 12),
                          _buildInfoCard(
                            "Age",
                            "$age Years",
                            Icons.cake,
                          ),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 25),

                  /// =========================
                  /// EMOTION REPORT (FIXED UI)
                  /// =========================
                  FutureBuilder<Map<String, double>>(
                    future: _emotionFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const CircularProgressIndicator();
                      }

                      final data = snapshot.data ?? {};

                      if (data.isEmpty) {
                        return const Text(
                          "No emotion data available",
                          style: TextStyle(color: Colors.grey),
                        );
                      }

                      return Card(
                        elevation: 3,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Emotion Report (Last 7 Days)",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),

                              ...data.entries.map((e) {
                                return Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 8),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "${_label(e.key)} "
                                        "(${e.value.toStringAsFixed(1)}%)",
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      LinearProgressIndicator(
                                        value: e.value / 100,
                                        backgroundColor: Colors.grey[300],
                                        color: Colors.green,
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// =========================
  /// HEADER
  /// =========================
  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.green,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      padding: const EdgeInsets.only(bottom: 40, top: 20),
      child: Column(
        children: [
          const CircleAvatar(
            radius: 50,
            backgroundColor: Colors.white,
            child: Icon(Icons.person, size: 50, color: Colors.green),
          ),
          const SizedBox(height: 15),
          Text(
            widget.user.name ?? "Elder User",
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  /// =========================
  /// INFO CARD
  /// =========================
  Widget _buildInfoCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.green),
          ),
          const SizedBox(width: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: Colors.grey[600])),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// =========================
  /// LABELS
  /// =========================
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
      case "neutral":
        return "Neutral";
      default:
        return key;
    }
  }
}