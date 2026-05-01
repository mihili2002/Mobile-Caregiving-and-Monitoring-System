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
      String residentId,
      {String? elderEmail}) async {

    final url =
        Uri.parse("$baseUrl$therapyPrefix/generate_personalized_plan");

    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "resident_id": residentId,
        "elder_email": elderEmail, // ⭐ new optional field
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

  // ---------------------------------------------------
  // 📥 Get Active Approved Plan (by Resident ID)
  // ---------------------------------------------------
  static Future<Map<String, dynamic>> getActivePlan(
      String residentId) async {

    final url =
        Uri.parse("$baseUrl$therapyPrefix/get_active_plan/$residentId");

    final response = await http.get(url);

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception(
        "Failed to fetch active plan (${response.statusCode})",
      );
    }
  }

  // ---------------------------------------------------
  // 📥 Get Active Plan by Email (for Elder Dashboard)
  // ---------------------------------------------------
  static Future<Map<String, dynamic>> getPlanByEmail(
      String email) async {

    final url =
        Uri.parse("$baseUrl$therapyPrefix/get_plan_by_email/$email");

    final response = await http.get(url);

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception("No plan found for this user");
    }
  }
}