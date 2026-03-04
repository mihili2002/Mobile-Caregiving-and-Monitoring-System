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

  // ===================== Doctor-Friendly Summary Badge =====================
  int _avgPercent(List<DiseaseJustificationResult?> rules) {
    final values = rules.where((r) => r != null).map((r) => r!.percent).toList();
    if (values.isEmpty) return 0;
    final sum = values.reduce((a, b) => a + b);
    return (sum / values.length).round();
  }

  String _suitabilityLabel(int percent) {
    if (percent >= 80) return "HIGH";
    if (percent >= 60) return "MODERATE";
    return "LOW";
  }

  Color _suitabilityColor(int percent) {
    if (percent >= 80) return const Color(0xFF1B7F3A); // green
    if (percent >= 60) return const Color(0xFFB26A00); // amber
    return const Color(0xFFB00020); // red
  }

  Widget _summaryBadge({
    required bool hasAnyDisease,
    required bool hasNone,
    required DiseaseJustificationResult? diabetesRule,
    required DiseaseJustificationResult? hyperRule,
    required DiseaseJustificationResult? heartRule,
  }) {
    if (!hasAnyDisease || (hasNone && !hasAnyDisease)) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.black.withOpacity(0.08)),
        ),
        child: Text(
          "GENERAL",
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 12,
            color: Colors.black.withOpacity(0.65),
          ),
        ),
      );
    }

    final overallPercent = _avgPercent([diabetesRule, hyperRule, heartRule]);
    final overallLabel = _suitabilityLabel(overallPercent);
    final overallColor = _suitabilityColor(overallPercent);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: overallColor.withOpacity(0.35)),
      ),
      child: Text(
        "$overallLabel • $overallPercent%",
        style: TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: 12,
          color: overallColor,
        ),
      ),
    );
  }
  // ========================================================================

  // ===================== Clinical Recommendation Text =====================
  String _clinicalRecommendation({
    required bool hasAnyDisease,
    required bool hasNone,
    required bool hasDiabetes,
    required bool hasHypertension,
    required bool hasHeart,
    required DiseaseJustificationResult? diabetesRule,
    required DiseaseJustificationResult? hyperRule,
    required DiseaseJustificationResult? heartRule,
    required List<String> diabetesBullets,
    required List<String> hyperBullets,
    required List<String> heartBullets,
  }) {
    if (!hasAnyDisease || (hasNone && !hasAnyDisease)) {
      return "Clinical recommendation: No chronic disease constraints selected. This plan follows general nutritional guidance; doctor may validate based on overall context.";
    }

    final parts = <String>[];

    void add({
      required String label,
      required DiseaseJustificationResult? r,
      required List<String> bullets,
      String focusGood = "supportive patterns",
      String focusWarn = "warnings",
    }) {
      if (r == null) return;

      String because = "";
      if (bullets.isNotEmpty) {
        final take = bullets.take(2).toList();
        because = " (e.g., ${take.join("; ")})";
      }

      if (r.percent >= 80 && r.warnings.isEmpty) {
        parts.add("$label: Suitable based on detected $focusGood$because.");
      } else if (r.percent >= 60) {
        if (r.warnings.isNotEmpty) {
          parts.add(
              "$label: Generally suitable, but review $focusWarn (found ${r.warnings.length}).");
        } else {
          parts.add(
              "$label: Generally suitable based on detected $focusGood$because.");
        }
      } else {
        parts.add(
            "$label: Needs doctor review (lower evidence score: ${r.percent}%).");
      }
    }

    if (hasDiabetes) {
      add(
        label: "Diabetes",
        r: diabetesRule,
        bullets: diabetesBullets,
        focusGood: "glycaemic-control patterns",
        focusWarn: "carb/sugar-related warnings",
      );
    }

    if (hasHypertension) {
      add(
        label: "Hypertension",
        r: hyperRule,
        bullets: hyperBullets,
        focusGood: "BP-friendly patterns",
        focusWarn: "sodium/frying-related warnings",
      );
    }

    if (hasHeart) {
      add(
        label: "Heart",
        r: heartRule,
        bullets: heartBullets,
        focusGood: "heart-friendly patterns",
        focusWarn: "fat/sodium-related warnings",
      );
    }

    if (parts.isEmpty) {
      return "Clinical recommendation: Tap View to see disease-aware justification and evidence.";
    }

    return "Clinical recommendation: ${parts.join(" ")}";
  }

  Widget _clinicalRecommendationCard(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.local_hospital,
              size: 18, color: Colors.black.withOpacity(0.70)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.black.withOpacity(0.78),
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
  // ========================================================================

  // ===================== Disease Tabs Helpers =========================
  Widget _tabsBlock({
    required List<String> tabTitles,
    required List<Widget> tabViews,
  }) {
    if (tabTitles.isEmpty) return const SizedBox.shrink();

    // TabBarView needs a bounded height in many parent layouts (e.g., ListView).
    const double tabViewHeight = 520;

    return DefaultTabController(
      length: tabTitles.length,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFBFE8CD)),
            ),
            child: TabBar(
              isScrollable: tabTitles.length > 2,
              labelColor: const Color(0xFF1B7F3A),
              unselectedLabelColor: Colors.black.withOpacity(0.65),
              labelStyle: const TextStyle(fontWeight: FontWeight.w900),
              indicator: BoxDecoration(
                color: const Color(0xFFEFFAF4),
                borderRadius: BorderRadius.circular(10),
              ),
              tabs: tabTitles.map((t) => Tab(text: t)).toList(),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: tabViewHeight,
            child: TabBarView(
              children: tabViews
                  .map(
                    (w) => SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: w,
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
  // ========================================================================

  // ===================== Nutrient-Level Justification (NEW) =====================
  // NOTE: This is "proxy nutrient justification" using your existing meal text,
  // so it works 100% even if MealPlanModel doesn't include nutrient fields.
  //
  // If later your API returns actual nutrients (sodium, sugar, carbs, etc.),
  // you can replace the heuristics with real numbers without changing the UI.
  List<_NutrientSignal> _nutrientSignals({
    required bool hasDiabetes,
    required bool hasHypertension,
    required bool hasHeart,
    required List<String> mealsText,
  }) {
    // "positives" and "warnings" are keyword-based nutrient proxies
    final signals = <_NutrientSignal>[];

    bool hasAny(List<String> keys) => _containsAny(mealsText, keys);

    // --- proxies ---
    final highFibre =
        hasAny(["lentil", "chickpea", "cowpea", "black bean", "gram", "dhal"]) ||
            hasAny(["salad", "leafy", "vegetable", "greens"]) ||
            hasAny(["kurakkan", "sorghum", "quinoa", "brown rice", "whole wheat"]);

    final lowAddedSugar = !hasAny(
        ["cake", "dessert", "sweet", "sugar syrup", "soft drink", "toffee"]);

    final lowSodiumProxy = !hasAny(
        ["processed", "sausage", "bacon", "instant noodles", "pickle", "chips"]);

    final heartHealthyFat =
        hasAny(["fish", "tuna", "salmon", "sardine", "mackerel"]) ||
            hasAny(["nuts", "almond", "walnut", "cashew", "avocado", "olive"]);

    final lowFriedProxy = !hasAny(["fried", "deep fried", "deep-fried"]);

    final healthierCooking =
        hasAny(["steamed", "baked", "grilled", "roast", "roasted"]);

    // --- diabetes nutrient layer ---
    if (hasDiabetes) {
      signals.add(
        _NutrientSignal(
          name: "Carbohydrate quality",
          rationale: highFibre
              ? "High-fibre / low-GI signals detected (whole grains / legumes / vegetables)."
              : "Fibre/whole-grain signals are limited in text; consider adding legumes/whole grains.",
          status: highFibre ? _NutrientStatus.good : _NutrientStatus.warn,
        ),
      );
      signals.add(
        _NutrientSignal(
          name: "Added sugar",
          rationale: lowAddedSugar
              ? "No obvious added-sugar/dessert items detected (proxy for lower added sugar)."
              : "Sugary items detected; consider reducing desserts/soft drinks for glycaemic control.",
          status: lowAddedSugar ? _NutrientStatus.good : _NutrientStatus.bad,
        ),
      );
    }

    // --- hypertension nutrient layer ---
    if (hasHypertension) {
      signals.add(
        _NutrientSignal(
          name: "Sodium",
          rationale: lowSodiumProxy
              ? "No obvious processed/high-sodium food keywords detected (proxy for lower sodium)."
              : "Processed/high-sodium food keywords detected; consider lower-sodium alternatives.",
          status: lowSodiumProxy ? _NutrientStatus.good : _NutrientStatus.warn,
        ),
      );
    }

    // --- heart nutrient layer ---
    if (hasHeart) {
      signals.add(
        _NutrientSignal(
          name: "Fat quality",
          rationale: heartHealthyFat
              ? "Fish/nuts/healthy-fat signals detected (proxy for better fat profile)."
              : "Limited omega-3/healthy-fat signals; consider fish/nuts/olive-based options.",
          status: heartHealthyFat ? _NutrientStatus.good : _NutrientStatus.warn,
        ),
      );
      signals.add(
        _NutrientSignal(
          name: "Fried food exposure",
          rationale: lowFriedProxy
              ? "No obvious deep-fried keywords detected (proxy for lower saturated/trans fat load)."
              : "Fried keywords detected; consider baked/steamed/grilled alternatives.",
          status: lowFriedProxy ? _NutrientStatus.good : _NutrientStatus.bad,
        ),
      );
    }

    // --- general cooking method (helpful even when 2 diseases selected) ---
    if ((hasDiabetes || hasHypertension || hasHeart)) {
      signals.add(
        _NutrientSignal(
          name: "Cooking methods",
          rationale: healthierCooking
              ? "Steamed/baked/grilled/roasted keywords detected (proxy for lower added fat/sodium)."
              : "Cooking-method keywords are limited; encourage steamed/baked/grilled methods.",
          status: healthierCooking ? _NutrientStatus.good : _NutrientStatus.warn,
        ),
      );
    }

    return signals;
  }

  Widget _nutrientJustificationCard({
    required bool hasAnyDisease,
    required bool hasNone,
    required bool hasDiabetes,
    required bool hasHypertension,
    required bool hasHeart,
    required List<String> mealsText,
  }) {
    if (!hasAnyDisease || (hasNone && !hasAnyDisease)) {
      return const SizedBox.shrink(); // keep UI clean for GENERAL mode
    }

    final signals = _nutrientSignals(
      hasDiabetes: hasDiabetes,
      hasHypertension: hasHypertension,
      hasHeart: hasHeart,
      mealsText: mealsText,
    );

    if (signals.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.science, size: 18, color: Colors.black.withOpacity(0.70)),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  "Nutrient-Level Justification",
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F7F7),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.black.withOpacity(0.06)),
                ),
                child: Text(
                  "Proxy signals",
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    color: Colors.black.withOpacity(0.65),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...signals.map((s) => _NutrientRow(signal: s)),
          const SizedBox(height: 8),
          Text(
            "Note: These are keyword-based nutrient proxies (until numeric nutrient data is available).",
            style: TextStyle(fontSize: 12, color: Colors.black.withOpacity(0.55)),
          ),
        ],
      ),
    );
  }
  // ========================================================================

  @override
  Widget build(BuildContext context) {
    final cond =
        widget.chronicConditions.map((e) => e.toLowerCase().trim()).toList();

    final hasDiabetes = cond.any((c) => c.contains("diab"));
    final hasHypertension = cond.any((c) => c.contains("hyper"));
    final hasHeart = cond.any((c) => c.contains("heart"));
    final hasNone = cond.any((c) => c == "none");

    final hasAnyDisease = hasDiabetes || hasHypertension || hasHeart;
    final effectiveHasDisease = hasAnyDisease;

    final mealsText = _flattenMealText(widget.plan);

    final diabetes = hasDiabetes ? _diabetesHighlights(mealsText) : <String>[];
    final hyper =
        hasHypertension ? _hypertensionHighlights(mealsText) : <String>[];
    final heart = hasHeart ? _heartHighlights(mealsText) : <String>[];

    final diabetesScore = hasDiabetes ? _score(diabetes) : null;
    final hyperScore = hasHypertension ? _score(hyper) : null;
    final heartScore = hasHeart ? _score(heart) : null;

    final diabetesRule =
        hasDiabetes ? DiseaseRules.evaluateDiabetes(widget.plan) : null;
    final hyperRule =
        hasHypertension ? DiseaseRules.evaluateHypertension(widget.plan) : null;
    final heartRule =
        hasHeart ? DiseaseRules.evaluateHeartDisease(widget.plan) : null;

    final summaryLine = _buildSummaryLine(
      hasAnyDisease: hasAnyDisease,
      hasNone: hasNone,
      diabetesRule: diabetesRule,
      hyperRule: hyperRule,
      heartRule: heartRule,
    );

    final recommendation = _clinicalRecommendation(
      hasAnyDisease: hasAnyDisease,
      hasNone: hasNone,
      hasDiabetes: hasDiabetes,
      hasHypertension: hasHypertension,
      hasHeart: hasHeart,
      diabetesRule: diabetesRule,
      hyperRule: hyperRule,
      heartRule: heartRule,
      diabetesBullets: diabetes,
      hyperBullets: hyper,
      heartBullets: heart,
    );

    final tabTitles = <String>[];
    final tabViews = <Widget>[];

    if (hasDiabetes) {
      tabTitles.add("Diabetes");
      tabViews.add(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Section(
              title: "Diabetes Care",
              subtitle: "Indicators that support blood sugar control",
              scoreText: diabetesScore,
              bullets: diabetes,
            ),
            if (diabetesRule != null) _RuleEngineSection(result: diabetesRule),
          ],
        ),
      );
    }

    if (hasHypertension) {
      tabTitles.add("Hypertension");
      tabViews.add(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Section(
              title: "Hypertension Care",
              subtitle: "Indicators that support blood pressure control",
              scoreText: hyperScore,
              bullets: hyper,
            ),
            if (hyperRule != null) _RuleEngineSection(result: hyperRule),
          ],
        ),
      );
    }

    if (hasHeart) {
      tabTitles.add("Heart");
      tabViews.add(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Section(
              title: "Heart Disease Care",
              subtitle: "Indicators that support heart health",
              scoreText: heartScore,
              bullets: heart,
            ),
            if (heartRule != null) _RuleEngineSection(result: heartRule),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF1FBF6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFBFE8CD)),
      ),
      child: Column(
        children: [
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
                      style:
                          TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                    ),
                  ),
                  _summaryBadge(
                    hasAnyDisease: hasAnyDisease,
                    hasNone: hasNone,
                    diabetesRule: diabetesRule,
                    hyperRule: hyperRule,
                    heartRule: heartRule,
                  ),
                  const SizedBox(width: 8),
                  if (!_expanded)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: const Color(0xFFBFE8CD)),
                      ),
                      child: const Text(
                        "View",
                        style: TextStyle(
                            fontWeight: FontWeight.w900, fontSize: 12),
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
                  _clinicalRecommendationCard(recommendation),
                  const SizedBox(height: 10),

                  // ✅ NEW: Nutrient-level card (collapsed too)
                  _nutrientJustificationCard(
                    hasAnyDisease: hasAnyDisease,
                    hasNone: hasNone,
                    hasDiabetes: hasDiabetes,
                    hasHypertension: hasHypertension,
                    hasHeart: hasHeart,
                    mealsText: mealsText,
                  ),
                  const SizedBox(height: 10),

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

                        _clinicalRecommendationCard(recommendation),
                        const SizedBox(height: 12),

                        // ✅ NEW: Nutrient-level card (expanded)
                        _nutrientJustificationCard(
                          hasAnyDisease: hasAnyDisease,
                          hasNone: hasNone,
                          hasDiabetes: hasDiabetes,
                          hasHypertension: hasHypertension,
                          hasHeart: hasHeart,
                          mealsText: mealsText,
                        ),
                        const SizedBox(height: 12),

                        _MiniSignalsRow(
                          chronicConditions: widget.chronicConditions,
                          age: widget.age,
                          bmi: widget.bmi,
                          bloodPressure: widget.bloodPressure,
                          bloodSugar: widget.bloodSugar,
                        ),
                        const SizedBox(height: 12),

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

                        if (tabTitles.isNotEmpty) ...[
                          _tabsBlock(tabTitles: tabTitles, tabViews: tabViews),
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
      bullets.add("Vegetable/fibre-rich items detected (supports glycaemic control)");
    }
    if (!_containsAny(
        meals, ["cake", "dessert", "sweet", "sugar syrup", "soft drink"])) {
      bullets.add("No obvious sugary dessert items detected in plan");
    }
    if (_containsAny(meals, ["roast", "steamed", "baked", "grilled"])) {
      bullets.add("Healthier cooking methods detected (roasted/steamed/baked/grilled)");
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

  String _score(List<String> bullets) {
    const total = 5;
    final matched = bullets.length > total ? total : bullets.length;
    return "Score: $matched/$total";
  }
}

// ===================== Nutrient UI Pieces (NEW) =====================
enum _NutrientStatus { good, warn, bad }

class _NutrientSignal {
  final String name;
  final String rationale;
  final _NutrientStatus status;

  const _NutrientSignal({
    required this.name,
    required this.rationale,
    required this.status,
  });
}

class _NutrientRow extends StatelessWidget {
  final _NutrientSignal signal;

  const _NutrientRow({required this.signal});

  Color _colorFor(_NutrientStatus s) {
    switch (s) {
      case _NutrientStatus.good:
        return const Color(0xFF1B7F3A);
      case _NutrientStatus.warn:
        return const Color(0xFFB26A00);
      case _NutrientStatus.bad:
        return const Color(0xFFB00020);
    }
  }

  IconData _iconFor(_NutrientStatus s) {
    switch (s) {
      case _NutrientStatus.good:
        return Icons.check_circle;
      case _NutrientStatus.warn:
        return Icons.info;
      case _NutrientStatus.bad:
        return Icons.warning_amber_rounded;
    }
  }

  String _labelFor(_NutrientStatus s) {
    switch (s) {
      case _NutrientStatus.good:
        return "Good";
      case _NutrientStatus.warn:
        return "Review";
      case _NutrientStatus.bad:
        return "Risk";
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _colorFor(signal.status);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: c.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: c.withOpacity(0.20)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(_iconFor(signal.status), size: 18, color: c),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          signal.name,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: c.withOpacity(0.25)),
                        ),
                        child: Text(
                          _labelFor(signal.status),
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                            color: c,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    signal.rationale,
                    style: TextStyle(
                      color: Colors.black.withOpacity(0.72),
                      height: 1.30,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
// =====================================================================

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
    final condText =
        chronicConditions.isEmpty ? "-" : chronicConditions.join(", ");

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
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
