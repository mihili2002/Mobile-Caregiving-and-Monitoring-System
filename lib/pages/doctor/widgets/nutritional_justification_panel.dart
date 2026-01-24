import 'package:flutter/material.dart';
import '../../../models/meal_plan_model.dart';
import 'disease_rules.dart';

class NutritionalJustificationPanel extends StatefulWidget {
  final List<String> chronicConditions;
  final MealPlanModel plan;

  /// Personalization signals (from latestSubmission map)
  final int? age;
  final double? bmi;
  final Map<String, dynamic>? bloodPressure;
  final double? bloodSugar;
  final String? dietaryHabit;
  final String? foodAllergies;

  const NutritionalJustificationPanel({
    super.key,
    required this.chronicConditions,
    required this.plan,
    this.age,
    this.bmi,
    this.bloodPressure,
    this.bloodSugar,
    this.dietaryHabit,
    this.foodAllergies,
  });

  @override
  State<NutritionalJustificationPanel> createState() =>
      _NutritionalJustificationPanelState();
}

class _NutritionalJustificationPanelState
    extends State<NutritionalJustificationPanel> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final cond =
        widget.chronicConditions.map((e) => e.toLowerCase().trim()).toList();

    final hasDiabetes = cond.any((c) => c.contains("diab"));
    final hasHypertension = cond.any((c) => c.contains("hyper"));
    final hasHeart = cond.any((c) => c.contains("heart"));
    final hasNone = cond.any((c) => c == "none");

    final hasAnyDisease = hasDiabetes || hasHypertension || hasHeart;

    // If user selected "None" plus diseases, ignore "None"
    final effectiveHasDisease = hasAnyDisease;

    final mealsText = _flattenMealText(widget.plan);

    final diabetes = hasDiabetes ? _diabetesHighlights(mealsText) : <String>[];
    final hyper =
        hasHypertension ? _hypertensionHighlights(mealsText) : <String>[];
    final heart = hasHeart ? _heartHighlights(mealsText) : <String>[];

    // Scores (optional but strong)
    final diabetesScore = hasDiabetes ? _score(diabetes) : null;
    final hyperScore = hasHypertension ? _score(hyper) : null;
    final heartScore = hasHeart ? _score(heart) : null;

    // ---------------- Disease Rules Engine (Explainable evidence) ----------------
    final diabetesRule =
        hasDiabetes ? DiseaseRules.evaluateDiabetes(widget.plan) : null;
    final hyperRule =
        hasHypertension ? DiseaseRules.evaluateHypertension(widget.plan) : null;
    final heartRule =
        hasHeart ? DiseaseRules.evaluateHeartDisease(widget.plan) : null;
    // ---------------------------------------------------------------------------

    final summaryLine = _buildSummaryLine(
      hasAnyDisease: hasAnyDisease,
      hasNone: hasNone,
      diabetesRule: diabetesRule,
      hyperRule: hyperRule,
      heartRule: heartRule,
    );

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF1FBF6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFBFE8CD)),
      ),
      child: Column(
        children: [
          // ---------------- Header (tap to expand/collapse) ----------------
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
              child: Row(
                children: [
                  const Icon(Icons.verified, color: Color(0xFF1B7F3A)),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      "Disease-Aware Nutritional Justification",
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                    ),
                  ),
                  if (!_expanded)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: const Color(0xFFBFE8CD)),
                      ),
                      child: const Text(
                        "View",
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: const Color(0xFF1B7F3A),
                  ),
                ],
              ),
            ),
          ),

          // ---------------- Collapsed content (small + professional) ----------------
          if (!_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    summaryLine,
                    style: TextStyle(color: Colors.black.withOpacity(0.70)),
                  ),
                  const SizedBox(height: 10),

                  // Compact chips only (NOT repeating full health details)
                  _MiniSignalsRow(
                    chronicConditions: widget.chronicConditions,
                    age: widget.age,
                    bmi: widget.bmi,
                    bloodPressure: widget.bloodPressure,
                    bloodSugar: widget.bloodSugar,
                  ),
                ],
              ),
            ),

          // ---------------- Expanded full content ----------------
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeInOut,
            child: _expanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "This section explains why the generated meals match chronic disease constraints with evidence.",
                          style: TextStyle(color: Colors.black.withOpacity(0.70)),
                        ),
                        const SizedBox(height: 12),

                        // Optional chips again (still compact)
                        _MiniSignalsRow(
                          chronicConditions: widget.chronicConditions,
                          age: widget.age,
                          bmi: widget.bmi,
                          bloodPressure: widget.bloodPressure,
                          bloodSugar: widget.bloodSugar,
                        ),
                        const SizedBox(height: 12),

                        // If "None" only (or no disease found) show general section
                        if (!effectiveHasDisease || (hasNone && !hasAnyDisease))
                          const _ExplainSection(
                            title: "General Nutrition Plan",
                            subtitle: "No chronic disease selected",
                            bullets: [
                              "Plan is personalised using age, BMI, activity level and food preferences.",
                              "Meals are generated within predicted nutrient targets from ML models.",
                              "Doctor performs final clinical validation (approve/reject).",
                            ],
                          ),

                        // ✅ Diabetes block
                        if (hasDiabetes) ...[
                          _Section(
                            title: "Diabetes Care",
                            subtitle: "Indicators that support blood sugar control",
                            scoreText: diabetesScore,
                            bullets: diabetes,
                          ),
                          if (diabetesRule != null)
                            _RuleEngineSection(result: diabetesRule),
                        ],

                        // ✅ Hypertension block
                        if (hasHypertension) ...[
                          _Section(
                            title: "Hypertension Care",
                            subtitle: "Indicators that support blood pressure control",
                            scoreText: hyperScore,
                            bullets: hyper,
                          ),
                          if (hyperRule != null) _RuleEngineSection(result: hyperRule),
                        ],

                        // ✅ Heart block
                        if (hasHeart) ...[
                          _Section(
                            title: "Heart Disease Care",
                            subtitle: "Indicators that support heart health",
                            scoreText: heartScore,
                            bullets: heart,
                          ),
                          if (heartRule != null) _RuleEngineSection(result: heartRule),
                        ],

                        const SizedBox(height: 6),
                        Text(
                          "* Final approval remains with the doctor. This is an explainability aid, not a clinical diagnosis.",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.black.withOpacity(0.55),
                          ),
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  String _buildSummaryLine({
    required bool hasAnyDisease,
    required bool hasNone,
    required DiseaseJustificationResult? diabetesRule,
    required DiseaseJustificationResult? hyperRule,
    required DiseaseJustificationResult? heartRule,
  }) {
    if (!hasAnyDisease || (hasNone && !hasAnyDisease)) {
      return "No chronic disease rules applied. Tap View to see general rationale.";
    }

    final parts = <String>[];
    if (diabetesRule != null) parts.add("Diabetes ${diabetesRule.percent}%");
    if (hyperRule != null) parts.add("HTN ${hyperRule.percent}%");
    if (heartRule != null) parts.add("Heart ${heartRule.percent}%");

    if (parts.isEmpty) return "Tap View to see disease-aware justification.";
    return "Rule validation summary — ${parts.join(" • ")}. Tap View for evidence.";
  }

  // ---------- Extract text from plan ----------
  List<String> _flattenMealText(MealPlanModel plan) {
    final list = <String>[];

    // Prefer API structure
    if (plan.days.isNotEmpty) {
      for (final d in plan.days) {
        for (final item in d.meals.breakfast) {
          list.add("${item.foodName} ${item.notes}".toLowerCase());
        }
        for (final item in d.meals.lunch) {
          list.add("${item.foodName} ${item.notes}".toLowerCase());
        }
        for (final item in d.meals.dinner) {
          list.add("${item.foodName} ${item.notes}".toLowerCase());
        }
        for (final item in d.meals.snacks) {
          list.add("${item.foodName} ${item.notes}".toLowerCase());
        }
      }
      return list;
    }

    // Backward compatible: plan.meals map
    final mealsMap = plan.meals;
    for (final day in mealsMap.keys) {
      final dayMeals = mealsMap[day] as Map<String, dynamic>;
      for (final mealType in dayMeals.keys) {
        final items =
            (dayMeals[mealType] as List).map((e) => e.toString().toLowerCase());
        list.addAll(items);
      }
    }
    return list;
  }

  bool _containsAny(List<String> meals, List<String> keywords) {
    for (final m in meals) {
      for (final k in keywords) {
        if (m.contains(k)) return true;
      }
    }
    return false;
  }

  // ---------- Diabetes ----------
  List<String> _diabetesHighlights(List<String> meals) {
    final bullets = <String>[];

    if (_containsAny(meals,
        ["kurakkan", "sorghum", "quinoa", "brown rice", "whole wheat"])) {
      bullets.add(
          "Low/medium glycaemic grains detected (Kurakkan / Sorghum / Quinoa / Whole grains)");
    }
    if (_containsAny(meals,
        ["lentil", "chickpea", "cowpea", "black bean", "gram", "dhal"])) {
      bullets.add("High-fibre legumes detected (Lentils / Chickpeas / Beans)");
    }
    if (_containsAny(meals, ["salad", "leafy", "vegetable", "greens"])) {
      bullets.add(
          "Vegetable/fibre-rich items detected (supports glycaemic control)");
    }
    if (!_containsAny(
        meals, ["cake", "dessert", "sweet", "sugar syrup", "soft drink"])) {
      bullets.add("No obvious sugary dessert items detected in plan");
    }
    if (_containsAny(meals, ["roast", "steamed", "baked", "grilled"])) {
      bullets.add(
          "Healthier cooking methods detected (roasted/steamed/baked/grilled)");
    }

    if (bullets.isEmpty) {
      bullets.add("No clear diabetes-specific indicators found from meal text labels.");
    }
    return bullets;
  }

  // ---------- Hypertension ----------
  List<String> _hypertensionHighlights(List<String> meals) {
    final bullets = <String>[];

    if (_containsAny(meals, ["low oil", "low-oil"])) {
      bullets.add("Low-oil meals detected (supports BP control)");
    }
    if (_containsAny(meals, ["low salt", "low-salt"])) {
      bullets.add("Low-salt meals detected (supports BP control)");
    }
    if (_containsAny(meals, ["steamed", "baked", "grilled"])) {
      bullets.add(
          "Steamed/baked/grilled cooking detected (supports lower sodium/fat intake)");
    }
    if (!_containsAny(meals, ["processed", "sausage", "bacon", "instant noodles"])) {
      bullets.add("No obvious processed/high-sodium foods detected");
    }

    if (bullets.isEmpty) {
      bullets.add("No clear hypertension-specific indicators found from meal text labels.");
    }
    return bullets;
  }

  // ---------- Heart Disease ----------
  List<String> _heartHighlights(List<String> meals) {
    final bullets = <String>[];

    if (_containsAny(meals, ["low oil", "low-oil"])) {
      bullets.add("Low-oil meals detected (supports heart health)");
    }
    if (_containsAny(meals, ["steamed", "baked", "grilled"])) {
      bullets.add("Heart-friendly cooking methods detected (steamed/baked/grilled)");
    }
    if (_containsAny(meals, ["fish", "tuna", "salmon", "sardine", "mackerel"])) {
      bullets.add("Fish-based meals detected (potential omega-3 benefit)");
    }
    if (!_containsAny(meals, ["fried", "deep fried"])) {
      bullets.add("No obvious deep-fried items detected");
    }

    if (bullets.isEmpty) {
      bullets.add("No clear heart-disease indicators found from meal text labels.");
    }
    return bullets;
  }

  // Simple "score" text: e.g., "Score: 4/5"
  String _score(List<String> bullets) {
    const total = 5;
    final matched = bullets.length > total ? total : bullets.length;
    return "Score: $matched/$total";
  }
}

