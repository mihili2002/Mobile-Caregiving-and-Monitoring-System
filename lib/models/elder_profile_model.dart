import 'package:cloud_firestore/cloud_firestore.dart';

enum Gender { male, female, other }

enum MobilityLevel { excellent, good, moderate, limited, severe }

enum CognitiveLevel { excellent, good, moderate, mild, severe }

class ElderProfile {
  final String uid;
  final String fullName;              // 👈 NEW
  final Gender gender;
  /// e.g., "65-70", "70-75", "75-80", ">80"
  final String ageGroup;
  final MobilityLevel mobilityLevel;
  final CognitiveLevel cognitiveLevel;
  /// e.g., ["depression", "anxiety"] or ["none"]
  final List<String> mentalHealthIssues;
  /// brief description, e.g. "Stable", "Moderate issues"
  final String mentalHealthStatus;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isOnboardingComplete;

  ElderProfile({
    required this.uid,
    required this.fullName,           // 👈 NEW
    required this.gender,
    required this.ageGroup,
    required this.mobilityLevel,
    required this.cognitiveLevel,
    required this.mentalHealthIssues,
    required this.mentalHealthStatus,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.isOnboardingComplete = false,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'full_name': fullName,          // 👈 NEW
      'gender': gender.name,
      'age_group': ageGroup,
      'mobility_level': mobilityLevel.name,
      'cognitive_level': cognitiveLevel.name,
      'mental_health_issues': mentalHealthIssues,
      'mental_health_status': mentalHealthStatus,
      'created_at': Timestamp.fromDate(createdAt),
      'updated_at': Timestamp.fromDate(updatedAt),
      'is_onboarding_complete': isOnboardingComplete,
    };
  }

  factory ElderProfile.fromMap(Map<String, dynamic> map) {
    final dynamic genderRaw = map['gender'];
    final dynamic mobilityRaw = map['mobility_level'];
    final dynamic cognitiveRaw = map['cognitive_level'];

    return ElderProfile(
      uid: (map['uid'] ?? '') as String,
      fullName: (map['full_name'] ?? '') as String,  // 👈 NEW
      gender: _parseGender(genderRaw?.toString()),
      ageGroup: (map['age_group'] ?? '') as String,
      mobilityLevel: _parseMobilityLevel(mobilityRaw?.toString()),
      cognitiveLevel: _parseCognitiveLevel(cognitiveRaw?.toString()),
      mentalHealthIssues: _parseStringList(map['mental_health_issues']),
      mentalHealthStatus: (map['mental_health_status'] ?? '') as String,
      createdAt: map['created_at'] is Timestamp
          ? (map['created_at'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: map['updated_at'] is Timestamp
          ? (map['updated_at'] as Timestamp).toDate()
          : DateTime.now(),
      isOnboardingComplete:
          (map['is_onboarding_complete'] as bool?) ?? false,
    );
  }

  static Gender _parseGender(String? value) {
    switch (value) {
      case 'male':
        return Gender.male;
      case 'female':
        return Gender.female;
      case 'other':
        return Gender.other;
      default:
        return Gender.other;
    }
  }

  static MobilityLevel _parseMobilityLevel(String? value) {
    switch (value) {
      case 'excellent':
        return MobilityLevel.excellent;
      case 'good':
        return MobilityLevel.good;
      case 'moderate':
        return MobilityLevel.moderate;
      case 'limited':
        return MobilityLevel.limited;
      case 'severe':
        return MobilityLevel.severe;
      default:
        return MobilityLevel.moderate;
    }
  }

  static CognitiveLevel _parseCognitiveLevel(String? value) {
    switch (value) {
      case 'excellent':
        return CognitiveLevel.excellent;
      case 'good':
        return CognitiveLevel.good;
      case 'moderate':
        return CognitiveLevel.moderate;
      case 'mild':
        return CognitiveLevel.mild;
      case 'severe':
        return CognitiveLevel.severe;
      default:
        return CognitiveLevel.moderate;
    }
  }

  static List<String> _parseStringList(dynamic value) {
    if (value == null) return <String>[];
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    return <String>[];
  }

  ElderProfile copyWith({
    String? uid,
    String? fullName,                 // 👈 NEW
    Gender? gender,
    String? ageGroup,
    MobilityLevel? mobilityLevel,
    CognitiveLevel? cognitiveLevel,
    List<String>? mentalHealthIssues,
    String? mentalHealthStatus,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isOnboardingComplete,
  }) {
    return ElderProfile(
      uid: uid ?? this.uid,
      fullName: fullName ?? this.fullName,  // 👈 NEW
      gender: gender ?? this.gender,
      ageGroup: ageGroup ?? this.ageGroup,
      mobilityLevel: mobilityLevel ?? this.mobilityLevel,
      cognitiveLevel: cognitiveLevel ?? this.cognitiveLevel,
      mentalHealthIssues: mentalHealthIssues ?? this.mentalHealthIssues,
      mentalHealthStatus: mentalHealthStatus ?? this.mentalHealthStatus,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      isOnboardingComplete:
          isOnboardingComplete ?? this.isOnboardingComplete,
    );
  }
}
