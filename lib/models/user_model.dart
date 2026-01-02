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
  final String email;
  final UserRole role;
  final String? name;

  AppUser({
    required this.uid,
    required this.email,
    required this.role,
    this.name,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'role': role.toString().split('.').last,
      'name': name,
    };
  }

  factory AppUser.fromMap(Map<String, dynamic> data, String uid) {
    return AppUser(
      uid: uid,
      email: data['email'] ?? '',
      role: _parseRole(data['role']),
      name: data['name'],
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
        return UserRole.elder; // Default fallback
    }
  }
}
