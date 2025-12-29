class MedicationModel {
  String drugName;
  String dosage;
  String? frequency;
  String timing; // before_meal / after_meal / with_meal / unknown
  List<String>? meals; // breakfast/lunch/dinner
  String? duration;
  String? notes;
  double confidence;

  MedicationModel({
    required this.drugName,
    required this.dosage,
    this.frequency,
    required this.timing,
    this.meals,
    this.duration,
    this.notes,
    required this.confidence,
  });

  factory MedicationModel.fromJson(Map<String, dynamic> json) {
    return MedicationModel(
      drugName: json["drug_name"] ?? "",
      dosage: json["dosage"] ?? "",
      frequency: json["frequency"],
      timing: json["timing"] ?? "unknown",
      meals: (json["meals"] as List?)?.map((e) => e.toString()).toList(),
      duration: json["duration"],
      notes: json["notes"],
      confidence: (json["confidence"] is int)
          ? (json["confidence"] as int).toDouble()
          : (json["confidence"] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
    "drug_name": drugName,
    "dosage": dosage,
    "frequency": frequency,
    "timing": timing,
    "meals": meals,
    "duration": duration,
    "notes": notes,
    "confidence": confidence,
  };
}
