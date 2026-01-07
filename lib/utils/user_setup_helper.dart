import '../models/user_model.dart';
import '../auth/auth_service.dart';
import '../services/user_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Helper class to ensure user documents exist in Firestore
class UserSetupHelper {
  /// Creates a user document in Firestore if it doesn't exist
  /// This is useful for users created directly in Firebase Console
  static Future<bool> ensureUserDocumentExists({
    required String uid,
    required String email,
    String? name,
    UserRole defaultRole = UserRole.elder,
  }) async {
    try {
      final userService = UserService();
      final existingUser = await userService.getUser(uid);
      
      if (existingUser != null) {
        return true; // User document already exists
      }

      // Create user document with default role
      final newUser = AppUser(
        uid: uid,
        email: email,
        name: name,
        elderId: uid,
        role: defaultRole,
      );

      await userService.saveUser(newUser);
      return true;
    } catch (e) {
      print('Error creating user document: $e');
      return false;
    }
  }

  /// Creates user document for current authenticated user if missing
  static Future<bool> ensureCurrentUserDocumentExists({
    UserRole? defaultRole,
  }) async {
    final authService = AuthService();
    final currentUser = authService.currentUser;
    
    if (currentUser == null) {
      return false;
    }

    final userService = UserService();
    final existingUser = await userService.getUser(currentUser.uid);
    
    if (existingUser != null) {
      return true; // User document already exists
    }

    // Create user document
    final role = defaultRole ?? UserRole.elder;
    final newUser = AppUser(
      uid: currentUser.uid,
      email: currentUser.email ?? '',
      name: currentUser.displayName,
      elderId: currentUser.uid,
      role: role,
    );

    try {
      await userService.saveUser(newUser);
      return true;
    } catch (e) {
      print('Error creating user document: $e');
      return false;
    }
  }
}

