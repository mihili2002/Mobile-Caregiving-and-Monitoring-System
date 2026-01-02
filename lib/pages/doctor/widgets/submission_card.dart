import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/elder_health_profile_model.dart';
import '../../../models/meal_plan_model.dart';
import 'status_badge.dart';

class SubmissionCard extends StatefulWidget {
  final ElderHealthProfileModel profile;
  final MealPlanModel? latestMealPlan;

  final VoidCallback onShowMore;
  final VoidCallback onViewMealPlan;
  final VoidCallback onGenerateMealPlan;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onEdit;
  final bool canApproveRejectEdit;

  const SubmissionCard({
    super.key,
    required this.profile,
    required this.latestMealPlan,
    required this.onShowMore,
    required this.onViewMealPlan,
    required this.onGenerateMealPlan,
    required this.onApprove,
    required this.onReject,
    required this.onEdit,
    required this.canApproveRejectEdit,
  });

  @override
  State<SubmissionCard> createState() => _SubmissionCardState();
}

class _SubmissionCardState extends State<SubmissionCard> {
  bool expanded = false;

  String _fmtDate(DateTime? d) {
    if (d == null) return "-";
    return DateFormat("MMM d, yyyy").format(d);
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: RichText(
        text: TextSpan(
          style: TextStyle(color: Colors.black.withOpacity(0.70), height: 1.35),
          children: [
            TextSpan(text: "$k: ", style: const TextStyle(fontWeight: FontWeight.w800)),
            TextSpan(text: v),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.profile;
    final plan = widget.latestMealPlan;

    final bmi = p.bmi;
    final bpSys = p.bloodPressure?['systolic'];
    final bpDia = p.bloodPressure?['diastolic'];

    final status = plan?.status ?? "No Plan";

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row with Show More
          Row(
            children: [
              const Expanded(
                child: Text(
                  "Health Details",
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => expanded = !expanded),
                child: Text(
                  expanded ? "Show Less" : "Show More",
                  style: const TextStyle(
                    color: Color(0xFF8B5CF6),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Always-visible summary
          _kv("Age", "${p.age ?? '-'} • Gender: ${p.gender ?? '-'}"),
          _kv("BMI", bmi == null ? "-" : bmi.toStringAsFixed(1)),
          _kv("Conditions", p.chronicConditions.isEmpty ? "-" : p.chronicConditions.join(", ")),
          _kv("BP", (bpSys == null || bpDia == null) ? "-" : "$bpSys/$bpDia"),
          _kv("Blood Sugar", p.bloodSugar == null ? "-" : "${p.bloodSugar} mg/dL"),
          _kv("Submitted", _fmtDate(p.createdAt)),

          // Expanded content (like screenshot 3)
          if (expanded) ...[
            const Divider(height: 22),
            Row(
              children: [
                Expanded(child: _kv("Height", p.height == null ? "-" : "${p.height} cm")),
                Expanded(child: _kv("Weight", p.weight == null ? "-" : "${p.weight} kg")),
              ],
            ),
            Row(
              children: [
                Expanded(child: _kv("Cholesterol", p.cholesterol == null ? "-" : "${p.cholesterol} mg/dL")),
                Expanded(child: _kv("Daily Steps", p.dailySteps == null ? "-" : "${p.dailySteps}")),
              ],
            ),
            Row(
              children: [
                Expanded(child: _kv("Exercise", p.exerciseFrequency ?? "-")),
                Expanded(child: _kv("Sleep", p.sleepHours == null ? "-" : "${p.sleepHours} hours")),
              ],
            ),
            const SizedBox(height: 6),
            _kv("Dietary Preference", p.dietaryHabit ?? "-"),
            _kv("Food Allergies", p.foodAllergies ?? "-"),
            _kv("Food Aversions", p.foodAversions ?? "-"),
            _kv("Preferred Cuisine", p.preferredCuisine ?? "-"),

            const SizedBox(height: 8),

            Row(
              children: [
                Expanded(child: _kv("Smoking", p.smoking ? "Yes" : "No")),
                Expanded(child: _kv("Alcohol", p.alcohol ? "Yes" : "No")),
                Expanded(child: _kv("Genetic Risk", p.geneticRisk ? "Yes" : "No")),
              ],
            ),
          ],

          const Divider(height: 26),

          // Meal plan section
          const Text("Meal Plan", style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),

          if (plan != null)
            Row(
              children: [
                Expanded(
                  child: Text(
                    plan.planId,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                TextButton.icon(
                  onPressed: widget.onViewMealPlan,
                  icon: const Icon(Icons.remove_red_eye, size: 18, color: Color(0xFF8B5CF6)),
                  label: const Text(
                    "View",
                    style: TextStyle(color: Color(0xFF8B5CF6), fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            )
          else
            Text(
              "No plan generated",
              style: TextStyle(color: Colors.black.withOpacity(0.55)),
            ),

          const SizedBox(height: 10),

          const Divider(height: 26),

          // Status
          const Text("Status", style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          StatusBadge(status: status),

          const SizedBox(height: 14),

          // ACTION BUTTONS
          if (plan == null) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8B5CF6),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                onPressed: widget.onGenerateMealPlan,
                child: const Text("Generate Meal Plan", style: TextStyle(fontWeight: FontWeight.w900)),
              ),
            ),
          ] else if (widget.canApproveRejectEdit) ...[
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00C853),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: widget.onApprove,
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text("Approve", style: TextStyle(fontWeight: FontWeight.w900)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF1744),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: widget.onReject,
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text("Reject", style: TextStyle(fontWeight: FontWeight.w900)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2979FF),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: widget.onEdit,
                    icon: const Icon(Icons.edit, size: 18),
                    label: const Text("Edit", style: TextStyle(fontWeight: FontWeight.w900)),
                  ),
                ),
              ],
            ),
          ] else ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8B5CF6),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                onPressed: widget.onGenerateMealPlan,
                child: const Text("Generate New Plan", style: TextStyle(fontWeight: FontWeight.w900)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
