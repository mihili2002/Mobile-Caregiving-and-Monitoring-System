import 'dart:convert';
import 'package:http/http.dart' as http;

class TherapyPlanService {

  // ✅ Use 127.0.0.1 for FastAPI (stable with Flutter Web)
  static const String baseUrl = "http://127.0.0.1:8000";

  // ✅ Backend prefix
  static const String therapyPrefix = "/api/therapy";

  // ---------------------------------------------------
  // 🧠 Generate AI Personalized Plan
  // ---------------------------------------------------
  static Future<Map<String, dynamic>> generatePlan(
      String residentId) async {

    final url =
        Uri.parse("$baseUrl$therapyPrefix/generate_personalized_plan");

    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "resident_id": residentId,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception(
        "Failed to generate plan (${response.statusCode}): ${response.body}",
      );
    }
  }

  // ---------------------------------------------------
  // ✅ Approve Plan (Save Edited Version)
  // ---------------------------------------------------
  static Future<void> approvePlan({
    required String planId,
    required String therapistName,
    required List<dynamic> domains,
  }) async {

    final url =
        Uri.parse("$baseUrl$therapyPrefix/approve_plan");

    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "plan_id": planId,
        "therapist_name": therapistName,
        "domains": domains,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
        "Failed to approve plan (${response.statusCode}): ${response.body}",
      );
    }
  }

  // ---------------------------------------------------
  // 📄 PDF Download URL
  // ---------------------------------------------------
  static String getPdfUrl(String planId) {
    return "$baseUrl$therapyPrefix/export_plan_pdf/$planId";
  }
}