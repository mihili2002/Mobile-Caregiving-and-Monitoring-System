import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/elder_profile_model.dart';

class ElderProfileService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Save or update elder profile
  Future<void> saveElderProfile(ElderProfile profile) async {
    try {
      await _db.collection('elder_profiles').doc(profile.uid).set(
            profile.toMap(),
            SetOptions(merge: true),
          );
    } catch (e) {
      throw Exception('Failed to save elder profile: $e');
    }
  }

  /// Get elder profile by UID
  Future<ElderProfile?> getElderProfile(String uid) async {
    try {
      final doc = await _db.collection('elder_profiles').doc(uid).get();
      if (doc.exists) {
        return ElderProfile.fromMap(doc.data() as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to fetch elder profile: $e');
    }
  }

  /// Check if elder has completed onboarding
  Future<bool> isOnboardingComplete(String uid) async {
    try {
      final profile = await getElderProfile(uid);
      return profile?.isOnboardingComplete ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Mark onboarding as complete
  Future<void> completeOnboarding(String uid) async {
    try {
      await _db.collection('elder_profiles').doc(uid).update({
        'is_onboarding_complete': true,
        'updated_at': Timestamp.now(),
      });
    } catch (e) {
      throw Exception('Failed to complete onboarding: $e');
    }
  }
}
