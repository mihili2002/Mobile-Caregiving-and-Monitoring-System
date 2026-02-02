import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole {
  admin,
  elder,
  caregiver,
  doctor,
  therapist,
  familyMember,
}

UserRole userRoleFromString(String? v) {
  switch ((v ?? '').toLowerCase().trim()) {
    case 'admin':
      return UserRole.admin;
    case 'elder':
      return UserRole.elder;
    case 'caregiver':
      return UserRole.caregiver;
    case 'doctor':
      return UserRole.doctor;
    case 'therapist':
      return UserRole.therapist;
    case 'familymember':
    case 'family_member':
    case 'family':
      return UserRole.familyMember;
    default:
      return UserRole.elder;
  }
}

String userRoleToString(UserRole role) {
  switch (role) {
    case UserRole.admin:
      return 'admin';
    case UserRole.elder:
      return 'elder';
    case UserRole.caregiver:
      return 'caregiver';
    case UserRole.doctor:
      return 'doctor';
    case UserRole.therapist:
      return 'therapist';
    case UserRole.familyMember:
      return 'familyMember';
  }
}

class AppUser {
  final String uid;
  final String email;
  final UserRole role;
  final String name;

  AppUser({
    required this.uid,
    required this.email,
    required this.role,
    required this.name,
  });

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'email': email,
        'role': userRoleToString(role),
        'name': name,
        'updatedAt': FieldValue.serverTimestamp(),
      };

  /// ✅ FIX: allow uidOverride so UserService can pass doc.id safely
  factory AppUser.fromMap(Map<String, dynamic> map, {String? uidOverride}) {
    return AppUser(
      uid: uidOverride ?? (map['uid'] ?? '') as String,
      email: (map['email'] ?? '') as String,
      role: userRoleFromString(map['role']?.toString()),
      name: (map['name'] ?? '') as String,
    );
  }

  /// Optional helper
  factory AppUser.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return AppUser.fromMap(data, uidOverride: doc.id);
  }
}
