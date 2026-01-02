import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/elder_health_profile_model.dart';
import '../models/meal_plan_model.dart';

class DoctorDashboardService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<List<ElderHealthProfileModel>> streamHealthSubmissions() {
    return _db
        .collection('elder_health_profiles')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => ElderHealthProfileModel.fromDoc(d)).toList());
  }

  /// Get latest meal plan for elder (if exists)
  Future<MealPlanModel?> getLatestMealPlanForElder(String elderId) async {
    final query = await _db
        .collection('meal_plans')
        .where('elderId', isEqualTo: elderId)
        .orderBy('startDate', descending: true)
        .limit(1)
        .get();

    if (query.docs.isEmpty) return null;
    return MealPlanModel.fromDoc(query.docs.first);
  }

  Future<void> updateMealPlanStatus({
    required String mealPlanDocId,
    required String status,
  }) async {
    await _db.collection('meal_plans').doc(mealPlanDocId).update({
      'status': status,
      'updatedAt': Timestamp.now(),
    });
  }
}
