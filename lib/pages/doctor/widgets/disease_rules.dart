import '../../../models/meal_plan_model.dart';

/// Result object your UI panel can display
class DiseaseJustificationResult {
  final String disease; // "Diabetes", "Hypertension", "Heart Disease"
  final int score; // 0..maxScore
  final int maxScore;

  /// Short “why it’s good” evidence
  final List<String> positives;

  /// Short “needs attention” warnings
  final List<String> warnings;

  /// Which meals triggered positives/warnings (for “Show Evidence” UI)
  final List<String> matchedPositiveMeals;
  final List<String> matchedWarningMeals;

  DiseaseJustificationResult({
    required this.disease,
    required this.score,
    required this.maxScore,
    required this.positives,
    required this.warnings,
    required this.matchedPositiveMeals,
    required this.matchedWarningMeals,
  });

  /// Convenience: percent for UI
  int get percent {
    if (maxScore <= 0) return 0;
    final p = (score / maxScore * 100).round();
    if (p < 0) return 0;
    if (p > 100) return 100;
    return p;
  }
}

/// Pure logic “rules engine” for explainability.
/// This does NOT generate meals. It only explains/validates what was generated.
class DiseaseRules {
  // -------------------- PUBLIC API --------------------

  static DiseaseJustificationResult evaluateDiabetes(MealPlanModel plan) {
    // Diabetes-friendly signals (VERY simple keyword evidence)
    const good = <String>[
      "whole grain",
      "whole-grain",
      "brown rice",
      "oats",
      "oatmeal",
      "quinoa",
      "lentil",
      "chickpea",
      "beans",
      "low sugar",
      "no sugar",
      "unsweetened",
      "high fiber",
      "fibre",
      "vegetable",
      "salad",
    ];

    const bad = <String>[
      "sugar",
      "sweet",
      "dessert",
      "syrup",
      "honey",
      "cake",
      "cookie",
      "soft drink",
      "juice",
      "refined",
      "white bread",
    ];

    return _evaluateByKeywords(
      disease: "Diabetes",
      plan: plan,
      goodKeywords: good,
      badKeywords: bad,

      // small "clinical-style" summary lines for your panel
      positiveSummaryTemplates: const [
        "More high-fiber / complex-carb choices were detected (e.g., oats, lentils, beans, whole grains).",
        "Lower added-sugar patterns were encouraged (unsweetened / low sugar signals).",
      ],
      warningSummaryTemplates: const [
        "Some items may contain added sugar or refined carbs — doctor review recommended.",
      ],
    );
  }

  static DiseaseJustificationResult evaluateHypertension(MealPlanModel plan) {
    // Hypertension (BP) signals: low sodium + cooking methods
    const good = <String>[
      "low-sodium",
      "low sodium",
      "unsalted",
      "low salt",
      "steamed",
      "grilled",
      "baked",
      "plain",
      "tomato base",
      "low-oil",
      "low oil",
    ];

    const bad = <String>[
      "salted",
      "high salt",
      "fried",
      "deep fried",
      "pickles",
      "processed",
    ];

    return _evaluateByKeywords(
      disease: "Hypertension",
      plan: plan,
      goodKeywords: good,
      badKeywords: bad,
      positiveSummaryTemplates: const [
        "Low-sodium / unsalted cooking signals were detected across multiple meals.",
        "Healthier cooking methods were detected (steamed / grilled / baked).",
      ],
      warningSummaryTemplates: const [
        "Some items may be high-sodium or fried — doctor review recommended.",
      ],
    );
  }

  static DiseaseJustificationResult evaluateHeartDisease(MealPlanModel plan) {
    // Heart disease signals: low oil, lean, grilled/baked, omega-3 fish
    const good = <String>[
      "low-oil",
      "low oil",
      "lean",
      "grilled",
      "baked",
      "steamed",
      "tuna",
      "salmon",
      "sardine",
      "mackerel",
      "omega",
      "nuts-free", // sometimes you may add this note later
    ];

    const bad = <String>[
      "fried",
      "deep fried",
      "butter",
      "cream",
      "high fat",
      "fatty",
      "processed",
    ];

    return _evaluateByKeywords(
      disease: "Heart Disease",
      plan: plan,
      goodKeywords: good,
      badKeywords: bad,
      positiveSummaryTemplates: const [
        "Low-oil and healthier cooking methods were detected (grilled/baked/steamed).",
        "Heart-healthy protein patterns were detected (lean proteins / omega-3 fish keywords).",
      ],
      warningSummaryTemplates: const [
        "Some items may increase saturated fat/sodium risk — doctor review recommended.",
      ],
    );
  }

