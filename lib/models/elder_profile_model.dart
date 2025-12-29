class ElderProfile {
  final String uid;
  final String gender;
  final int age;
  final String mobility;
  final String cognitive;
  final String mentalHealth;
  final String? medicalConditions;
  final bool isOnboardingComplete;

  ElderProfile({
    required this.uid,
    required this.gender,
    required this.age,
    required this.mobility,
    required this.cognitive,
    required this.mentalHealth,
    this.medicalConditions,
    this.isOnboardingComplete = false,
  });

  factory ElderProfile.fromMap(Map<String, dynamic> map, String uid) {
    return ElderProfile(
      uid: uid,
      gender: map['gender'] ?? '',
      age: map['age'] ?? 0,
      mobility: map['mobility'] ?? '',
      cognitive: map['cognitive'] ?? '',
      mentalHealth: map['mental_health'] ?? '',
      medicalConditions: map['medical_conditions'],
      isOnboardingComplete: map['is_onboarding_complete'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'gender': gender,
      'age': age,
      'mobility': mobility,
      'cognitive': cognitive,
      'mental_health': mentalHealth,
      'medical_conditions': medicalConditions,
      'is_onboarding_complete': isOnboardingComplete,
    };
  }
}
