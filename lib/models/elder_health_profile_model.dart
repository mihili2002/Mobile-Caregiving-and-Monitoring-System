import 'package:cloud_firestore/cloud_firestore.dart';

class ElderHealthProfileModel {
  final String uid;
  final int? age;
  final String? gender;
  final double? height;
  final double? weight;
  final List<String> chronicConditions;

  final Map<String, dynamic>? bloodPressure;
  final double? bloodSugar;
  final double? cholesterol;

  final bool geneticRisk;
  final int? dailySteps;
  final String? exerciseFrequency;
  final double? sleepHours;

  final bool smoking;
  final bool alcohol;

  final String? dietaryHabit;
  final String? preferredCuisine;

  final String? foodAllergies;
  final String? foodAversions;

  final DateTime? createdAt;

  ElderHealthProfileModel({
    required this.uid,
    this.age,
    this.gender,
    this.height,
    this.weight,
    required this.chronicConditions,
    this.bloodPressure,
    this.bloodSugar,
    this.cholesterol,
    required this.geneticRisk,
    this.dailySteps,
    this.exerciseFrequency,
    this.sleepHours,
    required this.smoking,
    required this.alcohol,
    this.dietaryHabit,
    this.preferredCuisine,
    this.foodAllergies,
    this.foodAversions,
    this.createdAt,
  });

  factory ElderHealthProfileModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return ElderHealthProfileModel(
      uid: data['uid'] ?? doc.id,
      age: data['age'],
      gender: data['gender'],
      height: (data['height'] is num) ? (data['height'] as num).toDouble() : null,
      weight: (data['weight'] is num) ? (data['weight'] as num).toDouble() : null,
      chronicConditions: List<String>.from(data['chronicConditions'] ?? []),
      bloodPressure: (data['bloodPressure'] is Map) ? Map<String, dynamic>.from(data['bloodPressure']) : null,
      bloodSugar: (data['bloodSugar'] is num) ? (data['bloodSugar'] as num).toDouble() : null,
      cholesterol: (data['cholesterol'] is num) ? (data['cholesterol'] as num).toDouble() : null,
      geneticRisk: data['geneticRisk'] ?? false,
      dailySteps: data['dailySteps'],
      exerciseFrequency: data['exerciseFrequency'],
      sleepHours: (data['sleepHours'] is num) ? (data['sleepHours'] as num).toDouble() : null,
      smoking: data['smoking'] ?? false,
      alcohol: data['alcohol'] ?? false,
      dietaryHabit: data['dietaryHabit'],
      preferredCuisine: data['preferredCuisine'],
      foodAllergies: data['foodAllergies'],
      foodAversions: data['foodAversions'],
      createdAt: (data['createdAt'] is Timestamp) ? (data['createdAt'] as Timestamp).toDate() : null,
    );
  }

  /// Construct from JSON returned by the REST API
  factory ElderHealthProfileModel.fromJson(Map<String, dynamic> json) {
    return ElderHealthProfileModel(
      uid: json['uid'] ?? json['id'] ?? '',
      age: json['age'],
      gender: json['gender'],
      height: (json['height'] is num) ? (json['height'] as num).toDouble() : null,
      weight: (json['weight'] is num) ? (json['weight'] as num).toDouble() : null,
      chronicConditions: List<String>.from(json['chronicConditions'] ?? []),
      bloodPressure: (json['bloodPressure'] is Map) ? Map<String, dynamic>.from(json['bloodPressure']) : null,
      bloodSugar: (json['bloodSugar'] is num) ? (json['bloodSugar'] as num).toDouble() : null,
      cholesterol: (json['cholesterol'] is num) ? (json['cholesterol'] as num).toDouble() : null,
      geneticRisk: json['geneticRisk'] ?? false,
      dailySteps: json['dailySteps'],
      exerciseFrequency: json['exerciseFrequency'],
      sleepHours: (json['sleepHours'] is num) ? (json['sleepHours'] as num).toDouble() : null,
      smoking: json['smoking'] ?? false,
      alcohol: json['alcohol'] ?? false,
      dietaryHabit: json['dietaryHabit'],
      preferredCuisine: json['preferredCuisine'],
      foodAllergies: json['foodAllergies'],
      foodAversions: json['foodAversions'],
      createdAt: json['createdAt'] is String
          ? DateTime.tryParse(json['createdAt'])
          : (json['createdAt'] is int ? DateTime.fromMillisecondsSinceEpoch(json['createdAt']) : null),
    );
  }

  double? get bmi {
    if (height == null || weight == null) return null;
    final hMeters = (height! / 100.0);
    if (hMeters <= 0) return null;
    return weight! / (hMeters * hMeters);
  }
}
