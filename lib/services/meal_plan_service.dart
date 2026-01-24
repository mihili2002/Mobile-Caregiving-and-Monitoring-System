import 'package:firebase_auth/firebase_auth.dart';

import '../models/meal_plan_model.dart';
import 'meal_plan_api_service.dart';
import '../models/all_submission_model.dart';

class MealPlanService {
  final MealPlanApiService _api = MealPlanApiService();

  ///Get Firebase token safely (Fixes String? issue)
  Future<String> _getToken() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw Exception("User not logged in. Please login again.");
    }

    final token = await user.getIdToken();

    //Fix: token could be null in some setups
    if (token == null || token.trim().isEmpty) {
      throw Exception("Firebase token is empty. Please login again.");
    }

    return token;
  }

  ///Loads dashboard JSON from backend:
  /// GET /elder/meal-plans/dashboard
  Future<Map<String, dynamic>> fetchDashboard() async {
    final token = await _getToken();
    return await _api.getDashboard(token: token);
  }

  ///Extract current approved meal plan from backend response
  Future<MealPlanModel?> getCurrentMealPlan() async {
    final data = await fetchDashboard();

    final current = data["current_meal_plan"];
    if (current == null) return null;

    return MealPlanModel.fromJson(current as Map<String, dynamic>);
  }


  ///Extract completed meal plans list from backend response
  Future<List<MealPlanModel>> getCompletedMealPlans() async {
    final data = await fetchDashboard();

    final completed = (data["completed_meal_plans"] as List?) ?? [];

    return completed
        .map((e) => MealPlanModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  ///Get full meal plan details by mealPlanId
  /// GET /elder/meal-plans/{meal_plan_id}
  Future<MealPlanModel> getMealPlanDetails(String mealPlanId) async {
    final token = await _getToken();

    final json = await _api.getMealPlanDetails(
      token: token,
      mealPlanId: mealPlanId,
    );

    //The backend returns a single plan JSON
    return MealPlanModel.fromJson(json);
  }

  ///Get all submitted meal plan records (summary only)
  Future<List<AllSubmissionModel>> getAllSubmissions() async {
    final data = await fetchDashboard();
    print(data);
    final list = (data["all_submissions"] as List?) ?? [];

    return list
        .map((e) => AllSubmissionModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }



  ///Backward compatible function (if your UI still calls getCompletedPlans)
  Future<List<MealPlanModel>> getCompletedPlans(String elderId) async {
    return await getCompletedMealPlans();
  }

  ///Backward compatible function (if your UI still calls getCurrentMealPlan(elderId))
  Future<MealPlanModel?> getCurrentMealPlanByElder(String elderId) async {
    return await getCurrentMealPlan();
  }

  ///Backward compatible function (if your UI still calls getMealPlanById)
  Future<MealPlanModel?> getMealPlanById(String id) async {
    return await getMealPlanDetails(id);
  }

}
