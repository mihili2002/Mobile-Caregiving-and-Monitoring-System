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

  String _riskTier = "Tier 1";

  // Used for conversational follow-up flows such as "Later"
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
          final freshTier = profileMap['prediction_tier']?.toString() ?? "Tier 1";
          final freshProb = profileMap['prediction_probability'];

          await prefs.setString('cached_risk_tier', freshTier);
          if (freshProb != null) {
            double p = (freshProb is int) ? freshProb.toDouble() : freshProb;
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
    final selected = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
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
      debugPrint("DailyRoutinePage: API failed for past date, checking Firestore...");
      final firestoreData =
          await _scheduleService.getScheduleFromFirestore(effectiveUid, _selectedDate);
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
    final insights = await _behaviorService.getInsights();
    if (insights.isNotEmpty && mounted) {
      setState(() => _insights = insights);
    }
  }

  Future<void> _enterPlanningMode() async {
    final suggestions = await _routineService.getDailySuggestions(effectiveUid) ?? {};

    if (!mounted) return;

    setState(() {
      final rawCommon = suggestions['common'] as List? ?? [];
      final Map<String, Map<String, dynamic>> uniqueCommon = {};

      for (var x in rawCommon) {
        final item = Map<String, dynamic>.from(x);
        final name = (item['task_name'] ?? "").toString().trim().toLowerCase();
        if (name.isNotEmpty && !uniqueCommon.containsKey(name)) {
          uniqueCommon[name] = item;
        }
      }

      _planningCommon = uniqueCommon.values.toList();
      _planningMeds = List<Map<String, dynamic>>.from(
        (suggestions['medications'] as List? ?? []).map((x) => Map<String, dynamic>.from(x)),
      );
      _planningTherapy = List<Map<String, dynamic>>.from(
        (suggestions['therapy'] as List? ?? []).map((x) => Map<String, dynamic>.from(x)),
      );

      _isPlanningMode = true;
      _isLoading = false;
      _selectedCommonIds.clear();

      for (var t in _planningTherapy) {
        if (t['time'] == null) t['time'] = "10:00";
      }
    });
  }

  void _adaptMedicationTimes() {
    String? breakfastTime;
    String? lunchTime;
    String? dinnerTime;

    for (var c in _planningCommon) {
      final name = c['task_name'].toString().toLowerCase();
      final time = c['default_time'];

      if (name.contains("breakfast")) breakfastTime = time;
      if (name.contains("lunch")) lunchTime = time;
      if (name.contains("dinner")) dinnerTime = time;
    }

    for (var m in _planningMeds) {
      final label = m['timing_label'].toString().toLowerCase();
      String? baseTime;

      if (label.contains("breakfast")) baseTime = breakfastTime;
      if (label.contains("lunch")) baseTime = lunchTime;
      if (label.contains("dinner")) baseTime = dinnerTime;

      if (baseTime != null) {
        try {
          final parts = baseTime.split(':');
          final dt = DateTime(2022, 1, 1, int.parse(parts[0]), int.parse(parts[1]));
          DateTime newDt = dt;

          if (label.contains("before")) newDt = dt.subtract(const Duration(minutes: 30));
          if (label.contains("after")) newDt = dt.add(const Duration(minutes: 30));

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

      for (var c in _planningCommon) {
        if (_selectedCommonIds.contains(c['id'].toString())) {
          final task = {
            "task_name": c['task_name'],
            "time": c['default_time'],
            "type": "common",
            "completed": false,
            "id": "${effectiveUid}_common_${c['id']}_${DateTime.now().microsecondsSinceEpoch}",
            "scheduledAt": _combineDateAndTime(_selectedDate, c['default_time']),
            "graceMinutes": 30,
            "status": "scheduled",
          };
          await _scheduleService.addTask(effectiveUid, _selectedDate, task);
          allTasksForFirestore.add(task);
        }
      }

      for (var m in _planningMeds) {
        final task = {
          "task_name": "${m['drug_name']} ${m['dosage'] ?? ''}".trim(),
          "time": m['time'],
          "type": "medication",
          "completed": false,
          "subtitle": m['timing_label'],
          "id": "${effectiveUid}_med_${m['id']}_${DateTime.now().microsecondsSinceEpoch}",
          "scheduledAt": _combineDateAndTime(_selectedDate, m['time']),
          "graceMinutes": 60,
          "status": "scheduled",
        };
        await _scheduleService.addTask(effectiveUid, _selectedDate, task);
        allTasksForFirestore.add(task);
      }

      for (var t in _planningTherapy) {
        final task = {
          "task_name": t['activity_name'],
          "time": t['time'],
          "type": "therapy",
          "completed": false,
          "subtitle": t['duration'],
          "id": "${effectiveUid}_therapy_${t['id']}_${DateTime.now().microsecondsSinceEpoch}",
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
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => VoiceChatbotPage(
                user: user,
                initialPrompt:
                    "Your plan is ready. Is there anything to add additionally into your today's plan, like appointments or calls?",
              ),
            ),
          ).then((_) {
            if (mounted) _fetchSchedule();
          });
        }
      }

      _fetchSchedule();
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
    debugPrint(
      "Scheduling Reminders for ${_dailyTasks.length} tasks with offsets $offsets (Tier: $_riskTier)",
    );

    for (var t in _dailyTasks) {
      if (t['completed'] == true) continue;

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
      } catch (e) {
        debugPrint("Error parsing time for task ${t['id']}: $e");
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

  Future<void> _showRescheduleVoiceDialog(String taskId, String initialPrompt) async {
    if (!mounted) return;

    String? userInput;
    String currentPrompt = initialPrompt;

    while (mounted) {
      final controller = TextEditingController();

      final submitted = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text("Alex"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(currentPrompt),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: "Type the time, e.g. 2:30 PM",
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: const Text("Send"),
            ),
          ],
        ),
      );

      if (submitted == null || submitted.isEmpty) {
        return;
      }

      userInput = submitted;

      final result = await _scheduleService.sendVoiceCommand(
        uid: effectiveUid,
        text: userInput,
        sessionId: _voiceSessionId,
        localTime: DateTime.now(),
      );

      if (result == null) {
        await _showVoiceReplyDialog("Sorry, I couldn't update the time right now.");
        return;
      }

      final reply = result['reply']?.toString() ?? "Okay.";
      final intent = result['intent']?.toString() ?? "";

      if (intent == "task_rescheduled") {
        await _showVoiceReplyDialog(reply);
        await _fetchSchedule();
        return;
      }

      if (intent == "task_followup" || intent == "task_followup_confirmation") {
        currentPrompt = reply;
        continue;
      }

      await _showVoiceReplyDialog(reply);
      await _fetchSchedule();
      return;
    }
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

    await _showRescheduleVoiceDialog(taskId, reply);
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

  Future<void> _handleSkipTask(String taskId) async {
    final dateStr = _selectedDate.toIso8601String().split('T')[0];
    await _scheduleService.skipTask(
      uid: effectiveUid,
      date: dateStr,
      taskId: taskId,
    );
    _cancelTaskNotifications(taskId);
    _fetchSchedule();
  }

  String _statusLabel(String status, bool isCompleted) {
    switch (status) {
      case 'scheduled':
        return "Scheduled";
      case 'upcoming':
        return "Coming up";
      case 'reminder_triggered':
        return "Reminder sent";
      case 'acknowledged':
        return "Acknowledged";
      case 'snoozed':
        return "Delayed";
      case 'in_progress':
        return "In progress";
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
      case 'pending':
      default:
        return isCompleted ? "Completed" : "Scheduled";
    }
  }

  Color _statusColor(String status, bool isCompleted) {
    switch (status) {
      case 'scheduled':
      case 'upcoming':
        return Colors.teal;
      case 'reminder_triggered':
      case 'snoozed':
        return Colors.orange;
      case 'acknowledged':
      case 'in_progress':
        return Colors.blue;
      case 'completed_confirmed':
      case 'completed_likely':
        return Colors.green;
      case 'skipped':
        return Colors.grey;
      case 'missed_likely':
      case 'missed_confirmed':
      case 'escalated':
        return Colors.red;
      case 'needs_caregiver_review':
        return Colors.purple;
      case 'pending':
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
      case 'acknowledged':
        return Icons.thumb_up_alt_outlined;
      case 'snoozed':
        return Icons.snooze;
      case 'in_progress':
        return Icons.play_circle_outline;
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
      case 'pending':
      default:
        return isCompleted ? Icons.check_circle : Icons.access_time;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          _isPlanningMode
              ? "Plan Your Day"
              : (widget.elderName != null ? "${widget.elderName}'s Routine" : "My Routine"),
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
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                  ),
                  const SizedBox(height: 8),
                  ..._insights.map(
                    (i) => Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                          const SnackBar(content: Text("Error loading user profile for voice.")),
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

  Widget _buildPlanningView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _isToday ? "${_getGreeting()} Set up your schedule." : "Planning for $_dateTitle",
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

                    final p = await showTimePicker(context: context, initialTime: initial);
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
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal),
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

                  final p = await showTimePicker(context: context, initialTime: initial);
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
              child: const Text("Create My Day Plan", style: TextStyle(fontSize: 18)),
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

    final common = _dailyTasks.where((t) => t['type'] == 'common' || t['type'] == 'custom').toList();
    final meds = _dailyTasks.where((t) => t['type'] == 'medication').toList();
    final therapy =
        _dailyTasks.where((t) => t['type'] == 'therapy' || t['type'] == 'therapist').toList();

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

  Widget _buildTaskTile(Map<String, dynamic> task) {
    final bool isCompleted = task['completed'] == true;
    final String status =
        task['status'] ?? (isCompleted ? "completed_confirmed" : "scheduled");
    final String time = task['time'] ?? "--:--";
    final String subtitle = task['subtitle'] ?? "";

    final statusColor = _statusColor(status, isCompleted);
    final statusIcon = _statusIcon(status, isCompleted);
    final statusLabel = _statusLabel(status, isCompleted);

    final bool canActOnTask = const [
      'scheduled',
      'upcoming',
      'reminder_triggered',
      'acknowledged',
      'snoozed',
      'in_progress',
    ].contains(status);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                  onChanged: (val) => _toggleTaskCompletion(task['id'], isCompleted),
                  activeColor: Colors.teal,
                ),
              ],
            ),
          ),
          if (canActOnTask)
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ElevatedButton(
                    onPressed: () => _handleCompleteTask(task['id']),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Done'),
                  ),
                  OutlinedButton(
                    onPressed: () => _handleLaterTask(task['id']),
                    child: const Text('Later'),
                  ),
                  OutlinedButton(
                    onPressed: () => _handleStartTask(task['id']),
                    child: const Text('Doing now'),
                  ),
                  TextButton(
                    onPressed: () => _handleSkipTask(task['id']),
                    child: const Text(
                      'Skip',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
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
                final p = await showTimePicker(
                  context: context,
                  initialTime: selectedTime,
                );
                if (p != null) selectedTime = p;
              },
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            child: const Text("Add"),
            onPressed: () async {
              if (nameController.text.isNotEmpty) {
                final hhmm =
                    "${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}";
                final success = await _scheduleService.addTask(
                  effectiveUid,
                  _selectedDate,
                  {
                    "task_name": nameController.text,
                    "time": hhmm,
                    "type": "common",
                    "completed": false,
                    "id": "${effectiveUid}_manual_${DateTime.now().millisecondsSinceEpoch}",
                    "scheduledAt": _combineDateAndTime(_selectedDate, hhmm),
                    "status": "scheduled",
                    "graceMinutes": 30,
                  },
                );

                if (success && ctx.mounted) {
                  Navigator.pop(ctx);
                  _fetchSchedule();
                }
              }
            },
          ),
        ],
      ),
    );
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

  Future<void> _deleteTask(String taskId) async {
    setState(() => _dailyTasks.removeWhere((t) => t['id'] == taskId));
    await _scheduleService.deleteTask(effectiveUid, _selectedDate, taskId);
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

    final p = await showTimePicker(context: context, initialTime: initial);
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
}