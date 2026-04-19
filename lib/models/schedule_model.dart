// lib/models/schedule_model.dart

class Schedule {
  final String userID;
  final String userName;
  final String date;
  final List<ScheduleTask> tasks;

  Schedule({
    required this.userID,
    required this.userName,
    required this.date,
    required this.tasks,
  });

  factory Schedule.fromJson(Map<String, dynamic> json) {
    return Schedule(
      userID: json['UserID'] ?? json['userId'] ?? json['uid'] ?? '',
      userName: json['UserName'] ?? json['userName'] ?? '',
      date: json['Date'] ?? json['date'] ?? '',
      tasks: (json['tasks'] as List<dynamic>?)
              ?.map((e) => ScheduleTask.fromJson(Map<String, dynamic>.from(e)))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userID,
      'userName': userName,
      'date': date,
      'tasks': tasks.map((e) => e.toJson()).toList(),
    };
  }
}

class ScheduleTask {
  final String taskId;
  final int taskNumber;
  final String taskName;
  final String time;
  final String type;
  final bool isCompleted;
  final String status;

  final String? scheduledAt;
  final String? validFrom;
  final String? validUntil;

  final int? graceMinutes;
  final int? retryCount;
  final int? maxRetries;
  final int? retryIntervalMinutes;

  final String? lastReminderAt;
  final String? acknowledgedAt;
  final String? startedAt;
  final String? skippedAt;
  final String? skipReason;
  final String? snoozedUntil;

  final String? completedAt;
  final String? completedBy;

  final String? priority;
  final String? riskLevel;
  final String? recurrenceRule;

  final bool? caregiverNotified;
  final bool? escalateOnMiss;

  final String? createdAt;
  final String? updatedAt;

  ScheduleTask({
    required this.taskId,
    required this.taskNumber,
    required this.taskName,
    required this.time,
    required this.type,
    required this.isCompleted,
    this.status = 'pending',
    this.scheduledAt,
    this.validFrom,
    this.validUntil,
    this.graceMinutes,
    this.retryCount,
    this.maxRetries,
    this.retryIntervalMinutes,
    this.lastReminderAt,
    this.acknowledgedAt,
    this.startedAt,
    this.skippedAt,
    this.skipReason,
    this.snoozedUntil,
    this.completedAt,
    this.completedBy,
    this.priority,
    this.riskLevel,
    this.recurrenceRule,
    this.caregiverNotified,
    this.escalateOnMiss,
    this.createdAt,
    this.updatedAt,
  });

  factory ScheduleTask.fromJson(Map<String, dynamic> json) {
    final completed = json['isCompleted'] ?? json['completed'] ?? false;

    return ScheduleTask(
      taskId: json['taskId'] ?? json['id'] ?? '',
      taskNumber: json['taskNumber'] ?? 0,
      taskName: json['taskName'] ?? json['task_name'] ?? '',
      time: json['Time'] ?? json['time'] ?? '',
      type: json['Type'] ?? json['type'] ?? 'common',
      isCompleted: completed,
      status: json['status'] ?? (completed == true ? 'completed_confirmed' : 'scheduled'),
      scheduledAt: json['scheduledAt'],
      validFrom: json['validFrom'],
      validUntil: json['validUntil'],
      graceMinutes: json['graceMinutes'],
      retryCount: json['retryCount'],
      maxRetries: json['maxRetries'],
      retryIntervalMinutes: json['retryIntervalMinutes'],
      lastReminderAt: json['lastReminderAt'],
      acknowledgedAt: json['acknowledgedAt'],
      startedAt: json['startedAt'],
      skippedAt: json['skippedAt'],
      skipReason: json['skipReason'],
      snoozedUntil: json['snoozedUntil'],
      completedAt: json['completedAt'],
      completedBy: json['completedBy'],
      priority: json['priority'],
      riskLevel: json['riskLevel'],
      recurrenceRule: json['recurrenceRule'],
      caregiverNotified: json['caregiverNotified'],
      escalateOnMiss: json['escalateOnMiss'],
      createdAt: json['createdAt'],
      updatedAt: json['updatedAt'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': taskId,
      'taskNumber': taskNumber,
      'task_name': taskName,
      'time': time,
      'type': type,
      'completed': isCompleted,
      'status': status,
      'scheduledAt': scheduledAt,
      'validFrom': validFrom,
      'validUntil': validUntil,
      'graceMinutes': graceMinutes,
      'retryCount': retryCount,
      'maxRetries': maxRetries,
      'retryIntervalMinutes': retryIntervalMinutes,
      'lastReminderAt': lastReminderAt,
      'acknowledgedAt': acknowledgedAt,
      'startedAt': startedAt,
      'skippedAt': skippedAt,
      'skipReason': skipReason,
      'snoozedUntil': snoozedUntil,
      'completedAt': completedAt,
      'completedBy': completedBy,
      'priority': priority,
      'riskLevel': riskLevel,
      'recurrenceRule': recurrenceRule,
      'caregiverNotified': caregiverNotified,
      'escalateOnMiss': escalateOnMiss,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  bool get isActiveLike => const [
        'scheduled',
        'upcoming',
        'reminder_triggered',
        'acknowledged',
        'snoozed',
        'in_progress',
      ].contains(status);

  bool get isFinishedLike => const [
        'completed_confirmed',
        'completed_likely',
        'skipped',
        'missed_likely',
        'missed_confirmed',
        'needs_caregiver_review',
        'escalated',
      ].contains(status);
}