enum UserRole {
  elder,
  caregiver,
  doctor,
  admin,
  therapist,
  familyMember,
}

class AppUser {
  final String uid;
  final String elderId;
  final String email;
  final UserRole role;
  final String? name;

  // ✅ ALL REQUIRED FIELDS
  final int? age;
  final String? gender;
  final String? education; // 🔥 ADD THIS

  AppUser({
    required this.uid,
    required this.elderId,
    required this.email,
    required this.role,
    this.name,
    this.age,
    this.gender,
    this.education, // 🔥 ADD THIS
  });

  String get id => uid;

  /// Convert to Firestore
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'elderId': elderId,
      'email': email,
      'role': role.toString().split('.').last,
      'name': name,
      'age': age,
      'gender': gender,
      'education': education, // 🔥 ADD THIS
    };
  }

  /// From Firestore
  factory AppUser.fromMap(Map<String, dynamic> data, String uid) {
    return AppUser(
      uid: uid,
      elderId: data['elderId'] ?? uid,
      email: data['email'] ?? '',
      role: _parseRole(data['role']),
      name: data['name'],
      age: data['age'] != null ? int.tryParse(data['age'].toString()) : null,
      gender: data['gender'],
      education: data['education'], // 🔥 ADD THIS
    );
  }

  static UserRole _parseRole(String? role) {
    switch (role?.toLowerCase()) {
      case 'elder':
        return UserRole.elder;
      case 'caregiver':
        return UserRole.caregiver;
      case 'doctor':
        return UserRole.doctor;
      case 'therapist':
        return UserRole.therapist;
      case 'admin':
        return UserRole.admin;
      case 'family_member':
      case 'familymember':
        return UserRole.familyMember;
      default:
        return UserRole.elder;
    }
  }
}