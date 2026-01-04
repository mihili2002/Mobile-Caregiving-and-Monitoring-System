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
  final String elderId; // ✅ NEW FIELD
  final String email;
  final UserRole role;
  final String? name;

  AppUser({
    required this.uid,
    required this.elderId, // ✅ REQUIRED
    required this.email,
    required this.role,
    this.name,
  });

  /// Convert to Firestore map
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'elderId': elderId, // ✅ stored
      'email': email,
      'role': role.toString().split('.').last,
      'name': name,
    };
  }

  /// Create from Firestore map
  factory AppUser.fromMap(Map<String, dynamic> data, String uid) {
    return AppUser(
      uid: uid,
      elderId: data['elderId'] ?? uid, // ✅ fallback for old users
      email: data['email'] ?? '',
      role: _parseRole(data['role']),
      name: data['name'],
    );
  }

  /// Parse role safely
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
        return UserRole.elder; // Default fallback
    }
  }
}
