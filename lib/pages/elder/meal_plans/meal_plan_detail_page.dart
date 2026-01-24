import 'package:flutter/material.dart';
import '../../../models/meal_plan_model.dart';
import '../../../services/meal_plan_service.dart';

class MealPlanDetailPage extends StatefulWidget {
  final String? planId;
  final MealPlanModel? plan;

  const MealPlanDetailPage({
    super.key,
    this.planId,
    this.plan,
  });

  @override
  State<MealPlanDetailPage> createState() => _MealPlanDetailPageState();
}

class _MealPlanDetailPageState extends State<MealPlanDetailPage> {
  final MealPlanService _service = MealPlanService();
  MealPlanModel? _plan;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    try {
      if (widget.plan != null) {
        _plan = widget.plan;
      } else if (widget.planId != null) {
        _plan = await _service.getMealPlanById(widget.planId!);
      }
    } catch (e) {
      debugPrint("MealPlanDetail load error: $e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const teal = Color(0xFF11BFA8);

    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_plan == null) {
      return const Scaffold(
        body: Center(child: Text("Meal plan not found")),
      );
    }

    final plan = _plan!;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: teal,
        foregroundColor: Colors.white,
        title: const Text("Meal Plan Details"),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(14),
          children: [
            // Header card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: teal,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Plan ID: ${plan.id}",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Status: ${plan.status}",
                    style: const TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Dates: ${plan.startDate.toString().split(" ")[0]} → ${plan.endDate.toString().split(" ")[0]}",
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            //API-based plan days
            if (plan.days.isNotEmpty)
              ...plan.days.map((dayObj) => _dayAccordion(dayObj)).toList()

            //fallback for Firestore old plan.meals
            else
              ...plan.meals.keys.map((dayKey) {
                final dayMeals = plan.meals[dayKey] as Map<String, dynamic>;
                return Card(
                  child: ExpansionTile(
                    title: Text(dayKey),
                    children: [
                      _simpleMealList("Breakfast", dayMeals["Breakfast"]),
                      _simpleMealList("Lunch", dayMeals["Lunch"]),
                      _simpleMealList("Dinner", dayMeals["Dinner"]),
                      _simpleMealList("Snacks", dayMeals["Snacks"]),
                    ],
                  ),
                );
              }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _dayAccordion(MealPlanDay dayObj) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ExpansionTile(
        title: Text("Day ${dayObj.day}",
            style: const TextStyle(fontWeight: FontWeight.w900)),
        childrenPadding: const EdgeInsets.all(14),
        children: [
          _mealSection("Breakfast", dayObj.meals.breakfast),
          _mealSection("Lunch", dayObj.meals.lunch),
          _mealSection("Dinner", dayObj.meals.dinner),
          _mealSection("Snacks", dayObj.meals.snacks),
        ],
      ),
    );
  }

  Widget _mealSection(String title, List<MealItem> items) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          ...items.map((i) => Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(i.foodName,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text("Portion: ${i.portion}"),
                    if (i.notes.isNotEmpty) Text("Notes: ${i.notes}"),
                  ],
                ),
              ))
        ],
      ),
    );
  }

  Widget _simpleMealList(String title, dynamic list) {
    final items = (list is List) ? list : [];
    if (items.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          ...items.map((e) => Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text("• ${e.toString()}"),
              ))
        ],
      ),
    );
  }
}
