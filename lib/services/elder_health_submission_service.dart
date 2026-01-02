import 'dart:convert';
import 'package:http/http.dart' as http;

import '../config/api_config.dart'; // ✅ adjust path if yours is different

class ElderHealthSubmissionService {
  /// ✅ Calls backend API:
  /// POST /elder/health-submissions/
  Future<void> submitHealthDetails({
    required String token,
    required Map<String, dynamic> payload,
  }) async {
    final url = Uri.parse("${ApiConfig.baseUrl}/elder/health-submissions/");

    final response = await http.post(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode(payload),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      // ✅ success
      return;
    }

    // ❌ failed: show backend error
    String message = "Failed to submit health details.";
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded["detail"] != null) {
        message = decoded["detail"].toString();
      } else {
        message = decoded.toString();
      }
    } catch (_) {
      message = response.body;
    }

    throw Exception("[${
      response.statusCode
    }] $message");
  }
}
