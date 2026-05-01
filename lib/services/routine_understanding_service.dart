import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'schedule_service.dart';
import '../models/schedule_model.dart';

class RoutineUnderstandingService {
  final ScheduleService _scheduleService = ScheduleService();

  /// Analyzes user input to see if it matches any scheduled tasks.
  /// status can be 'completed', 'missed', etc.
  Future<void> processSpeechInput(String uid, String text, {String? backendIntent}) async {
    final now = DateTime.now();
    final dateStr = DateFormat('yyyy-MM-dd').format(now);
    
    // 1. Fetch current schedule
    final scheduleData = await _scheduleService.getScheduleFromFirestore(uid, now);
    if (scheduleData == null || scheduleData['tasks'] == null) return;

    List<dynamic> tasks = List<dynamic>.from(scheduleData['tasks']);
    
    // 2. Simple Rule-based matching for now (can be enhanced with AI)
    String normalizedText = text.toLowerCase();
    
    for (var taskMap in tasks) {
      String taskName = (taskMap['task_name'] ?? taskMap['taskName'] ?? "").toLowerCase();
      if (taskName.isEmpty) continue;

      // Check if task name is mentioned in speech
      if (normalizedText.contains(taskName)) {
        // Determine action from text
        if (_isCompletion(normalizedText)) {
          await _scheduleService.updateFirestoreTaskStatus(
            uid, 
            now, 
            taskMap['id']?.toString() ?? "", 
            true, 
            status: 'completed_likely'
          );
        } else if (_isMissed(normalizedText)) {
          await _scheduleService.updateFirestoreTaskStatus(
            uid, 
            now, 
            taskMap['id']?.toString() ?? "", 
            false, 
            status: 'missed_likely'
          );
        }
      }
    }
    
    // 3. Handle specific intents from backend if available
    if (backendIntent != null && backendIntent != 'none') {
       // Future: Use backend intent to map to specific tasks
    }
  }

  bool _isCompletion(String text) {
    final keywords = ['took', 'done', 'finished', 'had', 'already', 'completed', 'yes'];
    return keywords.any((k) => text.contains(k));
  }

  bool _isMissed(String text) {
    final keywords = ['forgot', 'missed', 'didn\'t', 'not yet', 'no'];
    return keywords.any((k) => text.contains(k));
  }
  
  /// Formulate a verification question based on task
  String getVerificationQuestion(String taskName) {
    if (taskName.toLowerCase().contains('med') || taskName.toLowerCase().contains('pill')) {
      return "Did you take your $taskName?";
    }
    if (taskName.toLowerCase().contains('breakfast') || taskName.toLowerCase().contains('lunch') || taskName.toLowerCase().contains('dinner')) {
      return "Did you have your $taskName?";
    }
    return "Have you finished $taskName yet?";
  }
}
