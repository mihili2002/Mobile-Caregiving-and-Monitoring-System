import 'dart:convert';
import 'package:http/http.dart' as http;

class RiskApi {
  // ✅ Use 127.0.0.1 for FastAPI (more stable with Flutter Web)
  static const String baseUrl = "http://127.0.0.1:8000";

  // -----------------------------------------
  // 🔮 Predict Risk
  // -----------------------------------------
  static Future<Map<String, dynamic>> predictRisk({
    required String residentId,
    required Map<String, dynamic> features,
  }) async {
    final uri = Uri.parse('$baseUrl/api/risk/predict');

    final response = await http.post(
      uri,
      headers: {
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "resident_id": residentId,
        "features": features,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception(
        "Risk prediction failed (${response.statusCode}): ${response.body}",
      );
    }
  }

  // -----------------------------------------
  // 📊 Get Risk History
  // -----------------------------------------
  static Future<Map<String, dynamic>> getRiskHistory({
    required String residentId,
    int days = 30,
  }) async {
    final uri = Uri.parse(
      '$baseUrl/api/risk/history?resident_id=$residentId&days=$days',
    );

    final response = await http.get(uri);

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception(
        "Failed to load risk history (${response.statusCode}): ${response.body}",
      );
    }
  }
}