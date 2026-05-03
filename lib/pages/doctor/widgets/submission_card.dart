import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/meal_plan_model.dart';
import 'status_badge.dart';

class SubmissionCard extends StatefulWidget {
  final String elderId;
  final Map<String, dynamic> latestSubmission;
  final MealPlanModel? latestMealPlan;

  final VoidCallback onShowMore;
  final VoidCallback onViewMealPlan;
  final VoidCallback onGenerateMealPlan;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  // final VoidCallback onEdit;
  final bool canApproveRejectEdit;

  const SubmissionCard({
    super.key,
    required this.elderId,
    required this.latestSubmission,
    required this.latestMealPlan,
    required this.onShowMore,
    required this.onViewMealPlan,
    required this.onGenerateMealPlan,
    required this.onApprove,
    required this.onReject,
    // required this.onEdit,
    required this.canApproveRejectEdit,
  });

  @override
  State<SubmissionCard> createState() => _SubmissionCardState();
}

class _SubmissionCardState extends State<SubmissionCard> {
  bool expanded = false;

  // ---------------- SAFE HELPERS ----------------

  String _fmtDate(dynamic d) {
    if (d == null) return "-";
    if (d is String) {
      final parsed = DateTime.tryParse(d);
      return parsed == null
          ? "-"
          : DateFormat("MMM d, yyyy").format(parsed);
    }
    if (d is int) {
      return DateFormat("MMM d, yyyy")
          .format(DateTime.fromMillisecondsSinceEpoch(d));
    }
    if (d is DateTime) {
      return DateFormat("MMM d, yyyy").format(d);
    }
    return "-";
  }

  Widget _kv(String k, dynamic v) {
    final text = v == null || v.toString().isEmpty ? "-" : v.toString();

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: RichText(
        text: TextSpan(
          style: TextStyle(
            color: Colors.black.withOpacity(0.70),
            height: 1.35,
          ),
          children: [
            TextSpan(
              text: "$k: ",
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            TextSpan(text: text),
          ],
        ),
      ),
    );
  }

