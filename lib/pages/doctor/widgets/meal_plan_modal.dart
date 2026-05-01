import 'package:flutter/material.dart';

import '../../../models/meal_plan_model.dart';
import '../../elder/meal_plans/widgets/meal_day_accordion.dart';
import 'nutritional_justification_panel.dart';
import 'edit_meal_plan_screen.dart';
import '../../../services/doctor_meal_plan_service.dart';

class MealPlanModal extends StatefulWidget {
  final MealPlanModel plan;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final ValueChanged<MealPlanModel>? onEdit;

  // ✅ Optional fields for Disease-Aware Nutritional Justification Panel
  final List<String> chronicConditions;
  final int? age;
  final double? bmi;
  final Map<String, dynamic>? bloodPressure;
  final double? bloodSugar;
  final String? dietaryHabit;
  final String? foodAllergies;

  const MealPlanModal({
    super.key,
    required this.plan,
    required this.onApprove,
    required this.onReject,
    this.onEdit,

    // ✅ added (safe defaults so old code won’t break)
    this.chronicConditions = const [],
    this.age,
    this.bmi,
    this.bloodPressure,
    this.bloodSugar,
    this.dietaryHabit,
    this.foodAllergies,
  });

  @override
  State<MealPlanModal> createState() => _MealPlanModalState();
}

class _MealPlanModalState extends State<MealPlanModal> {
  bool _isSaving = false;

  Future<void> _updateMealPlan(MealPlanModel plan) async {
    setState(() => _isSaving = true);

    try {
      final svc = DoctorMealPlanService();
      await svc.edit(mealPlanId: plan.id, payload: plan.toJson());

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Meal plan saved')));

      // Notify parent to refresh UI
      widget.onEdit?.call(plan);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
    final days = plan.meals.keys.toList();

    return SafeArea(
      child: Column(
        children: [
          // ---------------- TOP HEADER (teal) ----------------
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(18, 18, 10, 18),
            decoration: const BoxDecoration(
              color: Color(0xFF11BFA8),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(22),
                bottomRight: Radius.circular(22),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        plan.planId.replaceAll("_", " "),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.22),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          plan.status,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ---------------- SCROLLABLE CONTENT ----------------
          // ✅ Panel is INSIDE ListView so it won't block day accordions
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              children: [
                // ✅ Collapsible Disease-aware panel
                NutritionalJustificationPanel(
                  chronicConditions: widget.chronicConditions,
                  plan: plan,
                  age: widget.age,
                  bmi: widget.bmi,
                  bloodPressure: widget.bloodPressure,
                  bloodSugar: widget.bloodSugar,
                  dietaryHabit: widget.dietaryHabit,
                  foodAllergies: widget.foodAllergies,
                ),

                const SizedBox(height: 12),

                // ✅ Day accordions (keep your existing plan.meals logic)
                ...days.map((day) {
                  final raw = plan.meals[day];

                  // Safety: avoid runtime crash if something unexpected comes
                  if (raw is! Map<String, dynamic>) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(
                        "Meal data format error for $day",
                        style: TextStyle(color: Colors.red.withOpacity(0.8)),
                      ),
                    );
                  }

                  return MealDayAccordion(day: day, meals: raw);
                }),
              ],
            ),
          ),

          // ---------------- BOTTOM ACTION BUTTONS ----------------
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 16),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00C853),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: _isSaving ? null : widget.onApprove,
                    child: const Text(
                      "Approve Plan",
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF1744),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: _isSaving ? null : widget.onReject,
                    child: const Text(
                      "Reject Plan",
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // Edit button — opens an editor and returns updated plan
                if (widget.onEdit != null)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2979FF),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: _isSaving
                          ? null
                          : () async {
                              final updated = await Navigator.of(context).push<MealPlanModel>(
                                MaterialPageRoute(
                                  builder: (_) => EditMealPlanScreen(plan: plan),
                                ),
                              );

                              if (updated != null) {
                                await _updateMealPlan(updated);
                              }
                            },
                      child: _isSaving
                          ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text("Edit Plan", style: TextStyle(fontWeight: FontWeight.w900)),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
