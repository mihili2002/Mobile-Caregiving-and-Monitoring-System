class ElderHealthSubmissionIn {
  final int age;
  final String gender;
  final double heightCm;
  final double weightKg;

  final List<String> chronicConditions;
  final bool geneticRisk;

  final int systolic;
  final int diastolic;

  final double bloodSugarMgDl;
  final double cholesterolMgDl;

  final int dailySteps;
  final int exerciseFrequency; // backend expects int (1,2,3)
  final double sleepHours;

  final bool smoking;
  final bool alcohol;

  final String dietaryHabit;

  final int? caloricIntake;
  final int? proteinIntake;
  final int? carbohydrateIntake;
  final int? fatIntake;

  final String? foodAllergies;
  final String preferredCuisine;
  final String? foodAversions;

  final Map<String, dynamic>? extra;

  ElderHealthSubmissionIn({
    required this.age,
    required this.gender,
    required this.heightCm,
    required this.weightKg,
    required this.chronicConditions,
    required this.geneticRisk,
    required this.systolic,
    required this.diastolic,
    required this.bloodSugarMgDl,
    required this.cholesterolMgDl,
    required this.dailySteps,
    required this.exerciseFrequency,
    required this.sleepHours,
    required this.smoking,
    required this.alcohol,
    required this.dietaryHabit,
    this.caloricIntake,
    this.proteinIntake,
    this.carbohydrateIntake,
    this.fatIntake,
    this.foodAllergies,
    required this.preferredCuisine,
    this.foodAversions,
    this.extra,
  });

  Map<String, dynamic> toJson() {
    return {
      "age": age,
      "gender": gender,
      "height_cm": heightCm,
      "weight_kg": weightKg,
      "chronic_conditions": chronicConditions,
      "genetic_risk": geneticRisk,
      "blood_pressure": {
        "systolic": systolic,
        "diastolic": diastolic,
      },
      "blood_sugar_mg_dl": bloodSugarMgDl,
      "cholesterol_mg_dl": cholesterolMgDl,
      "daily_steps": dailySteps,
      "exercise_frequency": exerciseFrequency,
      "sleep_hours": sleepHours,
      "smoking": smoking,
      "alcohol": alcohol,
      "dietary_habit": dietaryHabit,
      "caloric_intake": caloricIntake,
      "protein_intake": proteinIntake,
      "carbohydrate_intake": carbohydrateIntake,
      "fat_intake": fatIntake,
      "food_allergies": foodAllergies,
      "preferred_cuisine": preferredCuisine,
      "food_aversions": foodAversions,
      "extra": extra,
    };
  }
}
