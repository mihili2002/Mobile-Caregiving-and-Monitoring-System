import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

class BehaviorService {
  // Uses similar URL logic as other services
  String get baseUrl {
    if (kIsWeb) return "http://127.0.0.1:5000";
    if (defaultTargetPlatform == TargetPlatform.android) return "http://10.0.2.2:5000";
    return "http://192.168.8.115:5000";
  }

  Future<void> logEvent(String eventType, [Map<String, dynamic>? metadata]) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    try {
      await http.post(
        Uri.parse('$baseUrl/api/behavior/log_event'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "uid": user.uid,
          "event_type": eventType,
          "timestamp": DateTime.now().toIso8601String(),
          "metadata": metadata ?? {}
        }),
      );
    } catch (e) {
      print("Error logging behavior: $e");
    }
  }

  Future<List<dynamic>> getInsights() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/behavior/generate_insights?uid=${user.uid}'),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body)['insights'] ?? [];
      }
    } catch (e) {
      print("Error fetching insights: $e");
    }
    return [];
  }
}
