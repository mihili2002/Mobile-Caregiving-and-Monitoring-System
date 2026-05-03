import 'package:cloud_firestore/cloud_firestore.dart';

class MealPlanModel {
  final String id;

  /// Support both API snake_case + Firestore camelCase
  final String elderId;
  final String planId; // Added back for old UI
  final String status;

  final DateTime startDate;
  final DateTime endDate;

  final List<String> warnings;
  final Map<String, dynamic> nutrientTargets;

  /// API structure
  final List<MealPlanDay> days;

  MealPlanModel({
    required this.id,
    required this.elderId,
    required this.planId,
    required this.status,
    required this.startDate,
    required this.endDate,
    required this.warnings,
    required this.nutrientTargets,
    required this.days,
  });

  // API JSON Factory
  factory MealPlanModel.fromJson(Map<String, dynamic> json) {
    return MealPlanModel(
      id: (json["id"] ?? "").toString(),
      elderId: (json["elder_id"] ?? json["elderId"] ?? "").toString(),
      planId: (json["plan_id"] ?? json["planId"] ?? json["id"] ?? "").toString(), //fallback
      status: (json["status"] ?? "").toString(),
      startDate: _parseDate(json["start_date"] ?? json["startDate"]),
      endDate: _parseDate(json["end_date"] ?? json["endDate"]),
      warnings: List<String>.from(json["warnings"] ?? []),
      nutrientTargets: Map<String, dynamic>.from(json["nutrient_targets"] ?? {}),
      days: (json["days"] as List? ?? [])
          .map((d) => MealPlanDay.fromJson(Map<String, dynamic>.from(d)))
          .toList(),
    );
  }

  ///Firestore Document Factory (BACKWARD SUPPORT)
  factory MealPlanModel.fromDoc(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>? ?? {});

    return MealPlanModel(
      id: doc.id,
      elderId: data["elderId"] ?? data["elder_id"] ?? "",
      planId: data["planId"] ?? data["plan_id"] ?? doc.id,
      status: data["status"] ?? "pending",
      startDate: _parseTimestamp(data["startDate"] ?? data["start_date"]),
      endDate: _parseTimestamp(data["endDate"] ?? data["end_date"]),
      warnings: List<String>.from(data["warnings"] ?? []),
      nutrientTargets:
          Map<String, dynamic>.from(data["nutrientTargets"] ?? data["nutrient_targets"] ?? {}),
      days: [], //Firestore old structure does not contain days
    );
  }

  ///Compatibility: Old UI expects plan.meals
  /// Convert API days -> old meals map format
  Map<String, dynamic> get meals {
    final Map<String, dynamic> map = {};

    if (days.isEmpty) return map;

    for (final day in days) {
      map["Day ${day.day}"] = {
        "Breakfast": day.meals.breakfast.map((e) => e.foodName).toList(),
        "Lunch": day.meals.lunch.map((e) => e.foodName).toList(),
        "Dinner": day.meals.dinner.map((e) => e.foodName).toList(),
        "Snacks": day.meals.snacks.map((e) => e.foodName).toList(),
      };
    }

    return map;
  }

  //Helper for API string dates
  static DateTime _parseDate(dynamic value) {
    if (value == null) return DateTime.now();

    if (value is DateTime) return value;

    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.now();
    }

    return DateTime.now();
  }

  //Helper for Firestore timestamps
  static DateTime _parseTimestamp(dynamic value) {
    if (value == null) return DateTime.now();

    if (value is Timestamp) return value.toDate();

    if (value is DateTime) return value;

    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.now();
    }

    return DateTime.now();
  }

  /// Serialize to JSON for API calls
  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "elder_id": elderId,
      "plan_id": planId,
      "status": status,
      "start_date": startDate.toIso8601String(),
      "end_date": endDate.toIso8601String(),
      "warnings": warnings,
      "nutrient_targets": nutrientTargets,
      "days": days.map((d) => d.toJson()).toList(),
    };
  }
}

//Day Model
class MealPlanDay {
  final int day;
  final MealDayMeals meals;

  MealPlanDay({
    required this.day,
    required this.meals,
  });

  factory MealPlanDay.fromJson(Map<String, dynamic> json) {
    return MealPlanDay(
      day: json["day"] ?? 0,
      meals: MealDayMeals.fromJson(Map<String, dynamic>.from(json["meals"] ?? {})),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "day": day,
      "meals": meals.toJson(),
    };
  }
}

//Meals inside each day
class MealDayMeals {
  final List<MealItem> breakfast;
  final List<MealItem> lunch;
  final List<MealItem> dinner;
  final List<MealItem> snacks;

  MealDayMeals({
    required this.breakfast,
    required this.lunch,
    required this.dinner,
    required this.snacks,
  });

  factory MealDayMeals.fromJson(Map<String, dynamic> json) {
    return MealDayMeals(
      breakfast: (json["breakfast"] as List? ?? [])
          .map((e) => MealItem.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      lunch: (json["lunch"] as List? ?? [])
          .map((e) => MealItem.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      dinner: (json["dinner"] as List? ?? [])
          .map((e) => MealItem.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      snacks: (json["snacks"] as List? ?? [])
          .map((e) => MealItem.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "breakfast": breakfast.map((m) => m.toJson()).toList(),
      "lunch": lunch.map((m) => m.toJson()).toList(),
      "dinner": dinner.map((m) => m.toJson()).toList(),
      "snacks": snacks.map((m) => m.toJson()).toList(),
    };
  }
}

//Single Meal Item
class MealItem {
  final String portion;
  final String foodName;
  final String notes;

  MealItem({
    required this.portion,
    required this.foodName,
    required this.notes,
  });

  factory MealItem.fromJson(Map<String, dynamic> json) {
    return MealItem(
      portion: (json["portion"] ?? "").toString(),
      foodName: (json["food_name"] ?? json["foodName"] ?? "").toString(),
      notes: (json["notes"] ?? "").toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "portion": portion,
      "food_name": foodName,
      "notes": notes,
    };
  }
}
