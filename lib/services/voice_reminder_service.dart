import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'voice_service.dart';
import 'notification_service.dart';
import 'user_service.dart'; // 👈 NEW
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:audioplayers/audioplayers.dart';

class VoiceReminderService {
  static final VoiceReminderService _instance = VoiceReminderService._internal();
  factory VoiceReminderService() => _instance;
  VoiceReminderService._internal();

  final VoiceService _voiceService = VoiceService();
  final NotificationService _notificationService = NotificationService();
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  List<dynamic> _tasks = [];
  String _riskTier = "Tier 1";
  StreamSubscription<QuerySnapshot>? _subscription;
  StreamSubscription<RemoteMessage>? _fcmSubscription;
  
  // NEW: Track played reminders locally for Web/Mobile sync
  final Map<String, int> _lastPlayedCounts = {};

  // Restore helper methods
  void updateTasks(List<dynamic> tasks, String tier) {
    _tasks = tasks;
    _riskTier = tier;
    debugPrint("VoiceReminderService: Updated with ${tasks.length} tasks and Tier: $tier");
    
    // Schedule Local Notifications immediately
    _scheduleNotificationsForTasks();
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
    
    final query = FirebaseFirestore.instance
        .collection('schedules')
        .where('uid', isEqualTo: uid)
        .where('date', isEqualTo: dateStr)
        .limit(1);

    _subscription = query.snapshots().listen((querySnapshot) {
       if (querySnapshot.docs.isNotEmpty) {
          final data = querySnapshot.docs.first.data();
          final String elderId = data['uid'] ?? uid;

          if (data['tasks'] != null) {
              final newTasks = List<dynamic>.from(data['tasks']);
              
              // TRIGGER: Check for reminder_count increases (FOR WEB/CHROME DEMO)
              for (var task in newTasks) {
                final taskId = task['id']?.toString() ?? "";
                final currentCount = task['reminder_count'] ?? 0;
                final lastCount = _lastPlayedCounts[taskId] ?? 0;

                if (currentCount > lastCount) {
                  debugPrint("🔊 FIRESTORE TRIGGER: Reminder count increased for $taskId ($lastCount -> $currentCount)");
                  
                  // Play the reminder manually since FCM might not work on Web
                  _handleManualReminderTrigger(elderId, task);
                  
                  // Update tracking
                  _lastPlayedCounts[taskId] = currentCount;
                }
              }

              updateTasks(newTasks, _riskTier);
          }
       }
    }, onError: (e) {
        debugPrint("VoiceReminderService: Firestore Listen Error: $e");
    });
  }

  void _handleManualReminderTrigger(String uid, Map<String, dynamic> task) {
    final taskName = task['task_name'] ?? task['taskName'] ?? "Task";
    final category = task['type'] ?? task['category'] ?? "common";
    final taskId = task['id'] ?? task['taskId'] ?? "";
    
    // Construct the same audio URL the backend uses
    final audioUrl = "http://127.0.0.1:8000/api/audio/$uid/$taskId";
    
    debugPrint("🔊 Triggering Local Playback for: $taskName");
    
    // Reuse the existing handler
    final message = RemoteMessage(
      data: {
        'type': 'VOICE_REMINDER',
        'taskName': taskName,
        'audioUrl': audioUrl,
        'category': category,
      }
    );
    _handleVoiceReminder(message);
  }

  void start(String uid) async {
    debugPrint("VoiceReminderService: Starting service for $uid...");
    
    if (kIsWeb) {
      debugPrint("VoiceReminderService: Web platform detected. Skipping FCM token registration (Mobile only).");
    } else {
      // 1. Get FCM Token and update backend (Mobile Only)
      try {
        String? token = await FirebaseMessaging.instance.getToken();
        if (token != null) {
          debugPrint("VoiceReminderService: FCM Token retrieved: ${token.substring(0, 10)}...");
          bool success = await UserService().updateFCMToken(uid, token);
          if (success) {
            debugPrint("VoiceReminderService: FCM Token registered successfully");
          } else {
            debugPrint("VoiceReminderService: FCM Token registration failed");
          }
        } else {
          debugPrint("VoiceReminderService: Could not retrieve FCM Token");
        }
      } catch (e) {
        debugPrint("VoiceReminderService: Error during FCM registration: $e");
      }
    }

    // 2. Listen for foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _handleVoiceReminder(message);
    });

    // 3. Handle background messages
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleVoiceReminder(message);
    });
  }

  void _handleVoiceReminder(RemoteMessage message) async {
    if (message.data['type'] == 'VOICE_REMINDER') {
      final taskName = message.data['taskName'];
      final audioUrl = message.data['audioUrl'];
      final category = message.data['category'];
      
      debugPrint("🔊 Voice Reminder Received: $taskName, Type: $category");
      
      try {
        if (audioUrl != null && audioUrl.isNotEmpty) {
          await _audioPlayer.play(UrlSource(audioUrl));
        } else {
          // Fallback to local TTS if no audio URL provided
          await _voiceService.speak("Reminder: it is time for $taskName.");
        }
      } catch (e) {
        debugPrint("Error playing voice reminder: $e");
      }
    }
  }

  void stop() {
    _subscription?.cancel();
    _subscription = null;
    _fcmSubscription?.cancel();
    _fcmSubscription = null;
    _audioPlayer.dispose();
  }

  // NEW: Schedule Local Notifications for reliability
  Future<void> _scheduleNotificationsForTasks() async {
    await _notificationService.init();
    
    for (var task in _tasks) {
      if (task['completed'] == true) continue;
      
      final timeStr = task['time']?.toString() ?? "";
      if (!timeStr.contains(":")) continue;
      
      try {
        final parts = timeStr.split(":");
        final taskHour = int.parse(parts[0]);
        final taskMinute = int.parse(parts[1]);
        
        final now = DateTime.now();
        final scheduledTime = DateTime(
          now.year, now.month, now.day,
          taskHour, taskMinute
        );
        
        // Only schedule if time is in future
        if (scheduledTime.isAfter(now)) {
           final taskIdStr = task['id']?.toString() ?? task['task_name']?.toString() ?? "";
           
           // Use hash for ID
           // We use offset 0 for main reminder
           final notifId = NotificationService.makeId(task['uid'] ?? "user", taskIdStr, 0);
           
           await _notificationService.scheduleNotification(
             id: notifId, 
             title: "Reminder", 
             body: "Time for ${task['task_name']}", 
             scheduledTime: scheduledTime
           );
        }
      } catch (e) {
        debugPrint("VoiceReminderService: Error scheduling local notification: $e");
      }
    }
  }

}
