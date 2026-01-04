import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/routine_service.dart';
import '../../services/schedule_service.dart';
import '../../services/voice_service.dart';
import '../../services/notification_service.dart';
import '../../services/behavior_service.dart';
import '../../services/user_service.dart';
import 'voice_chatbot_page.dart';
import '../../services/voice_reminder_service.dart';
import 'dart:async';

class DailyRoutinePage extends StatefulWidget {
  final String? elderId;
  final String? elderName;

  const DailyRoutinePage({super.key, this.elderId, this.elderName});

  @override
  State<DailyRoutinePage> createState() => _DailyRoutinePageState();
}

class _DailyRoutinePageState extends State<DailyRoutinePage> with SingleTickerProviderStateMixin {
  final RoutineService _routineService = RoutineService();
  final ScheduleService _scheduleService = ScheduleService();
  final VoiceService _voiceService = VoiceService();
  final NotificationService _notificationService = NotificationService();
  final BehaviorService _behaviorService = BehaviorService();
  
  late final String effectiveUid;
  Timer? _timer;

  // Mode
  bool _isPlanningMode = false;
  bool _isLoading = false;

  // Data
  DateTime _selectedDate = DateTime.now();
  List<dynamic> _dailyTasks = [];
  
  // Planning State (Mutable Lists for Logic)
  List<Map<String, dynamic>> _planningCommon = [];
  List<Map<String, dynamic>> _planningMeds = [];
  List<Map<String, dynamic>> _planningTherapy = [];
  
  // Selections
  final Set<String> _selectedCommonIds = {}; 
  // Insights
  List<dynamic> _insights = [];

  @override
  void initState() {
    super.initState();
    effectiveUid = widget.elderId ?? FirebaseAuth.instance.currentUser!.uid;
    _initServices();
  }

