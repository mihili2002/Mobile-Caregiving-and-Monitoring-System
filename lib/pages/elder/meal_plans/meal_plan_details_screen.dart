import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../services/meal_plan_api_service.dart';

class MealPlanDetailsScreen extends StatefulWidget {
  final String submissionId;

  const MealPlanDetailsScreen({
    Key? key,
    required this.submissionId,
  }) : super(key: key);

  @override
  State<MealPlanDetailsScreen> createState() => _MealPlanDetailsScreenState();
}

class _MealPlanDetailsScreenState extends State<MealPlanDetailsScreen> {
  final MealPlanApiService _service = MealPlanApiService();

  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _mealPlan;

  @override
  void initState() {
    super.initState();
    _loadMealPlan();
  }

  // --------------------------------------------------
  // Load meal plan using health_submission_id
  // --------------------------------------------------
  Future<void> _loadMealPlan() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("User not logged in");

      final token = await user.getIdToken();
      if (token == null) throw Exception("Invalid token");

      // 1️⃣ Find meal_plan_id by health_submission_id
      final mealPlanId = await _service.getMealPlanIdBySubmission(
        token: token,
        submissionId: widget.submissionId,
      );

      // 2️⃣ Fetch full meal plan
      final plan = await _service.getMealPlanDetails(
        token: token,
        mealPlanId: mealPlanId,
      );

      if (!mounted) return;

      setState(() {
        _mealPlan = plan;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // --------------------------------------------------
  // UI
  // --------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Meal Plan"),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Text(
          _error!,
          style: const TextStyle(color: Colors.red),
        ),
      );
    }

    if (_mealPlan == null) {
      return const Center(child: Text("Meal plan not found"));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _summaryCard(),
        const SizedBox(height: 16),
        ..._buildDays(),
        const SizedBox(height: 20),
        _dietitianNotesCard(),
      ],
    );
  }

  // --------------------------------------------------
  // SUMMARY
  // --------------------------------------------------
  Widget _summaryCard() {
    final targets = _mealPlan!["nutrient_targets"];

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Nutrient Targets",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            _kv("Calories", "${targets["Recommended_Calories"]} kcal"),
            _kv("Protein", "${targets["Recommended_Protein"]} g"),
            _kv("Carbohydrates", "${targets["Recommended_Carbs"]} g"),
            _kv("Fats", "${targets["Recommended_Fats"]} g"),
            _kv("Meal Plan Type", targets["Recommended_Meal_Plan"]),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------
  // DAYS + MEALS
  // --------------------------------------------------
  List<Widget> _buildDays() {
    final List days = _mealPlan!["days"];

    return days.map<Widget>((day) {
      return Card(
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Day ${day["day"]}",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 10),
              ..._buildMeals(day["meals"]),
            ],
          ),
        ),
      );
    }).toList();
  }

  List<Widget> _buildMeals(Map<String, dynamic> meals) {
    final List<String> order = ["breakfast", "lunch", "snacks", "dinner"];

    return order.map((mealType) {
      final List items = meals[mealType] ?? [];

      if (items.isEmpty) return const SizedBox.shrink();

      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              mealType.toUpperCase(),
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.teal,
              ),
            ),
            const SizedBox(height: 6),
            ...items.map<Widget>((item) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  "• ${item["food_name"]} (${item["portion"]})"
                      "${item["notes"] != null ? " – ${item["notes"]}" : ""}",
                ),
              );
            }),
          ],
        ),
      );
    }).toList();
  }

  // --------------------------------------------------
  // DIETITIAN NOTES
  // --------------------------------------------------
  Widget _dietitianNotesCard() {
    final notes = _mealPlan!["dietitian_notes"];

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Dietitian Notes",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            _note("Chronic Disease Safety", notes["chronic_disease_safety"]),
            _note("Allergy Safety", notes["allergy_safety"]),
            _note("Macro Alignment", notes["macro_alignment"]),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------
  // HELPERS
  // --------------------------------------------------
  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(width: 140, child: Text(k)),
          Expanded(child: Text(v)),
        ],
      ),
    );
  }

  Widget _note(String title, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(text),
        ],
      ),
    );
  }
}
