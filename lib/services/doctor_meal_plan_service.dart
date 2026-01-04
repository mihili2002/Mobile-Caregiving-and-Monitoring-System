import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';

class DoctorMealPlanService {
  final String baseUrl = ApiConfig.baseUrl;

  Future<void> generateMealPlan({
    required String elderId,
    required String healthSubmissionId,
  }) async {
    final token = await FirebaseAuth.instance.currentUser!.getIdToken();

    final res = await http.post(
      Uri.parse("$baseUrl/doctor/meal-plans/generate"),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "elder_id": elderId,
        "health_submission_id": healthSubmissionId,
      }),
    );

    if (res.statusCode != 201) {
      throw Exception("Meal plan generation failed");
    }
  }

  Future<void> approve(String mealPlanId) async {
    await _simplePost("/doctor/meal-plans/$mealPlanId/approve");
  }

  Future<void> reject(String mealPlanId) async {
    await _simplePost("/doctor/meal-plans/$mealPlanId/reject");
  }

  Future<void> edit({
    required String mealPlanId,
    required Map<String, dynamic> payload,
  }) async {
    final token = await FirebaseAuth.instance.currentUser!.getIdToken();

    final res = await http.put(
      Uri.parse("$baseUrl/doctor/meal-plans/$mealPlanId"),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
      body: jsonEncode(payload),
    );

    if (res.statusCode != 200) {
      throw Exception("Failed to edit meal plan");
    }
  }

  Future<void> _simplePost(String path) async {
    final token = await FirebaseAuth.instance.currentUser!.getIdToken();

    final res = await http.post(
      Uri.parse("$baseUrl$path"),
      headers: {"Authorization": "Bearer $token"},
    );

    if (res.statusCode != 200) {
      throw Exception("Action failed");
    }
  }
}
