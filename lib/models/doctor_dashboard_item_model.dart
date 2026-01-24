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
      latestSubmission: Map<String, dynamic>.from(
        json['latest_submission'] ??
            json['latestSubmission'] ??
            {},
      ),
      latestMealPlan: json['latest_meal_plan'] != null
          ? MealPlanModel.fromJson(
              Map<String, dynamic>.from(json['latest_meal_plan']),
            )
          : null,
    );
  }

  // ---------------- SAFE GETTERS ----------------

  /// 🔑 Always get submission ID from latest_submission
  String get latestSubmissionId =>
      (latestSubmission['id'] ??
              latestSubmission['submission_id'] ??
              '')
          .toString();

  /// ✅ Approval status (comes ONLY from latest submission)
  bool get isApproved =>
      latestSubmission['approved'] == true;

  /// 🕒 Submission time (optional convenience)
  DateTime? get submittedAt {
    final value = latestSubmission['submitted_at'];
    if (value == null) return null;

    if (value is String) {
      return DateTime.tryParse(value);
    }

    // Firestore Timestamp support
    try {
      return value.toDate();
    } catch (_) {
      return null;
    }
  }

  /// 🍽 Whether meal plan exists for this submission
  bool get hasMealPlan => latestMealPlan != null;
}