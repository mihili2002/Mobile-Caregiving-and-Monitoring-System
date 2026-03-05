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
  StreamSubscription<DocumentSnapshot>? _profileSubscription; // NEW
  StreamSubscription<RemoteMessage>? _fcmSubscription;
  Timer? _checkTimer;
  
  // NEW: Track played reminders locally for Web/Mobile sync
  final Map<String, int> _lastPlayedCounts = {};
  final Set<String> _spokenKeys = {}; // NEW: Prevents duplicate voice announcements

  // Restore helper methods
  void updateTasks(List<dynamic> tasks) {
    _tasks = tasks;
    debugPrint("VoiceReminderService: Updated with ${tasks.length} tasks (Current Tier: $_riskTier)");
    
    // Schedule Local Notifications immediately
    _scheduleNotificationsForTasks();
    
    // NEW: Start local time-based checking
    _startChecking();
  }

  void updateRiskTier(String tier) {
    if (_riskTier == tier) return; // Skip if no change
    
    final oldTier = _riskTier;
    _riskTier = tier;
    debugPrint("🔊 RISK TIER SYNC: $oldTier -> $_riskTier");
    
    // Trigger check immediately on tier change
    _checkLocalReminders();
    _startChecking();
  }

  // NEW: Periodic check for reminders
  void _startChecking() {
    if (_checkTimer != null) return;
    
    debugPrint("VoiceReminderService: Starting periodic check timer (30s interval)...");
    _checkTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _checkLocalReminders();
    });
    
    // Run once immediately
    _checkLocalReminders();
  }

  void _checkLocalReminders() {
    if (_tasks.isEmpty) {
      debugPrint("VoiceReminderService: No tasks to check.");
      return;
    }
    
    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;
    
    debugPrint("VoiceReminderService: Checking ${_tasks.length} tasks for reminders (Risk Tier: $_riskTier, Time: ${now.hour}:${now.minute})");
    
    for (var task in _tasks) {
      if (task['completed'] == true) continue;
      
      String? tStr = task['time'];
      if (tStr == null || !tStr.contains(":")) continue;
      
      try {
        final parts = tStr.split(":");
        final taskMinutes = int.parse(parts[0]) * 60 + int.parse(parts[1]);
        
        int diff = currentMinutes - taskMinutes;
        
        // 1. Standard/Tier-based triggers
        bool shouldRemind = false;
        if (diff < 0) continue; // Future task

        if (_riskTier.contains("Tier 3") || _riskTier.contains("High")) {
          // Tier 3: Every 2 minutes indefinitely
          shouldRemind = diff % 2 == 0;
        } else if (_riskTier.contains("Tier 2")) {
          // Tier 2: 0, 2, 4, 6, 8 (5 total)
          shouldRemind = diff % 2 == 0 && diff <= 8;
        } else {
          // Default / Tier 1: 0, 2
          shouldRemind = diff == 0 || diff == 2;
        }

        // 2. Forgotten Task Logic (All Tiers)
        if (diff == 30) {
           shouldRemind = true;
        }

        if (shouldRemind) {
          // Unique Key: TaskID + the specific minute we are reminding at
          final key = "${task['id']}_$diff";
          
          if (!_spokenKeys.contains(key)) {
            String taskName = task['task_name'] ?? "Task";
            debugPrint("🔊 TRIGGER: Speaking reminder for $taskName at diff $diff (Tier: $_riskTier)");
            
            if (diff == 30) {
               _voiceService.speak("Reminder: You haven't finished $taskName yet. Please try to complete it at least now.");
            } else if (diff > 0) {
               _voiceService.speak("Reminder: You haven't finished $taskName yet. It's time.");
            } else {
               _voiceService.speakReminder(taskName);
            }
            
            _spokenKeys.add(key);
          }
        }
      } catch (e) {
        debugPrint("VoiceReminderService: Error parsing task time: $e");
      }
    }
  }

  // Start listening to Firestore for real-time updates
  void listen(String uid) {
    if (_subscription != null) return;
    
    debugPrint("VoiceReminderService: Listening to Firestore for $uid...");
    
    // 1. Listen for Profile Changes (For Risk Tier)
    _profileSubscription?.cancel();
    _profileSubscription = FirebaseFirestore.instance
        .collection('elder_profiles')
        .doc(uid)
        .snapshots()
        .listen((doc) {
          if (doc.exists && doc.data() != null) {
            final data = doc.data() as Map<String, dynamic>;
            final tier = data['prediction_tier']?.toString() ?? "Tier 1";
            debugPrint("🔊 FIRESTORE PROFILE SYNC: Found Tier $tier for $uid");
            updateRiskTier(tier);
          }
        }, onError: (e) => debugPrint("VoiceReminderService: Profile Listen Error: $e"));

    // 2. Listen for Schedule Changes
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
                // Skip if task is completed - no reminders for finished tasks!
                if (task['completed'] == true) continue;
                
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

              updateTasks(newTasks);
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
          // Attempt to play recorded audio from backend
          // We set a short timeout for the source load to fail fast if backend is down
          await _audioPlayer.play(UrlSource(audioUrl)).timeout(
            const Duration(seconds: 2),
            onTimeout: () => throw TimeoutException("Backend audio server unreachable"),
          );
        } else {
          // Fallback to local TTS if no URL
          await _voiceService.speak("Reminder: it is time for $taskName.");
        }
      } catch (e) {
        // Silently fallback without noisy stack traces if it's a known connection/format error
        debugPrint("🔊 TTS FALLBACK: Remote audio at $audioUrl failed to play (Likely Backend Offline). Using local voice.");
        await _voiceService.speak("Reminder: it is time for $taskName.");
      }
    }
  }

  void stop() {
    _subscription?.cancel();
    _subscription = null;
    _profileSubscription?.cancel();
    _profileSubscription = null;
    _fcmSubscription?.cancel();
    _fcmSubscription = null;
    _checkTimer?.cancel();
    _checkTimer = null;
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
