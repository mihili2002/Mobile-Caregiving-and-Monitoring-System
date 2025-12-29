import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/routine_service.dart';
import '../../services/schedule_service.dart';
import '../../services/voice_service.dart';
import '../../services/smart_reminder_service.dart';
import '../../models/routine_models.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'add_routine_page.dart';

class DailyRoutinePage extends StatefulWidget {
  final String elderId;
  final String? elderName;

  const DailyRoutinePage({Key? key, required this.elderId, this.elderName}) : super(key: key);

  @override
  State<DailyRoutinePage> createState() => _DailyRoutinePageState();
}

class _DailyRoutinePageState extends State<DailyRoutinePage> {
  final RoutineService _routineService = RoutineService();
  final ScheduleService _scheduleService = ScheduleService();
  final VoiceService _voiceService = VoiceService();
  final SmartReminderService _reminderService = SmartReminderService();

  List<dynamic> _timelineItems = [];
  bool _isLoading = true;
  DateTime _selectedDate = DateTime.now();
  Timer? _voiceNudgeTimer;

  @override
  void initState() {
    super.initState();
    _initServices();
    _loadRoutineData();
    _startVoiceNudgeTimer();
  }

  Future<void> _initServices() async {
    await _voiceService.init();
    await _reminderService.init();
  }

  @override
  void dispose() {
    _voiceNudgeTimer?.cancel();
    _voiceService.stop();
    super.dispose();
  }

  // --- VOICE NUDGE LOGIC ---
  void _startVoiceNudgeTimer() {
    // Run every 30 seconds as requested
    _voiceNudgeTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _checkAndSpeakReminders();
    });
  }

  void _checkAndSpeakReminders() {
    final now = TimeOfDay.now();
    final nowMinutes = now.hour * 60 + now.minute;

    // Night Cap: Silence between 9 PM (21:00) and 7 AM (07:00)
    if (now.hour >= 21 || now.hour < 7) return;

    for (var item in _timelineItems) {
      if (item['type'] == 'task') {
        final task = item['data'];
        if (task['completed'] == true) continue;

        final timeStr = item['time'] as String; // "HH:mm"
        final parts = timeStr.split(':');
        final taskMinutes = int.parse(parts[0]) * 60 + int.parse(parts[1]);

        // If task is overdue by 5-10 mins (simple logic for demo)
        // More complex logic would track "last spoken time" to avoid spamming
        int diff = nowMinutes - taskMinutes;
        
        // Speak if it's 1 minute past due (demonstration)
        // In real app, check if we haven't spoken it yet.
        // For this demo, we'll rely on the 30s timer and random chance or a flag to not be annoying
        if (diff > 0 && diff < 2) { 
           _voiceService.speakReminder(task['taskName'] ?? 'Task', elderName: widget.elderName);
        }
      }
    }
  }

  Future<void> _loadRoutineData() async {
    setState(() => _isLoading = true);
    try {
      final scheduleMap = await _scheduleService.getSchedule(widget.elderId, _selectedDate);
      List<dynamic> tasks = (scheduleMap != null && scheduleMap['tasks'] != null) ? scheduleMap['tasks'] : [];

      final meds = await _routineService.getMedicationsByElderId(widget.elderId);

      _timelineItems = [
        ...tasks.map((t) => {'type': 'task', 'data': t, 'time': t['Time'] ?? '00:00'}),
        ...meds.map((m) => {
          'type': 'medication', 
          'data': m, 
          'time': _extractTimeFromMed(m)
        }),
      ];

      _timelineItems.sort((a, b) => (a['time'] as String).compareTo(b['time'] as String));

    } catch (e) {
      print("Error loading routine: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  
  String _extractTimeFromMed(Medication med) {
    if (med.frequency.toLowerCase().contains('morning')) return '08:00';
    if (med.frequency.toLowerCase().contains('afternoon')) return '13:00';
    if (med.frequency.toLowerCase().contains('evening')) return '18:00';
    if (med.frequency.toLowerCase().contains('night')) return '20:00';
    return '09:00'; 
  }

  @override
  Widget build(BuildContext context) {
    const brown = Color(0xFF4E342E);
    const brownDark = Color(0xFF3E2723);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F3F0),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: BackButton(color: brown),
        title: Text("Today's Routine", style: TextStyle(color: brown, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : _timelineItems.isEmpty 
            ? _buildEmptyState()
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _timelineItems.length,
                itemBuilder: (context, index) {
                  final item = _timelineItems[index];
                  if (item['type'] == 'medication') {
                    return _buildMedicationCard(item['data'] as Medication, item['time']);
                  } else {
                    return _buildTaskCard(item['data'], item['time']);
                  }
                },
              ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
           final result = await Navigator.push(
             context,
             MaterialPageRoute(
               builder: (_) => AddRoutinePage(
                 elderId: widget.elderId,
                 selectedDate: _selectedDate,
               ),
             ),
           );
           if (result == true) {
             _loadRoutineData();
           }
        },
        backgroundColor: brownDark,
        icon: const Icon(Icons.add),
        label: const Text("Add Task"),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_available, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text("No tasks for today", style: TextStyle(fontSize: 18, color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildMedicationCard(Medication med, String time) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.medication, color: Colors.redAccent),
        ),
        title: Text(med.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text("${med.dosage} • ${med.frequency}"),
        trailing: Text(time, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black54)),
      ),
    );
  }

  Widget _buildTaskCard(Map<String, dynamic> task, String time) {
    bool isCompleted = task['completed'] ?? false;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(12)),
          child: Icon(isCompleted ? Icons.check_circle : Icons.schedule, color: isCompleted ? Colors.green : Colors.blue),
        ),
        title: Text(
          task['taskName'] ?? 'Unnamed Task',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            decoration: isCompleted ? TextDecoration.lineThrough : null,
            color: isCompleted ? Colors.grey : Colors.black
          ),
        ),
        subtitle: Text(task['description'] ?? 'No description'),
        trailing: Switch(
          value: isCompleted,
          onChanged: (val) async {
             setState(() => task['completed'] = val);
             await _scheduleService.updateTaskStatus(widget.elderId, _selectedDate, task['taskId'], val);
          },
        ),
      ),
    );
  }
}
