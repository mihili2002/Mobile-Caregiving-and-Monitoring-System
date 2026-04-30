import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ScheduleService {
  String get baseUrl {
    if (kIsWeb) return "http://127.0.0.1:8000";
    if (defaultTargetPlatform == TargetPlatform.android) return "http://10.0.2.2:8000";
    return "http://192.168.8.115:8000";
  }

  Map<String, String> get _jsonHeaders => {"Content-Type": "application/json"};

  // ----------------------------
  // Schedule CRUD
  // ----------------------------

  Future<Map<String, dynamic>?> getSchedule(String uid, DateTime date) async {
    final dateStr = date.toIso8601String().split('T')[0];
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/schedule/get_schedule'),
        headers: _jsonHeaders,
        body: jsonEncode({
          "uid": uid,
          "date": dateStr,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        debugPrint("ScheduleService.getSchedule failed: ${response.body}");
        return null;
      }
    } catch (e) {
      debugPrint("ScheduleService.getSchedule error: $e");
      return null;
    }
  }

  Future<bool> addTask(String uid, DateTime date, Map<String, dynamic> task) async {
    final dateStr = date.toIso8601String().split('T')[0];
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/schedule/add_task'),
        headers: _jsonHeaders,
        body: jsonEncode({
          "uid": uid,
          "date": dateStr,
          "task": task,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      debugPrint("ScheduleService.addTask error: $e");
      return false;
    }
  }

  Future<bool> updateTaskStatus(String uid, DateTime date, String taskId, bool completed) async {
    final dateStr = date.toIso8601String().split('T')[0];
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/schedule/update_task_status'),
        headers: _jsonHeaders,
        body: jsonEncode({
          "uid": uid,
          "date": dateStr,
          "task_id": taskId,
          "completed": completed,
          "status": completed ? "completed_confirmed" : "scheduled",
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      debugPrint("ScheduleService.updateTaskStatus error: $e");
      return false;
    }
  }

  Future<bool> deleteTask(String uid, DateTime date, String taskId) async {
    final dateStr = date.toIso8601String().split('T')[0];
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/schedule/delete_task'),
        headers: _jsonHeaders,
        body: jsonEncode({
          "uid": uid,
          "date": dateStr,
          "task_id": taskId,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      debugPrint("ScheduleService.deleteTask error: $e");
      return false;
    }
  }

  Future<bool> updateTask(String uid, DateTime date, String taskId, Map<String, dynamic> updates) async {
    final dateStr = date.toIso8601String().split('T')[0];
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/schedule/update_task'),
        headers: _jsonHeaders,
        body: jsonEncode({
          "uid": uid,
          "date": dateStr,
          "task_id": taskId,
          "updates": updates,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      debugPrint("ScheduleService.updateTask error: $e");
      return false;
    }
  }

  // ----------------------------
  // AI task action endpoints
  // ----------------------------

  Future<bool> completeTask({
    required String uid,
    required String date,
    required String taskId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/ai/tasks/complete'),
        headers: _jsonHeaders,
        body: jsonEncode({
          "uid": uid,
          "date": date,
          "task_id": taskId,
          "actor": "elder",
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint("ScheduleService.completeTask error: $e");
      return false;
    }
  }

  Future<bool> acknowledgeTask({
    required String uid,
    required String date,
    required String taskId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/ai/tasks/acknowledge'),
        headers: _jsonHeaders,
        body: jsonEncode({
          "uid": uid,
          "date": date,
          "task_id": taskId,
          "actor": "elder",
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint("ScheduleService.acknowledgeTask error: $e");
      return false;
    }
  }

  Future<bool> startTask({
    required String uid,
    required String date,
    required String taskId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/ai/tasks/start'),
        headers: _jsonHeaders,
        body: jsonEncode({
          "uid": uid,
          "date": date,
          "task_id": taskId,
          "actor": "elder",
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint("ScheduleService.startTask error: $e");
      return false;
    }
  }

  // Old direct snooze remains available if you ever still need it.
  Future<bool> snoozeTask({
    required String uid,
    required String date,
    required String taskId,
    int snoozeMinutes = 10,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/ai/tasks/snooze'),
        headers: _jsonHeaders,
        body: jsonEncode({
          "uid": uid,
          "date": date,
          "task_id": taskId,
          "actor": "elder",
          "snooze_minutes": snoozeMinutes,
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint("ScheduleService.snoozeTask error: $e");
      return false;
    }
  }

  Future<Map<String, dynamic>> skipTask({
    required String uid,
    required String date,
    required String taskId,
    required List<String> reasons,
    required String decisionBy, // elder | caregiver
    String? caregiverNote,
    bool confirmed = false,
    bool? notifyCaregiver,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/ai/tasks/skip'),
      headers: _jsonHeaders,
      body: jsonEncode({
        "uid": uid,
        "date": date,
        "task_id": taskId,
        "actor": decisionBy,
        "reasons": reasons,
        "reason": reasons.isNotEmpty ? reasons.first : "other", // backward compat
        "skip_decision_by": decisionBy,
        "caregiver_skip_note": caregiverNote,
        "confirmed": confirmed,
        "notify_caregiver": notifyCaregiver,
      }),
    );

    if (response.statusCode >= 400) {
      throw Exception('Failed to skip task: ${response.body}');
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  // ----------------------------
  // New conversational "Later" flow
  // ----------------------------

  Future<Map<String, dynamic>?> requestTaskLater({
    required String uid,
    required String date,
    required String taskId,
    String? sessionId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/ai/tasks/request_later'),
        headers: _jsonHeaders,
        body: jsonEncode({
          "uid": uid,
          "date": date,
          "task_id": taskId,
          "session_id": sessionId,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }

      debugPrint("ScheduleService.requestTaskLater failed: ${response.body}");
      return null;
    } catch (e) {
      debugPrint("ScheduleService.requestTaskLater error: $e");
      return null;
    }
  }

  Future<Map<String, dynamic>?> sendVoiceCommand({
    required String uid,
    required String text,
    String? sessionId,
    DateTime? localTime,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/ai/process_voice_command'),
        headers: _jsonHeaders,
        body: jsonEncode({
          "uid": uid,
          "text": text,
          "session_id": sessionId,
          "local_time": (localTime ?? DateTime.now()).toIso8601String(),
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }

      debugPrint("ScheduleService.sendVoiceCommand failed: ${response.body}");
      return null;
    } catch (e) {
      debugPrint("ScheduleService.sendVoiceCommand error: $e");
      return null;
    }
  }

  // ----------------------------
  // Firestore helpers
  // ----------------------------

  Future<void> saveScheduleToFirestore(String uid, DateTime date, List<dynamic> tasks) async {
    final dateStr = date.toIso8601String().split('T')[0];
    final docId = "${uid}_$dateStr";

    try {
      await FirebaseFirestore.instance.collection('schedules').doc(docId).set({
        'uid': uid,
        'date': dateStr,
        'tasks': tasks,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      debugPrint("ScheduleService: Saved schedule to Firestore for $docId");
    } catch (e) {
      debugPrint("ScheduleService: Error saving to Firestore: $e");
    }
  }

  Future<Map<String, dynamic>?> getScheduleFromFirestore(String uid, DateTime date) async {
    final dateStr = date.toIso8601String().split('T')[0];
    final docId = "${uid}_$dateStr";

    try {
      final doc = await FirebaseFirestore.instance.collection('schedules').doc(docId).get();
      if (doc.exists) {
        return doc.data();
      }
    } catch (e) {
      debugPrint("ScheduleService: Error fetching from Firestore: $e");
    }
    return null;
  }

  Future<void> updateFirestoreTaskStatus(
    String uid,
    DateTime date,
    String taskId,
    bool completed, {
    String? status,
  }) async {
    final dateStr = date.toIso8601String().split('T')[0];
    final docId = "${uid}_$dateStr";

    try {
      final docRef = FirebaseFirestore.instance.collection('schedules').doc(docId);
      final doc = await docRef.get();

      if (doc.exists) {
        final tasks = List<dynamic>.from(doc.data()?['tasks'] ?? []);
        bool changed = false;

        for (var task in tasks) {
          if (task['id'] == taskId) {
            task['completed'] = completed;
            task['status'] = status ?? (completed ? 'completed_confirmed' : 'scheduled');
            changed = true;
            break;
          }
        }

        if (changed) {
          await docRef.update({'tasks': tasks});
        }
      }
    } catch (e) {
      debugPrint("ScheduleService: Error updating Firestore task status: $e");
    }
  }
}