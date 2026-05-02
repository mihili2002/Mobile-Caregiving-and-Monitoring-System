import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'voice_service.dart';
import 'notification_service.dart';
import 'routine_understanding_service.dart';
import 'schedule_service.dart';
import 'user_service.dart'; // 👈 NEW
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:audioplayers/audioplayers.dart';

class VoiceReminderService {
  static final VoiceReminderService _instance = VoiceReminderService._internal();
  factory VoiceReminderService() => _instance;
  VoiceReminderService._internal();

  final VoiceService _voiceService = VoiceService();
  final NotificationService _notificationService = NotificationService();
  final RoutineUnderstandingService _routineService = RoutineUnderstandingService();
  final ScheduleService _scheduleService = ScheduleService();
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  String? _currentUid; // NEW: Store current user context
  List<dynamic> _tasks = [];
  String _riskTier = "Tier 1";
  StreamSubscription<QuerySnapshot>? _subscription;
  StreamSubscription<DocumentSnapshot>? _profileSubscription; // NEW
  StreamSubscription<RemoteMessage>? _fcmSubscription;
  Timer? _checkTimer;
  Timer? _cleanupTimer;
  
  // NEW: Track played reminders locally for Web/Mobile sync
  final Map<String, int> _lastPlayedCounts = {};
  final Set<String> _spokenKeys = {}; // Prevents duplicate voice announcements in _checkLocalReminders

  // CROSS-PATH deduplication: prevents the same reminder from being spoken
  // by multiple trigger paths (local timer, Firestore listener, FCM)
  final Set<String> _spokenReminderIds = {};
  
  // AUDIO QUEUE: Ensures reminders don't clash or get dropped
  final List<RemoteMessage> _audioQueue = [];
  bool _isProcessingQueue = false;
  bool _isCurrentlyPlaying = false; // Internal flag for the processor

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
    
    // Clean up old spoken keys every hour to avoid unbounded memory growth
    _cleanupTimer ??= Timer.periodic(const Duration(hours: 1), (_) {
      _spokenReminderIds.clear();
      _spokenKeys.clear();
      debugPrint("VoiceReminderService: Cleaned up spoken key caches.");
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
      // Stop reminding if task is completed or effectively "finished" (skipped, missed, etc.)
      final status = task['status']?.toString() ?? '';
      if (task['completed'] == true || 
          status == 'skipped' || 
          status == 'needs_caregiver_review' || 
          status == 'escalated' || 
          status == 'in_progress' || // STOP TIER-BASED REMINDERS IF IN PROGRESS
          status.startsWith('missed')) {
        
        // HOWEVER, we still want to allow the 10-min verification question for 'in_progress'
        // So we don't 'continue' here yet, we'll check diff below.
      }
      
      DateTime? effectiveReminderTime;

      try {
        if (task['status'] == 'snoozed' && task['snoozedUntil'] != null) {
          effectiveReminderTime = DateTime.parse(task['snoozedUntil']).toLocal();
        } else if (task['scheduledAt'] != null) {
          effectiveReminderTime = DateTime.parse(task['scheduledAt']).toLocal();
        } else {
          final tStr = task['time']?.toString();
          if (tStr != null && tStr.contains(":")) {
            final parts = tStr.split(":");
            effectiveReminderTime = DateTime(
              now.year,
              now.month,
              now.day,
              int.parse(parts[0]),
              int.parse(parts[1]),
            );
          }
        }
      } catch (e) {
        debugPrint("VoiceReminderService: Error parsing effective reminder time: $e");
        continue;
      }

      if (effectiveReminderTime == null) continue;

      final taskMinutes =
          effectiveReminderTime.hour * 60 + effectiveReminderTime.minute;
      final diff = currentMinutes - taskMinutes;
        
        bool shouldRemind = false;
        
        // 1. Future Task Check
        if (diff < 0) continue; 

        // 2. Forgotten Task Logic (30 mins after) - HIGHEST PRIORITY
        // This fires even if status just flipped to 'missed_likely'
        if (diff == 30) {
          final key = "${task['id']}_$diff";
          if (!_spokenKeys.contains(key) && task['completed'] != true) {
            debugPrint("🔊 FORGOTTEN ALERT (30 mins): Triggering for ${task['task_name']}");
            _handleManualReminderTrigger(task['uid'] ?? _currentUid ?? "", task, forgotten: true);
            _spokenKeys.add(key);
          }
          continue; // Finish this task processing for this tick
        }

        // 3. Status Check for regular reminders/questions
        final isFinished = task['completed'] == true || 
                          ['skipped', 'needs_caregiver_review', 'escalated', 'missed_likely', 'missed_confirmed']
                          .contains(status);
        if (isFinished) continue;

        // 4. Verification Mode Triggers (10 & 20 mins after)
        if (diff == 10 || diff == 20) {
           String taskName = task['task_name'] ?? "Task";
           debugPrint("🔊 VERIFICATION ($diff mins): Asking if $taskName is done (Status: $status)");
           _voiceService.speak(_routineService.getVerificationQuestion(taskName), category: 'urgent');
           
           if (status == 'pending' || status == 'scheduled' || status == 'reminder_triggered') {
             _scheduleService.updateFirestoreTaskStatus(
               task['uid'] ?? _currentUid ?? "", 
               now, 
               task['id']?.toString() ?? "", 
               false, 
               status: 'pending' 
             );
           }
           continue; 
        }

        // 5. Tier-based reminders (ONLY for non-in-progress tasks)
        if (status == 'in_progress') {
           continue;
        }

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

        if (shouldRemind) {
          // Unique Key: TaskID + the specific minute we are reminding at
          final key = "${task['id']}_$diff";
          
          if (!_spokenKeys.contains(key)) {
            String taskName = task['task_name'] ?? "Task";
            String category = task['type'] ?? "common"; // Extract category

            debugPrint("🔊 TRIGGER: Speaking reminder for $taskName at diff $diff (Tier: $_riskTier)");
            
            if (diff == 30) {
               _handleManualReminderTrigger(task['uid'] ?? _currentUid ?? "", task, forgotten: true);
            } else if (diff > 0) {
               _handleManualReminderTrigger(task['uid'] ?? _currentUid ?? "", task, forgotten: true);
            } else {
               _handleManualReminderTrigger(task['uid'] ?? _currentUid ?? "", task, forgotten: false);
            }
            
            _spokenKeys.add(key);
          }
        }
    }
  }

