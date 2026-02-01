import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/risk_history_point.dart';

class RiskHistoryApi {
  // change if needed (Android emulator uses 10.0.2.2)
  static const String baseUrl = "http://127.0.0.1:8000/api/risk";

  static Future<List<RiskHistoryPoint>> fetchHistory({
    required String residentId,
    int days = 30,
  }) async {
    final uri = Uri.parse("$baseUrl/history?resident_id=$residentId&days=$days");
    final res = await http.get(uri);

    if (res.statusCode != 200) {
      throw Exception("History request failed: ${res.statusCode} ${res.body}");
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final items = (data["items"] as List<dynamic>)
        .map((e) => RiskHistoryPoint.fromJson(e as Map<String, dynamic>))
        .where((p) => p.hasValidNumbers) // filters out old null docs
        .toList();

    // sort ascending by time for chart
    items.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return items;
  }
}