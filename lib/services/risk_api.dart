import 'dart:convert';
import 'package:http/http.dart' as http;

class RiskApi {
  static const String baseUrl = "http://127.0.0.1:8000";

  // -----------------------------------------
  // 🔮 Predict Risk
  // -----------------------------------------
  static Future<Map<String, dynamic>> predictRisk({
    required String residentId,
    required Map<String, dynamic> features,
  }) async {
    final uri = Uri.parse('$baseUrl/api/risk/predict');

    print("🔵 Sending prediction for ID: $residentId");

    final response = await http.post(
      uri,
      headers: {
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "resident_id": residentId, // ✅ correct
        "features": features,
      }),
    );

    print("🟡 Predict response: ${response.statusCode}");
    print("🟡 Body: ${response.body}");

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      return _convertMap(decoded);
    } else {
      throw Exception(
        "Risk prediction failed (${response.statusCode}): ${response.body}",
      );
    }
  }

  // -----------------------------------------
  // 📊 Get Risk History (FINAL FIX)
  // -----------------------------------------
  static Future<Map<String, dynamic>> getRiskHistory({
    required String residentId,
    int days = 30,
  }) async {
    // ✅ FIXED: use resident_id (snake_case)
    final uri = Uri.parse(
      '$baseUrl/api/risk/history?resident_id=$residentId&days=$days',
    );

    print("🔵 Fetching history for ID: $residentId");
    print("🔵 URL: $uri");

    final response = await http.get(uri);

    print("🟡 History response: ${response.statusCode}");
    print("🟡 Body: ${response.body}");

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      return _convertMap(decoded);
    } else {
      throw Exception(
        "Failed to load risk history (${response.statusCode}): ${response.body}",
      );
    }
  }

  // -----------------------------------------
  // 🔥 SAFE MAP CONVERSION
  // -----------------------------------------
  static Map<String, dynamic> _convertMap(dynamic data) {
    if (data is Map) {
      return data.map(
        (key, value) => MapEntry(
          key.toString(),
          _convertValue(value),
        ),
      );
    }
    return {};
  }

  static dynamic _convertValue(dynamic value) {
    if (value is Map) {
      return _convertMap(value);
    } else if (value is List) {
      return value.map(_convertValue).toList();
    } else {
      return value;
    }
  }
}