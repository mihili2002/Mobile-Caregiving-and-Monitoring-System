import 'dart:convert';
import 'package:flutter/foundation.dart'; // REQUIRED for kIsWeb
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'users';

  // --- SMART URL SELECTION ---
  // --- SMART URL SELECTION ---
  String get baseUrl => getApiUrl(null);

  static String getApiUrl(dynamic context) {
    if (kIsWeb) {
      return "http://127.0.0.1:5000"; // Chrome
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      return "http://10.0.2.2:5000";  // Android Emulator
    } else {
      return "http://192.168.8.115:5000"; // Real Phone / iOS
    }
  }

  // --- PYTHON BACKEND METHODS (Writes/AI) ---
  
  Future<bool> checkProfileExists(String uid) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/ai/check_profile/$uid'));
      if (response.statusCode == 200) {
        return jsonDecode(response.body)['exists'];
      }
      return false;
    } catch (e) {
      print("Backend Connection Error ($baseUrl): $e");
      return false; 
    }
  }

  Future<Map<String, dynamic>?> createElderProfile(Map<String, dynamic> profileData) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/ai/create_profile'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(profileData),
      );
      if (response.statusCode == 201) {
         return jsonDecode(response.body);
      }
      print("Backend returned status ${response.statusCode}. Falling back to Firestore.");
    } catch (e) {
      print("Backend connection failed: $e. Falling back to Firestore.");
    }

    // Fallback: Write directly to Firestore
    try {
      final String uid = profileData['uid'];
      // Ensure we don't overwrite if not intended, but usually profile creation is a SET
       await _firestore.collection('elder_profiles').doc(uid).set(profileData);
       
       return {
         'status': 'success',
         'profile': profileData,
         'message': 'Saved locally (Backend unavailable)'
       };
    } catch (e) {
      print("Error creating profile in Firestore: $e");
      return null;
    }
  }

  // --- FIRESTORE METHODS (Reads) ---

  // NEW: Fetch the detailed onboarding data
  Future<Map<String, dynamic>?> getElderProfile(String uid) async {
    try {
      final doc = await _firestore.collection('elder_profiles').doc(uid).get();
      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      print("Error fetching elder profile: $e");
      return null;
    }
  }

  // Alias needed by DailyRoutinePage
  Future<Map<String, dynamic>?> getUserProfileAsMap(String uid) => getElderProfile(uid);

  Future<void> updateUser(String uid, {String? name, String? email}) async {
    final Map<String, dynamic> updates = {};
    if (name != null) updates['name'] = name;
    if (email != null) updates['email'] = email;
    if (updates.isNotEmpty) {
      await _firestore.collection(_collection).doc(uid).update(updates);
    }
  }

  Future<void> saveUser(AppUser user) async {
    await _firestore.collection(_collection).doc(user.uid).set(user.toMap());
  }

  Future<AppUser?> getUser(String uid) async {
    final doc = await _firestore.collection(_collection).doc(uid).get();
    if (doc.exists) return AppUser.fromMap(doc.data()!, uid);
    return null;
  }

  Future<void> updateUserRole(String uid, UserRole newRole) async {
     // Convert enum to string (e.g., UserRole.admin -> 'admin')
    String roleStr = newRole.toString().split('.').last;
    await _firestore.collection(_collection).doc(uid).update({'role': roleStr});
  }

  Future<List<AppUser>> getAllUsers() async {
    final snapshot = await _firestore.collection(_collection).get();
    return snapshot.docs.map((doc) => AppUser.fromMap(doc.data(), doc.id)).toList();
  }

  Future<List<AppUser>> getUsersByRole(UserRole role) async {
    String roleStr = role.toString().split('.').last;
    final snapshot = await _firestore.collection(_collection).where('role', isEqualTo: roleStr).get();
    return snapshot.docs.map((doc) => AppUser.fromMap(doc.data(), doc.id)).toList();
  }
}