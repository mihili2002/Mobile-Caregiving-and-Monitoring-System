// lib/models/routine_models.dart

class RoutineAIInsights {
  final double? completionProb;
  final double? expectedDelay;
  final int? predictedRetries;
  final int? predictedSnoozes;
  final bool? needsEscalation;

  RoutineAIInsights({
    this.completionProb,
    this.expectedDelay,
    this.predictedRetries,
    this.predictedSnoozes,
    this.needsEscalation,
  });

  factory RoutineAIInsights.fromJson(Map<String, dynamic> json) {
    return RoutineAIInsights(
      completionProb: json['ai_completion_prob']?.toDouble() ?? json['completion_probability']?.toDouble(),
      expectedDelay: json['ai_expected_delay']?.toDouble() ?? json['expected_delay_minutes']?.toDouble(),
      predictedRetries: json['ai_predicted_retries'] ?? json['predicted_reminder_retries'], // Fixed key
      predictedSnoozes: json['ai_predicted_snoozes'] ?? json['predicted_snooze_count'], // Fixed key
      needsEscalation: json['ai_needs_escalation'] ?? json['escalation_risk'], // Fixed key
    );
  }
}

// BUCKET A: Common Routine
class CommonTask {
  final String? id;
  final String? uid; // Added uid
  final String taskName;
  final String defaultTime;
  final RoutineAIInsights? aiInsights; 

  CommonTask({
    this.id, 
    this.uid,
    required this.taskName, 
    required this.defaultTime, 
    this.aiInsights
  });

  Map<String, dynamic> toJson() {
    return {
      'uid': uid, // Send uid to backend
      'task_name': taskName,
      'default_time': defaultTime,
      'type': 'common',
    };
  }

  factory CommonTask.fromJson(Map<String, dynamic> json) {
    return CommonTask(
      id: json['id']?.toString(), 
      uid: json['uid'],
      taskName: json['task_name'],
      defaultTime: json['default_time'] ?? json['task_time'] ?? "00:00",
      aiInsights: RoutineAIInsights.fromJson(json), 
    );
  }
}

// BUCKET B: Therapist Activity
class TherapistActivity {
  final String? id;
  final String? elderId;
  final String activityName;
  final String? duration; 
  final String? assignedTime; 
  final bool? isActive;
  final RoutineAIInsights? aiInsights;

  TherapistActivity({
    this.id,
    this.elderId,
    required this.activityName,
    this.duration,
    this.assignedTime,
    this.isActive,
    this.aiInsights,
  });

  Map<String, dynamic> toJson() { 
    return {
      'activity_name': activityName,
      'duration': duration,
      'assigned_time': assignedTime,
      'elder_id': elderId,
      'is_active': isActive,
      'type': 'therapist',
    };
  }

  factory TherapistActivity.fromJson(Map<String, dynamic> json) {
    return TherapistActivity(
      id: json['id']?.toString(),
      elderId: json['elder_id'],
      activityName: json['activity_name'] ?? json['name'] ?? 'Unknown Activity',
      duration: json['duration'],
      assignedTime: json['assigned_time'],
      isActive: json['is_active'],
      aiInsights: RoutineAIInsights.fromJson(json),
    );
  }
}

// BUCKET C: Medication
class Medication {
  final String? id;
  final String? elderId;
  final String drugName; // Renamed to drugName to match your UI
  final String? dosage;
  final List<String>? frequency;
  final List<String>? times;
  final bool? isActive;
  final String? timing; 
  final String? startDate;
  final String? endDate;
  final RoutineAIInsights? aiInsights;

  Medication({
    this.id,
    this.elderId,
    required this.drugName,
    this.dosage,
    this.frequency,
    this.times,
    this.isActive,
    this.timing,
    this.startDate,
    this.endDate,
    this.aiInsights,
  });
  
  // Compatibility getter: If other files ask for .name, give them .drugName
  String get name => drugName;

  Map<String, dynamic> toJson() {
    return {
      'drug_name': drugName, // Backend will save this key
      'timing': timing,
      'dosage': dosage,
      'frequency': frequency,
      'times': times,
      'elder_id': elderId,
      'is_active': isActive,
      'start_date': startDate,
      'end_date': endDate,
      'type': 'medication',
    };
  }

  factory Medication.fromJson(Map<String, dynamic> json) {
    return Medication(
      id: json['id']?.toString(),
      elderId: json['elder_id'],
      // Handle fallback if backend sends 'name' or 'drug_name'
      drugName: json['drug_name'] ?? json['name'] ?? 'Unknown Drug',
      dosage: json['dosage'],
      frequency: json['frequency'] != null ? List<String>.from(json['frequency']) : [],
      times: json['times'] != null ? List<String>.from(json['times']) : [],
      isActive: json['is_active'],
      timing: json['timing'],
      startDate: json['start_date'],
      endDate: json['end_date'],
      aiInsights: RoutineAIInsights.fromJson(json),
    );
  }
}