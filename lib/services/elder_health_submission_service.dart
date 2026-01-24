import 'dart:convert';
import 'package:http/http.dart' as http;

import '../config/api_config.dart'; //adjust path if yours is different

class ElderHealthSubmissionService {
  ///Calls backend API:
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
      //success
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

  Future<Map<String, dynamic>> getSubmissionDetails({
    required String token,
    required String submissionId,
  }) async {
    final url =
    Uri.parse("${ApiConfig.baseUrl}/elder/health-submissions/$submissionId");

    final response = await http.get(
      url,
      headers: {
        "Authorization": "Bearer $token",
        "Accept": "application/json",
      },
    );

    if (response.statusCode != 200) {
      throw Exception(
        "Failed to load submission details "
            "(status: ${response.statusCode})",
      );
    }

    final decoded = jsonDecode(response.body);

    //Backend returns a single submission object
    return decoded as Map<String, dynamic>;
  }

  Future<void> updateHealthDetails({
    required String token,
    required String submissionId,
    required Map<String, dynamic> payload,
  }) async {
    final res = await http.put(
      Uri.parse("${ApiConfig.baseUrl}/elder/health-submissions/$submissionId"),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
      body: jsonEncode(payload),
    );

    if (res.statusCode != 200) {
      throw Exception("Failed to update submission");
    }
  }


}
