import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'voice_service.dart';
import 'notification_service.dart';
import 'routine_understanding_service.dart';
import 'schedule_service.dart';
import 'user_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:audioplayers/audioplayers.dart';

class VoiceReminderService {
  static final VoiceReminderService _instance = VoiceReminderService._internal();
  factory VoiceReminderService() => _instance;
  VoiceReminderService._internal();

  final VoiceService _voiceService = VoiceService();
  final NotificationService _notificationService = NotificationService();
  final RoutineUnderstandingService _routineService =
      RoutineUnderstandingService();
  final ScheduleService _scheduleService = ScheduleService();
  final AudioPlayer _audioPlayer = AudioPlayer();

  String? _currentUid;
  List<dynamic> _tasks = [];
  String _riskTier = "Tier 1";

  StreamSubscription<QuerySnapshot>? _subscription;
  StreamSubscription<DocumentSnapshot>? _profileSubscription;
  StreamSubscription<RemoteMessage>? _fcmSubscription;

  Timer? _checkTimer;
  Timer? _cleanupTimer;

  final Set<String> _spokenReminderIds = {};
  // [GENERALIZED] Guard for tasks undergoing state changes (reschedule, skip, complete)
  final Set<String> _pendingTaskStateChangeIds = {};

  final List<Map<String, dynamic>> _audioQueue = [];
  bool _isProcessingQueue = false;

  final Map<String, int> _lastPlayedCounts = {};

  void updateTasks(List<dynamic> tasks) {
    final oldTasks = List.from(_tasks);
    _tasks = tasks;

    for (final t in tasks) {
      final id = t['id']?.toString() ?? "";
      if (id.isEmpty) continue;

      final status = t['status']?.toString() ?? "";

      // [GENERALIZED] If in pending state change, only clear if we see the new info
      if (_pendingTaskStateChangeIds.contains(id)) {
        final oldTask = oldTasks.isEmpty
            ? null
            : oldTasks.firstWhere((ot) => ot['id'] == id, orElse: () => null);

        if (oldTask != null) {
          final oldTime = oldTask['scheduledAt'] ?? oldTask['time'];
          final newTime = t['scheduledAt'] ?? t['time'];
          final oldVersion = int.tryParse(oldTask['reminderVersion']?.toString() ?? '0') ?? 0;
          final newVersion = int.tryParse(t['reminderVersion']?.toString() ?? '0') ?? 0;

          // Clear guard if time changed, status became stable, or version incremented
          if (oldTime != newTime || 
              newVersion > oldVersion ||
              status == 'scheduled' || 
              status == 'skipped' || 
              status == 'completed') {
            _pendingTaskStateChangeIds.remove(id);
            debugPrint(
              "🔊 VoiceReminderService: Fresh data confirmed for $id (status=$status), clearing pending guard.",
            );
          }
        } else {
          // Task just appeared or was missing before
          _pendingTaskStateChangeIds.remove(id);
        }
      }

      // Always clear for terminal or resolve-like states
      if (status == 'skipped' ||
          status == 'completed' ||
          status == 'completed_confirmed') {
        _pendingTaskStateChangeIds.remove(id);
      }
    }

    debugPrint(
      "VoiceReminderService: Updated with ${tasks.length} tasks "
      "(Current Tier: $_riskTier, Pending Changes: ${_pendingTaskStateChangeIds.length})",
    );

    _scheduleNotificationsForTasks();
    _startChecking();
  }

  void updateRiskTier(String tier) {
    if (_riskTier == tier) return;

    final oldTier = _riskTier;
    _riskTier = tier;

    debugPrint("🔊 RISK TIER SYNC: $oldTier -> $_riskTier");

    _checkLocalReminders();
    _startChecking();
  }

