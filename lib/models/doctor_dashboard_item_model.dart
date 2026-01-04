import 'meal_plan_model.dart';

class DoctorDashboardItem {
  final String elderId;
  final Map<String, dynamic> latestSubmission;
  final MealPlanModel? latestMealPlan;

  DoctorDashboardItem({
    required this.elderId,
    required this.latestSubmission,
    this.latestMealPlan,
  });

  factory DoctorDashboardItem.fromJson(Map<String, dynamic> json) {
    return DoctorDashboardItem(
      elderId: (json['elder_id'] ?? json['elderId'] ?? '').toString(),
      latestSubmission: Map<String, dynamic>.from(json['latest_submission'] ?? json['latestSubmission'] ?? {}),
      latestMealPlan: json['latest_meal_plan'] != null
          ? MealPlanModel.fromJson(Map<String, dynamic>.from(json['latest_meal_plan']))
          : null,
    );
  }

  String get latestSubmissionId => (latestSubmission['id'] ?? latestSubmission['submission_id'] ?? '').toString();
}
