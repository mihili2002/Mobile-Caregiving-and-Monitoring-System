import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

class SmartReminderService {
  final String baseUrl = "http://192.168.1.5:5000"; // Update with your IP
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();

  // 1. The Master Function: Call this when user clicks "Save Task"
  Future<void> scheduleSmartReminder(String uid, int taskId, String taskName, int hour, int minute) async {
    print("AI Analysis: Generating strategy for '$taskName'...");
    
    try {
      // A. Get Strategy from Python
      final response = await http.post(
        Uri.parse('$baseUrl/predict_reminder_strategy'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"uid": uid}),
      );

      if (response.statusCode != 200) {
        // Fallback if AI is offline: Schedule 1 standard alarm
        _scheduleStandardAlarm(taskId, taskName, hour, minute);
        return;
      }

      final strategy = jsonDecode(response.body);
      print("Strategy Received: $strategy");

      // B. Execute the Strategy
      await _applyStrategy(taskId, taskName, hour, minute, strategy);

    } catch (e) {
      print("Error: $e");
      _scheduleStandardAlarm(taskId, taskName, hour, minute);
    }
  }

  // 2. Logic to Apply the AI's Advice
  Future<void> _applyStrategy(int id, String title, int hour, int minute, Map<String, dynamic> strategy) async {
    int retries = strategy['auto_retries_count'];
    bool escalate = strategy['caregiver_escalation_enabled'];
    
    // Step 1: Schedule the Main Alarm (Exactly at requested time)
    await _scheduleNotification(id, title, "It's time for your routine.", hour, minute);

    // Step 2: Adaptive Retries (Scheduling "Nags")
    // If AI says they need 3 retries, we schedule them 15 mins apart automatically
    for (int i = 1; i <= retries; i++) {
      int offsetMinutes = i * 15; // 15, 30, 45 mins later
      await _scheduleNotification(
        id + 1000 + i, // Unique ID for retries
        title, 
        "Reminder $i: Have you completed $title yet?", 
        hour, 
        minute + offsetMinutes
      );
    }

    // Step 3: Escalation Monitor (Concept)
    if (escalate) {
      print("HIGH RISK: Scheduling Caregiver Alert Check for ${hour + 1}:00");
      // In a real app, you would schedule a background worker here 
      // to check Firestore in 1 hour. If status != 'done', send SMS to caregiver.
    }
  }

  // Standard Notification Helper (Boilerplate)
  Future<void> _scheduleNotification(int id, String title, String body, int hour, int minute) async {
    // ... (Use your existing TimeZone scheduling logic here) ...
    // Ensure minute overflow is handled (e.g., minute 65 -> hour + 1)
  }

  Future<void> _scheduleStandardAlarm(int id, String title, int hour, int minute) async {
    print("Using Standard Alarm (No AI)");
    await _scheduleNotification(id, title, "Time for $title", hour, minute);
  }
}