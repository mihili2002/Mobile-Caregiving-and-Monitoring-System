import 'dart:convert';
import 'package:http/http.dart' as http;

class RiskApi {
  // ✅ BASE URL for Flutter Web → FastAPI
  // IMPORTANT: use localhost, NOT 127.0.0.1
  static const String baseUrl = "http://localhost:8000";

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

    if (response.statusCode != 200) {
      throw Exception(
        "Risk prediction failed (${response.statusCode}): ${response.body}",
      );
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }
}