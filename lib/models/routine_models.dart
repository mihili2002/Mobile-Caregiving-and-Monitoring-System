class Medication {
  final String? id;
  final String name;
  final String dosage;
  final String frequency;
  final String? elderId;
  final DateTime? startDate;
  final DateTime? endDate;

  Medication({
    this.id,
    required this.name,
    required this.dosage,
    required this.frequency,
    this.elderId,
    this.startDate,
    this.endDate,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'dosage': dosage,
      'frequency': frequency,
      'elderId': elderId,
      'startDate': startDate?.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
    };
  }

  factory Medication.fromJson(Map<String, dynamic> map, String id) {
    return Medication(
      id: id,
      name: map['name'] ?? '',
      dosage: map['dosage'] ?? '',
      frequency: map['frequency'] ?? '',
      elderId: map['elderId'],
      startDate: map['startDate'] != null ? DateTime.tryParse(map['startDate']) : null,
      endDate: map['endDate'] != null ? DateTime.tryParse(map['endDate']) : null,
    );
  }
}

class TherapistActivity {
  final String title;
  final String description;
  final String elderId;
  final DateTime assignedDate;

  TherapistActivity({
    required this.title,
    required this.description,
    required this.elderId,
    required this.assignedDate,
  });

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'elderId': elderId,
      'assignedDate': assignedDate.toIso8601String(),
    };
  }

  factory TherapistActivity.fromJson(Map<String, dynamic> json) {
    return TherapistActivity(
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      elderId: json['elderId'] ?? '',
      assignedDate: DateTime.tryParse(json['assignedDate'] ?? '') ?? DateTime.now(),
    );
  }
}

class CommonTask {
  final String taskName;
  final String taskType;
  final String timeString; // HH:mm
  final String uid;

  CommonTask({
    required this.taskName,
    required this.taskType,
    required this.timeString,
    required this.uid,
  });

  Map<String, dynamic> toJson() {
    return {
      'task_name': taskName,
      'task_type': taskType,
      'time_string': timeString,
      'uid': uid,
    };
  }

  factory CommonTask.fromJson(Map<String, dynamic> json) {
    return CommonTask(
      taskName: json['task_name'] ?? '',
      taskType: json['task_type'] ?? '',
      timeString: json['time_string'] ?? '',
      uid: json['uid'] ?? '',
    );
  }
}

class RoutineAIInsights {
  final String prediction;
  final double confidence;

  RoutineAIInsights({required this.prediction, required this.confidence});

  factory RoutineAIInsights.fromJson(Map<String, dynamic> json) {
    return RoutineAIInsights(
      prediction: json['prediction'] ?? 'No prediction',
      confidence: (json['confidence'] ?? 0.0).toDouble(),
    );
  }
}
