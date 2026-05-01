import 'dart:convert';

import 'package:flutter/foundation.dart'; // kIsWeb, defaultTargetPlatform, debugPrint
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/user_model.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'users';

  // ==========================================================
  // SMART API URL SELECTION
  // ==========================================================

  String get baseUrl => getApiUrl(null);

  static String getApiUrl(dynamic context) {
    if (kIsWeb) {
      return "http://127.0.0.1:8000";
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      return "http://10.0.2.2:8000";
    } else {
      return "http://192.168.8.115:8000"; // change to your PC IP for real phone
    }
  }

  // ==========================================================
  // AUTH TOKEN (FIX FOR 401 ERROR)
  // ==========================================================

  Future<String?> getAuthToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    return await user.getIdToken();
  }

  Future<Map<String, String>> getAuthHeaders() async {
    final token = await getAuthToken();

    return {
      "Content-Type": "application/json",
      if (token != null) "Authorization": "Bearer $token",
    };
  }

  // ==========================================================
  // PYTHON BACKEND METHODS (AI + SERVER)
  // ==========================================================

  Future<bool> checkProfileExists(String uid) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/ai/check_profile/$uid'),
        headers: await getAuthHeaders(),
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
        headers: await getAuthHeaders(),
        body: jsonEncode(profileData),
      );

      if (response.statusCode == 201) {
        return jsonDecode(response.body);
      }

      debugPrint(
        "createElderProfile failed: ${response.statusCode} ${response.body}",
      );
      return null;
    } catch (e) {
      debugPrint("Error in createElderProfile: $e");
      return null;
    }
  }

  Future<bool> updateFCMToken(String uid, String token) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/ai/update_fcm_token'),
        headers: await getAuthHeaders(),
        body: jsonEncode({
          "uid": uid,
          "fcm_token": token,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      debugPrint("Error updating FCM token: $e");
      return false;
    }
  }

  // ==========================================================
  // FIRESTORE METHODS
  // ==========================================================

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

  Future<void> saveUser(AppUser user) async {
    await _firestore
        .collection(_collection)
        .doc(user.uid)
        .set(user.toMap(), SetOptions(merge: true));
  }

  Future<AppUser?> getUser(String uid) async {
    final doc = await _firestore.collection(_collection).doc(uid).get();

    if (!doc.exists || doc.data() == null) return null;

    return AppUser.fromMap(
      doc.data() as Map<String, dynamic>,
      doc.id,
    );
  }

  Future<AppUser?> getCurrentUserProfile(String uid) => getUser(uid);

  Future<void> updateUserRole(String uid, UserRole newRole) async {
    final roleStr = newRole.toString().split('.').last;

    await _firestore.collection(_collection).doc(uid).update({
      'role': roleStr,
    });
  }

  Future<List<AppUser>> getAllUsers() async {
    final snapshot = await _firestore.collection(_collection).get();

    return snapshot.docs.map((doc) {
      return AppUser.fromMap(
        doc.data() as Map<String, dynamic>,
        doc.id,
      );
    }).toList();
  }

  Future<List<AppUser>> getUsersByRole(UserRole role) async {
    final roleStr = role.toString().split('.').last;

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

  Future<void> deleteUser(String uid) async {
    try {
      await _firestore.collection(_collection).doc(uid).delete();

      debugPrint("Deleted user $uid from '$_collection'");

      final elderDoc =
          await _firestore.collection('elder_profiles').doc(uid).get();

      if (elderDoc.exists) {
        await _firestore.collection('elder_profiles').doc(uid).delete();
        debugPrint("Deleted elder profile $uid from 'elder_profiles'");
      }
    } catch (e) {
      debugPrint("Error deleting user $uid: $e");
      rethrow;
    }
  }
}