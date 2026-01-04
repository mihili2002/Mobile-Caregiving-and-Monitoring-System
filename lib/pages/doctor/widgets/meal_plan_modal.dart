import 'package:flutter/material.dart';
import '../../../models/meal_plan_model.dart';
import '../../elder/meal_plans/widgets/meal_day_accordion.dart';

class MealPlanModal extends StatelessWidget {
  final MealPlanModel plan;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onEdit;

  const MealPlanModal({
    super.key,
    required this.plan,
    required this.onApprove,
    required this.onReject,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final days = plan.meals.keys.toList();

    return SafeArea(
      child: Column(
        children: [
          // Top Header (teal)
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
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(
                      plan.planId.replaceAll("_", " "),
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.22),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        plan.status,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ]),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              children: [
                ...days.map((day) {
                  final dayMeals = plan.meals[day] as Map<String, dynamic>;
                  return MealDayAccordion(day: day, meals: dayMeals);
                }),
              ],
            ),
          ),

          // Bottom action buttons (3 big buttons)
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: onApprove,
                    child: const Text("Approve Plan", style: TextStyle(fontWeight: FontWeight.w900)),
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: onReject,
                    child: const Text("Reject Plan", style: TextStyle(fontWeight: FontWeight.w900)),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2979FF),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: onEdit,
                    child: const Text("Edit Plan", style: TextStyle(fontWeight: FontWeight.w900)),
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
