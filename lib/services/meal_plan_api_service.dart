import 'dart:convert';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';

class MealPlanApiService {
  /// ✅ GET /elder/meal-plans/dashboard
  Future<Map<String, dynamic>> getDashboard({
    required String token,
  }) async {
    final url = Uri.parse("${ApiConfig.baseUrl}/elder/meal-plans/dashboard");

    final response = await http.get(
      url,
      headers: {
        "Accept": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    throw Exception(
      "[${response.statusCode}] Failed to load dashboard: ${response.body}",
    );
  }

  Future<String> getMealPlanIdBySubmission({
    required String token,
    required String submissionId,
  }) async {
    final url = Uri.parse(
      "${ApiConfig.baseUrl}/elder/meal-plans/by-submission/$submissionId",
    );

    final response = await http.get(
      url,
      headers: {
        "Authorization": "Bearer $token",
        "Accept": "application/json",
      },
    );

    if (response.statusCode != 200) {
      throw Exception(
        "Failed to resolve meal plan for submission "
            "(status: ${response.statusCode})",
      );
    }

    final decoded = jsonDecode(response.body);

    final mealPlanId = decoded["meal_plan_id"];
    if (mealPlanId == null) {
      throw Exception("meal_plan_id not found in response");
    }

    return mealPlanId as String;
  }

  // --------------------------------------------------
  // Get full meal plan details by meal_plan_id
  // --------------------------------------------------
  Future<Map<String, dynamic>> getMealPlanDetails({
    required String token,
    required String mealPlanId,
  }) async {
    final url = Uri.parse(
      "${ApiConfig.baseUrl}/elder/meal-plans/$mealPlanId",
    );

    final response = await http.get(
      url,
      headers: {
        "Authorization": "Bearer $token",
        "Accept": "application/json",
      },
    );

    if (response.statusCode != 200) {
      throw Exception(
        "Failed to load meal plan "
            "(status: ${response.statusCode})",
      );
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }
}

/// ✅ GET /elder/meal-plans/{meal_plan_id}
  Future<Map<String, dynamic>> getMealPlanDetails({
    required String token,
    required String mealPlanId,
  }) async {
    final url = Uri.parse("${ApiConfig.baseUrl}/elder/meal-plans/$mealPlanId");

    final response = await http.get(
      url,
      headers: {
        "Accept": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    throw Exception(
      "[${response.statusCode}] Failed to load meal plan: ${response.body}",
    );
  }