  double? _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    return null;
  }

  int? _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return null;
  }

  // ---------------- BUILD ----------------

  @override
  Widget build(BuildContext context) {
    final s = widget.latestSubmission;
    final plan = widget.latestMealPlan;

    // ---------- SAFE EXTRACTION ----------
    final age = _toInt(s['age']);
    final gender = s['gender'];
    final height = _toDouble(s['height_cm'] ?? s['height']);
    final weight = _toDouble(s['weight_kg'] ?? s['weight']);

    final chronicConditions =
    List<String>.from(s['chronic_conditions'] ?? []);

    final bp = s['blood_pressure'] is Map
        ? Map<String, dynamic>.from(s['blood_pressure'])
        : null;

    final bloodSugar = _toDouble(s['blood_sugar_mg_dl']);
    final cholesterol = _toDouble(s['cholesterol_mg_dl']);
    final dailySteps = _toInt(s['daily_steps']);
    final sleepHours = _toDouble(s['sleep_hours']);

    final dietaryHabit = s['dietary_habit'];
    final caloricintake = _toDouble(s['caloric_intake']);
    final proteinintake = _toDouble(s['protein_intake']);
    final fatintake = _toDouble(s['fat_intake']);
    final carbintake = _toDouble(s['carbohydrate_intake']);
    final exerciseFrequency = s['exercise_frequency'];
    final preferredCuisine = s['preferred_cuisine'];
    final foodAllergies = s['food_allergies'];
    final foodAversions = s['food_aversions'];

    final smoking = s['smoking'] == true;
    final alcohol = s['alcohol'] == true;
    final geneticRisk = s['genetic_risk'] == true;

    final createdAt = s['submitted_at'] ?? s['created_at'];

    // ---------- BMI ----------
    double? bmi;
    if (height != null && weight != null && height > 0) {
      final hMeters = height / 100;
      bmi = weight / (hMeters * hMeters);
    }

    final status = plan?.status ?? "No Plan";

    // ---------------- UI ----------------
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
          // ---------- HEADER ----------
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
                    color: Color(0xFF11BFA8),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          _kv("Age / Gender", "$age • $gender"),
          _kv("BMI", bmi == null ? "-" : bmi.toStringAsFixed(1)),
          _kv("Conditions",
              chronicConditions.isEmpty ? "-" : chronicConditions.join(", ")),
          _kv(
            "Blood Pressure",
            bp == null ? "-" : "${bp['systolic']}/${bp['diastolic']}",
          ),
          _kv("Blood Sugar",
              bloodSugar == null ? "-" : "$bloodSugar mg/dL"),
          _kv("Submitted", _fmtDate(createdAt)),

          if (expanded) ...[
            const Divider(height: 22),
            _kv("Height", height == null ? "-" : "$height cm"),
            _kv("Weight", weight == null ? "-" : "$weight kg"),
            _kv("Cholesterol",
                cholesterol == null ? "-" : "$cholesterol mg/dL"),
            _kv("Daily Steps", dailySteps),
            _kv("Exercise", s['exercise_frequency']),
            _kv("Sleep", sleepHours == null ? "-" : "$sleepHours hrs"),
            _kv("Dietary Habit", dietaryHabit),
            _kv("Caloric Intake",
                caloricintake == null ? "-" : "$caloricintake kcal"),
            _kv("Protein Intake",
                proteinintake == null ? "-" : "$proteinintake g"),
            _kv("Fat Intake", fatintake == null ? "-" : "$fatintake g"),
            _kv("Carbohydrate Intake",
                carbintake == null ? "-" : "$carbintake g"),
            _kv("Exercise Frequency", exerciseFrequency),
            _kv("Preferred Cuisine", preferredCuisine),
            _kv("Food Allergies", foodAllergies),
            _kv("Food Aversions", foodAversions),
            _kv("Smoking", smoking ? "Yes" : "No"),
            _kv("Alcohol", alcohol ? "Yes" : "No"),
            _kv("Genetic Risk", geneticRisk ? "Yes" : "No"),
          ],

          const Divider(height: 26),

          const Text("Meal Plan", style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),

          if (plan != null)
            Row(
              children: [
                Expanded(
                  child:
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        "Generated",
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: widget.onViewMealPlan,
                  icon: const Icon(Icons.remove_red_eye,
                      size: 18, color: Color(0xFF11BFA8)),
                  label: const Text(
                    "View",
                    style: TextStyle(
                        color: Color(0xFF11BFA8),
                        fontWeight: FontWeight.w800),
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

          const Text("Status", style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          StatusBadge(status: status),

          const SizedBox(height: 14),

          // ---------- ACTIONS ----------
          if (plan == null)
            _primaryButton("Generate Meal Plan", widget.onGenerateMealPlan)
          // else if (widget.canApproveRejectEdit)
          //   _approvalButtons()
          else
            _primaryButton("Generate New Plan", widget.onGenerateMealPlan),
        ],
      ),
    );
  }

  // ---------------- BUTTONS ----------------

  Widget _primaryButton(String text, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF11BFA8),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
        onPressed: onTap,
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.w900)),
      ),
    );
  }

  Widget _approvalButtons() {
    return Row(
      children: [
        _actionBtn("Approve", Icons.check, const Color(0xFF00C853),
            widget.onApprove),
        const SizedBox(width: 10),
        _actionBtn("Reject", Icons.close, const Color(0xFFFF1744),
            widget.onReject),
        // const SizedBox(width: 10),
        // _actionBtn(
        //     "Edit", Icons.edit, const Color(0xFF2979FF), widget.onEdit),
      ],
    );
  }

  Widget _actionBtn(
      String label, IconData icon, Color color, VoidCallback onTap) {
    return Expanded(
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(label,
            style: const TextStyle(fontWeight: FontWeight.w900)),
      ),
    );
  }
}
