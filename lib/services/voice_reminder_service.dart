import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'voice_service.dart';

class VoiceReminderService {
  static final VoiceReminderService _instance = VoiceReminderService._internal();
  factory VoiceReminderService() => _instance;
  VoiceReminderService._internal();

  final VoiceService _voiceService = VoiceService();
  List<dynamic> _tasks = [];
  String _riskTier = "Tier 1";
  Timer? _timer;
  final Set<String> _spokenTaskIds = {}; 
  
  StreamSubscription<QuerySnapshot>? _subscription;

  // Restore helper methods
  void updateTasks(List<dynamic> tasks, String tier) {
    _tasks = tasks;
    _riskTier = tier;
    debugPrint("VoiceReminderService: Updated with ${tasks.length} tasks and Tier: $tier");
  }

  void updateRiskTier(String tier) {
    _riskTier = tier;
    debugPrint("VoiceReminderService: Updated Risk Tier to $tier");
  }

  // Start listening to Firestore for real-time updates
  void listen(String uid) {
    if (_subscription != null) return;
    
    debugPrint("VoiceReminderService: Listening to Firestore for $uid...");
    
    // Switch to Query-based listening to avoid Permission Denied on non-existent docs
    // Field 'date' is stored as YYYY-MM-DD in ai_routes.py
    final now = DateTime.now();
    final dateStr = DateFormat('yyyy-MM-dd').format(now);
    
    // Use QuerySnapshot instead of DocumentSnapshot
    // We listen to the schedules collection where uid matches and date matches today
    final query = FirebaseFirestore.instance
        .collection('schedules')
        .where('uid', isEqualTo: uid)
        .where('date', isEqualTo: dateStr)
        .limit(1);

    _subscription = query.snapshots().listen((querySnapshot) {
       if (querySnapshot.docs.isNotEmpty) {
          final data = querySnapshot.docs.first.data();
          if (data['tasks'] != null) {
              final newTasks = List<dynamic>.from(data['tasks']);
              updateTasks(newTasks, _riskTier);
          }
       } else {
          // No schedule yet for today, cleared tasks or empty
          // updateTasks([], _riskTier); // Optional: clear tasks if day changed?
       }
    }, onError: (e) {
        debugPrint("VoiceReminderService: Firestore Listen Error: $e");
    });
  }

  void start() {
    if (_timer != null) return;
    debugPrint("VoiceReminderService: Starting timer...");
    _timer = Timer.periodic(const Duration(seconds: 45), (timer) {
      _checkReminders();
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _subscription?.cancel();
    _subscription = null;
  }

  void _checkReminders() async {
    final now = DateTime.now();
    final currentHour = now.hour;
    final currentMinute = now.minute;
    final int currentTotalMinutes = currentHour * 60 + currentMinute;

    // Policy Offsets
    List<int> offsets = [0];
    if (_riskTier.contains("Tier 3") || _riskTier.contains("High")) {
      offsets = [0, 10, 20];
    } else if (_riskTier.contains("Tier 2") || _riskTier.contains("Medium")) {
      offsets = [0, 15];
    }

    for (var task in _tasks) {
      if (task['completed'] == true) continue;
      
      final timeStr = task['time']?.toString() ?? "";
      if (!timeStr.contains(":")) continue;

      try {
        final parts = timeStr.split(":");
        final taskHour = int.parse(parts[0]);
        final taskMinute = int.parse(parts[1]);
        final int taskTotalMinutes = taskHour * 60 + taskMinute;

        final int diff = currentTotalMinutes - taskTotalMinutes;

        if (offsets.contains(diff)) {
          final taskId = task['id']?.toString() ?? task['task_name']?.toString() ?? "";
          final uniqueKey = "${taskId}_${currentTotalMinutes}";

          if (!_spokenTaskIds.contains(uniqueKey)) {
            _spokenTaskIds.add(uniqueKey);
            
            String reminderMsg = task['task_name'] ?? "task";
            if (diff > 0) {
               reminderMsg = "Reminder: you haven't finished $reminderMsg yet.";
            }
            
            debugPrint("🔊 Speaking reminder for: $reminderMsg (diff $diff)");
            await _voiceService.speakReminder(reminderMsg);
          }
        }
      } catch (e) {
        debugPrint("VoiceReminderService: Error parsing time '$timeStr': $e");
      }
    }

    // Cleanup old spoken IDs (keep a window of 30 mins)
    _spokenTaskIds.removeWhere((key) {
       try {
         final parts = key.split("_");
         final timeMark = int.parse(parts.last);
         return (currentTotalMinutes - timeMark).abs() > 30;
       } catch(_) { return true; }
    });
  }
}
