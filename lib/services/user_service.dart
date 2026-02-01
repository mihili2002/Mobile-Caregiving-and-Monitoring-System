import 'dart:convert';

import 'package:flutter/foundation.dart'; // kIsWeb, defaultTargetPlatform, debugPrint
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_model.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'users';

  // --- SMART URL SELECTION ---
  String get baseUrl => getApiUrl(null);

  static String getApiUrl(dynamic context) {
    if (kIsWeb) {
      return "http://127.0.0.1:8000"; // Chrome web -> FastAPI
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      return "http://10.0.2.2:8000"; // Android Emulator -> host machine
    } else {
      return "http://192.168.8.115:8000"; // Real phone / iOS (change to your PC IP)
    }
  }

  // ==========================================================
  // PYTHON BACKEND METHODS (Writes/AI)
  // ==========================================================

  Future<bool> checkProfileExists(String uid) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/ai/check_profile/$uid'),
      );

      if (response.statusCode == 200) {
        return (jsonDecode(response.body)['exists'] as bool?) ?? false;
      }
      return false;
    } catch (e) {
      debugPrint("Backend Connection Error ($baseUrl): $e");
      return false;
    }
  }

  Future<Map<String, dynamic>?> createElderProfile(
    Map<String, dynamic> profileData,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/ai/create_profile'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(profileData),
      );

      if (response.statusCode == 201) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }

      debugPrint(
        "createElderProfile failed: ${response.statusCode} ${response.body}",
      );
      return null;
    } catch (e) {
      debugPrint("Error creating profile: $e");
      return null;
    }
  }

  // ==========================================================
  // FIRESTORE METHODS (Reads/Writes)
  // ==========================================================

  /// Elder profile collection (separate from users)
  Future<Map<String, dynamic>?> getElderProfile(String uid) async {
    try {
      final doc = await _firestore.collection('elder_profiles').doc(uid).get();
      if (doc.exists) return doc.data();
      return null;
    } catch (e) {
      debugPrint("Error fetching elder profile: $e");
      return null;
    }
  }

  Future<Map<String, dynamic>?> getUserProfileAsMap(String uid) =>
      getElderProfile(uid);

  Future<void> updateUser(String uid, {String? name, String? email}) async {
    final Map<String, dynamic> updates = {};
    if (name != null) updates['name'] = name;
    if (email != null) updates['email'] = email;

    if (updates.isNotEmpty) {
      await _firestore.collection(_collection).doc(uid).update(updates);
    }
  }

  /// Save user to "users" collection
  /// Uses merge to avoid overwriting unrelated fields that may exist already.
  Future<void> saveUser(AppUser user) async {
    await _firestore
        .collection(_collection)
        .doc(user.uid)
        .set(user.toMap(), SetOptions(merge: true));
  }

  /// Get user from "users" collection
  Future<AppUser?> getUser(String uid) async {
    final doc = await _firestore.collection(_collection).doc(uid).get();
    if (!doc.exists || doc.data() == null) return null;

    // ✅ FIX: your AppUser.fromMap expects (data, uid)
    return AppUser.fromMap(
      doc.data() as Map<String, dynamic>,
      doc.id,
    );
  }

  /// Optional helper if you want it elsewhere
  Future<AppUser?> getCurrentUserProfile(String uid) => getUser(uid);

  /// Update role (keeps same role string format as your model)
  Future<void> updateUserRole(String uid, UserRole newRole) async {
    final roleStr = newRole.toString().split('.').last; // ✅ FIX
    await _firestore.collection(_collection).doc(uid).update({'role': roleStr});
  }

  /// Get all users
  Future<List<AppUser>> getAllUsers() async {
    final snapshot = await _firestore.collection(_collection).get();

    return snapshot.docs.map((doc) {
      return AppUser.fromMap(
        doc.data() as Map<String, dynamic>,
        doc.id,
      );
    }).toList();
  }

  /// Get users by role
  Future<List<AppUser>> getUsersByRole(UserRole role) async {
    final roleStr = role.toString().split('.').last; // ✅ FIX

    final snapshot = await _firestore
        .collection(_collection)
        .where('role', isEqualTo: roleStr)
        .get();

    return snapshot.docs.map((doc) {
      return AppUser.fromMap(
        doc.data() as Map<String, dynamic>,
        doc.id,
      );
    }).toList();
  }
}