// ---------------- Compact signal chips row ----------------
class _MiniSignalsRow extends StatelessWidget {
  final List<String> chronicConditions;
  final int? age;
  final double? bmi;
  final Map<String, dynamic>? bloodPressure;
  final double? bloodSugar;

  const _MiniSignalsRow({
    required this.chronicConditions,
    required this.age,
    required this.bmi,
    required this.bloodPressure,
    required this.bloodSugar,
  });

  @override
  Widget build(BuildContext context) {
    String bpText = "-";
    if (bloodPressure != null) {
      final s = bloodPressure!['systolic'];
      final d = bloodPressure!['diastolic'];
      if (s != null && d != null) bpText = "$s/$d";
    }

    final bmiText = bmi == null ? "-" : bmi!.toStringAsFixed(1);
    final sugarText = bloodSugar == null ? "-" : bloodSugar!.toStringAsFixed(0);
    final condText = chronicConditions.isEmpty ? "-" : chronicConditions.join(", ");

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _chip("Cond", condText),
        _chip("Age", age?.toString() ?? "-"),
        _chip("BMI", bmiText),
        _chip("BP", bpText),
        _chip("Sugar", sugarText),
      ],
    );
  }

  static Widget _chip(String k, String v) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFBFE8CD)),
      ),
      child: Text(
        "$k: $v",
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

// ---------------- General explanation section ----------------
class _ExplainSection extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<String> bullets;

  const _ExplainSection({
    required this.title,
    required this.subtitle,
    required this.bullets,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFBFE8CD)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 2),
          Text(subtitle, style: TextStyle(color: Colors.black.withOpacity(0.65))),
          const SizedBox(height: 10),
          ...bullets.map(
            (b) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check_circle, size: 18, color: Color(0xFF1B7F3A)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(b)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<String> bullets;
  final String? scoreText;

  const _Section({
    required this.title,
    required this.subtitle,
    required this.bullets,
    required this.scoreText,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFBFE8CD)),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                  ),
                ),
                if (scoreText != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFFAF4),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: const Color(0xFFBFE8CD)),
                    ),
                    child: Text(
                      scoreText!,
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text(subtitle, style: TextStyle(color: Colors.black.withOpacity(0.65))),
            const SizedBox(height: 10),
            ...bullets.map(
              (b) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.check_circle,
                        size: 18, color: Color(0xFF1B7F3A)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(b)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------- Rule Engine Evidence ----------------
class _RuleEngineSection extends StatefulWidget {
  final DiseaseJustificationResult result;

  const _RuleEngineSection({required this.result});

  @override
  State<_RuleEngineSection> createState() => _RuleEngineSectionState();
}

class _RuleEngineSectionState extends State<_RuleEngineSection> {
  bool showEvidence = false;

  @override
  Widget build(BuildContext context) {
    final r = widget.result;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE3D8FF)),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.analytics, size: 18, color: Color(0xFF6D28D9)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Rule Engine Validation: ${r.disease}",
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF6F3FF),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0xFFE3D8FF)),
                  ),
                  child: Text(
                    "${r.percent}%",
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            if (r.positives.isNotEmpty) ...[
              const Text("Positives", style: TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              ...r.positives.map(
                (text) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.check_circle,
                          size: 18, color: Color(0xFF1B7F3A)),
                      const SizedBox(width: 8),
                      Expanded(child: Text(text)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],

            if (r.warnings.isNotEmpty) ...[
              const Text("Warnings", style: TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              ...r.warnings.map(
                (w) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          size: 18, color: Color(0xFFB00020)),
                      const SizedBox(width: 8),
                      Expanded(child: Text(w)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],

            InkWell(
              onTap: () => setState(() => showEvidence = !showEvidence),
              child: Row(
                children: [
                  Icon(
                    showEvidence ? Icons.expand_less : Icons.expand_more,
                    color: const Color(0xFF6D28D9),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    showEvidence ? "Hide Evidence" : "Show Evidence (matched meals)",
                    style: const TextStyle(
                      color: Color(0xFF6D28D9),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),

            if (showEvidence) ...[
              const SizedBox(height: 10),
              if (r.matchedPositiveMeals.isNotEmpty) ...[
                const Text("Matched supportive meals:",
                    style: TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                ...r.matchedPositiveMeals.map(
                  (m) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text("• $m"),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              if (r.matchedWarningMeals.isNotEmpty) ...[
                const Text("Matched warning meals:",
                    style: TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                ...r.matchedWarningMeals.map(
                  (m) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text("• $m"),
                  ),
                ),
              ],
              if (r.matchedPositiveMeals.isEmpty && r.matchedWarningMeals.isEmpty)
                Text(
                  "No keyword evidence lines detected from current meal text.",
                  style: TextStyle(color: Colors.black.withOpacity(0.65)),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