  // Start listening to Firestore for real-time updates
  void listen(String uid) {
    _currentUid = uid;
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
              
              for (var task in newTasks) {
                final status = task['status']?.toString() ?? '';
                if (task['completed'] == true || 
                    status == 'skipped' || 
                    status == 'needs_caregiver_review' || 
                    status == 'escalated' || 
                    status.startsWith('missed')) continue;
                
                final taskId = task['id']?.toString() ?? "";
                final currentCount = task['reminder_count'] ?? 0;
                final lastCount = _lastPlayedCounts[taskId] ?? 0;

                if (currentCount > lastCount) {
                  final dedupeKey = '${taskId}_${DateTime.now().hour}_${DateTime.now().minute}';
                  if (_spokenReminderIds.contains(dedupeKey)) {
                    _lastPlayedCounts[taskId] = currentCount;
                    continue;
                  }
                  _handleManualReminderTrigger(elderId, task);
                  _lastPlayedCounts[taskId] = currentCount;
                }
              }
              updateTasks(newTasks);
          }
       }
    }, onError: (e) => debugPrint("VoiceReminderService: Firestore Listen Error: $e"));
  }

  void _handleManualReminderTrigger(String uid, Map<String, dynamic> task, {bool forgotten = false}) {
    final taskName = task['task_name'] ?? task['taskName'] ?? "Task";
    final category = task['type'] ?? task['category'] ?? "common";
    final taskId = task['id'] ?? task['taskId'] ?? "";
    
    String audioUrl = "http://127.0.0.1:8000/api/audio/$uid/$taskId";
    if (forgotten) {
      audioUrl += "?forgotten=true";
    }
    
    final message = RemoteMessage(
      data: {
        'type': 'VOICE_REMINDER',
        'taskName': taskName,
        'audioUrl': audioUrl,
        'category': category,
        'taskId': taskId.toString(),
      }
    );
    _handleVoiceReminder(message);
  }

  void start(String uid) async {
    _currentUid = uid;
    if (!kIsWeb) {
      try {
        String? token = await FirebaseMessaging.instance.getToken();
        if (token != null) {
          await UserService().updateFCMToken(uid, token);
        }
      } catch (e) {
        debugPrint("VoiceReminderService: FCM Error: $e");
      }
    }

    FirebaseMessaging.onMessage.listen(_handleVoiceReminder);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleVoiceReminder);
  }

  Future<void> _handleVoiceReminder(RemoteMessage message) async {
    if (message.data['type'] != 'VOICE_REMINDER') return;

    final taskName = message.data['taskName'] ?? 'Task';
    final taskId = message.data['taskId'] ?? '';

    // ── CROSS-PATH DEDUPLICATION ──────────────────────────────────
    final now = DateTime.now();
    final dedupeKey = '${taskId}_${now.hour}_${now.minute}';
    if (_spokenReminderIds.contains(dedupeKey)) return;
    _spokenReminderIds.add(dedupeKey);

    // ── ADD TO QUEUE ─────────────────────────────────────────────
    debugPrint("🔊 QUEUED: $taskName");
    _audioQueue.add(message);
    
    // Start processing if not already running
    _processAudioQueue();
  }

  Future<void> _processAudioQueue() async {
    if (_isProcessingQueue) return;
    _isProcessingQueue = true;

    while (_audioQueue.isNotEmpty) {
      final message = _audioQueue.removeAt(0);
      final taskName = message.data['taskName'] ?? 'Task';
      final audioUrl = message.data['audioUrl'];
      final category = message.data['category'] ?? 'common';

      _isCurrentlyPlaying = true;
      debugPrint("🔊 PLAYING FROM QUEUE: $taskName");

      bool backendSuccess = false;
      try {
        if (audioUrl != null && audioUrl.isNotEmpty) {
          await _audioPlayer.setVolume(1.0);
          await _audioPlayer.play(UrlSource(audioUrl)).timeout(
            const Duration(seconds: 8),
            onTimeout: () => throw TimeoutException("Timeout"),
          );
          
          // Wait for the audio to actually finish playing
          await _audioPlayer.onPlayerComplete.first.timeout(
            const Duration(seconds: 15), 
            onTimeout: () => debugPrint("🔊 Audio playback took too long, moving to next"),
          );
          backendSuccess = true;
        }
      } catch (e) {
        debugPrint("🔊 Backend audio failed for $taskName: $e");
      }

      if (!backendSuccess) {
        debugPrint("🔊 TTS FALLBACK: Using FlutterTts for $taskName");
        await _voiceService.speakReminder(taskName, category: category);
      }

      _isCurrentlyPlaying = false;
      
      // BREATHING SPACE: Wait 2 seconds before the next reminder starts
      if (_audioQueue.isNotEmpty) {
        debugPrint("🔊 Queue breathing space (2s)...");
        await Future.delayed(const Duration(seconds: 2));
      }
    }

    _isProcessingQueue = false;
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
    _cleanupTimer?.cancel();
    _cleanupTimer = null;
    _spokenReminderIds.clear();
    _isCurrentlyPlaying = false;
    _audioPlayer.dispose();
  }

  Future<void> resyncAfterTaskReschedule(String uid, String taskId) async {
    _spokenKeys.removeWhere((key) => key.startsWith("${taskId}_"));
    _spokenReminderIds.removeWhere((key) => key.startsWith("${taskId}_"));
    _lastPlayedCounts.remove(taskId);

    for (int i = 0; i < 5; i++) {
      final notifId = NotificationService.makeId(uid, taskId, i);
      await _notificationService.cancel(notifId);
    }
  }

  Future<void> _scheduleNotificationsForTasks() async {
    await _notificationService.init();
    
    for (var task in _tasks) {
      final status = task['status']?.toString() ?? '';
      if (task['completed'] == true || 
          status == 'skipped' || 
          status == 'needs_caregiver_review' || 
          status == 'escalated') continue;
      
      DateTime? scheduledTime;
      final now = DateTime.now();

      try {
        if (task['status'] == 'snoozed' && task['snoozedUntil'] != null) {
          scheduledTime = DateTime.parse(task['snoozedUntil']).toLocal();
        } else if (task['scheduledAt'] != null) {
          scheduledTime = DateTime.parse(task['scheduledAt']).toLocal();
        } else {
          final timeStr = task['time']?.toString() ?? "";
          if (timeStr.contains(":")) {
            final parts = timeStr.split(":");
            scheduledTime = DateTime(now.year, now.month, now.day, int.parse(parts[0]), int.parse(parts[1]));
          }
        }
      } catch (e) { continue; }

      if (scheduledTime != null && scheduledTime.isAfter(now)) {
        final taskIdStr = task['id']?.toString() ?? task['task_name']?.toString() ?? "";
        final notifId = NotificationService.makeId(task['uid'] ?? "user", taskIdStr, 0);
        await _notificationService.scheduleNotification(
          id: notifId, 
          title: "Reminder", 
          body: "Time for ${task['task_name']}", 
          scheduledTime: scheduledTime
        );
      }
    }
  }
}
