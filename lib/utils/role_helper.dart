import '../models/user_model.dart';

class RoleHelper {
  // Check if user has admin role
  static bool isAdmin(UserRole role) {
    return role == UserRole.admin;
  }

  // Check if user is caregiver
  static bool isCaregiver(UserRole role) {
    return role == UserRole.caregiver;
  }

  // Check if user is elder
  static bool isElder(UserRole role) {
    return role == UserRole.elder;
  }

  // Check if user is family member
  static bool isFamilyMember(UserRole role) {
    return role == UserRole.familyMember;
  }

  // Check if user can manage users (Admin only)
  static bool canManageUsers(UserRole role) {
    return role == UserRole.admin;
  }

  // Check if user can view all elders (Admin, Caregiver, Family Member)
  static bool canViewAllElders(UserRole role) {
    return role == UserRole.admin || 
           role == UserRole.caregiver || 
           role == UserRole.familyMember;
  }

  // Check if user can manage routines (Admin, Caregiver, Family Member)
  static bool canManageRoutines(UserRole role) {
    return role == UserRole.admin || 
           role == UserRole.caregiver || 
           role == UserRole.familyMember;
  }

  // Check if user can view their own data (All roles)
  static bool canViewOwnData(UserRole role) {
    return true; // All roles can view their own data
  }

  // Get role-specific color
  static int getRoleColorValue(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return 0xFFFF0000; // Red
      case UserRole.caregiver:
        return 0xFF2196F3; // Blue
      case UserRole.elder:
        return 0xFF4CAF50; // Green
      case UserRole.familyMember:
        return 0xFFFF9800; // Orange
      case UserRole.therapist:
        // TODO: Handle this case.
        throw UnimplementedError();
    }
  }
}

