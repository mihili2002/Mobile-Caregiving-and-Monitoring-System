import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/behavior_service.dart';
import '../../services/notification_service.dart';
import '../../services/routine_service.dart';
import '../../services/schedule_service.dart';
import '../../services/user_service.dart';
import '../../services/voice_reminder_service.dart';
import '../../services/voice_service.dart';
import 'schedule_history_page.dart';
import 'voice_chatbot_page.dart';
import 'widgets/task_skip_review_widget.dart';

const skipReasonOptions = [
  'not_feeling_well',
  'not_available',
  'already_done_uncertain',
  'out_of_medicine',
  'elder_refused',
  'caregiver_skipped',
  'other',
];

class DailyRoutinePage extends StatefulWidget {
  final String? elderId;
  final String? elderName;
  final DateTime? initialDate;

  const DailyRoutinePage({
    super.key,
    this.elderId,
    this.elderName,
    this.initialDate,
  });

  @override
  State<DailyRoutinePage> createState() => _DailyRoutinePageState();
}

class _DailyRoutinePageState extends State<DailyRoutinePage>
    with SingleTickerProviderStateMixin {
  final RoutineService _routineService = RoutineService();
  final ScheduleService _scheduleService = ScheduleService();
  final VoiceService _voiceService = VoiceService();
  final NotificationService _notificationService = NotificationService();
  final BehaviorService _behaviorService = BehaviorService();

  late final String effectiveUid;
  Timer? _timer;

  bool _isPlanningMode = false;
  bool _isLoading = false;
  bool _hasError = false;

  late DateTime _selectedDate;
  List<dynamic> _dailyTasks = [];

  List<Map<String, dynamic>> _planningCommon = [];
  List<Map<String, dynamic>> _planningMeds = [];
  List<Map<String, dynamic>> _planningTherapy = [];

  final Set<String> _selectedCommonIds = {};
  List<dynamic> _insights = [];
  bool _insightsFetched = false; // Guard: only fetch insights once per session

  String _riskTier = "Tier 1";
  String _voiceSessionId = "";

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate ?? DateTime.now();
    effectiveUid = widget.elderId ?? FirebaseAuth.instance.currentUser!.uid;
    _voiceSessionId = "${effectiveUid}_routine_followup";
    _loadCachedTier();
    _initServices();
  }

  Future<void> _loadCachedTier() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedTier = prefs.getString('cached_risk_tier');
    if (cachedTier != null && mounted) {
      setState(() => _riskTier = cachedTier);
      debugPrint("DailyRoutinePage: Pre-loaded Risk Tier from Cache: $cachedTier");
    }
  }

  Future<void> _initServices() async {
    await _voiceService.init();
    await _notificationService.init();

    if (mounted) {
      _fetchSchedule();
      _fetchRiskProfile();
      VoiceReminderService().listen(effectiveUid);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _voiceService.stop();
    super.dispose();
  }

  Future<void> _fetchRiskProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final UserService userService = UserService();
      final baseUrl = userService.baseUrl;

      final url = Uri.parse("$baseUrl/api/ai/check_profile/$effectiveUid");
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint("Profile Debug: received data: $data");

        if (data is Map && data['exists'] == true && data['data'] is Map) {
          final Map<String, dynamic> profileMap = data['data'];
          final freshTier =
              profileMap['prediction_tier']?.toString() ?? "Tier 1";
          final freshProb = profileMap['prediction_probability'];

          await prefs.setString('cached_risk_tier', freshTier);
          if (freshProb != null) {
            final p = (freshProb is int) ? freshProb.toDouble() : freshProb as double;
            await prefs.setDouble('cached_risk_prob', p);
          }

          if (freshTier != _riskTier && mounted) {
            setState(() => _riskTier = freshTier);
            debugPrint("Updated Risk Tier from Network: $_riskTier");
            _scheduleTieredReminders();
          }
        }
      }
    } catch (e) {
      debugPrint("Error fetching profile: $e");
    }
  }

  bool get _isPast {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selected =
        DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    return selected.isBefore(today);
  }

  bool get _isToday {
    final now = DateTime.now();
    return _selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day;
  }

  Future<void> _fetchSchedule() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    var data = await _scheduleService.getSchedule(effectiveUid, _selectedDate);

    if (data == null && _isPast) {
      debugPrint(
          "DailyRoutinePage: API failed for past date, checking Firestore...");
      final firestoreData =
          await _scheduleService.getScheduleFromFirestore(
              effectiveUid, _selectedDate);
      if (firestoreData != null) {
        data = firestoreData;
      }
    }

    if (data == null) {
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
      return;
    }

    final tasks = List<dynamic>.from(data['tasks'] ?? []);
    setState(() {
      _dailyTasks = tasks;
    });

    if (tasks.isEmpty && !_isPast) {
      await _enterPlanningMode();
    } else {
      setState(() {
        _isPlanningMode = false;
        _isLoading = false;
      });
    }

    if (mounted && _isToday) {
      VoiceReminderService().updateTasks(tasks);
    }

    if (!_isPlanningMode) {
      _scheduleTieredReminders();
      _checkInsights();
    }
  }

  Future<void> _checkInsights() async {
    // Only fetch insights once per page session to avoid repeated API calls
    if (_insightsFetched) return;
    _insightsFetched = true;

    final insights = await _behaviorService.getInsights();
    if (insights.isNotEmpty && mounted) {
      setState(() => _insights = insights);
    }
  }

  Future<void> _enterPlanningMode() async {
    final suggestions =
        await _routineService.getDailySuggestions(effectiveUid) ?? {};

    if (!mounted) return;

    setState(() {
      final rawCommon = suggestions['common'] as List? ?? [];
      final Map<String, Map<String, dynamic>> uniqueCommon = {};

      for (final x in rawCommon) {
        final item = Map<String, dynamic>.from(x);
        final name =
            (item['task_name'] ?? "").toString().trim().toLowerCase();
        if (name.isNotEmpty && !uniqueCommon.containsKey(name)) {
          uniqueCommon[name] = item;
        }
      }

      _planningCommon = uniqueCommon.values.toList();
      _planningMeds = List<Map<String, dynamic>>.from(
        (suggestions['medications'] as List? ?? [])
            .map((x) => Map<String, dynamic>.from(x)),
      );
      _planningTherapy = List<Map<String, dynamic>>.from(
        (suggestions['therapy'] as List? ?? [])
            .map((x) => Map<String, dynamic>.from(x)),
      );

      _isPlanningMode = true;
      _isLoading = false;
      _selectedCommonIds.clear();

      for (final t in _planningTherapy) {
        if (t['time'] == null) t['time'] = "10:00";
      }
    });
  }

  void _adaptMedicationTimes() {
    String? breakfastTime;
    String? lunchTime;
    String? dinnerTime;

    for (final c in _planningCommon) {
      final name = c['task_name'].toString().toLowerCase();
      final time = c['default_time'];

      if (name.contains("breakfast")) breakfastTime = time;
      if (name.contains("lunch")) lunchTime = time;
      if (name.contains("dinner")) dinnerTime = time;
    }

    for (final m in _planningMeds) {
      final label = m['timing_label'].toString().toLowerCase();
      String? baseTime;

      if (label.contains("breakfast")) baseTime = breakfastTime;
      if (label.contains("lunch")) baseTime = lunchTime;
      if (label.contains("dinner")) baseTime = dinnerTime;

      if (baseTime != null) {
        try {
          final parts = baseTime.split(':');
          final dt = DateTime(
            2022,
            1,
            1,
            int.parse(parts[0]),
            int.parse(parts[1]),
          );
          var newDt = dt;

          if (label.contains("before")) {
            newDt = dt.subtract(const Duration(minutes: 30));
          }
          if (label.contains("after")) {
            newDt = dt.add(const Duration(minutes: 30));
          }

          m['time'] =
              "${newDt.hour.toString().padLeft(2, '0')}:${newDt.minute.toString().padLeft(2, '0')}";
        } catch (e) {
          debugPrint("Time calc error: $e");
        }
      }
    }
  }

  Future<void> _savePlan() async {
    setState(() => _isLoading = true);

    try {
      final List<Map<String, dynamic>> allTasksForFirestore = [];

      for (final c in _planningCommon) {
        if (_selectedCommonIds.contains(c['id'].toString())) {
          final task = {
            "task_name": c['task_name'],
            "time": c['default_time'],
            "type": "common",
            "completed": false,
            "id":
                "${effectiveUid}_common_${c['id']}_${DateTime.now().microsecondsSinceEpoch}",
            "scheduledAt":
                _combineDateAndTime(_selectedDate, c['default_time']),
            "graceMinutes": 30,
            "status": "scheduled",
          };
          await _scheduleService.addTask(effectiveUid, _selectedDate, task);
          allTasksForFirestore.add(task);
        }
      }

      for (final m in _planningMeds) {
        final task = {
          "task_name": "${m['drug_name']} ${m['dosage'] ?? ''}".trim(),
          "time": m['time'],
          "type": "medication",
          "completed": false,
          "subtitle": m['timing_label'],
          "id":
              "${effectiveUid}_med_${m['id']}_${DateTime.now().microsecondsSinceEpoch}",
          "scheduledAt": _combineDateAndTime(_selectedDate, m['time']),
          "graceMinutes": 60,
          "status": "scheduled",
        };
        await _scheduleService.addTask(effectiveUid, _selectedDate, task);
        allTasksForFirestore.add(task);
      }

      for (final t in _planningTherapy) {
        final task = {
          "task_name": t['activity_name'],
          "time": t['time'],
          "type": "therapy",
          "completed": false,
          "subtitle": t['duration'],
          "id":
              "${effectiveUid}_therapy_${t['id']}_${DateTime.now().microsecondsSinceEpoch}",
          "scheduledAt": _combineDateAndTime(_selectedDate, t['time']),
          "graceMinutes": 15,
          "status": "scheduled",
        };
        await _scheduleService.addTask(effectiveUid, _selectedDate, task);
        allTasksForFirestore.add(task);
      }

      await _scheduleService.saveScheduleToFirestore(
        effectiveUid,
        _selectedDate,
        allTasksForFirestore,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Daily Plan Created!")),
        );

        final user = await UserService().getUser(effectiveUid);
        if (user != null) {
          // await the push so _fetchSchedule() fires exactly once, after dismissal
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => VoiceChatbotPage(
                user: user,
                initialPrompt:
                    "Your plan is ready. Is there anything to add additionally into your today's plan, like appointments or calls?",
              ),
            ),
          );
        }
        // Single refresh after returning from the chatbot
        if (mounted) _fetchSchedule();
      }
    } catch (e) {
      debugPrint("Error saving plan: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return "Good Morning!";
    if (hour < 17) return "Good Afternoon!";
    return "Good Evening!";
  }

  String get _dateTitle {
    if (_isToday) return "Today's Plan";

    final now = DateTime.now();
    final tomorrow = now.add(const Duration(days: 1));

    if (_selectedDate.year == tomorrow.year &&
        _selectedDate.month == tomorrow.month &&
        _selectedDate.day == tomorrow.day) {
      return "Tomorrow's Plan";
    }

    return "${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}";
  }

  void _changeDate(int offset) {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: offset));
    });
    _fetchSchedule();
  }

  List<int> _getTierOffsets(String tier) {
    if (tier.contains("Tier 3") || tier.contains("High")) return [0, 10, 20];
    if (tier.contains("Tier 2")) return [0, 15];
    return [0];
  }

  void _scheduleTieredReminders() async {
    if (_dailyTasks.isEmpty) return;

    await _notificationService.cancelAll();

    final offsets = _getTierOffsets(_riskTier);

    for (final t in _dailyTasks) {
      final bool isCompleted = t['completed'] == true;
      final String rawStatus = (t['status'] ?? '').toString().trim();
      final String normalizedStatus = _normalizeStatus(rawStatus, isCompleted);

      if (isCompleted) continue;
      if (_isTerminalStatus(normalizedStatus)) continue;

      DateTime? scheduledTime;
      try {
        if (t['scheduledAt'] != null) {
          scheduledTime = DateTime.parse(t['scheduledAt']);
        } else if (t['time'] != null && t['time'].toString().contains(":")) {
          final now = DateTime.now();
          final parts = t['time'].split(":");
          scheduledTime = DateTime(
            now.year,
            now.month,
            now.day,
            int.parse(parts[0]),
            int.parse(parts[1]),
          );
        }
      } catch (_) {
        continue;
      }

      if (scheduledTime == null) continue;

      for (int i = 0; i < offsets.length; i++) {
        final offset = offsets[i];
        final remindTime = scheduledTime.add(Duration(minutes: offset));

        if (remindTime.isAfter(DateTime.now())) {
          final id = NotificationService.makeId(effectiveUid, t['id'], i);

          String title = "Reminder";
          String body = "Time for ${t['task_name']}";
          if (offset > 0) {
            title = "Follow-up Reminder";
            body = "You haven't finished ${t['task_name']} yet.";
          }

          _notificationService.scheduleNotification(
            id: id,
            title: title,
            body: body,
            scheduledTime: remindTime,
          );
        }
      }
    }
  }

  void _cancelTaskNotifications(String taskId) async {
    for (int i = 0; i < 5; i++) {
      final id = NotificationService.makeId(effectiveUid, taskId, i);
      await _notificationService.cancel(id);
    }
  }

  bool _isTerminalStatus(String status) {
    return const {
      'completed',
      'completed_confirmed',
      'completed_likely',
      'skipped',
      'missed_likely',
      'missed_confirmed',
      'needs_caregiver_review',
      'escalated',
      'snoozed',
      'in_progress',
    }.contains(status);
  }

  String _normalizeStatus(String? rawStatus, bool isCompleted) {
    final status = (rawStatus ?? '').trim();

    if (status.isEmpty) {
      return isCompleted ? 'completed_confirmed' : 'scheduled';
    }

    switch (status) {
      case 'pending':
        return isCompleted ? 'completed_confirmed' : 'scheduled';
      case 'acknowledged':
        return 'reminder_triggered';
      case 'reminder_sent':
        return 'reminder_triggered';
      default:
        return status;
    }
  }

  bool _showDone(String status, bool isCompleted) {
    if (isCompleted) return false;

    return const {
      'scheduled',
      'upcoming',
      'reminder_triggered',
      'snoozed',
      'in_progress',
      'needs_caregiver_review',
      'escalated',
    }.contains(status);
  }

  bool _showLater(String status, bool isCompleted) {
    if (isCompleted) return false;

    return const {
      'scheduled',
      'upcoming',
      'reminder_triggered',
      'snoozed',
      'missed_likely',
      'missed_confirmed',
      'needs_caregiver_review',
    }.contains(status);
  }

  bool _showDoingNow(String status, bool isCompleted) {
    if (isCompleted) return false;

    return const {
      'scheduled',
      'upcoming',
      'reminder_triggered',
      'snoozed',
      'needs_caregiver_review',
    }.contains(status);
  }

  bool _showSkip(String status, bool isCompleted) {
    if (isCompleted) return false;

    return const {
      'scheduled',
      'upcoming',
      'reminder_triggered',
      'snoozed',
      'missed_likely',
      'missed_confirmed',
      'needs_caregiver_review',
      'escalated',
    }.contains(status);
  }

  String _buildSkipReasonText(Map<String, dynamic> task) {
    final dynamic reasons = task['skipReasons'];

    if (reasons is List && reasons.isNotEmpty) {
      return reasons.map((e) => e.toString().replaceAll('_', ' ')).join(', ');
    }

    final singleReason = (task['skipReason'] ?? '').toString().trim();
    if (singleReason.isNotEmpty) {
      return singleReason.replaceAll('_', ' ');
    }

    return '—';
  }

  String _buildDecisionByText(Map<String, dynamic> task) {
    final decisionBy =
        (task['skipDecisionBy'] ?? task['lastSkipDecisionBy'] ?? '')
            .toString()
            .trim();

    if (decisionBy.isEmpty) return '—';
    return decisionBy;
  }

  String _formatSkippedAt(dynamic raw) {
    if (raw == null) return '—';

    final value = raw.toString().trim();
    if (value.isEmpty) return '—';

    try {
      final parsed = DateTime.parse(value).toLocal();
      final day = parsed.day.toString().padLeft(2, '0');
      final month = parsed.month.toString().padLeft(2, '0');
      final year = parsed.year.toString();
      final hour = parsed.hour.toString().padLeft(2, '0');
      final minute = parsed.minute.toString().padLeft(2, '0');
      return '$day/$month/$year $hour:$minute';
    } catch (_) {
      return value;
    }
  }

  Future<void> _showVoiceReplyDialog(String message) async {
    if (!mounted) return;

    try {
      await _voiceService.speak(message);
    } catch (_) {}

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Alex"),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  Future<void> _showRescheduleVoiceConversation(
      String taskId, String initialPrompt) async {
    if (!mounted) return;

    final List<Map<String, String>> laterConversation = [];
    laterConversation.add({"speaker": "alex", "text": initialPrompt});

    String currentPrompt = initialPrompt;
    bool flowStarted = false;
    bool isListening = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setStateSheet) {
            if (!flowStarted) {
              flowStarted = true;
              Future.microtask(() async {
                while (ctx.mounted) {
                  await _voiceService.speak(currentPrompt);

                  if (!ctx.mounted) break;
                  setStateSheet(() {
                    isListening = true;
                  });

                  final heardText = await _voiceService.listenOnce(
                    listenFor: const Duration(seconds: 8),
                    pauseFor: const Duration(seconds: 3),
                  );

                  if (!ctx.mounted) break;
                  setStateSheet(() {
                    isListening = false;
                  });

                  if (heardText == null || heardText.trim().isEmpty) {
                    currentPrompt =
                        "I didn't catch that. Please say the time again.";
                    setStateSheet(() {
                      laterConversation
                          .add({"speaker": "alex", "text": currentPrompt});
                    });
                    continue;
                  }

                  setStateSheet(() {
                    laterConversation.add({"speaker": "elder", "text": heardText});
                  });

                  final result = await _scheduleService.sendVoiceCommand(
                    uid: effectiveUid,
                    text: heardText,
                    sessionId: _voiceSessionId,
                    localTime: DateTime.now(),
                  );

                  if (result == null) {
                    const failMsg =
                        "Sorry, I couldn't update the time right now.";
                    setStateSheet(() {
                      laterConversation.add({"speaker": "alex", "text": failMsg});
                    });
                    await _voiceService.speak(failMsg);
                    await Future.delayed(const Duration(seconds: 2));
                    if (ctx.mounted) Navigator.pop(ctx);
                    return;
                  }

                  final reply = result['reply']?.toString() ?? "Okay.";
                  final intent = result['intent']?.toString() ?? "";

                  setStateSheet(() {
                    laterConversation.add({"speaker": "alex", "text": reply});
                  });

                  if (intent == "task_rescheduled") {
                    await _voiceService.speak(reply);
                    await VoiceReminderService().resyncAfterTaskReschedule(
                      effectiveUid,
                      taskId,
                    );
                    await _fetchSchedule();
                    await Future.delayed(const Duration(seconds: 2));
                    if (ctx.mounted) Navigator.pop(ctx);
                    return;
                  }

                  if (intent == "task_followup" ||
                      intent == "task_followup_confirmation") {
                    currentPrompt = reply;
                    continue;
                  }

                  await _voiceService.speak(reply);
                  await _fetchSchedule();
                  await Future.delayed(const Duration(seconds: 2));
                  if (ctx.mounted) Navigator.pop(ctx);
                  return;
                }
              });
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
                left: 16,
                right: 16,
                top: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Reschedule Task",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(ctx).size.height * 0.4,
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: laterConversation.length,
                      itemBuilder: (context, index) {
                        final msg = laterConversation[index];
                        final isAlex = msg['speaker'] == 'alex';
                        return Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          alignment: isAlex
                              ? Alignment.centerLeft
                              : Alignment.centerRight,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: isAlex
                                  ? Colors.teal.shade50
                                  : Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(16).copyWith(
                                bottomLeft: isAlex
                                    ? const Radius.circular(0)
                                    : const Radius.circular(16),
                                bottomRight: !isAlex
                                    ? const Radius.circular(0)
                                    : const Radius.circular(16),
                              ),
                              border: Border.all(
                                color: isAlex
                                    ? Colors.teal.shade200
                                    : Colors.blue.shade200,
                              ),
                            ),
                            child: Text(
                              msg['text'] ?? "",
                              style: TextStyle(
                                fontSize: 16,
                                color: isAlex
                                    ? Colors.teal.shade900
                                    : Colors.blue.shade900,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (isListening)
                    const Column(
                      children: [
                        Icon(Icons.mic, color: Colors.redAccent, size: 48),
                        SizedBox(height: 8),
                        Text(
                          "Listening...",
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    )
                  else
                    const SizedBox(height: 72),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () {
                      _voiceService.stop();
                      Navigator.pop(ctx);
                    },
                    child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _handleCompleteTask(String taskId) async {
    final dateStr = _selectedDate.toIso8601String().split('T')[0];
    await _scheduleService.completeTask(
      uid: effectiveUid,
      date: dateStr,
      taskId: taskId,
    );
    _cancelTaskNotifications(taskId);
    _fetchSchedule();
  }

  Future<void> _handleLaterTask(String taskId) async {
    final dateStr = _selectedDate.toIso8601String().split('T')[0];

    final result = await _scheduleService.requestTaskLater(
      uid: effectiveUid,
      date: dateStr,
      taskId: taskId,
      sessionId: _voiceSessionId,
    );

    if (result == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't start the reschedule conversation.")),
      );
      return;
    }

    final reply = result['reply']?.toString() ??
        "Alright. Then, at what time would you like to complete this task?";

    await _showRescheduleVoiceConversation(taskId, reply);
  }

  Future<void> _handleStartTask(String taskId) async {
    final dateStr = _selectedDate.toIso8601String().split('T')[0];
    await _scheduleService.startTask(
      uid: effectiveUid,
      date: dateStr,
      taskId: taskId,
    );
    _fetchSchedule();
  }

  Future<void> _handleSkipTask(
    String taskId, {
    required Map<String, dynamic> task,
  }) async {
    final skipData = await _showSkipDialog(context);
    if (skipData == null) return;

    final dateStr = _selectedDate.toIso8601String().split('T')[0];
    final reasons = skipData['reasons'] as List<String>;
    final decisionBy = skipData['decisionBy'] as String;
    final caregiverNote = skipData['caregiverNote'] as String?;

    try {
      final result = await _scheduleService.skipTask(
        uid: effectiveUid,
        date: dateStr,
        taskId: taskId,
        reasons: reasons,
        decisionBy: decisionBy,
        caregiverNote: caregiverNote,
      );

      final resultStatus = result['status'];

      if (resultStatus == 'confirmation_required') {
        if (!mounted) return;

        final taskName = task['task_name'] ?? 'this task';
        final bool willNotifyCaregiver = task['escalateOnSkip'] == true ||
            task['notifyCaregiverOnSkip'] == true ||
            task['type'] == 'medication';

        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: const [
                Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
                SizedBox(width: 10),
                Text('Skip Task?'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  result['message'] ??
                      'Are you sure you want to skip "$taskName"?',
                  style: const TextStyle(fontSize: 15),
                ),
                if (willNotifyCaregiver) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.info_outline, color: Colors.orange, size: 18),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Your caregiver may be informed about this skip.',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.deepOrange,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Yes, Skip'),
              ),
            ],
          ),
        );

        if (confirmed == true) {
          await _scheduleService.skipTask(
            uid: effectiveUid,
            date: dateStr,
            taskId: taskId,
            reasons: reasons,
            decisionBy: decisionBy,
            caregiverNote: caregiverNote,
            confirmed: true,
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Task skipped.')),
            );
          }
        } else {
          return;
        }
      } else if (resultStatus == 'blocked') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ??
                  'This task cannot be skipped right now.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Task skipped successfully.')),
          );
        }
      }

      _cancelTaskNotifications(taskId);
      _fetchSchedule();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error skipping task: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _statusLabel(String status, bool isCompleted) {
    switch (status) {
      case 'scheduled':
        return "Scheduled";
      case 'upcoming':
        return "Coming up";
      case 'snoozed':
        return "Delayed";
      case 'in_progress':
        return "In progress";
      case 'completed':
      case 'completed_confirmed':
        return "Completed";
      case 'completed_likely':
        return "Probably completed";
      case 'skipped':
        return "Skipped";
      case 'missed_likely':
      case 'missed_confirmed':
        return "Missed";
      case 'needs_caregiver_review':
        return "Needs review";
      case 'escalated':
        return "Caregiver informed";
      default:
        return isCompleted ? "Completed" : "Scheduled";
    }
  }

  Color _statusColor(String status, bool isCompleted) {
    switch (status) {
      case 'scheduled':
      case 'upcoming':
      case 'reminder_triggered':
        return Colors.teal;
      case 'snoozed':
        return Colors.orange;
      case 'in_progress':
        return Colors.blue;
      case 'completed':
      case 'completed_confirmed':
      case 'completed_likely':
        return Colors.green;
      case 'skipped':
        return Colors.red;
      case 'missed_likely':
      case 'missed_confirmed':
      case 'escalated':
        return Colors.red;
      case 'needs_caregiver_review':
        return Colors.purple;
      default:
        return isCompleted ? Colors.green : Colors.teal;
    }
  }

  IconData _statusIcon(String status, bool isCompleted) {
    switch (status) {
      case 'scheduled':
        return Icons.access_time;
      case 'upcoming':
        return Icons.upcoming;
      case 'reminder_triggered':
        return Icons.notifications_active;
      case 'snoozed':
        return Icons.snooze;
      case 'in_progress':
        return Icons.play_circle_outline;
      case 'completed':
      case 'completed_confirmed':
      case 'completed_likely':
        return Icons.check_circle;
      case 'skipped':
        return Icons.skip_next;
      case 'missed_likely':
      case 'missed_confirmed':
        return Icons.cancel;
      case 'needs_caregiver_review':
        return Icons.notification_important;
      case 'escalated':
        return Icons.warning;
      default:
        return isCompleted ? Icons.check_circle : Icons.access_time;
    }
  }

  Future<void> _handleCaregiverSkipTask(
    String taskId, {
    required Map<String, dynamic> task,
  }) async {
    final skipData =
        await _showSkipDialog(context, initialDecisionBy: 'caregiver');
    if (skipData == null) return;

    final dateStr = _selectedDate.toIso8601String().split('T')[0];
    final reasons = skipData['reasons'] as List<String>;
    final decisionBy = skipData['decisionBy'] as String;
    final caregiverNote = skipData['caregiverNote'] as String?;

    try {
      await _scheduleService.skipTask(
        uid: effectiveUid,
        date: dateStr,
        taskId: taskId,
        reasons: reasons,
        decisionBy: decisionBy,
        caregiverNote: caregiverNote,
      );
      _cancelTaskNotifications(taskId);
      _fetchSchedule();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to skip: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<Map<String, dynamic>?> _showSkipDialog(
    BuildContext context, {
    String initialDecisionBy = 'elder',
  }) async {
    final selectedReasons = <String>{};
    String decisionBy = initialDecisionBy;
    final caregiverNoteController = TextEditingController();

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Skip task'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Why is this task being skipped?'),
                    const SizedBox(height: 8),
                    ...skipReasonOptions.map((reason) {
                      return CheckboxListTile(
                        value: selectedReasons.contains(reason),
                        title: Text(reason.replaceAll('_', ' ')),
                        controlAffinity: ListTileControlAffinity.leading,
                        onChanged: (checked) {
                          setState(() {
                            if (checked == true) {
                              selectedReasons.add(reason);
                            } else {
                              selectedReasons.remove(reason);
                            }
                          });
                        },
                      );
                    }),
                    const SizedBox(height: 12),
                    const Text('Decision by'),
                    RadioListTile<String>(
                      value: 'elder',
                      groupValue: decisionBy,
                      title: const Text('Elder'),
                      onChanged: (value) => setState(() => decisionBy = value!),
                    ),
                    RadioListTile<String>(
                      value: 'caregiver',
                      groupValue: decisionBy,
                      title: const Text('Caregiver'),
                      onChanged: (value) => setState(() => decisionBy = value!),
                    ),
                    if (decisionBy == 'caregiver') ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: caregiverNoteController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Caregiver note',
                          hintText:
                              'Explain why the caregiver decided to skip this task',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: selectedReasons.isEmpty ||
                          (decisionBy == 'caregiver' &&
                              caregiverNoteController.text.trim().isEmpty)
                      ? null
                      : () {
                          Navigator.pop(context, {
                            'reasons': selectedReasons.toList(),
                            'decisionBy': decisionBy,
                            'caregiverNote': caregiverNoteController.text.trim(),
                          });
                        },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildTaskTile(Map<String, dynamic> task) {
    final bool isCompleted = task['completed'] == true;
    final String rawStatus = (task['status'] ?? '').toString().trim();
    final String status = _normalizeStatus(rawStatus, isCompleted);
    final String time = task['time'] ?? "--:--";
    final String subtitle = task['subtitle'] ?? "";

    final statusColor = _statusColor(status, isCompleted);
    final statusIcon = _statusIcon(status, isCompleted);
    final statusLabel = _statusLabel(status, isCompleted);

    final bool showDone = _showDone(status, isCompleted);
    final bool showLater = _showLater(status, isCompleted);
    final bool showDoingNow = _showDoingNow(status, isCompleted);
    final bool showSkip = _showSkip(status, isCompleted);

    final String skipReasonText = _buildSkipReasonText(task);
    final String decisionByText = _buildDecisionByText(task);
    final String skippedAtText = _formatSkippedAt(task['skippedAt']);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            onLongPress: () => _confirmDeleteTask(task),
            leading: CircleAvatar(
              backgroundColor: statusColor.withOpacity(0.1),
              child: Icon(statusIcon, color: statusColor),
            ),
            title: Text(
              task['task_name'] ?? "Task",
              style: TextStyle(
                decoration: isCompleted ? TextDecoration.lineThrough : null,
                color: isCompleted ? Colors.grey : Colors.black87,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (subtitle.isNotEmpty)
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                if (statusLabel.isNotEmpty)
                  Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () => _updateTaskTime(task),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.teal.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.teal.withOpacity(0.3)),
                    ),
                    child: Text(
                      time,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.teal,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Checkbox(
                  value: isCompleted,
                  onChanged: (val) =>
                      _toggleTaskCompletion(task['id'], isCompleted),
                  activeColor: Colors.teal,
                ),
              ],
            ),
          ),
          if (showDone || showLater || showDoingNow || showSkip)
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (showDone)
                    ElevatedButton(
                      onPressed: () => _handleCompleteTask(task['id']),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Done'),
                    ),
                  if (showLater)
                    OutlinedButton(
                      onPressed: () => _handleLaterTask(task['id']),
                      child: const Text('Later'),
                    ),
                  if (showDoingNow)
                    OutlinedButton(
                      onPressed: () => _handleStartTask(task['id']),
                      child: const Text('Doing now'),
                    ),
                  if (showSkip) _buildElderSkipButton(task),
                ],
              ),
            ),
          if (showSkip && widget.elderId == null)
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (task['requireSkipConfirmation'] == true) ...[
                    const SizedBox(height: 6),
                    const Text(
                      'Skipping this task may require confirmation.',
                      style: TextStyle(fontSize: 12, color: Colors.orange),
                    ),
                  ],
                  if (task['notifyCaregiverOnSkip'] == true ||
                      task['escalateOnSkip'] == true ||
                      task['type'] == 'medication') ...[
                    const SizedBox(height: 4),
                    const Text(
                      'Your caregiver may be informed.',
                      style: TextStyle(fontSize: 12, color: Colors.redAccent),
                    ),
                  ],
                ],
              ),
            ),
          if (widget.elderId != null ||
              status == 'skipped' ||
              status == 'needs_caregiver_review' ||
              status == 'escalated')
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
              child: TaskSkipReviewWidget(
                task: {
                  ...task,
                  'status': status,
                  'skipReasonDisplay': skipReasonText,
                  'skipDecisionByDisplay': decisionByText,
                  'skippedAtDisplay': skippedAtText,
                },
                isCaregiverMode: widget.elderId != null,
                onCaregiverSkip: widget.elderId != null
                    ? () => _handleCaregiverSkipTask(task['id'], task: task)
                    : null,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildElderSkipButton(Map<String, dynamic> task) {
    final bool requireConfirmation = task['requireSkipConfirmation'] == true;

    if (requireConfirmation) {
      return OutlinedButton.icon(
        onPressed: () => _handleSkipTask(task['id'], task: task),
        icon: const Icon(Icons.block, size: 16, color: Colors.red),
        label: const Text('Skip', style: TextStyle(color: Colors.red)),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Colors.red),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }

    return TextButton(
      onPressed: () => _handleSkipTask(task['id'], task: task),
      child: const Text('Skip', style: TextStyle(color: Colors.red)),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.teal),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanningView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _isToday
                ? "Good day! Set up your schedule."
                : "Planning for $_dateTitle",
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.teal,
            ),
          ),
          const SizedBox(height: 16),
          _buildPlanSectionHeader("Section A: Routine Tasks", Icons.wb_sunny),
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text("Select tasks & adjust time."),
          ),
          ..._planningCommon.map((item) {
            final id = item['id'].toString();
            final isSelected = _selectedCommonIds.contains(id);

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Checkbox(
                  value: isSelected,
                  activeColor: Colors.teal,
                  onChanged: (val) {
                    setState(() {
                      if (val == true) {
                        _selectedCommonIds.add(id);
                      } else {
                        _selectedCommonIds.remove(id);
                      }
                    });
                  },
                ),
                title: Text(item['task_name']),
                trailing: OutlinedButton(
                  onPressed: () async {
                    String t = item['default_time'];
                    TimeOfDay initial = const TimeOfDay(hour: 8, minute: 0);
                    try {
                      initial = TimeOfDay(
                        hour: int.parse(t.split(':')[0]),
                        minute: int.parse(t.split(':')[1]),
                      );
                    } catch (_) {}

                    final p = await showTimePicker(
                      context: context,
                      initialTime: initial,
                    );
                    if (p != null) {
                      setState(() {
                        item['default_time'] =
                            "${p.hour.toString().padLeft(2, '0')}:${p.minute.toString().padLeft(2, '0')}";
                        _adaptMedicationTimes();
                      });
                    }
                  },
                  child: Text(item['default_time']),
                ),
              ),
            );
          }),
          const SizedBox(height: 24),
          _buildPlanSectionHeader("Section B: Medications", Icons.medication),
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text("Times adapt to your meals automatically."),
          ),
          if (_planningMeds.isEmpty)
            const Text(
              "No active medications.",
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
          ..._planningMeds.map((item) {
            return ListTile(
              leading: const Icon(Icons.check_circle, color: Colors.grey),
              title: Text("${item['drug_name']} ${item['dosage'] ?? ''}"),
              subtitle: Text(item['timing_label'] ?? ""),
              trailing: Text(
                item['time'],
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.teal,
                ),
              ),
            );
          }),
          const SizedBox(height: 24),
          _buildPlanSectionHeader("Section C: Therapy", Icons.accessibility),
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text("Choose your preferred time."),
          ),
          if (_planningTherapy.isEmpty)
            const Text(
              "No therapy assigned.",
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
          ..._planningTherapy.map((item) {
            return ListTile(
              leading: const Icon(Icons.check_circle, color: Colors.grey),
              title: Text(item['activity_name']),
              subtitle: Text(item['duration'] ?? ""),
              trailing: OutlinedButton(
                onPressed: () async {
                  String t = item['time'];
                  TimeOfDay initial = const TimeOfDay(hour: 10, minute: 0);
                  try {
                    initial = TimeOfDay(
                      hour: int.parse(t.split(':')[0]),
                      minute: int.parse(t.split(':')[1]),
                    );
                  } catch (_) {}

                  final p = await showTimePicker(
                    context: context,
                    initialTime: initial,
                  );
                  if (p != null) {
                    setState(() {
                      item['time'] =
                          "${p.hour.toString().padLeft(2, '0')}:${p.minute.toString().padLeft(2, '0')}";
                    });
                  }
                },
                child: Text(item['time']),
              ),
            );
          }),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
              ),
              onPressed: _savePlan,
              child: const Text(
                "Create My Day Plan",
                style: TextStyle(fontSize: 18),
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_off, color: Colors.grey, size: 60),
          const SizedBox(height: 16),
          const Text(
            "Connection Error",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            "We couldn't load your schedule.",
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _fetchSchedule,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
            ),
            child: const Text("Retry"),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Colors.teal),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildReadingView() {
    if (_dailyTasks.isEmpty) {
      return const Center(child: Text("No tasks scheduled for this day."));
    }

    final common = _dailyTasks
        .where((t) => t['type'] != 'medication' && t['type'] != 'therapy' && t['type'] != 'therapist')
        .toList();
    final meds = _dailyTasks.where((t) => t['type'] == 'medication').toList();
    final therapy = _dailyTasks
        .where((t) => t['type'] == 'therapy' || t['type'] == 'therapist')
        .toList();

    _dailyTasks.sort((a, b) => (a['time'] ?? "00:00").compareTo(b['time'] ?? "00:00"));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (common.isNotEmpty) ...[
            _buildSectionHeader("Today's Tasks", Icons.assignment),
            ...common.map((t) => _buildTaskTile(Map<String, dynamic>.from(t))),
            const SizedBox(height: 20),
          ],
          if (meds.isNotEmpty) ...[
            _buildSectionHeader("Medications", Icons.medication),
            ...meds.map((t) => _buildTaskTile(Map<String, dynamic>.from(t))),
            const SizedBox(height: 20),
          ],
          if (therapy.isNotEmpty) ...[
            _buildSectionHeader("Therapy", Icons.accessibility),
            ...therapy.map((t) => _buildTaskTile(Map<String, dynamic>.from(t))),
            const SizedBox(height: 20),
          ],
        ],
      ),
    );
  }

  Future<void> _deleteTask(String taskId) async {
    setState(() => _dailyTasks.removeWhere((t) => t['id'] == taskId));
    await _scheduleService.deleteTask(effectiveUid, _selectedDate, taskId);
    _cancelTaskNotifications(taskId);
  }

  void _confirmDeleteTask(Map<String, dynamic> task) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Task?"),
        content: Text("Delete '${task['task_name']}'?"),
        actions: [
          TextButton(
            child: const Text("Cancel"),
            onPressed: () => Navigator.pop(ctx),
          ),
          TextButton(
            child: const Text(
              "Delete",
              style: TextStyle(color: Colors.red),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _deleteTask(task['id']);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _updateTaskTime(Map<String, dynamic> task) async {
    String current = task['time'] ?? "08:00";
    TimeOfDay initial = const TimeOfDay(hour: 8, minute: 0);

    try {
      initial = TimeOfDay(
        hour: int.parse(current.split(':')[0]),
        minute: int.parse(current.split(':')[1]),
      );
    } catch (_) {}

    final p = await showTimePicker(
      context: context,
      initialTime: initial,
    );
    if (p != null) {
      final newTime =
          "${p.hour.toString().padLeft(2, '0')}:${p.minute.toString().padLeft(2, '0')}";
      setState(() => task['time'] = newTime);
      await _scheduleService.updateTask(
        effectiveUid,
        _selectedDate,
        task['id'],
        {"time": newTime},
      );
      _fetchSchedule();
    }
  }

  Future<void> _toggleTaskCompletion(String taskId, bool currentStatus) async {
    setState(() {
      final t = _dailyTasks.firstWhere((e) => e['id'] == taskId);
      t['completed'] = !currentStatus;
      t['status'] = !currentStatus ? 'completed_confirmed' : 'scheduled';
    });

    await _scheduleService.updateFirestoreTaskStatus(
      effectiveUid,
      _selectedDate,
      taskId,
      !currentStatus,
      status: !currentStatus ? 'completed_confirmed' : 'scheduled',
    );

    if (!currentStatus) {
      await _scheduleService.completeTask(
        uid: effectiveUid,
        date: _selectedDate.toIso8601String().split('T')[0],
        taskId: taskId,
      );
      _cancelTaskNotifications(taskId);
    } else {
      await _scheduleService.updateTaskStatus(
        effectiveUid,
        _selectedDate,
        taskId,
        false,
      );
      _scheduleTieredReminders();
    }

    _fetchSchedule();
  }

  int _calculateDelay(String? scheduledTimeStr, String? scheduledAtIso) {
    try {
      final now = DateTime.now();
      if (scheduledAtIso != null) {
        final scheduled = DateTime.parse(scheduledAtIso);
        return now.difference(scheduled).inMinutes;
      }
      if (scheduledTimeStr != null) {
        final parts = scheduledTimeStr.split(':');
        final scheduled = DateTime(
          now.year,
          now.month,
          now.day,
          int.parse(parts[0]),
          int.parse(parts[1]),
        );
        return now.difference(scheduled).inMinutes;
      }
    } catch (_) {}
    return 0;
  }

  String _combineDateAndTime(DateTime date, String timeStr) {
    try {
      final parts = timeStr.split(':');
      final dt = DateTime(
        date.year,
        date.month,
        date.day,
        int.parse(parts[0]),
        int.parse(parts[1]),
      );
      return dt.toIso8601String();
    } catch (_) {
      return DateTime.now().toIso8601String();
    }
  }

  String _getScheduleDocId() {
    final d =
        "${_selectedDate.day.toString().padLeft(2, '0')}.${_selectedDate.month.toString().padLeft(2, '0')}.${_selectedDate.year}";
    return "${effectiveUid}_$d";
  }

  String _determineCategory(String taskName) {
    final lower = taskName.toLowerCase();
    
    // Medication / Health
    if (lower.contains('pill') || lower.contains('vitamin') || lower.contains('medication') || lower.contains('medicine') || lower.contains('tablet') || lower.contains('syrup')) return 'medication';
    if (lower.contains('water') || lower.contains('drink') || lower.contains('hydrate') || lower.contains('health')) return 'health';
    
    // Meals
    if (lower.contains('eat') || lower.contains('breakfast') || lower.contains('lunch') || lower.contains('dinner') || lower.contains('meal') || lower.contains('snack')) return 'meals';
    
    // Social
    if (lower.contains('call') || lower.contains('visit') || lower.contains('talk') || lower.contains('friend') || lower.contains('daughter') || lower.contains('son') || lower.contains('family')) return 'social';
    
    // Leisure
    if (lower.contains('read') || lower.contains('tv') || lower.contains('relax') || lower.contains('walk') || lower.contains('garden') || lower.contains('music')) return 'leisure';
    
    // Therapy
    if (lower.contains('therapy') || lower.contains('stretch') || lower.contains('exercise') || lower.contains('massage') || lower.contains('physio')) return 'therapy';
    
    // Urgent
    if (lower.contains('doctor') || lower.contains('clinic') || lower.contains('hospital') || lower.contains('appointment') || lower.contains('emergency')) return 'urgent';
    
    return 'common';
  }

  void _showManualAddDialog() {
    final nameController = TextEditingController();
    TimeOfDay selectedTime = const TimeOfDay(hour: 12, minute: 0);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Add Custom Activity"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: "Name"),
            ),
            ListTile(
              title: const Text("Time"),
              trailing: Text(
                "${selectedTime.hour}:${selectedTime.minute.toString().padLeft(2, '0')}",
              ),
              onTap: () async {
                final picked = await showTimePicker(
                  context: context,
                  initialTime: selectedTime,
                );
                if (picked != null) {
                  selectedTime = picked;
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            child: const Text("Add"),
            onPressed: () async {
              final taskName = nameController.text.trim();
              if (taskName.isEmpty) return;

              final hhmm =
                  "${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}";
              
              final category = _determineCategory(taskName);

              final success = await _scheduleService.addTask(
                effectiveUid,
                _selectedDate,
                {
                  "task_name": taskName,
                  "time": hhmm,
                  "type": category,
                  "completed": false,
                  "id":
                      "${effectiveUid}_manual_${DateTime.now().millisecondsSinceEpoch}",
                  "scheduledAt": _combineDateAndTime(_selectedDate, hhmm),
                  "status": "scheduled",
                  "graceMinutes": 30,
                },
              );

              if (success && ctx.mounted) {
                Navigator.pop(ctx);
                _fetchSchedule();
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          _isPlanningMode
              ? "Plan Your Day"
              : (widget.elderName != null
                  ? "${widget.elderName}'s Routine"
                  : "My Routine"),
        ),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ScheduleHistoryPage()),
              );
            },
            tooltip: "View History",
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            color: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios),
                  onPressed: () => _changeDate(-1),
                ),
                Column(
                  children: [
                    Text(
                      _dateTitle,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (!_isToday)
                      GestureDetector(
                        onTap: () {
                          setState(() => _selectedDate = DateTime.now());
                          _fetchSchedule();
                        },
                        child: const Text(
                          "Go to Today",
                          style: TextStyle(color: Colors.blue, fontSize: 12),
                        ),
                      ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_forward_ios),
                  onPressed: () => _changeDate(1),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (_insights.isNotEmpty)
            Container(
              width: double.infinity,
              color: Colors.blue[50],
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "AI Suggestions",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ..._insights.map(
                    (i) => Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.auto_awesome, color: Colors.amber),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    i['message'] ?? "",
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton(
                                  onPressed: () => setState(() => _insights.remove(i)),
                                  child: const Text("Dismiss"),
                                ),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                    foregroundColor: Colors.white,
                                  ),
                                  onPressed: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text("Applying suggestion...")),
                                    );
                                    setState(() => _insights.remove(i));
                                  },
                                  child: const Text("Update Time"),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _hasError
                    ? _buildErrorView()
                    : _isPlanningMode
                        ? _buildPlanningView()
                        : _buildReadingView(),
          ),
        ],
      ),
      floatingActionButton: (!_isPlanningMode && !_isPast)
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton(
                  heroTag: "voice",
                  onPressed: () async {
                    try {
                      final user = await UserService().getUser(effectiveUid);
                      if (user != null && mounted) {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => VoiceChatbotPage(user: user)),
                        );
                        if (mounted) _fetchSchedule();
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Error loading user profile for voice."),
                          ),
                        );
                      }
                    } catch (e) {
                      debugPrint("Nav error: $e");
                    }
                  },
                  backgroundColor: Colors.redAccent,
                  child: const Icon(Icons.mic, color: Colors.white),
                ),
                const SizedBox(height: 16),
                FloatingActionButton(
                  heroTag: "manual",
                  onPressed: _showManualAddDialog,
                  backgroundColor: Colors.teal,
                  child: const Icon(Icons.add, color: Colors.white),
                ),
              ],
            )
          : null,
    );
  }
}