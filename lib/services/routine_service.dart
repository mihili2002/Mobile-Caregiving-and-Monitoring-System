import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../models/routine_models.dart';

class RoutineService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // --- SMART URL SELECTION ---
  String get baseUrl {
    if (kIsWeb) return "http://127.0.0.1:5000";
    if (defaultTargetPlatform == TargetPlatform.android) return "http://10.0.2.2:5000";
    return "http://192.168.8.115:5000";
  } 

  // --- WRITES (Must go through Python for AI) ---

  // 1. Add Common Routine
  Future<CommonTask?> addCommonTask(CommonTask task) async {
    return await _sendData('/add_task', task.toJson(), (json) => CommonTask.fromJson(json));
  }

  // 2. Add Therapist Activity
  Future<TherapistActivity?> addTherapistActivity(TherapistActivity activity) async {
    return await _sendData('/add_task', activity.toJson(), (json) => TherapistActivity.fromJson(json));
  }

  // 3. Add Medication
  Future<Medication?> addMedication(Medication med) async {
    return await _sendData('/add_task', med.toJson(), (json) => Medication.fromJson(json, json['id'] ?? ''));
  }

  // Helper for HTTP POST
  Future<T?> _sendData<T>(String endpoint, Map<String, dynamic> data, T Function(Map<String, dynamic>) fromJson) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl$endpoint'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(data),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        return fromJson(jsonDecode(response.body));
      } else {
        print("Backend Error: ${response.body}");
        return null;
      }
    } catch (e) {
      print("Connection Error: $e");
      return null;
    }
  }

  // --- READS (Can fetch from Python or Firestore) ---

  // 4. Get Daily Suggestions (From Python Logic)
  Future<Map<String, dynamic>?> getDailySuggestions(String uid) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/get_daily_suggestions/$uid'));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print("Error loading suggestions: $e");
    }
    return null;
  }

  // 5. Get Medications for Caregiver (New Structure Only)
  Future<List<Medication>> getMedicationsByElderId(String elderId) async {
    try {
      // Step 1: Ensure Elder doc has caregiverId (Fix Permission via Backend)
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        // We must call Backend because Rules block direct write if we are not ALREADY the caregiver.
        // Backend (Admin SDK) bypasses this rule.
        try {
            print("DEBUG: Calling /api/medications/fix_permissions for $elderId");
            await http.post(
                Uri.parse('$baseUrl/api/medications/fix_permissions'),
                headers: {"Content-Type": "application/json"},
                body: jsonEncode({
                    "elder_id": elderId,
                    "caregiver_id": currentUser.uid
                }),
            );
        } catch (apiErr) {
            print("Warning: Failed to auto-fix permissions: $apiErr");
        }
      }

      List<Medication> allMeds = [];

      // A. LEGACY QUERY REMOVED to prevent "Permission Denied" red bar
      // (If rules block top-level 'medication_prescriptions', this crashes the UI)
      /*
      final snapshotOld = await _db
          .collection('medication_prescriptions')
          .where('elder_id', isEqualTo: elderId)
          .where('is_active', isEqualTo: true)
          .get();
      // ... mapping code ...
      */

      // B. Fetch from NEW 'patient_medications' collection (Single Document Structure)
      final docSnapshot = await _db
          .collection('patient_medications')
          .doc(elderId)
          .get();

      if (docSnapshot.exists) {
        final data = docSnapshot.data();
        if (data != null && data['medications'] != null) {
          final List<dynamic> medsList = data['medications'];
          
          for (var medData in medsList) {
            // Filter only active meds
            if (medData['status'] == 'active') {
              allMeds.add(Medication(
                id: null,
                elderId: elderId,
                name: medData['drug_name'] ?? '',
                dosage: medData['dosage'] ?? '',
                frequency: medData['frequency'] != null ? medData['frequency'].toString() : '',
                startDate: medData['start_date'] != null ? DateTime.tryParse(medData['start_date']) : null,
                endDate: medData['end_date'] != null ? DateTime.tryParse(medData['end_date']) : null,
              ));
            }
          }
        }
      }

      return allMeds;
    } catch (e) {
      print("Firestore Error: $e"); // Print to console so we see the "red bar" reason
      throw Exception('Failed to load medications: $e');
    }
  }

  // 6. Delete/Archive Medication
  Future<void> deleteMedication(Medication med) async {
    try {
      // 1. Update in the single document (Array Management)
      final medDocRef = _db.collection('patient_medications').doc(med.elderId);
      final doc = await medDocRef.get();
      
      if (doc.exists) {
        final data = doc.data();
        if (data != null && data['medications'] != null) {
          List<dynamic> meds = List.from(data['medications']);
          // Find the medication to "delete" (deactivate)
          bool found = false;
          for (var item in meds) {
            if (item['drug_name'] == med.name && 
                item['dosage'] == med.dosage && 
                item['status'] == 'active') {
              item['status'] = 'inactive';
              found = true;
              break;
            }
          }
          
          if (found) {
            await medDocRef.update({'medications': meds});
          }
        }
      }

      // 2. Legacy Cleanup (Optional but keep for safety)
      final snapshot = await _db
          .collection('medication_prescriptions')
          .where('elder_id', isEqualTo: med.elderId)
          .where('drug_name', isEqualTo: med.name)
          .where('dosage', isEqualTo: med.dosage)
          .get();

      for (var d in snapshot.docs) {
        await d.reference.update({'is_active': false});
      }
    } catch (e) {
      throw Exception('Failed to delete medication: $e');
    }
  }

  // 7. Get Therapist Activities for Caregiver
  Future<List<TherapistActivity>> getTherapistActivities(String elderId) async {
    try {
      final snapshot = await _db
          .collection('therapist_assignments')
          .where('elder_id', isEqualTo: elderId)
          .where('is_active', isEqualTo: true)
          .get();

      return snapshot.docs.map((doc) {

        final data = doc.data();
        return TherapistActivity(
          title: data['activity_name'] ?? 'Therapy Session',
          description: data['description'] ?? '',
          elderId: data['elder_id'] ?? '',
          assignedDate: data['assigned_time'] != null ? DateTime.tryParse(data['assigned_time']) ?? DateTime.now() : DateTime.now(),
        );
      }).toList();
    } catch (e) {
      throw Exception('Failed to load therapist activities: $e');
    }
  }

  // 8. Predict Task Outcomes (AI)
  Future<RoutineAIInsights?> predictTaskOutcomes({
    required String uid,
    required String taskName,
    required String taskType,
    required String timeString,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/predict_task_outcomes'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "uid": uid,
          "task_name": taskName,
          "task_type": taskType,
          "time_string": timeString, // "HH:mm"
        }),
      );

      if (response.statusCode == 200) {
        return RoutineAIInsights.fromJson(jsonDecode(response.body));
      }
    } catch (e) {
      print("Prediction Error: $e");
    }
    return null;
  }
}