  // -------------------- INTERNAL HELPERS --------------------

  static DiseaseJustificationResult _evaluateByKeywords({
    required String disease,
    required MealPlanModel plan,
    required List<String> goodKeywords,
    required List<String> badKeywords,
    required List<String> positiveSummaryTemplates,
    required List<String> warningSummaryTemplates,
  }) {
    // Collect all meal text lines from the plan: "Day X • Breakfast • Avocado Toast — Notes..."
    final allLines = _extractMealLines(plan);

    int goodHits = 0;
    int badHits = 0;

    final matchedPositiveMeals = <String>[];
    final matchedWarningMeals = <String>[];

    for (final line in allLines) {
      final text = line.toLowerCase();

      final hasGood = _containsAny(text, goodKeywords);
      final hasBad = _containsAny(text, badKeywords);

      if (hasGood) {
        goodHits += 1;
        matchedPositiveMeals.add(line);
      }
      if (hasBad) {
        badHits += 1;
        matchedWarningMeals.add(line);
      }
    }

    // Scoring logic: simple and explainable
    // - Each good hit adds points
    // - Each bad hit reduces points
    // - Clamp within range
    final maxScore = 100;
    int score = 60; // base (neutral)
    score += (goodHits * 4);
    score -= (badHits * 10);

    if (score < 0) score = 0;
    if (score > maxScore) score = maxScore;

    // Positives/warnings: keep short and readable
    final positives = <String>[];
    final warnings = <String>[];

    if (goodHits > 0) {
      positives.addAll(positiveSummaryTemplates);
      positives.add("Detected $goodHits supportive meal signals (keywords matched).");
    } else {
      positives.add("Limited supportive keywords detected — consider doctor review.");
    }

    if (badHits > 0) {
      warnings.addAll(warningSummaryTemplates);
      warnings.add("Detected $badHits potentially risky signals (keywords matched).");
    } else {
      warnings.add("No obvious high-risk keywords detected from food names/notes.");
    }

    // Also include plan warnings if backend provided
    if (plan.warnings.isNotEmpty) {
      warnings.addAll(plan.warnings.map((w) => "System warning: $w"));
    }

    return DiseaseJustificationResult(
      disease: disease,
      score: score,
      maxScore: maxScore,
      positives: positives,
      warnings: warnings,
      matchedPositiveMeals: matchedPositiveMeals.take(8).toList(), // keep UI small
      matchedWarningMeals: matchedWarningMeals.take(8).toList(),
    );
  }

  static bool _containsAny(String text, List<String> keywords) {
    for (final k in keywords) {
      if (text.contains(k.toLowerCase())) return true;
    }
    return false;
  }

  static List<String> _extractMealLines(MealPlanModel plan) {
    final lines = <String>[];

    // Your model has both:
    // 1) plan.days -> MealItem(notes, foodName)
    // 2) plan.meals (compat map) -> only names (no notes)
    //
    // We'll prioritize plan.days if available, because notes are crucial for justification.
    if (plan.days.isNotEmpty) {
      for (final day in plan.days) {
        final d = day.day;

        void addItems(String mealType, List<MealItem> items) {
          for (final item in items) {
            final name = item.foodName.trim();
            final notes = item.notes.trim();
            final portion = item.portion.trim();

            final combined = [
              "Day $d • $mealType • $name",
              if (portion.isNotEmpty) "(Portion: $portion)",
              if (notes.isNotEmpty) "— Notes: $notes",
            ].join(" ");

            lines.add(combined);
          }
        }

        addItems("Breakfast", day.meals.breakfast);
        addItems("Lunch", day.meals.lunch);
        addItems("Dinner", day.meals.dinner);
        addItems("Snacks", day.meals.snacks);
      }

      return lines;
    }

    // Fallback: old format (names only)
    final mealsMap = plan.meals;
    for (final entry in mealsMap.entries) {
      final dayLabel = entry.key; // "Day 1"
      final dayMeals = entry.value as Map<String, dynamic>;

      for (final mealType in ["Breakfast", "Lunch", "Dinner", "Snacks"]) {
        final list = (dayMeals[mealType] as List?) ?? [];
        for (final item in list) {
          lines.add("$dayLabel • $mealType • ${item.toString()}");
        }
      }
    }

    return lines;
  }
}