  void _startChecking() {
    if (_checkTimer != null) return;

    debugPrint("VoiceReminderService: Starting periodic check timer...");

    _checkTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _checkLocalReminders();
    });

    _cleanupTimer ??= Timer.periodic(const Duration(hours: 1), (_) {
      _spokenReminderIds.clear();
      debugPrint("VoiceReminderService: Cleaned up spoken reminder cache.");
    });

    _checkLocalReminders();
  }

  void _checkLocalReminders() {
    if (_tasks.isEmpty) {
      debugPrint("VoiceReminderService: No tasks to check.");
      return;
    }

    final now = DateTime.now();

    debugPrint(
      "VoiceReminderService: Checking ${_tasks.length} tasks "
      "(Tier: $_riskTier, Time: ${now.hour}:${now.minute})",
    );

    for (final task in _tasks) {
      final String taskId = task['id']?.toString() ?? '';
      final status = task['status']?.toString() ?? '';

      if (taskId.isEmpty) continue;

      if (_pendingTaskStateChangeIds.contains(taskId)) {
        debugPrint(
          "🔊 VoiceReminderService: Skipping $taskId as it is pending state-change propagation.",
        );
        continue;
      }

      DateTime? effectiveReminderTime;

      try {
        if (task['status'] == 'snoozed' && task['snoozedUntil'] != null) {
          effectiveReminderTime =
              DateTime.parse(task['snoozedUntil']).toLocal();
        } else if (task['scheduledAt'] != null) {
          effectiveReminderTime =
              DateTime.parse(task['scheduledAt']).toLocal();
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
        debugPrint("VoiceReminderService: Time parse error: $e");
        continue;
      }

      if (effectiveReminderTime == null) continue;

      final diff = now.difference(effectiveReminderTime).inMinutes;

      final String name = task['task_name']?.toString() ?? "Unknown";
      debugPrint(
        "🔊 [Checking Task: $name] status=$status, effectiveTime=$effectiveReminderTime, diff=$diff",
      );

      if (now.isBefore(effectiveReminderTime)) continue;

      final minuteKey = "${taskId}_${now.hour}_${now.minute}";

      if (diff == 30) {
        if (!_spokenReminderIds.contains(minuteKey) &&
            task['completed'] != true) {
          _spokenReminderIds.add(minuteKey);

          debugPrint(
            "🔊 FORGOTTEN ALERT (30 mins): Triggering for "
            "${task['task_name']} [Key: $minuteKey]",
          );

          _handleManualReminderTrigger(
            task['uid'] ?? _currentUid ?? "",
            task,
            forgotten: true,
            dedupeKey: minuteKey,
          );
        }

        continue;
      }

      final isFinished = task['completed'] == true ||
          [
            'skipped',
            'done',
            'completed',
            'cancelled',
            'archived',
            'needs_caregiver_review',
            'escalated',
            'missed_likely',
            'missed_confirmed',
          ].contains(status);

      if (isFinished) {
        // [NEW] If finished but not cleared from guard, clear it
        if (_pendingTaskStateChangeIds.contains(taskId)) {
           _pendingTaskStateChangeIds.remove(taskId);
        }
        continue;
      }

      if (diff == 5 || diff == 10 || diff == 20) {
        if (!_spokenReminderIds.contains(minuteKey)) {
          _spokenReminderIds.add(minuteKey);

          final taskName = task['task_name'] ?? "Task";
          final question = _routineService.getVerificationQuestion(taskName);

          debugPrint("🔊 VERIFICATION QUESTION ($diff mins): $taskName");

          _enqueueFlutterTts(
            text: question,
            taskName: taskName,
            category: 'urgent',
          );

          if (status == 'pending' ||
              status == 'scheduled' ||
              status == 'reminder_triggered') {
            _scheduleService.updateFirestoreTaskStatus(
              task['uid'] ?? _currentUid ?? "",
              now,
              taskId,
              false,
              status: 'pending',
            );
          }
        }

        continue;
      }

      if (status == 'in_progress') continue;

      bool shouldRemind = false;

      if (_riskTier.contains("Tier 3") || _riskTier.contains("High")) {
        shouldRemind = diff % 2 == 0;
      } else if (_riskTier.contains("Tier 2")) {
        shouldRemind = diff % 2 == 0 && diff <= 8;
      } else {
        // Tier 1: Remind at 0 and 2. 
        // Also catch up if rescheduled to a recent past time (within 5 mins) and hasn't been spoken yet.
        shouldRemind = diff == 0 || diff == 2 || 
            (diff < 5 && !_spokenReminderIds.any((k) => k.startsWith("${taskId}_")));
      }

      if (shouldRemind) {
        if (!_spokenReminderIds.contains(minuteKey)) {
          _spokenReminderIds.add(minuteKey);

          debugPrint(
            "🔊 TIER REMINDER: ${task['task_name']} at diff $diff "
            "(Tier: $_riskTier)",
          );

          _handleManualReminderTrigger(
            task['uid'] ?? _currentUid ?? "",
            task,
            forgotten: diff > 0,
            dedupeKey: minuteKey,
          );
        }
      }
    }
  }

  void listen(String uid) {
    _currentUid = uid;

    if (_subscription != null) return;

    debugPrint("VoiceReminderService: Listening to Firestore for $uid...");

    _profileSubscription?.cancel();
    _profileSubscription = FirebaseFirestore.instance
        .collection('elder_profiles')
        .doc(uid)
        .snapshots()
        .listen((doc) {
      if (doc.exists && doc.data() != null) {
        final data = doc.data() as Map<String, dynamic>;
        final tier = data['prediction_tier']?.toString() ?? "Tier 1";
        updateRiskTier(tier);
      }
    }, onError: (e) {
      debugPrint("VoiceReminderService: Profile listen error: $e");
    });

    final now = DateTime.now();
    final dateStr = DateFormat('yyyy-MM-dd').format(now);

    final query = FirebaseFirestore.instance
        .collection('schedules')
        .where('uid', isEqualTo: uid)
        .where('date', isEqualTo: dateStr)
        .limit(1);

    _subscription = query.snapshots().listen((querySnapshot) {
      if (querySnapshot.docs.isEmpty) return;

      final data = querySnapshot.docs.first.data();
      final String elderId = data['uid'] ?? uid;

      if (data['tasks'] == null) return;

      final newTasks = List<dynamic>.from(data['tasks']);

      for (final task in newTasks) {
        final status = task['status']?.toString() ?? '';

        if (task['completed'] == true ||
            status == 'skipped' ||
            status == 'needs_caregiver_review' ||
            status == 'escalated' ||
            status.startsWith('missed')) {
          continue;
        }

        final taskId = task['id']?.toString() ?? "";
        final currentCount = task['reminder_count'] ?? 0;
        final lastCount = _lastPlayedCounts[taskId] ?? 0;

        if (currentCount > lastCount) {
          final dedupeKey =
              '${taskId}_${DateTime.now().hour}_${DateTime.now().minute}';

          if (_spokenReminderIds.contains(dedupeKey)) {
            debugPrint(
              "🔊 FIRESTORE SYNC: Skipping duplicate $taskId "
              "[Key: $dedupeKey]",
            );

            _lastPlayedCounts[taskId] = currentCount;
            continue;
          }

          _spokenReminderIds.add(dedupeKey);

          debugPrint(
            "🔊 FIRESTORE SYNC: Triggering $taskId [Key: $dedupeKey]",
          );

          _handleManualReminderTrigger(
            elderId,
            task,
            dedupeKey: dedupeKey,
          );

          _lastPlayedCounts[taskId] = currentCount;
        }
      }

      updateTasks(newTasks);
    }, onError: (e) {
      debugPrint("VoiceReminderService: Firestore listen error: $e");
    });
  }

  void _handleManualReminderTrigger(
    String uid,
    Map<String, dynamic> task, {
    bool forgotten = false,
    String? dedupeKey,
  }) {
    final taskName = task['task_name'] ?? task['taskName'] ?? "Task";
    final category = task['type'] ?? task['category'] ?? "common";
    final taskId = task['id'] ?? task['taskId'] ?? "";

    final baseUrl = UserService().baseUrl;

    final text = forgotten
        ? "Pardon me, it seems you have forgotten your $taskName"
        : "It is time for your $taskName. Please complete your $taskName";

    final encodedText = Uri.encodeComponent(text);

    final audioUrl =
        "$baseUrl/api/audio/generate?text=$encodedText&category=$category&forgotten=$forgotten";

    _enqueueOpenAiReminder(
      taskId: taskId.toString(),
      taskName: taskName,
      text: text,
      audioUrl: audioUrl,
      category: category,
      dedupeKey: dedupeKey,
    );
  }

  void start(String uid) async {
    _currentUid = uid;

    if (!kIsWeb) {
      try {
        final token = await FirebaseMessaging.instance.getToken();

        if (token != null) {
          await UserService().updateFCMToken(uid, token);
        }
      } catch (e) {
        debugPrint("VoiceReminderService: FCM error: $e");
      }
    }

    _fcmSubscription?.cancel();
    _fcmSubscription = FirebaseMessaging.onMessage.listen(_handleVoiceReminder);

    FirebaseMessaging.onMessageOpenedApp.listen(_handleVoiceReminder);
  }

  Future<void> _handleVoiceReminder(RemoteMessage message) async {
    if (message.data['type'] != 'VOICE_REMINDER') return;

    final taskName = message.data['taskName'] ?? 'Task';
    final taskId = message.data['taskId'] ?? '';
    final audioUrl = message.data['audioUrl'] ?? '';
    final category = message.data['category'] ?? 'common';
    final text = message.data['text'] ?? "Time for $taskName";

    final now = DateTime.now();
    final dedupeKey = '${taskId}_${now.hour}_${now.minute}';

    if (_spokenReminderIds.contains(dedupeKey)) {
      debugPrint("🔊 FCM SYNC: Skipping duplicate $taskName [Key: $dedupeKey]");
      return;
    }

    _spokenReminderIds.add(dedupeKey);

    debugPrint("🔊 FCM SYNC: Triggering $taskName [Key: $dedupeKey]");

    _enqueueOpenAiReminder(
      taskId: taskId,
      taskName: taskName,
      text: text,
      audioUrl: audioUrl,
      category: category,
      dedupeKey: dedupeKey,
    );
  }

  void _enqueueOpenAiReminder({
    required String taskId,
    required String taskName,
    required String text,
    required String audioUrl,
    required String category,
    String? dedupeKey,
  }) {
    debugPrint("🔊 QUEUED OPENAI REMINDER: $taskName");

    _audioQueue.add({
      'voiceType': 'OPENAI_REMINDER',
      'taskId': taskId,
      'taskName': taskName,
      'text': text,
      'audioUrl': audioUrl,
      'category': category,
      'dedupeKey': dedupeKey,
    });

    _processAudioQueue();
  }

  void _enqueueFlutterTts({
    required String text,
    required String taskName,
    String category = 'urgent',
  }) {
    debugPrint("🔊 QUEUED FLUTTERTTS QUESTION: $taskName");

    _audioQueue.add({
      'voiceType': 'FLUTTER_TTS',
      'taskName': taskName,
      'text': text,
      'category': category,
    });

    _processAudioQueue();
  }

  Future<void> _processAudioQueue() async {
    if (_isProcessingQueue) return;

    _isProcessingQueue = true;

    while (_audioQueue.isNotEmpty) {
      final item = _audioQueue.removeAt(0);

      final voiceType = item['voiceType'];
      final taskName = item['taskName'] ?? 'Task';
      final text = item['text'] ?? "Time for $taskName";
      final category = item['category'] ?? 'common';

      try {
        if (voiceType == 'FLUTTER_TTS') {
          debugPrint("🔊 PLAYING FLUTTERTTS VERIFICATION QUESTION: $taskName");

          try {
            await _audioPlayer.stop();
          } catch (_) {}

          await _voiceService.speak(
            text,
            category: category,
          );

          await Future.delayed(const Duration(seconds: 1));
        } else if (voiceType == 'OPENAI_REMINDER') {
          debugPrint("🔊 PLAYING OPENAI REMINDER ONLY: $taskName");

          final audioUrl = item['audioUrl'] ?? '';
          bool openAiSuccess = false;

          try {
            if (audioUrl.toString().isNotEmpty) {
              await _voiceService.stop();
              await _audioPlayer.stop();
              await _audioPlayer.setVolume(1.0);

              await _audioPlayer
                  .play(UrlSource(audioUrl))
                  .timeout(const Duration(seconds: 15));

              await _audioPlayer.onPlayerComplete.first.timeout(
                const Duration(seconds: 25),
                onTimeout: () {
                  throw TimeoutException(
                    "OpenAI audio completion timeout for $taskName",
                  );
                },
              );

              openAiSuccess = true;
            } else {
              debugPrint("🔊 Empty OpenAI audio URL for reminder: $taskName");
            }
          } catch (e) {
            debugPrint("🔊 OpenAI TTS failed for reminder $taskName: $e");

            try {
              await _audioPlayer.stop();
            } catch (_) {}

            openAiSuccess = false;
          }

          if (!openAiSuccess) {
            debugPrint(
              "🔊 FlutterTTS skipped for reminder: $taskName. "
              "FlutterTTS is reserved only for verification questions.",
            );
          }

          await Future.delayed(const Duration(seconds: 1));
        }
      } catch (e) {
        debugPrint("VoiceReminderService: Queue playback error: $e");
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
    _pendingTaskStateChangeIds.clear();
    _audioQueue.clear();
    _lastPlayedCounts.clear();

    _voiceService.stop();
    _audioPlayer.dispose();
  }

  /// Generalized resync to handle Later, Skip, and Completion.
  /// Stops current voice reminders and clears local states immediately.
  Future<void> resyncAfterTaskStateChange(
    String uid,
    String taskId, {
    List<dynamic>? updatedTasks,
    String? reason,
  }) async {
    debugPrint("🔊 VoiceReminderService: Resyncing $taskId. Reason: ${reason ?? 'Unknown'}");

    // 1. Add to pending guard immediately
    _pendingTaskStateChangeIds.add(taskId);

    // 2. Clear immediate spoken state so we don't repeat the old reminder
    _spokenReminderIds.removeWhere((key) => key.startsWith(taskId));
    _lastPlayedCounts.remove(taskId);

    // 3. Stop current audio playback if it relates to this task
    try {
      if (_audioQueue.any((item) => item['taskId'] == taskId)) {
        _audioQueue.removeWhere((item) => item['taskId'] == taskId);
        debugPrint("🔊 VoiceReminderService: Removed $taskId from audio queue.");
      }
      // Note: We don't stop the player immediately here as it might be playing something else,
      // but the queue removal prevents NEXT items for this task.
    } catch (e) {
      debugPrint("VoiceReminderService: Error clearing audio for task: $e");
    }

    // 4. Cancel local notifications immediately
    for (int i = 0; i < 5; i++) {
      final notifId = NotificationService.makeId(uid, taskId, i);
      await _notificationService.cancel(notifId);
    }

    // 5. If fresh data provided, update and potentially clear guard
    if (updatedTasks != null) {
      updateTasks(updatedTasks);
    }
  }

  // Backward compatibility wrapper
  Future<void> resyncAfterTaskReschedule(String uid, String taskId, {List<dynamic>? updatedTasks}) async {
    return resyncAfterTaskStateChange(uid, taskId, updatedTasks: updatedTasks, reason: "reschedule");
  }

  Future<void> _scheduleNotificationsForTasks() async {
    await _notificationService.init();

    for (final task in _tasks) {
      final status = task['status']?.toString() ?? '';

      if (task['completed'] == true ||
          status == 'skipped' ||
          status == 'needs_caregiver_review' ||
          status == 'escalated') {
        continue;
      }

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

            scheduledTime = DateTime(
              now.year,
              now.month,
              now.day,
              int.parse(parts[0]),
              int.parse(parts[1]),
            );
          }
        }
      } catch (e) {
        debugPrint(
          "VoiceReminderService: Notification schedule parse error: $e",
        );
        continue;
      }

      if (scheduledTime != null && scheduledTime.isAfter(now)) {
        final taskIdStr =
            task['id']?.toString() ?? task['task_name']?.toString() ?? "";

        final notifId = NotificationService.makeId(
          task['uid'] ?? "user",
          taskIdStr,
          0,
        );

        await _notificationService.scheduleNotification(
          id: notifId,
          title: "Reminder",
          body: "reminder, it is time for your ${task['task_name']}",
          scheduledTime: scheduledTime,
        );
      }
    }
  }
}