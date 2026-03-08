import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';

class ScheduleService {
  // Same smart URL logic as RoutineService
  String get baseUrl {
    if (kIsWeb) return "http://127.0.0.1:8000";
    if (defaultTargetPlatform == TargetPlatform.android) return "http://10.0.2.2:8000";
    return "http://192.168.8.115:8000";
  }

  // 1. Get Schedule for a Date
  Future<Map<String, dynamic>?> getSchedule(String uid, DateTime date) async {
    final dateStr = date.toIso8601String().split('T')[0]; // YYYY-MM-DD
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/schedule/get_schedule'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "uid": uid,
          "date": dateStr,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        print("Failed to load schedule: ${response.body}");
        return null;
      }
    } catch (e) {
      print("Error fetching schedule: $e");
      return null;
    }
  }

  // 2. Add Task to Schedule
  Future<bool> addTask(String uid, DateTime date, Map<String, dynamic> task) async {
    final dateStr = date.toIso8601String().split('T')[0];
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/schedule/add_task'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "uid": uid,
          "date": dateStr,
          "task": task
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      print("Error adding task: $e");
      return false;
    }
  }

  // 3. Update Task Status
  Future<bool> updateTaskStatus(String uid, DateTime date, String taskId, bool completed) async {
    final dateStr = date.toIso8601String().split('T')[0];
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/schedule/update_task_status'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "uid": uid,
          "date": dateStr,
          "task_id": taskId,
          "completed": completed
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      print("Error updating task: $e");
      return false;
    }
  }
  // 4. Delete Task
  Future<bool> deleteTask(String uid, DateTime date, String taskId) async {
    final dateStr = date.toIso8601String().split('T')[0];
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/schedule/delete_task'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "uid": uid,
          "date": dateStr,
          "task_id": taskId
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      print("Error deleting task: $e");
      return false;
    }
  }

  // 6. Complete Task (Log Event Side Effect)
  Future<bool> completeTask(String uid, DateTime date, String taskId) async {
    final dateStr = date.toIso8601String().split('T')[0];
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/schedule/complete'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "uid": uid,
          "date": dateStr,
          "taskId": taskId
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      print("Error completing task: $e");
      return false;
    }
  }

  // 5. Update Task Details
  Future<bool> updateTask(String uid, DateTime date, String taskId, Map<String, dynamic> updates) async {
    final dateStr = date.toIso8601String().split('T')[0];
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/schedule/update_task'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "uid": uid,
          "date": dateStr,
          "task_id": taskId,
          "updates": updates
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      print("Error updating task: $e");
      return false;
    }
  }

  // --- FIRESTORE PERSISTENCE (For History) ---

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

  Future<void> updateFirestoreTaskStatus(String uid, DateTime date, String taskId, bool completed) async {
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