  Future<void> _initServices() async {
    await _voiceService.init();
    await _notificationService.init(); // Critical: Wait for notifications to be ready
    
    if (mounted) {
       _fetchSchedule();
       _fetchRiskProfile();
       
       // Automatic Voice Check: Updates the service whenever schedule changes
       // Local timer removed in favor of global VoiceReminderService
       VoiceReminderService().listen(effectiveUid);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _voiceService.stop();
    super.dispose();
  }

  String _riskTier = "Tier 1"; // Default
  final Set<String> _remindedKeys = {};

  // Fetch Risk Tier
  Future<void> _fetchRiskProfile() async {
     try {
       // 1. Try Cache First
       final prefs = await SharedPreferences.getInstance();
       final cachedTier = prefs.getString('cached_risk_tier');
       if (cachedTier != null && mounted) {
          setState(() {
             _riskTier = cachedTier;
          });
          print("Loaded Cached Risk Tier: $_riskTier");
          VoiceReminderService().updateRiskTier(_riskTier);
          _scheduleTieredReminders();
       }

       // 2. Fetch Fresh
       // Use Service URL Logic
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
              
              // Update Cache
              await prefs.setString('cached_risk_tier', freshTier);
              if (freshProb != null) {
                 double p = (freshProb is int) ? freshProb.toDouble() : freshProb;
                 await prefs.setDouble('cached_risk_prob', p);
              }
             
             if (freshTier != _riskTier && mounted) {
                setState(() {
                   _riskTier = freshTier;
                });
                print("Updated Risk Tier from Network: $_riskTier");
                _scheduleTieredReminders();
             }
          }
       }
     } catch(e) {
       print("Error fetching profile: $e");
     }
  }

  void _checkAndSpeakReminders() {
    if (!_isToday) return; 
    
    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;
    final timeString = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
    
    // Night Cap: 9 PM to 7 AM
    final bool isNight = now.hour >= 21 || now.hour < 7;
    
    // Policy Offsets (in minutes)
    List<int> offsets = [0];
    if (_riskTier.contains("Tier 2")) offsets = [0, 15];
    if (_riskTier.contains("Tier 3") || _riskTier.contains("High")) offsets = [0, 10, 20];
    
    for (var task in _dailyTasks) {
       // Only process if not completed
       if (task['completed'] == true) continue;
       
       // Parse Task Time
       String tStr = task['time'];
       if (!tStr.contains(":")) continue;
       final parts = tStr.split(":");
       final taskMinutes = int.parse(parts[0]) * 60 + int.parse(parts[1]);
       
       // Calculate Difference
       int diff = currentMinutes - taskMinutes;
       
       // Night Cap Check: No followups (diff > 0) at night
       if (isNight && diff > 0) continue;
       
       // Check if this specific difference dictates a reminder
       if (offsets.contains(diff)) {
           // Unique Key: TaskID + The Time We Are Reminding At (current time string)
           final key = "${task['id']}_$timeString";
           
           if (!_remindedKeys.contains(key)) {
              String msg = task['task_name'] ?? "Task";
              if (diff > 0) msg = "Reminder: You haven't finished $msg yet. It's time.";
              
              _voiceService.speakReminder(msg, elderName: widget.elderName);
              _remindedKeys.add(key);
              
              // Visual Alert (Fallback for Web/Desktop or if Audio blocked)
              if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(children: [
                         const Icon(Icons.alarm, color: Colors.white), 
                         const SizedBox(width: 12),
                         Expanded(child: Text(msg))
                      ]),
                      backgroundColor: Colors.teal,
                      duration: const Duration(seconds: 10),
                      action: SnackBarAction(label: "Dismiss", textColor: Colors.yellow, onPressed: (){}),
                    )
                  );
              }

              // Log
              _behaviorService.logEvent('REMINDER_SENT', {
                 "uid": effectiveUid,
                 "scheduleDocId": _getScheduleDocId(),
                 "taskId": task['id'],
                 "type": "REMINDER_SENT",
                 "at": DateTime.now().toIso8601String(),
                 "meta": {
                     "task_name": task['task_name'],
                     "scheduled_time": task['time'],
                     "risk_tier": _riskTier,
                     "is_followup": diff > 0,
                     "delay_min": diff,
                     "policy_version": "v1.0"
                 }
              });
           }
       }
    }
  }

  // --- LOGIC ---

  bool get _isPast {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selected = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    return selected.isBefore(today);
  }

  bool get _isToday {
    final now = DateTime.now();
    return _selectedDate.year == now.year && _selectedDate.month == now.month && _selectedDate.day == now.day;
  }

  Future<void> _fetchSchedule() async {
    setState(() => _isLoading = true);
    
    // 1. Get Scheduled Tasks
    final data = await _scheduleService.getSchedule(effectiveUid, _selectedDate);
    final tasks = List<dynamic>.from(data?['tasks'] ?? []);
    
    setState(() {
      _dailyTasks = tasks;
    });

    // 2. Decide Mode
    // Enter Planning Mode if tasks are empty AND it is NOT a past date
    if (tasks.isEmpty && !_isPast) {
       await _enterPlanningMode();
    } else {
       setState(() {
         _isPlanningMode = false;
         _isLoading = false;
       });
    }
    
     // 3. Update Voice Reminder Service
     if (mounted && _isToday) {
        VoiceReminderService().updateTasks(tasks, _riskTier);
     }

     // 4. Schedule Notifications for existing tasks
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
      // Deep Copy for Mutation
      _planningCommon = List<Map<String, dynamic>>.from((suggestions['common'] as List? ?? []).map((x) => Map<String, dynamic>.from(x)));
      _planningMeds = List<Map<String, dynamic>>.from((suggestions['medications'] as List? ?? []).map((x) => Map<String, dynamic>.from(x)));
      _planningTherapy = List<Map<String, dynamic>>.from((suggestions['therapy'] as List? ?? []).map((x) => Map<String, dynamic>.from(x)));
      
      _isPlanningMode = true;
      _isLoading = false;
      
      // Default Selections and Times
      _selectedCommonIds.clear();
      
      // Initialize Therapy Times (Default 10:00)
      for (var t in _planningTherapy) {
        if (t['time'] == null) t['time'] = "10:00";
      }
    });
  }
  
  // Smart Adaptation Logic
  void _adaptMedicationTimes() {
    // 1. Find Meal Times from Common Tasks
    String? breakfastTime;
    String? lunchTime;
    String? dinnerTime;
    
    for (var c in _planningCommon) {
       final name = c['task_name'].toString().toLowerCase();
       final time = c['default_time']; // This is the user-adjusted time now
       
       if (name.contains("breakfast")) breakfastTime = time;
       else if (name.contains("lunch")) lunchTime = time;
       else if (name.contains("dinner")) dinnerTime = time;
    }
    
    // 2. Update Meds
    for (var m in _planningMeds) {
       final label = m['timing_label'].toString().toLowerCase(); // e.g., "After Meal - Breakfast"
       String? baseTime;
       
       if (label.contains("breakfast")) baseTime = breakfastTime;
       else if (label.contains("lunch")) baseTime = lunchTime;
       else if (label.contains("dinner")) baseTime = dinnerTime;
       
       if (baseTime != null) {
          // Calculate offset
          // Parse HH:MM
          try {
             final parts = baseTime.split(':');
             final dt = DateTime(2022,1,1, int.parse(parts[0]), int.parse(parts[1]));
             DateTime newDt = dt;
             
             if (label.contains("before")) newDt = dt.subtract(const Duration(minutes: 30));
             else if (label.contains("after")) newDt = dt.add(const Duration(minutes: 30));
             
             m['time'] = "${newDt.hour.toString().padLeft(2,'0')}:${newDt.minute.toString().padLeft(2,'0')}";
          } catch(e) {
             print("Time calc error: $e");
          }
       }
    }
  }

  Future<void> _savePlan() async {
    setState(() => _isLoading = true);
    try {
      // 1. Common Tasks
      for (var c in _planningCommon) {
         if (_selectedCommonIds.contains(c['id'].toString())) {
             await _scheduleService.addTask(effectiveUid, _selectedDate, {
                "task_name": c['task_name'],
                "time": c['default_time'], 
                "type": "common",
                "completed": false,
                "id": "${effectiveUid}_common_${c['id']}_${DateTime.now().microsecondsSinceEpoch}",
                
                // Behavior Fields (Refactored)
                "scheduledAt": _combineDateAndTime(_selectedDate, c['default_time']),
                "graceMinutes": 30,
                "status": "scheduled"
             });
         }
      }
      
      // 2. Medications (Mandatory)
      for (var m in _planningMeds) {
          await _scheduleService.addTask(effectiveUid, _selectedDate, {
             "task_name": "${m['drug_name']} ${m['dosage'] ?? ''}".trim(),
             "time": m['time'], 
             "type": "medication",
             "completed": false,
             "subtitle": m['timing_label'],
             "id": "${effectiveUid}_med_${m['id']}_${DateTime.now().microsecondsSinceEpoch}",
             
             // Behavior Fields (Refactored)
             "scheduledAt": _combineDateAndTime(_selectedDate, m['time']),
             "graceMinutes": 60,
             "status": "scheduled"
          });
      }
      
      // 3. Therapy (Mandatory)
      for (var t in _planningTherapy) {
         await _scheduleService.addTask(effectiveUid, _selectedDate, {
            "task_name": t['activity_name'],
            "time": t['time'],
            "type": "therapy",
            "completed": false,
            "subtitle": t['duration'],
            "id": "${effectiveUid}_therapy_${t['id']}_${DateTime.now().microsecondsSinceEpoch}",
            
            // Behavior Fields (Refactored)
            "scheduledAt": _combineDateAndTime(_selectedDate, t['time']),
            "graceMinutes": 15,
            "status": "scheduled"
         });
      }
      
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Daily Plan Created!")));
         
         // Trigger Voice Helper
         final user = await UserService().getUser(effectiveUid);
         if (user != null) {
            Navigator.push(context, MaterialPageRoute(builder: (_) => VoiceChatbotPage(
               user: user,
               initialPrompt: "Your plan is ready. Is there anything to add additionally into your today's plan, like appointments or calls?"
            ))).then((_) {
               if (mounted) _fetchSchedule();
            });
         }
      }
      _fetchSchedule(); 
      
    } catch (e) {
      print("Error saving plan: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- UI ---
  
  String get _dateTitle {
    if (_isToday) return "Today's Plan";
    final now = DateTime.now();
    final tomorrow = now.add(const Duration(days: 1));
    if (_selectedDate.year == tomorrow.year && _selectedDate.month == tomorrow.month && _selectedDate.day == tomorrow.day) {
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

  // --- Local Notification Logic ---
  
  List<int> _getTierOffsets(String tier) {
     if (tier.contains("Tier 3") || tier.contains("High")) return [0, 10, 20];
     if (tier.contains("Tier 2")) return [0, 15];
     return [0];
  }

  void _scheduleTieredReminders() async {
     if (_dailyTasks.isEmpty) return;
     
     // Clear previous for clean slate
     await _notificationService.cancelAll();
     
     final offsets = _getTierOffsets(_riskTier);
     debugPrint("Scheduling Reminders for ${_dailyTasks.length} tasks with offsets $offsets (Tier: $_riskTier)");
     
     for (var t in _dailyTasks) {
        if (t['completed'] == true) continue;
        
        DateTime? scheduledTime;
        try {
           if (t['scheduledAt'] != null) {
              scheduledTime = DateTime.parse(t['scheduledAt']);
           } else if (t['time'] != null && t['time'].toString().contains(":")) {
              final now = DateTime.now();
              final parts = t['time'].split(":");
              scheduledTime = DateTime(now.year, now.month, now.day, int.parse(parts[0]), int.parse(parts[1]));
           }
        } catch(e) {
           print("Error parsing time for task ${t['id']}: $e");
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
                 scheduledTime: remindTime
              );
           }
        }
     }
  }

  void _cancelTaskNotifications(String taskId) async {
      // Cancel potential indices 0..4 (covers up to 5 reminders)
      for (int i = 0; i < 5; i++) { 
          final id = NotificationService.makeId(effectiveUid, taskId, i);
          await _notificationService.cancel(id);
      }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50], 
      appBar: AppBar(
        title: Text(_isPlanningMode ? "Plan Your Day" : (widget.elderName != null ? "${widget.elderName}'s Routine" : "My Routine")),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
           // DATE DISPLAY (Always visible)
           Container(
             padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
             color: Colors.white,
             child: Row(
               mainAxisAlignment: MainAxisAlignment.spaceBetween,
               children: [
                 IconButton(icon: const Icon(Icons.arrow_back_ios), onPressed: () => _changeDate(-1)),
                 Column(children:[
                    Text(_dateTitle, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    if (!_isToday) GestureDetector(
                       onTap: () { setState(() => _selectedDate = DateTime.now()); _fetchSchedule(); },
                       child: const Text("Go to Today", style: TextStyle(color: Colors.blue, fontSize: 12))
                    )
                 ]),
                 IconButton(icon: const Icon(Icons.arrow_forward_ios), onPressed: () => _changeDate(1)),
               ],
             ),
           ),
           const Divider(height: 1),
           
           const Divider(height: 1),
           
           if (_insights.isNotEmpty) 
             Container(
               width: double.infinity,
               color: Colors.blue[50],
               padding: const EdgeInsets.all(12),
               child: Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                    const Text("AI Suggestions", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                    const SizedBox(height: 8),
                    ..._insights.map((i) => Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          children: [
                            Row(children: [
                               const Icon(Icons.auto_awesome, color: Colors.amber),
                               const SizedBox(width: 12),
                               Expanded(child: Text(i['message'] ?? "", style: const TextStyle(fontSize: 14))),
                            ]),
                            const SizedBox(height: 8),
                            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                               TextButton(onPressed: () => setState(() => _insights.remove(i)), child: const Text("Dismiss")),
                               ElevatedButton(
                                 style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                                 onPressed: () {
                                    // Apply Logic (mock for now or real update)
                                    // For now just acknowledge
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Applying suggestion...")));
                                    setState(() => _insights.remove(i));
                                 }, 
                                 child: const Text("Update Time")
                               ),
                            ])
                          ],
                        ),
                      ),
                    )),
                 ],
               )
             ),

           Expanded(
             child: _isLoading 
               ? const Center(child: CircularProgressIndicator()) 
               : _isPlanningMode 
                   ? _buildPlanningView() 
                   : _buildReadingView()
           )
        ]
      ),
       floatingActionButton: (!_isPlanningMode && !_isPast) ? Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            heroTag: "voice",
            onPressed: () async {
               // Determine current user object (Fetch or mock)
               // Since checking real user might be async, let's just fetch simplified or pass ID
               try {
                 final user = await UserService().getUser(effectiveUid);
                 if (user != null && mounted) {
                    await Navigator.push(context, MaterialPageRoute(builder: (_) => VoiceChatbotPage(user: user)));
                    if (mounted) _fetchSchedule(); // Refresh tasks on return
                 } else {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error loading user profile for voice.")));
                 }
               } catch(e) {
                 print("Nav error: $e");
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
      ) : null,
    );
  }

  // Voice Command (Simulated for Demo)
  Future<void> _simulateVoiceCommand() async {
     // 1. Ask User what to simulate
     String? chosenText = await showDialog<String>(
       context: context,
       builder: (context) => SimpleDialog(
         title: const Text("Select Voice Simulation"),
         children: [
            SimpleDialogOption(
               onPressed: () => Navigator.pop(context, "I finished lunch"),
               child: const Padding(padding: EdgeInsets.all(8.0), child: Text("1. Action: 'I finished lunch'")),
            ),
            SimpleDialogOption(
               onPressed: () => Navigator.pop(context, "Did I have lunch?"),
               child: const Padding(padding: EdgeInsets.all(8.0), child: Text("2. Question: 'Did I have lunch?' (Expect Yes)")),
            ),
            SimpleDialogOption(
               onPressed: () => Navigator.pop(context, "Did I take my snack?"),
               child: const Padding(padding: EdgeInsets.all(8.0), child: Text("3. Question: 'Did I take my snack?' (Expect No)")),
            ),
            SimpleDialogOption(
               onPressed: () => Navigator.pop(context, "Call Nikeshi"),
               child: const Padding(padding: EdgeInsets.all(8.0), child: Text("4. Action: 'Call Nikeshi'")),
            ),
         ],
       )
     );

     if (chosenText == null) return;

     // 2. Show "Listening" UI
     ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Simulating: '$chosenText'"), duration: const Duration(milliseconds: 1000)));
     
     // 3. Call Backend AI
     try {
         final UserService userService = UserService();
         final baseUrl = userService.baseUrl;
         
         final res = await http.post(
          Uri.parse('$baseUrl/api/ai/process_voice_command'),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({
             "text": chosenText,
             "uid": effectiveUid 
          })
       );
       
       if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          
          // Case A: Completion
          if (data['action'] == 'complete_task') {
             final keyword = data['task_keyword'];
             // Find task
             final task = _dailyTasks.firstWhere((t) => t['task_name'].toString().toLowerCase().contains(keyword) && t['completed'] == false, orElse: () => null);
             
             if (task != null) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['reply'])));
                _toggleTaskCompletion(task['id'], false); // Mark as done -> Logs "Actual Time"
             } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Task not found or already done.")));
             }
          } 
          // Case B: General Reply (Recall results, etc)
          else {
             // Show the reply from backend (e.g. "Yes, you have completed Lunch.")
             showDialog(
                context: context,
                builder: (context) => AlertDialog(
                   title: const Text("Assistant Reply"),
                   content: Text(data['reply'] ?? "No reply"),
                   actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK"))],
                )
             );
          }
       }
     } catch(e) {
       print("Voice Error: $e");
       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
     }
  }

  // === A. PLANNING VIEW ===
  Widget _buildPlanningView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_isToday ? "Good Morning! Set up your schedule." : "Planning for $_dateTitle", 
               style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal)),
          const SizedBox(height: 16),
          
          // SECTION A
          _buildPlanSectionHeader("Section A: Routine Tasks", Icons.wb_sunny),
          const Padding(padding: EdgeInsets.only(bottom: 8), child: Text("Select tasks & adjust time.")),
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
                        if (val == true) _selectedCommonIds.add(id);
                        else _selectedCommonIds.remove(id);
                      });
                    },
                 ),
                 title: Text(item['task_name']),
                 trailing: OutlinedButton(
                    onPressed: () async {
                       // Time Picker
                       String t = item['default_time'];
                       TimeOfDay initial = const TimeOfDay(hour: 8, minute: 0);
                       try { initial = TimeOfDay(hour: int.parse(t.split(':')[0]), minute: int.parse(t.split(':')[1])); } catch(_) {}
                       final p = await showTimePicker(context: context, initialTime: initial);
                       if (p != null) {
                          setState(() {
                            item['default_time'] = "${p.hour.toString().padLeft(2,'0')}:${p.minute.toString().padLeft(2,'0')}";
                            // TRIGGER SMART ADAPTATION
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

          // SECTION B
          _buildPlanSectionHeader("Section B: Medications", Icons.medication),
          const Padding(padding: EdgeInsets.only(bottom: 8), child: Text("Times adapt to your meals automatically.")),
          if (_planningMeds.isEmpty) const Text("No active medications.", style: TextStyle(fontStyle: FontStyle.italic)),
          ..._planningMeds.map((item) {
             return ListTile(
               leading: const Icon(Icons.check_circle, color: Colors.grey),
               title: Text("${item['drug_name']} ${item['dosage'] ?? ''}"),
               subtitle: Text(item['timing_label'] ?? ""),
               trailing: Text(item['time'], style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
             );
          }),
          const SizedBox(height: 24),

          // SECTION C
          _buildPlanSectionHeader("Section C: Therapy", Icons.accessibility),
          const Padding(padding: EdgeInsets.only(bottom: 8), child: Text("Choose your preferred time.")),
          if (_planningTherapy.isEmpty) const Text("No therapy assigned.", style: TextStyle(fontStyle: FontStyle.italic)),
          ..._planningTherapy.map((item) {
             return ListTile(
               leading: const Icon(Icons.check_circle, color: Colors.grey),
               title: Text(item['activity_name']),
               subtitle: Text(item['duration'] ?? ""),
               trailing: OutlinedButton(
                 onPressed: () async {
                    String t = item['time'];
                    TimeOfDay initial = const TimeOfDay(hour: 10, minute: 0);
                    try { initial = TimeOfDay(hour: int.parse(t.split(':')[0]), minute: int.parse(t.split(':')[1])); } catch(_) {}
                    final p = await showTimePicker(context: context, initialTime: initial);
                     if (p != null) {
                        setState(() {
                          item['time'] = "${p.hour.toString().padLeft(2,'0')}:${p.minute.toString().padLeft(2,'0')}";
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
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
              onPressed: _savePlan,
              child: const Text("Create My Day Plan", style: TextStyle(fontSize: 18)),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
  
  Widget _buildPlanSectionHeader(String title, IconData icon) {
    return Row(children: [
       Icon(icon, color: Colors.teal),
       const SizedBox(width: 8),
       Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))
    ]);
  }

  // === B. READING VIEW ===
  Widget _buildReadingView() {
    if (_dailyTasks.isEmpty) return const Center(child: Text("No tasks scheduled for this day.")); 
    
    final common = _dailyTasks.where((t) => t['type'] == 'common' || t['type'] == 'custom').toList();
    final meds = _dailyTasks.where((t) => t['type'] == 'medication').toList();
    final therapy = _dailyTasks.where((t) => t['type'] == 'therapy' || t['type'] == 'therapist').toList();
    
    // Sort by Time
    _dailyTasks.sort((a,b) => (a['time']??"00:00").compareTo(b['time']??"00:00"));

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
              ...meds.map((t) => _buildTaskTile(t)),
              const SizedBox(height: 20),
           ],
           if (therapy.isNotEmpty) ...[
              _buildSectionHeader("Therapy", Icons.accessibility),
              ...therapy.map((t) => _buildTaskTile(t)),
              const SizedBox(height: 20),
           ],
        ],
      ),
    );
  }

  Widget _buildTaskTile(Map<String, dynamic> task) {
    final bool isCompleted = task['completed'] == true;
    final String time = task['time'] ?? "--:--";
    final String subtitle = task['subtitle'] ?? "";
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        onLongPress: () => _confirmDeleteTask(task),
        leading: CircleAvatar(
          backgroundColor: isCompleted ? Colors.green[100] : Colors.teal.withOpacity(0.1),
          child: Icon(
            isCompleted ? Icons.check : Icons.access_time,
            color: isCompleted ? Colors.green : Colors.teal,
          ),
        ),
        title: Text(
          task['task_name'] ?? "Task",
          style: TextStyle(
            decoration: isCompleted ? TextDecoration.lineThrough : null,
            color: isCompleted ? Colors.grey : Colors.black87,
            fontWeight: FontWeight.w600,
            fontSize: 16
          ),
        ),
        subtitle: subtitle.isNotEmpty 
            ? Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[600])) 
            : null,
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
                  border: Border.all(color: Colors.teal.withOpacity(0.3))
                ),
                child: Text(
                  time, 
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)
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
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
     return Padding(
       padding: const EdgeInsets.symmetric(vertical: 8), 
       child: Row(children: [
         Icon(icon, color: Colors.teal), 
         const SizedBox(width: 8), 
         Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))
       ])
     );
  }
  
  // Voice & Notif
  void _scheduleNotifications() {
     if (!_isToday) return; 
     _notificationService.cancelAll();
     for (var task in _dailyTasks) {
        if (task['completed'] == true) continue;
        try {
          final parts = task['time'].toString().split(':');
          final now = DateTime.now();
          final date = DateTime(now.year, now.month, now.day, int.parse(parts[0]), int.parse(parts[1]));
          if (date.isAfter(now)) {
             _notificationService.scheduleNotification(id: task.hashCode, title: "Reminder", body: task['task_name'], scheduledTime: date);
          }
        } catch(_) {}
     }
  }

  // Manual Add
  void _showManualAddDialog() {
     final nameController = TextEditingController();
     TimeOfDay selectedTime = const TimeOfDay(hour: 12, minute: 0);
     showDialog(context: context, builder: (ctx) => AlertDialog(
       title: const Text("Add Custom Activity"),
       content: Column(
         mainAxisSize: MainAxisSize.min,
         children: [
           TextField(controller: nameController, decoration: const InputDecoration(labelText: "Name")),
           ListTile(
              title: const Text("Time"),
              trailing: Text("${selectedTime.hour}:${selectedTime.minute.toString().padLeft(2,'0')}"),
              onTap: () async {
                 final p = await showTimePicker(context: context, initialTime: selectedTime);
                 if (p != null) selectedTime = p;
              }
           )
         ],
       ),
       actions: [
         ElevatedButton(child: const Text("Add"), onPressed: () async {
          if (nameController.text.isNotEmpty) {
             // Show loading indicator or block double tap (simple await for now)
             final success = await _scheduleService.addTask(effectiveUid, _selectedDate, {
                "task_name": nameController.text,
                "time": "${selectedTime.hour.toString().padLeft(2,'0')}:${selectedTime.minute.toString().padLeft(2,'0')}",
                "type": "common",
                "completed": false,
                "id": "${effectiveUid}_manual_${DateTime.now().millisecondsSinceEpoch}",
                
                // Add required behavior fields for smart reminders
                "scheduledAt": _combineDateAndTime(_selectedDate, "${selectedTime.hour.toString().padLeft(2,'0')}:${selectedTime.minute.toString().padLeft(2,'0')}"),
                "status": "scheduled",
                "graceMinutes": 30
             });
             
             if (success && ctx.mounted) {
                 Navigator.pop(ctx);
                 _fetchSchedule(); // Helper will trigger _scheduleTieredReminders()
             }
          }
       })
       ],
     ));
  }
  
  // Helpers for Delete/Update
  void _confirmDeleteTask(Map<String, dynamic> task) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
        title: const Text("Delete Task?"),
        content: Text("Delete '${task['task_name']}'?"),
        actions: [
          TextButton(child: const Text("Cancel"), onPressed: () => Navigator.pop(ctx)),
          TextButton(child: const Text("Delete", style: TextStyle(color: Colors.red)), onPressed: () {
             Navigator.pop(ctx);
             _deleteTask(task['id']);
          }),
        ]
    ));
  }
  
  Future<void> _deleteTask(String taskId) async {
     setState(() => _dailyTasks.removeWhere((t) => t['id'] == taskId));
     await _scheduleService.deleteTask(effectiveUid, _selectedDate, taskId);
  }
  
  Future<void> _updateTaskTime(Map<String, dynamic> task) async {
     // ... re-impl time picker update for existing tasks in Reading Mode ...
     String current = task['time'] ?? "08:00";
     TimeOfDay initial = const TimeOfDay(hour: 8, minute: 0);
     try { initial = TimeOfDay(hour: int.parse(current.split(':')[0]), minute: int.parse(current.split(':')[1])); } catch(_) {}
     final p = await showTimePicker(context: context, initialTime: initial);
     if (p != null) {
        final newTime = "${p.hour.toString().padLeft(2,'0')}:${p.minute.toString().padLeft(2,'0')}";
        setState(() => task['time'] = newTime);
        await _scheduleService.updateTask(effectiveUid, _selectedDate, task['id'], {"time": newTime});
     }
  }
  
  Future<void> _toggleTaskCompletion(String taskId, bool currentStatus) async {
     setState(() {
        final t = _dailyTasks.firstWhere((e) => e['id'] == taskId);
        t['completed'] = !currentStatus;
     });
     
     if (!currentStatus) { 
        // Marking as COMPLETED -> Use new Backend Endpoint (logs event automatically)
        await _scheduleService.completeTask(effectiveUid, _selectedDate, taskId);
        _cancelTaskNotifications(taskId);
     } else {
        // Unmarking -> Use standard status update (no event log needed for "undo" usually, or simple update)
        await _scheduleService.updateTaskStatus(effectiveUid, _selectedDate, taskId, false);
        _scheduleTieredReminders();
     }
  }

  int _calculateDelay(String? scheduledTimeStr, String? scheduledAtIso) {
     try {
       final now = DateTime.now();
       // Prefer explicit timestamp
       if (scheduledAtIso != null) {
          final scheduled = DateTime.parse(scheduledAtIso);
          return now.difference(scheduled).inMinutes;
       }
       // Fallback to "Time" string (Today + HH:MM)
       if (scheduledTimeStr != null) {
         final parts = scheduledTimeStr.split(':');
         final scheduled = DateTime(now.year, now.month, now.day, int.parse(parts[0]), int.parse(parts[1]));
         return now.difference(scheduled).inMinutes;
       }
     } catch(_) {}
     return 0;
  }

  String _combineDateAndTime(DateTime date, String timeStr) {
     try {
       final parts = timeStr.split(':');
       final dt = DateTime(date.year, date.month, date.day, int.parse(parts[0]), int.parse(parts[1]));
       return dt.toIso8601String();
     } catch(_) {
       return DateTime.now().toIso8601String();
     }
  }

  String _getScheduleDocId() {
     final d = "${_selectedDate.day.toString().padLeft(2,'0')}.${_selectedDate.month.toString().padLeft(2,'0')}.${_selectedDate.year}";
     return "${effectiveUid}_$d";
  }
}